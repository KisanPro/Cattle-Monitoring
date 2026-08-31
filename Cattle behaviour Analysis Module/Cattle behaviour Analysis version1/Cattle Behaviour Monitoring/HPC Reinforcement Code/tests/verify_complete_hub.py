import os
import sys
import shutil
import numpy as np
from pathlib import Path
from datetime import datetime, timedelta

# Add project root to path
sys.path.append(os.getcwd())

from app.core.database import init_db, get_db_connection, get_db_path
from app.services.baseline_service import update_baseline, get_anomaly_z_scores, calculate_health_score
from app.services.alert_service import evaluate_behavior_and_alert
from app.services.global_train_service import run_global_distillation
from app.core.config import settings

# Test tenant IDs
TENANT_A = "Geetha_8796547890_Blessing_Farm"
TENANT_B = "Sunita_7775533221_Samruddhi_Farm"

def seed_historical_data(tenant_id: str, cow_id: str):
    """
    Populates SQLite database with 21 days of normal cow behavior logs.
    """
    init_db(tenant_id)
    conn = get_db_connection(tenant_id)
    cursor = conn.cursor()
    
    start_date = datetime.now() - timedelta(days=22)
    
    print(f"🌱 Seeding 21 days of baseline telemetry for {cow_id} in {tenant_id}...")
    for day in range(22):
        timestamp = (start_date + timedelta(days=day)).strftime("%Y-%m-%d")
        
        # Introduce mild random variation around standard dairy cow profiles
        standing = int(np.random.normal(36000, 1800)) # ~10 hours
        lying = int(np.random.normal(36000, 1800))    # ~10 hours
        eating = int(np.random.normal(14400, 900))    # ~4 hours
        rumination = int(np.random.normal(28800, 1200)) # ~8 hours
        activity = float(np.random.normal(85.0, 5.0))
        
        cursor.execute("""
            INSERT OR REPLACE INTO cow_daily_metrics 
            (cow_id, standing_duration, lying_duration, eating_duration, rumination_duration, activity_score, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (cow_id, standing, lying, eating, rumination, activity, timestamp))
        
    conn.commit()
    conn.close()

def create_mock_train_vectors(tenant_id: str, classes=["standing", "lying"]):
    """
    Writes mock training .npy vectors directly to the tenant's training datasets folders.
    """
    from app.core.config import TenantContext
    tenant = TenantContext(tenant_id, Path(settings.farms_dir))
    
    for cls in classes:
        cls_dir = tenant.datasets_dir / "train" / cls
        cls_dir.mkdir(parents=True, exist_ok=True)
        
        # Write dummy 1280 dimension vectors
        for i in range(3):
            dummy_vector = np.random.randn(1, 1280).astype(np.float32)
            np.save(cls_dir / f"vector_sample_{i}.npy", dummy_vector)
            
    print(f"📂 Created mock training vectors in {tenant.datasets_dir}.")

def run_integration_test():
    print("====================================================")
    print("🚀 Running Complete Kisan Hub Core Verification Test...")
    print("====================================================")
    
    # Clean previous state
    farms_dir = Path(settings.farms_dir)
    global_dir = Path("global_workspace")
    if farms_dir.exists():
        shutil.rmtree(farms_dir)
    if global_dir.exists():
        shutil.rmtree(global_dir)
        
    cow_id = "COW-B642"
    
    # 1. Seed historical telemetry
    seed_historical_data(TENANT_A, cow_id)
    
    # 2. Compute rolling baseline (21 days)
    success = update_baseline(TENANT_A, cow_id)
    assert success, "Baseline calculation failed!"
    
    # Verify baseline database entries
    conn = get_db_connection(TENANT_A)
    cursor = conn.cursor()
    cursor.execute("SELECT metric, mean, std_dev FROM baselines WHERE cow_id = ?", (cow_id,))
    baseline_records = cursor.fetchall()
    conn.close()
    
    assert len(baseline_records) == 4, "Not all baseline behavior metrics recorded!"
    print("✅ Rolling baseline successfully calculated and saved to SQLite.")
    
    # 3. Simulate an anomaly (severe rumination drop - 80% lower than normal)
    # Target rumination is ~28800. We pass 5000 seconds (under 1.5 hours)
    anomaly_metrics = {
        "standing_duration": 36000,
        "lying_duration": 36000,
        "eating_duration": 14400,
        "rumination_duration": 5000 # Critical drop
    }
    
    print("\n🔍 Feeding anomalous telemetry day to check Alert Intelligence Engine...")
    alerts, health = evaluate_behavior_and_alert(TENANT_A, cow_id, anomaly_metrics)
    
    print(f"📊 Calculated Behavioral Health Score: {health:.1f}/100")
    assert health < 80.0, "Anomalous day did not reduce health score!"
    
    # Verify alerts are generated
    assert len(alerts) > 0, "No alerts generated for critical behavior drop!"
    assert any(a["severity"] == "CRITICAL" for a in alerts), "No CRITICAL alert generated!"
    print(f"✅ Alert Intelligence Engine successfully raised CRITICAL notification.")
    
    # Verify alerts table in tenant SQLite
    conn = get_db_connection(TENANT_A)
    cursor = conn.cursor()
    cursor.execute("SELECT severity, reason FROM alerts WHERE cow_id = ?", (cow_id,))
    saved_alerts = cursor.fetchall()
    conn.close()
    
    assert len(saved_alerts) > 0, "Alerts were not saved to tenant isolated database!"
    print(f"✅ Anomaly logged strictly within isolated database: {get_db_path(TENANT_A)}")
    
    # 4. Generate mock vectors across multiple farms to test Global Distillation
    print("\n📦 Simulating continuous dataset accumulation for multiple farms...")
    create_mock_train_vectors(TENANT_A)
    create_mock_train_vectors(TENANT_B)
    
    # 5. Execute Global Model Distillation Pipeline
    base_model = run_global_distillation()
    assert base_model is not None, "Global training failed!"
    assert Path(base_model).exists(), "Global base model not generated!"
    print(f"✅ Global Model Distillation Pipeline executed. Saved to {base_model}")
    
    print("\n🎉 ALL COMPLETE CORE ENGINE TESTS COMPLETED SUCCESSFULLY!")
    
    # Clean up test directories
    if farms_dir.exists():
        shutil.rmtree(farms_dir)
    if global_dir.exists():
        shutil.rmtree(global_dir)
    print("🧹 Workspace cleaned up successfully.")

if __name__ == "__main__":
    run_integration_test()
