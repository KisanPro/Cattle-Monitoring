from sqlalchemy import Column, String, DateTime, func, ForeignKey, Text
from sqlalchemy.orm import relationship
from ..core.database import Base

class Farm(Base):
    __tablename__ = "farms"

    farm_id = Column(String(100), primary_key=True, index=True) # e.g. "8088032780_Samruddhi_Farm"
    farm_name = Column(String(150), nullable=False)
    farmer_name = Column(String(100), nullable=False)
    contact_number = Column(String(30), nullable=True)
    location = Column(String(150), nullable=True, default="Karnataka, India")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    cattles = relationship("Cattle", back_populates="farm", cascade="all, delete-orphan")


class Cattle(Base):
    __tablename__ = "cattles"

    cattle_id = Column(String(100), primary_key=True, index=True) # e.g. "KA-1989"
    name = Column(String(100), nullable=False, default="Geetha")
    breed = Column(String(50), nullable=False, default="HF")
    farm_id = Column(String(100), ForeignKey("farms.farm_id"), nullable=False, index=True)
    age_years = Column(String(20), nullable=True, default="4")
    gender = Column(String(20), nullable=True, default="Female")
    registered_at = Column(DateTime(timezone=True), server_default=func.now())

    farm = relationship("Farm", back_populates="cattles")
    milk_records = relationship("MilkLog", back_populates="cattle", cascade="all, delete-orphan")
    weight_records = relationship("WeightLog", back_populates="cattle", cascade="all, delete-orphan")
    vaccination_records = relationship("VaccinationLog", back_populates="cattle", cascade="all, delete-orphan")
    health_alerts = relationship("HealthAlert", back_populates="cattle", cascade="all, delete-orphan")
