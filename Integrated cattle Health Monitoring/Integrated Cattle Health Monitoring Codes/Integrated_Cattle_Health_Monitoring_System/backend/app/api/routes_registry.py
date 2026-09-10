from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

from ..core.database import get_db
from ..models.registry_models import Farm, Cattle

router = APIRouter(prefix="/registry", tags=["Registry"])

# Pydantic Schemas
class FarmCreate(BaseModel):
    farm_id: str
    farm_name: str
    farmer_name: str
    contact_number: Optional[str] = None
    location: Optional[str] = "Karnataka, India"

class CattleCreate(BaseModel):
    cattle_id: str
    name: str
    breed: str
    farm_id: str
    age_years: Optional[str] = "4"
    gender: Optional[str] = "Female"

@router.post("/farms/")
def register_farm(farm: FarmCreate, db: Session = Depends(get_db)):
    existing = db.query(Farm).filter(Farm.farm_id == farm.farm_id).first()
    if existing:
        return {"status": "exists", "farm_id": existing.farm_id}
    new_farm = Farm(**farm.dict())
    db.add(new_farm)
    db.commit()
    db.refresh(new_farm)
    return {"status": "created", "farm": new_farm.farm_id}

@router.get("/farms/")
def list_farms(db: Session = Depends(get_db)):
    return db.query(Farm).all()

@router.post("/cattles/")
def register_cattle(cattle: CattleCreate, db: Session = Depends(get_db)):
    existing = db.query(Cattle).filter(Cattle.cattle_id == cattle.cattle_id).first()
    if existing:
        return {"status": "exists", "cattle_id": existing.cattle_id}
    
    farm = db.query(Farm).filter(Farm.farm_id == cattle.farm_id).first()
    if not farm:
        # Auto-create farm if missing
        farm = Farm(
            farm_id=cattle.farm_id,
            farm_name=f"Farm {cattle.farm_id}",
            farmer_name="Registered Farmer"
        )
        db.add(farm)
        db.commit()

    new_cattle = Cattle(**cattle.dict())
    db.add(new_cattle)
    db.commit()
    db.refresh(new_cattle)
    return {"status": "created", "cattle": new_cattle.cattle_id}

@router.get("/cattles/")
def list_cattles(farm_id: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(Cattle)
    if farm_id:
        query = query.filter(Cattle.farm_id == farm_id)
    return query.all()

@router.get("/cattles/{cattle_id}")
def get_cattle_details(cattle_id: str, db: Session = Depends(get_db)):
    cattle = db.query(Cattle).filter(Cattle.cattle_id == cattle_id).first()
    if not cattle:
        raise HTTPException(status_code=404, detail="Cattle not found")
    return {
        "cattle_id": cattle.cattle_id,
        "name": cattle.name,
        "breed": cattle.breed,
        "age_years": cattle.age_years,
        "gender": cattle.gender,
        "farm_id": cattle.farm_id,
        "registered_at": cattle.registered_at
    }
