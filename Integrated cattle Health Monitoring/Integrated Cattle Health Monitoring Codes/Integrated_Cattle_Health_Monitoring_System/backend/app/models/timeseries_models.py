from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Integer, Date
from sqlalchemy.orm import relationship
import uuid
from ..core.database import Base

class MilkLog(Base):
    __tablename__ = "milk_logs"

    id = Column(String(50), primary_key=True, default=lambda: str(uuid.uuid4()))
    cattle_id = Column(String(100), ForeignKey("cattles.cattle_id"), nullable=False, index=True)
    record_date = Column(Date, nullable=False, index=True)
    shift = Column(String(20), nullable=False, default="morning") # morning, evening, total
    quantity_liters = Column(Float, nullable=False)
    fat_percentage = Column(Float, nullable=True, default=4.0)
    snf_percentage = Column(Float, nullable=True, default=8.5)
    source_app = Column(String(50), default="Milk_Monitoring_APK")
    created_at = Column(DateTime, nullable=True)

    cattle = relationship("Cattle", back_populates="milk_records")


class WeightLog(Base):
    __tablename__ = "weight_logs"

    id = Column(String(50), primary_key=True, default=lambda: str(uuid.uuid4()))
    cattle_id = Column(String(100), ForeignKey("cattles.cattle_id"), nullable=False, index=True)
    record_date = Column(Date, nullable=False, index=True)
    weight_kg = Column(Float, nullable=False)
    body_length_cm = Column(Float, nullable=True)
    heart_girth_cm = Column(Float, nullable=True)
    withers_height_cm = Column(Float, nullable=True)
    bcs_score = Column(Float, nullable=True, default=3.0) # Body condition score 1-5
    source_app = Column(String(50), default="Weight_Monitoring_APK")
    created_at = Column(DateTime, nullable=True)

    cattle = relationship("Cattle", back_populates="weight_records")


class VaccinationLog(Base):
    __tablename__ = "vaccination_logs"

    id = Column(String(50), primary_key=True, default=lambda: str(uuid.uuid4()))
    cattle_id = Column(String(100), ForeignKey("cattles.cattle_id"), nullable=False, index=True)
    vaccine_name = Column(String(150), nullable=False)
    administered_date = Column(Date, nullable=False)
    next_due_date = Column(Date, nullable=False, index=True)
    status = Column(String(50), nullable=False, default="Up to Date") # Up to Date, Due Soon, Overdue
    disease_targeted = Column(String(100), nullable=True)
    source_app = Column(String(50), default="Vaccination_Monitoring_APK")
    created_at = Column(DateTime, nullable=True)

    cattle = relationship("Cattle", back_populates="vaccination_records")
