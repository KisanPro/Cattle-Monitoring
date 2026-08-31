from datetime import datetime
import json
from app.core.database import get_db_connection
from app.services.baseline_service import get_anomaly_z_scores, calculate_health_score

def evaluate_behavior_and_alert(tenant_id: str, cow_id: str, daily_metrics: dict):
    """
    Compares daily metrics against baselines, saves anomalies as alerts,
    and returns a list of generated alerts.
    """
    z_scores = get_anomaly_z_scores(tenant_id, cow_id, daily_metrics)
    health_score = calculate_health_score(z_scores)
    
    conn = get_db_connection(tenant_id)
    cursor = conn.cursor()
    
    # Check current baseline statistics for specific drop percentage checks
    cursor.execute("SELECT mean FROM baselines WHERE cow_id = ? AND metric = 'rumination_duration'", (cow_id,))
    rumination_baseline_row = cursor.fetchone()
    rumination_baseline_mean = rumination_baseline_row["mean"] if rumination_baseline_row else None
    
    alerts_triggered = []
    timestamp_str = datetime.now().isoformat()
    
    # Rule 1: Severe Rumination Drop (Metabolic sickness indication)
    rumin_z = z_scores.get("rumination_duration", 0)
    if rumin_z < -2.0:
        severity = "WARNING"
        reason = "Significant drop in rumination time."
        
        # Check if the drop is critical (e.g. less than 45% of the average baseline)
        if rumination_baseline_mean:
            rumin_pct = daily_metrics["rumination_duration"] / rumination_baseline_mean
            if rumin_pct < 0.45:
                severity = "CRITICAL"
                reason = "Severe rumination drop (<45% of baseline). Inspect animal immediately for digestive illness."
        elif rumin_z < -3.5:
            severity = "CRITICAL"
            reason = "Severe rumination drop from baseline. Inspect animal immediately."
            
        alerts_triggered.append({
            "cow_id": cow_id,
            "reason": reason,
            "severity": severity,
            "evidence": json.dumps({"z_score": round(rumin_z, 2), "duration_seconds": daily_metrics["rumination_duration"]})
        })
        
    # Rule 2: Excessive Lying (Lameness indication)
    lying_z = z_scores.get("lying_duration", 0)
    if lying_z > 2.5:
        alerts_triggered.append({
            "cow_id": cow_id,
            "reason": f"Abnormally high lying duration (Z-score: {lying_z:.2f}). Check for potential lameness or injury.",
            "severity": "HIGH",
            "evidence": json.dumps({"z_score": round(lying_z, 2), "duration_seconds": daily_metrics["lying_duration"]})
        })
        
    # Write alerts to database
    for alert in alerts_triggered:
        cursor.execute("""
            INSERT INTO alerts (cow_id, reason, severity, evidence, timestamp, resolved)
            VALUES (?, ?, ?, ?, ?, 0)
        """, (alert["cow_id"], alert["reason"], alert["severity"], alert["evidence"], timestamp_str))
        print(f"⚠️ [{alert['severity']}] Alert generated for Cow {cow_id} in farm '{tenant_id}': {alert['reason']}")
        
    conn.commit()
    conn.close()
    return alerts_triggered, health_score
