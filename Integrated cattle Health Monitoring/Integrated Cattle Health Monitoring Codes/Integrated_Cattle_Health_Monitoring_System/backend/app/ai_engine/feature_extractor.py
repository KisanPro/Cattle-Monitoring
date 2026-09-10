from datetime import date, timedelta
from typing import List, Dict, Any, Optional
import numpy as np

class FeatureExtractor:
    """
    Extracts time-series multivariable features from Milk, Weight, and Vaccination records.
    Calculates velocity, rolling averages, deviations, and trends.
    """

    @staticmethod
    def extract_features(
        milk_records: List[Dict[str, Any]],
        weight_records: List[Dict[str, Any]],
        vaccination_records: List[Dict[str, Any]],
        as_of_date: Optional[date] = None
    ) -> Dict[str, Any]:
        if as_of_date is None:
            as_of_date = date.today()

        # -------------------------------------------------------------
        # 1. Milk Feature Extraction
        # -------------------------------------------------------------
        # Aggregate daily milk liters
        daily_milk = {}
        for r in milk_records:
            r_date = r.get("record_date")
            if isinstance(r_date, str):
                r_date = date.fromisoformat(r_date)
            qty = float(r.get("quantity_liters", 0.0))
            daily_milk[r_date] = daily_milk.get(r_date, 0.0) + qty

        sorted_milk_dates = sorted(daily_milk.keys())
        
        current_milk = daily_milk.get(as_of_date, None)
        if current_milk is None and sorted_milk_dates:
            as_of_date = sorted_milk_dates[-1]
            current_milk = daily_milk[as_of_date]
        elif current_milk is None:
            current_milk = 0.0

        # Baseline (prior 7-day average excluding current day, or available historical average)
        prior_milk_vals = [daily_milk[d] for d in sorted_milk_dates if d < as_of_date]
        if len(prior_milk_vals) >= 7:
            baseline_milk_7d = float(np.mean(prior_milk_vals[-7:]))
            baseline_milk_3d = float(np.mean(prior_milk_vals[-3:]))
        elif prior_milk_vals:
            baseline_milk_7d = float(np.mean(prior_milk_vals))
            baseline_milk_3d = float(np.mean(prior_milk_vals[-min(3, len(prior_milk_vals)):]))
        else:
            baseline_milk_7d = current_milk
            baseline_milk_3d = current_milk

        peak_milk_historical = float(np.max(list(daily_milk.values()))) if daily_milk else current_milk

        delta_milk_pct_7d = ((current_milk - baseline_milk_7d) / baseline_milk_7d * 100.0) if baseline_milk_7d > 0 else 0.0
        delta_milk_pct_3d = ((current_milk - baseline_milk_3d) / baseline_milk_3d * 100.0) if baseline_milk_3d > 0 else 0.0
        delta_milk_from_peak = ((current_milk - peak_milk_historical) / peak_milk_historical * 100.0) if peak_milk_historical > 0 else 0.0

        # -------------------------------------------------------------
        # 2. Weight Feature Extraction
        # -------------------------------------------------------------
        daily_weight = {}
        for w in weight_records:
            w_date = w.get("record_date")
            if isinstance(w_date, str):
                w_date = date.fromisoformat(w_date)
            daily_weight[w_date] = float(w.get("weight_kg", 0.0))

        sorted_weight_dates = sorted(daily_weight.keys())
        
        current_weight = daily_weight.get(as_of_date, None)
        if current_weight is None and sorted_weight_dates:
            current_weight = daily_weight[sorted_weight_dates[-1]]
        elif current_weight is None:
            current_weight = 400.0 # Standard default

        prior_weight_vals = [daily_weight[d] for d in sorted_weight_dates if d < as_of_date]
        if len(prior_weight_vals) >= 7:
            baseline_weight_7d = float(np.mean(prior_weight_vals[-7:]))
        elif prior_weight_vals:
            baseline_weight_7d = float(np.mean(prior_weight_vals))
        else:
            baseline_weight_7d = current_weight

        peak_weight_historical = float(np.max(list(daily_weight.values()))) if daily_weight else current_weight

        delta_weight_kg_7d = current_weight - baseline_weight_7d
        delta_weight_pct_7d = (delta_weight_kg_7d / baseline_weight_7d * 100.0) if baseline_weight_7d > 0 else 0.0
        delta_weight_from_peak = ((current_weight - peak_weight_historical) / peak_weight_historical * 100.0) if peak_weight_historical > 0 else 0.0

        # -------------------------------------------------------------
        # 3. Vaccination Feature Extraction
        # -------------------------------------------------------------
        vaccine_status = "Up to Date"
        min_days_to_due = 999
        overdue_vaccines = []
        due_soon_vaccines = []

        for v in vaccination_records:
            due_date = v.get("next_due_date")
            if isinstance(due_date, str):
                due_date = date.fromisoformat(due_date)
            
            days_diff = (due_date - as_of_date).days
            v_name = v.get("vaccine_name", "Vaccine")

            if days_diff < 0:
                overdue_vaccines.append(f"{v_name} ({abs(days_diff)}d overdue)")
                if min_days_to_due > days_diff:
                    min_days_to_due = days_diff
            elif days_diff <= 14:
                due_soon_vaccines.append(f"{v_name} (due in {days_diff}d)")
                if min_days_to_due > days_diff:
                    min_days_to_due = days_diff
            else:
                if min_days_to_due > days_diff:
                    min_days_to_due = days_diff

        if overdue_vaccines:
            vaccine_status = "Overdue"
            vaccine_risk_score = 1.0
        elif due_soon_vaccines or min_days_to_due <= 14:
            vaccine_status = "Due Soon"
            vaccine_risk_score = 0.5
        else:
            vaccine_status = "Up to Date"
            vaccine_risk_score = 0.0

        return {
            "as_of_date": as_of_date.isoformat(),
            "current_milk": round(current_milk, 2),
            "baseline_milk_7d": round(baseline_milk_7d, 2),
            "baseline_milk_3d": round(baseline_milk_3d, 2),
            "peak_milk_historical": round(peak_milk_historical, 2),
            "delta_milk_pct_7d": round(delta_milk_pct_7d, 2),
            "delta_milk_pct_3d": round(delta_milk_pct_3d, 2),
            "delta_milk_from_peak": round(delta_milk_from_peak, 2),
            
            "current_weight": round(current_weight, 2),
            "baseline_weight_7d": round(baseline_weight_7d, 2),
            "peak_weight_historical": round(peak_weight_historical, 2),
            "delta_weight_kg_7d": round(delta_weight_kg_7d, 2),
            "delta_weight_pct_7d": round(delta_weight_pct_7d, 2),
            "delta_weight_from_peak": round(delta_weight_from_peak, 2),

            "vaccine_status": vaccine_status,
            "min_days_to_due": min_days_to_due,
            "vaccine_risk_score": vaccine_risk_score,
            "overdue_vaccines": overdue_vaccines,
            "due_soon_vaccines": due_soon_vaccines
        }
