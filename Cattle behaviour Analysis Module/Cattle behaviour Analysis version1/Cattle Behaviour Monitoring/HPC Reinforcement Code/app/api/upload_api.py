from fastapi import APIRouter, File, UploadFile, Depends, BackgroundTasks
from pathlib import Path
import shutil
from app.core.security import verify_api_token
from app.core.config import settings, TenantContext
from app.services.extract_service import extract_and_organize
from app.services.train_service import run_fine_tuning
from pydantic import BaseModel
from app.core.database import init_db, get_db_connection
from app.services.baseline_service import update_baseline
from app.services.alert_service import evaluate_behavior_and_alert

router = APIRouter()

class TelemetryData(BaseModel):
    cow_id: str
    standing_duration: int
    lying_duration: int
    eating_duration: int
    rumination_duration: int
    activity_score: float
    timestamp: str

@router.post("/telemetry")
async def upload_telemetry(
    data: TelemetryData,
    tenant: TenantContext = Depends(verify_api_token)
):
    """
    Endpoint for Jetson to upload daily telemetry metrics for a cow.
    Triggers rolling baseline updates and runs alert anomaly detection.
    """
    # Make sure DB is initialized for this tenant
    init_db(tenant.tenant_id)
    
    conn = get_db_connection(tenant.tenant_id)
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT OR REPLACE INTO cow_daily_metrics
        (cow_id, standing_duration, lying_duration, eating_duration, rumination_duration, activity_score, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        data.cow_id,
        data.standing_duration,
        data.lying_duration,
        data.eating_duration,
        data.rumination_duration,
        data.activity_score,
        data.timestamp
    ))
    conn.commit()
    conn.close()
    
    # Calculate baseline
    update_baseline(tenant.tenant_id, data.cow_id)
    
    # Run alert checking
    alerts, health_score = evaluate_behavior_and_alert(
        tenant.tenant_id,
        data.cow_id,
        {
            "standing_duration": data.standing_duration,
            "lying_duration": data.lying_duration,
            "eating_duration": data.eating_duration,
            "rumination_duration": data.rumination_duration,
            "activity_score": data.activity_score
        }
    )
    
    return {
        "status": "success",
        "message": "Telemetry metrics successfully processed.",
        "health_score": health_score,
        "alerts_generated": len(alerts)
    }

@router.post("/upload")
async def upload_batch(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    tenant: TenantContext = Depends(verify_api_token)
):
    """
    Endpoint for Jetson to upload compressed vector batches.
    Triggers extraction and background training.
    """
    incoming_path = tenant.uploads_dir / file.filename
    incoming_path.parent.mkdir(parents=True, exist_ok=True)
    
    # 1. Save File
    with open(incoming_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # 2. Extract and Organize
    extract_and_organize(incoming_path, tenant.tenant_id)
    
    # 3. Trigger Training in background
    background_tasks.add_task(run_fine_tuning, tenant.tenant_id)
    
    return {
        "status": "success",
        "message": f"Batch {file.filename} received. Intelligence Hub is now processing and training.",
        "filename": file.filename
    }
