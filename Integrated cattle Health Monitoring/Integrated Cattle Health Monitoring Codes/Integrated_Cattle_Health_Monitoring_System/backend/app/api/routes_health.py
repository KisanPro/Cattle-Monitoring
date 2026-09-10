from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
from datetime import date

from ..core.database import get_db
from ..models.registry_models import Cattle, Farm
from ..models.timeseries_models import MilkLog, WeightLog, VaccinationLog
from ..models.alert_models import HealthAlert
from ..ai_engine.feature_extractor import FeatureExtractor
from ..ai_engine.alert_generator import AlertGenerator

router = APIRouter(prefix="/health", tags=["AI Health Assessment"])

@router.get("/assess/{cattle_id}")
def assess_cattle_health(
    cattle_id: str,
    as_of: Optional[str] = None, # YYYY-MM-DD
    auto_persist_alert: bool = True,
    db: Session = Depends(get_db)
):
    cattle = db.query(Cattle).filter(Cattle.cattle_id == cattle_id).first()
    if not cattle:
        raise HTTPException(status_code=404, detail="Cattle not found")

    farm = db.query(Farm).filter(Farm.farm_id == cattle.farm_id).first()
    farm_info = {
        "farm_id": farm.farm_id if farm else cattle.farm_id,
        "farmer_name": farm.farmer_name if farm else "Farmer",
        "farm_name": farm.farm_name if farm else "Farm"
    }

    cattle_info = {
        "cattle_id": cattle.cattle_id,
        "name": cattle.name,
        "breed": cattle.breed,
        "age_years": cattle.age_years
    }

    # Fetch time-series logs
    milk_logs = db.query(MilkLog).filter(MilkLog.cattle_id == cattle_id).order_by(MilkLog.record_date.asc()).all()
    weight_logs = db.query(WeightLog).filter(WeightLog.cattle_id == cattle_id).order_by(WeightLog.record_date.asc()).all()
    vaccine_logs = db.query(VaccinationLog).filter(VaccinationLog.cattle_id == cattle_id).order_by(VaccinationLog.administered_date.asc()).all()

    milk_data = [{"record_date": str(m.record_date), "quantity_liters": m.quantity_liters} for m in milk_logs]
    weight_data = [{"record_date": str(w.record_date), "weight_kg": w.weight_kg} for w in weight_logs]
    vaccine_data = [{"vaccine_name": v.vaccine_name, "administered_date": str(v.administered_date), "next_due_date": str(v.next_due_date), "status": v.status} for v in vaccine_logs]

    ref_date = date.fromisoformat(as_of) if as_of else None

    # Extract time-series multivariable features
    features = FeatureExtractor.extract_features(milk_data, weight_data, vaccine_data, as_of_date=ref_date)

    # Generate full assessment report & early-warning alert payload
    report = AlertGenerator.generate_assessment_report(farm_info, cattle_info, features)
    report["features"] = features

    # Optionally persist alert if Risk is WARNING, HIGH RISK, or CRITICAL
    if auto_persist_alert and report["risk_level"] != "NORMAL":
        existing_today_alert = db.query(HealthAlert).filter(
            HealthAlert.cattle_id == cattle_id,
            HealthAlert.risk_level == report["risk_level"]
        ).first()

        if not existing_today_alert:
            new_alert = HealthAlert(
                cattle_id=cattle_id,
                farm_id=farm_info["farm_id"],
                risk_level=report["risk_level"],
                health_score=report["health_score"],
                alert_title=report["alert_title"],
                detected_changes=report["detected_changes"],
                ai_observation=report["ai_observation"],
                recommended_action=report["recommended_action"],
                possible_reasons=report["possible_reasons"],
                disclaimer=report["disclaimer"]
            )
            db.add(new_alert)
            db.commit()
            db.refresh(new_alert)
            report["persisted_alert_id"] = new_alert.id

    return report


@router.get("/timeseries/{cattle_id}")
def get_synchronized_timeseries(cattle_id: str, db: Session = Depends(get_db)):
    """
    Returns unified synchronized daily timeline with Milk, Weight, and Vaccine status.
    """
    cattle = db.query(Cattle).filter(Cattle.cattle_id == cattle_id).first()
    if not cattle:
        raise HTTPException(status_code=404, detail="Cattle not found")

    milk_logs = db.query(MilkLog).filter(MilkLog.cattle_id == cattle_id).order_by(MilkLog.record_date.asc()).all()
    weight_logs = db.query(WeightLog).filter(WeightLog.cattle_id == cattle_id).order_by(WeightLog.record_date.asc()).all()
    vaccine_logs = db.query(VaccinationLog).filter(VaccinationLog.cattle_id == cattle_id).order_by(VaccinationLog.administered_date.asc()).all()

    # Aggregate daily
    daily_map = {}
    for m in milk_logs:
        d_str = str(m.record_date)
        if d_str not in daily_map:
            daily_map[d_str] = {"date": d_str, "milk": 0.0, "weight": None, "vaccine": None, "fat": m.fat_percentage, "snf": m.snf_percentage}
        daily_map[d_str]["milk"] += m.quantity_liters

    for w in weight_logs:
        d_str = str(w.record_date)
        if d_str not in daily_map:
            daily_map[d_str] = {"date": d_str, "milk": None, "weight": w.weight_kg, "vaccine": None}
        else:
            daily_map[d_str]["weight"] = w.weight_kg

    for v in vaccine_logs:
        adm_str = str(v.administered_date)
        due_str = str(v.next_due_date)
        if adm_str in daily_map:
            daily_map[adm_str]["vaccine"] = f"Administered: {v.vaccine_name}"
        if due_str in daily_map:
            daily_map[due_str]["vaccine"] = f"Due: {v.vaccine_name} ({v.status})"

    sorted_series = [daily_map[k] for k in sorted(daily_map.keys())]

    return {
        "cattle_id": cattle_id,
        "name": cattle.name,
        "breed": cattle.breed,
        "timeline": sorted_series
    }
