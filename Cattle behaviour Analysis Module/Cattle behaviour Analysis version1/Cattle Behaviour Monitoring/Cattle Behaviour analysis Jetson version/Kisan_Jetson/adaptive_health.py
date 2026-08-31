"""
adaptive_health.py  –  Kisan CattleVision Personalized Behavioral Baseline Engine
Fully path-relative, dynamically references external Passport storage.
"""
import os
import json
import pandas as pd
import numpy as np
import time
from datetime import datetime

def get_user_prefix():
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, "config.json")
        with open(config_path) as f:
            c = json.load(f)
    except Exception:
        c = {}
    uname = str(c.get("user_name", "User")).replace(" ", "_")
    phone = str(c.get("phone", "Phone")).replace(" ", "_")
    fname = str(c.get("farm_name", "Farm")).replace(" ", "_")
    return f"{uname}_{phone}_{fname}"

script_dir = os.path.dirname(os.path.abspath(__file__))
from storage_utils import get_base_storage
BASE_STORAGE = get_base_storage(script_dir)
DATABASE_FILE = os.path.join(BASE_STORAGE, "behavior_logs.csv")
BASELINES_FILE = os.path.join(BASE_STORAGE, "cattle_baselines.json")

_cached_df = None
_df_mtime = 0
_df_cache_time = 0

def load_behavior_df():
    global _cached_df, _df_mtime, _df_cache_time
    if not os.path.exists(DATABASE_FILE):
        return None
    try:
        mtime = os.path.getmtime(DATABASE_FILE)
        now = time.time()
        if _cached_df is not None and now - _df_cache_time < 5.0:
            return _cached_df
        
        _cached_df = pd.read_csv(DATABASE_FILE, on_bad_lines="skip")
        _df_mtime = mtime
        _df_cache_time = now
        return _cached_df
    except Exception as e:
        print(f"[adaptive_health] Error reading database: {e}")
        return None

def compute_baselines():
    """Reads behavior_logs.csv and computes rolling 21-day baseline averages for each cattle."""
    try:
        raw_df = load_behavior_df()
        if raw_df is None or raw_df.empty:
            return {}
        df = raw_df.copy()
        if "Entity_ID" not in df.columns or "Timestamp" not in df.columns:
            return {}
        if "Duration_Sec" not in df.columns:
            df["Duration_Sec"] = 0.0

        df["dt_parsed"] = pd.to_datetime(df["Timestamp"], format="%d-%m-%Y %I:%M:%S %p", errors="coerce")
        df = df.dropna(subset=["dt_parsed"])
        if df.empty:
            return {}

        df["date_str"] = df["dt_parsed"].dt.strftime("%Y-%m-%d")
        baselines      = {}

        for cattle_id, group in df.groupby("Entity_ID"):
            cs = str(cattle_id).strip().upper()
            if not cs or cs == "NAN" or "ANALYSING" in cs or cs == "UNCERTAIN":
                continue

            unique_days = sorted(group["date_str"].unique())
            # Rolling 21-day window
            target_days = unique_days[-21:]
            day_count   = len(target_days)
            if day_count == 0:
                continue

            sub_df     = group[group["date_str"].isin(target_days)]
            daily_stats = []

            for day in target_days:
                day_df = sub_df[sub_df["date_str"] == day]
                
                # Compute transitions
                day_df_sorted = day_df.sort_values("dt_parsed")
                transitions = 0
                prev_posture = None
                for idx, row in day_df_sorted.iterrows():
                    p = row.get("Posture")
                    if p != prev_posture and prev_posture is not None:
                        transitions += 1
                    prev_posture = p

                daily_stats.append({
                    "standing": day_df[day_df["Posture"] == "Standing"]["Duration_Sec"].sum() / 3600.0,
                    "lying":    day_df[day_df["Posture"] == "Lying"]["Duration_Sec"].sum() / 3600.0,
                    "feeding":  day_df[day_df["Feeding"] == "Feeding_Behaviour"]["Duration_Sec"].sum() / 3600.0,
                    "idle":     day_df[day_df["Feeding"] == "Idle_Behaviour"]["Duration_Sec"].sum() / 3600.0,
                    "transitions": transitions
                })

            baselines[cs] = {
                "standing_avg": round(sum(d["standing"] for d in daily_stats) / day_count, 2),
                "lying_avg":    round(sum(d["lying"]    for d in daily_stats) / day_count, 2),
                "feeding_avg":  round(sum(d["feeding"]  for d in daily_stats) / day_count, 2),
                "idle_avg":     round(sum(d["idle"]     for d in daily_stats) / day_count, 2),
                "transitions_avg": round(sum(d["transitions"] for d in daily_stats) / day_count, 2),
                "learning_mode": day_count < 21,
                "days_learned":  day_count,
            }

        os.makedirs(BASE_STORAGE, exist_ok=True)
        with open(BASELINES_FILE, "w") as f:
            json.dump(baselines, f, indent=4)
        print(f"[adaptive_health] Rolling 21-day baselines saved for {len(baselines)} cattle.")
        return baselines
    except Exception as e:
        print(f"[adaptive_health] Error computing baselines: {e}")
        return {}


_cached_baselines = None
_baselines_mtime = 0
_baselines_cache_time = 0

def load_baselines():
    global _cached_baselines, _baselines_mtime, _baselines_cache_time
    if os.path.exists(BASELINES_FILE):
        try:
            mtime = os.path.getmtime(BASELINES_FILE)
            now = time.time()
            if _cached_baselines is not None and now - _baselines_cache_time < 5.0:
                return _cached_baselines
            with open(BASELINES_FILE) as f:
                _cached_baselines = json.load(f)
            _baselines_mtime = mtime
            _baselines_cache_time = now
            return _cached_baselines
        except Exception:
            pass
    return compute_baselines()


_eval_cache = {}
_cache_time = 0

def evaluate_current_behavior(cattle_id):
    """
    Evaluates today's behavior deviations against the personalized rolling baseline 
    to compute Behavior Health Score (0-100), severity class, and why/explanation.
    """
    global _eval_cache, _cache_time
    cattle_id = str(cattle_id).strip().upper()
    if not cattle_id or cattle_id == "NAN" or cattle_id == "UNCERTAIN" or "ANALYSING" in cattle_id:
        return {
            "cattle_id":    cattle_id,
            "risk_score":   0,
            "health_score": 100,
            "status":       "Normal",
            "learning_mode": False,
            "days_learned":  0,
            "baseline":      {},
            "current":       {"standing": 0.0, "lying": 0.0, "feeding": 0.0, "idle": 0.0, "transitions": 0},
            "deviations":    {"standing": 0.0, "lying": 0.0, "feeding": 0.0, "idle": 0.0, "transitions": 0},
            "why":           "N/A",
            "confidence":    99,
            "recommendation": "N/A"
        }
    now = time.time()
    if now - _cache_time < 5.0 and cattle_id in _eval_cache:
        return _eval_cache[cattle_id]

    baselines  = load_baselines()
    profile    = baselines.get(cattle_id, {
        "standing_avg": 8.0, "lying_avg": 8.0,
        "feeding_avg":  4.0, "idle_avg":  4.0,
        "transitions_avg": 25.0,
        "learning_mode": True, "days_learned": 0,
    })

    empty_result = {
        "cattle_id":    cattle_id,
        "risk_score":   0,
        "health_score": 100,
        "status":       "Learning Mode" if profile["learning_mode"] else "Normal",
        "learning_mode": profile["learning_mode"],
        "days_learned":  profile["days_learned"],
        "baseline":      profile,
        "current":       {"standing": 0.0, "lying": 0.0, "feeding": 0.0, "idle": 0.0, "transitions": 0},
        "deviations":    {"standing": 0.0, "lying": 0.0, "feeding": 0.0, "idle": 0.0, "transitions": 0},
        "why":           "Insufficient behavior logs recorded for this cattle yet.",
        "confidence":    50,
        "recommendation": "Allow learning period to complete (21 days) to establish baseline."
    }

    if not os.path.exists(DATABASE_FILE):
        return empty_result

    try:
        raw_df = load_behavior_df()
        if raw_df is None or raw_df.empty:
            return empty_result
        df = raw_df.copy()
        if "Duration_Sec" not in df.columns:
            df["Duration_Sec"] = 0.0
        cow_df = df[df["Entity_ID"].astype(str).str.strip().str.upper() == cattle_id]
        if cow_df.empty:
            return empty_result

        cow_df["dt_parsed"] = pd.to_datetime(cow_df["Timestamp"], format="%d-%m-%Y %I:%M:%S %p", errors="coerce")
        cow_df = cow_df.dropna(subset=["dt_parsed"])
        if cow_df.empty:
            return empty_result

        cow_df["date_str"] = cow_df["dt_parsed"].dt.strftime("%Y-%m-%d")
        latest_day = cow_df["date_str"].max()
        day_df     = cow_df[cow_df["date_str"] == latest_day]
        day_df_sorted = day_df.sort_values("dt_parsed")

        cur_standing = day_df[day_df["Posture"] == "Standing"]["Duration_Sec"].sum() / 3600.0
        cur_lying    = day_df[day_df["Posture"] == "Lying"]["Duration_Sec"].sum() / 3600.0
        cur_feeding  = day_df[day_df["Feeding"] == "Feeding_Behaviour"]["Duration_Sec"].sum() / 3600.0
        cur_idle     = day_df[day_df["Feeding"] == "Idle_Behaviour"]["Duration_Sec"].sum() / 3600.0

        cur_transitions = 0
        prev_posture = None
        for idx, row in day_df_sorted.iterrows():
            p = row.get("Posture")
            if p != prev_posture and prev_posture is not None:
                cur_transitions += 1
            prev_posture = p

        b_s = max(0.1, profile["standing_avg"])
        b_l = max(0.1, profile["lying_avg"])
        b_f = max(0.1, profile["feeding_avg"])
        b_i = max(0.1, profile["idle_avg"])
        b_t = max(1.0, profile["transitions_avg"])

        standing_dev = (cur_standing - b_s) / b_s
        lying_dev    = (cur_lying - b_l) / b_l
        feeding_dev  = (cur_feeding - b_f) / b_f
        idle_dev     = (cur_idle - b_i) / b_i
        trans_dev    = (cur_transitions - b_t) / b_t

        # Deduct health points for behavior deviations
        deductions = 0.0
        
        # 1. Feeding drop (extremely significant)
        if feeding_dev < -0.20:
            deductions += abs(feeding_dev) * 60.0
        # 2. Lying deviations
        if abs(lying_dev) > 0.15:
            deductions += min(25.0, abs(lying_dev) * 30.0)
        # 3. Standing deviations
        if abs(standing_dev) > 0.15:
            deductions += min(20.0, abs(standing_dev) * 25.0)
        # 4. Inactivity (Idle increase)
        if idle_dev > 0.20:
            deductions += min(20.0, idle_dev * 20.0)
        # 5. Activity drop (transitions)
        if trans_dev < -0.30:
            deductions += abs(trans_dev) * 15.0

        health_score = max(0, min(100, int(100 - deductions)))

        status = "Normal"
        if health_score >= 85:
            status = "Normal"
        elif health_score >= 70:
            status = "Warning"
        elif health_score >= 45:
            status = "High Risk"
        else:
            status = "Critical"

        # Critical override rules (emergencies)
        is_emergency = False
        emergency_reason = ""
        if cur_feeding == 0.0 and b_f > 1.0:
            is_emergency = True
            emergency_reason = "No feeding detected today."
            health_score = min(health_score, 18)
            status = "Critical"
        elif cur_lying > 18.0:
            is_emergency = True
            emergency_reason = "Continuous lying duration (>18 hours) detected."
            health_score = min(health_score, 18)
            status = "Critical"

        # If in learning mode and no emergency, label status as Learning Mode
        is_learning = profile["learning_mode"]
        if is_learning and not is_emergency:
            status = "Learning Mode"

        # Compute Confidence Score
        base_conf = 50 + min(40, profile["days_learned"] * 2)
        if status in ["High Risk", "Critical"]:
            base_conf += 10
        confidence = min(99, base_conf)

        # Build detailed explanations
        why_list = []
        rec_list = []

        if feeding_dev < -0.20:
            why_list.append(f"Feeding duration is reduced by {abs(feeding_dev)*100:.0f}% vs baseline ({cur_feeding:.1f}h vs {b_f:.1f}h).")
            rec_list.append("Inspect feed troughs and ensure fresh feed supply is accessible.")
        if lying_dev > 0.20:
            why_list.append(f"Lying duration is increased by {lying_dev*100:.0f}% vs baseline ({cur_lying:.1f}h vs {b_l:.1f}h).")
            rec_list.append("Observe for potential signs of lameness, milk fever, or exhaustion.")
        elif lying_dev < -0.20:
            why_list.append(f"Lying duration is decreased by {abs(lying_dev)*100:.0f}% vs baseline ({cur_lying:.1f}h vs {b_l:.1f}h).")
            rec_list.append("Check comfort of cubicles, bedding dryness, or signs of standing discomfort.")
        if cur_transitions < (b_t * 0.6):
            why_list.append(f"Cow transitions (lying/standing) are low ({cur_transitions} vs baseline {b_t:.0f}).")
            rec_list.append("Check mobility or joint discomfort.")

        if not why_list:
            why_list.append("Behavior patterns are stable and closely match the personalized baseline.")
            rec_list.append("No action required. Continue routine monitoring.")

        if is_emergency:
            why_list.insert(0, f"🚨 EMERGENCY: {emergency_reason}")
            rec_list.insert(0, "URGENT: Physically inspect the cow immediately.")

        res = {
            "cattle_id":    cattle_id,
            "risk_score":   100 - health_score,  # Map back to pipeline's original expectations
            "health_score": health_score,
            "status":       status,
            "learning_mode": is_learning,
            "days_learned":  profile["days_learned"],
            "baseline":      profile,
            "current":       {
                "standing": round(cur_standing, 2),
                "lying":    round(cur_lying, 2),
                "feeding":  round(cur_feeding, 2),
                "idle":     round(cur_idle, 2),
                "transitions": cur_transitions
            },
            "deviations":    {
                "standing": round(standing_dev * 100.0, 1),
                "lying":    round(lying_dev * 100.0, 1),
                "feeding":  round(feeding_dev * 100.0, 1),
                "idle":     round(idle_dev * 100.0, 1),
                "transitions": round(trans_dev * 100.0, 1),
                "standing_increase": round(max(0.0, standing_dev * 100.0), 1),
                "lying_increase":    round(max(0.0, lying_dev * 100.0), 1),
                "feeding_drop":      round(max(0.0, -feeding_dev * 100.0), 1),
                "idle_increase":     round(max(0.0, idle_dev * 100.0), 1)
            },
            "why":           " ".join(why_list),
            "confidence":    confidence,
            "recommendation": " ".join(rec_list)
        }

        if now - _cache_time > 5.0:
            _eval_cache.clear()
            _cache_time = now
        _eval_cache[cattle_id] = res
        return res
    except Exception as e:
        print(f"[adaptive_health] evaluate error: {e}")
        return empty_result
