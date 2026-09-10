from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional

from ..core.database import get_db
from ..models.alert_models import HealthAlert

router = APIRouter(prefix="/alerts", tags=["Health Alerts"])

@router.get("/")
def list_alerts(
    farm_id: Optional[str] = None,
    cattle_id: Optional[str] = None,
    risk_level: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(HealthAlert)
    if farm_id:
        query = query.filter(HealthAlert.farm_id == farm_id)
    if cattle_id:
        query = query.filter(HealthAlert.cattle_id == cattle_id)
    if risk_level:
        query = query.filter(HealthAlert.risk_level == risk_level)
    
    return query.order_by(HealthAlert.created_at.desc()).all()

@router.post("/{alert_id}/resolve")
def resolve_alert(alert_id: str, db: Session = Depends(get_db)):
    alert = db.query(HealthAlert).filter(HealthAlert.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    alert.is_resolved = "Resolved"
    db.commit()
    return {"status": "success", "alert_id": alert_id, "is_resolved": "Resolved"}
