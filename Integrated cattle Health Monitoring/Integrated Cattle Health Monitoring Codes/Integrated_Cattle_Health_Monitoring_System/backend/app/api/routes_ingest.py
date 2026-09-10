from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import date, datetime

from ..core.database import get_db
from ..models.registry_models import Cattle, Farm
from ..models.timeseries_models import MilkLog, WeightLog, VaccinationLog

router = APIRouter(prefix="/ingest", tags=["Data Ingestion from APKs"])

# -------------------------------------------------------------
# Schemas for Ingestion
# -------------------------------------------------------------
class MilkIngestRequest(BaseModel):
    cattle_id: str
    record_date: date
    shift: Optional[str] = "morning"
    quantity_liters: float
    fat_percentage: Optional[float] = 4.0
    snf_percentage: Optional[float] = 8.5
    source_app: Optional[str] = "Milk_Monitoring_APK"

class WeightIngestRequest(BaseModel):
    cattle_id: str
    record_date: date
    weight_kg: float
    body_length_cm: Optional[float] = None
    heart_girth_cm: Optional[float] = None
    withers_height_cm: Optional[float] = None
    bcs_score: Optional[float] = 3.0
    source_app: Optional[str] = "Weight_Monitoring_APK"

class VaccinationIngestRequest(BaseModel):
    cattle_id: str
    vaccine_name: str
    administered_date: date
    next_due_date: date
    status: Optional[str] = "Up to Date"
    disease_targeted: Optional[str] = None
    source_app: Optional[str] = "Vaccination_Monitoring_APK"

def _ensure_cattle_exists(cattle_id: str, db: Session):
    cattle = db.query(Cattle).filter(Cattle.cattle_id == cattle_id).first()
    if not cattle:
        # Create default placeholder if not pre-registered
        cattle = Cattle(
            cattle_id=cattle_id,
            name="Cattle-" + cattle_id,
            breed="HF",
            farm_id="8088032780_Samruddhi_Farm"
        )
        db.add(cattle)
        db.commit()
    return cattle

@router.post("/milk/")
def ingest_milk_data(data: MilkIngestRequest, db: Session = Depends(get_db)):
    _ensure_cattle_exists(data.cattle_id, db)
    log = MilkLog(
        cattle_id=data.cattle_id,
        record_date=data.record_date,
        shift=data.shift,
        quantity_liters=data.quantity_liters,
        fat_percentage=data.fat_percentage,
        snf_percentage=data.snf_percentage,
        source_app=data.source_app,
        created_at=datetime.utcnow()
    )
    db.add(log)
    db.commit()
    return {"status": "success", "type": "milk", "id": log.id, "cattle_id": log.cattle_id}

@router.post("/weight/")
def ingest_weight_data(data: WeightIngestRequest, db: Session = Depends(get_db)):
    _ensure_cattle_exists(data.cattle_id, db)
    log = WeightLog(
        cattle_id=data.cattle_id,
        record_date=data.record_date,
        weight_kg=data.weight_kg,
        body_length_cm=data.body_length_cm,
        heart_girth_cm=data.heart_girth_cm,
        withers_height_cm=data.withers_height_cm,
        bcs_score=data.bcs_score,
        source_app=data.source_app,
        created_at=datetime.utcnow()
    )
    db.add(log)
    db.commit()
    return {"status": "success", "type": "weight", "id": log.id, "cattle_id": log.cattle_id}

@router.post("/vaccination/")
def ingest_vaccination_data(data: VaccinationIngestRequest, db: Session = Depends(get_db)):
    _ensure_cattle_exists(data.cattle_id, db)
    log = VaccinationLog(
        cattle_id=data.cattle_id,
        vaccine_name=data.vaccine_name,
        administered_date=data.administered_date,
        next_due_date=data.next_due_date,
        status=data.status,
        disease_targeted=data.disease_targeted,
        source_app=data.source_app,
        created_at=datetime.utcnow()
    )
    db.add(log)
    db.commit()
    return {"status": "success", "type": "vaccination", "id": log.id, "cattle_id": log.cattle_id}
