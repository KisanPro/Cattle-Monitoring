import math
from datetime import datetime
from app.core.database import get_db_connection

METRICS_OF_INTEREST = [
    "standing_duration",
    "lying_duration",
    "eating_duration",
    "rumination_duration"
]

def update_baseline(tenant_id: str, cow_id: str):
    """
    Computes rolling mean and standard deviation for a cow's metrics over past 21 days
    and saves them to the baselines database.
    """
    conn = get_db_connection(tenant_id)
    cursor = conn.cursor()
    
    # Query past 21 days logs for this cow
    cursor.execute("""
        SELECT standing_duration, lying_duration, eating_duration, rumination_duration
        FROM cow_daily_metrics
        WHERE cow_id = ?
        ORDER BY timestamp DESC
        LIMIT 21
    """, (cow_id,))
    
    rows = cursor.fetchall()
    
    # If we have less than 3 days, we cannot compute a reliable standard deviation
    if len(rows) < 3:
        conn.close()
        return False
        
    num_days = len(rows)
    timestamp_str = datetime.now().isoformat()
    
    for metric in METRICS_OF_INTEREST:
        values = [row[metric] for row in rows]
        
        # Calculate Mean
        mean = sum(values) / num_days
        
        # Calculate Standard Deviation
        variance = sum((x - mean) ** 2 for x in values) / num_days
        std_dev = math.sqrt(variance)
        
        # Avoid division by zero: enforce min standard deviation (e.g. 60 seconds)
        if std_dev < 60:
            std_dev = 60.0
            
        # Store in baselines
        cursor.execute("""
            INSERT INTO baselines (cow_id, metric, mean, std_dev, last_updated)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(cow_id, metric) DO UPDATE SET
                mean = excluded.mean,
                std_dev = excluded.std_dev,
                last_updated = excluded.last_updated
        """, (cow_id, metric, mean, std_dev, timestamp_str))
        
    conn.commit()
    conn.close()
    return True

def get_anomaly_z_scores(tenant_id: str, cow_id: str, current_metrics: dict) -> dict:
    """
    Returns Z-scores for a cow's daily behavior metrics relative to baseline.
    """
    conn = get_db_connection(tenant_id)
    cursor = conn.cursor()
    
    cursor.execute("SELECT metric, mean, std_dev FROM baselines WHERE cow_id = ?", (cow_id,))
    baselines = {row["metric"]: (row["mean"], row["std_dev"]) for row in cursor.fetchall()}
    conn.close()
    
    z_scores = {}
    for metric in METRICS_OF_INTEREST:
        if metric in current_metrics and metric in baselines:
            mean, std_dev = baselines[metric]
            value = current_metrics[metric]
            z_scores[metric] = (value - mean) / std_dev
        else:
            # Cold start fallback if baseline is not established yet
            z_scores[metric] = 0.0
            
    return z_scores

def calculate_health_score(z_scores: dict) -> float:
    """
    Returns a health score (0-100) by penalizing high deviations from baseline.
    """
    health = 100.0
    for metric, z in z_scores.items():
        abs_z = abs(z)
        if abs_z > 2.0:
            # Penalize linearly for Z-scores past 2 standard deviations
            penalty = 15.0 * (abs_z - 1.5)
            health -= penalty
            
    return max(0.0, min(100.0, health))
