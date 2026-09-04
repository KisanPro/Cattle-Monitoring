"""
FastAPI Backend for Cattle Milk Monitoring
Integrated with PostgreSQL on AWS RDS
"""

from fastapi import FastAPI, Depends, HTTPException, Query
from sqlalchemy import create_engine, Column, String, Float, DateTime, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.dialects.postgresql import UUID
import uuid
import os
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime

# ============================================================
# LIVE AWS RDS DATABASE CONFIGURATION
# ============================================================
AWS_RDS_ENDPOINT = "database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com"
DEFAULT_AWS_URL = f"postgresql://postgres:%23kisanpro123@{AWS_RDS_ENDPOINT}:5432/kisan_pro_db"

DATABASE_URL = os.getenv("DATABASE_URL", DEFAULT_AWS_URL)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# ============================================================
# ORM MODELS (Automatic Table Generation)
# ============================================================

class MilkProduction(Base):
    __tablename__ = "milk_production"
    
    record_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cattle_id = Column(String(100), nullable=False)
    cattle_name = Column(String(100), nullable=True, default="Gauri")
    farm_id = Column(String(100), nullable=False)
    quantity_liters = Column(Float, nullable=False)
    quality_grade = Column(String(20), default="Grade A")
    fat_percentage = Column(Float)
    snf_percentage = Column(Float)
    milking_time = Column(String(10), nullable=False, default="morning")
    recorded_at = Column(DateTime(timezone=True), server_default=func.now())

# AUTOMATIC TABLE CREATION ON AWS STARTUP
Base.metadata.create_all(bind=engine)

# ============================================================
# PYDANTIC SCHEMAS
# ============================================================

class MilkRecordCreate(BaseModel):
    cattle_id: str
    cattle_name: Optional[str] = "Gauri"
    farm_id: str = "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d"
    quantity_liters: float
    quality_grade: Optional[str] = "Grade A"
    fat_percentage: Optional[float] = 4.0
    snf_percentage: Optional[float] = 8.5
    milking_time: str  # "morning" or "evening"

class MilkRecordResponse(MilkRecordCreate):
    record_id: uuid.UUID
    recorded_at: datetime

    class Config:
        from_attributes = True

# ============================================================
# FASTAPI APP & ENDPOINTS
# ============================================================

app = FastAPI(
    title="Kisan Pro - Cattle Milk Monitoring API",
    description="Live FastAPI Backend connected to AWS RDS PostgreSQL"
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def root():
    return {
        "status": "online",
        "system": "Cattle Milk Monitoring API",
        "database": "AWS RDS PostgreSQL (PostgreSQL 18.3)",
        "endpoint": AWS_RDS_ENDPOINT
    }

@app.get("/milk-production/", response_model=List[MilkRecordResponse])
def get_milk_records(farm_id: Optional[str] = None, db: Session = Depends(get_db)):
    """Fetch all milk records for a farm from AWS RDS PostgreSQL"""
    query = db.query(MilkProduction)
    if farm_id:
        query = query.filter(MilkProduction.farm_id == farm_id)
    records = query.order_by(MilkProduction.recorded_at.desc()).all()
    return records

@app.post("/milk-production/", response_model=MilkRecordResponse)
def create_milk_record(record: MilkRecordCreate, db: Session = Depends(get_db)):
    """Insert a new daily milk production entry into AWS RDS PostgreSQL"""
    db_record = MilkProduction(**record.dict())
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record

@app.get("/milk-production/analytics/")
def get_milk_analytics(farm_id: Optional[str] = None, db: Session = Depends(get_db)):
    """Calculate live milk production analytics for Flutter dashboard"""
    query = db.query(MilkProduction)
    if farm_id:
        query = query.filter(MilkProduction.farm_id == farm_id)
    records = query.all()
    
    total_quantity = sum(r.quantity_liters for r in records)
    morning_qty = sum(r.quantity_liters for r in records if r.milking_time == "morning")
    evening_qty = sum(r.quantity_liters for r in records if r.milking_time == "evening")
    
    return {
        "daily_total": round(total_quantity, 1),
        "morning_total": round(morning_qty, 1),
        "evening_total": round(evening_qty, 1),
        "total_records": len(records)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8082)
