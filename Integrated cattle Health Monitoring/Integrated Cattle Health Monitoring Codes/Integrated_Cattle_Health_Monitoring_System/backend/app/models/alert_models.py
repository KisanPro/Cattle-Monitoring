from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Text, JSON, func
from sqlalchemy.orm import relationship
import uuid
from ..core.database import Base

class HealthAlert(Base):
    __tablename__ = "health_alerts"

    id = Column(String(50), primary_key=True, default=lambda: str(uuid.uuid4()))
    cattle_id = Column(String(100), ForeignKey("cattles.cattle_id"), nullable=False, index=True)
    farm_id = Column(String(100), nullable=False)
    risk_level = Column(String(30), nullable=False, index=True) # NORMAL, WARNING, HIGH RISK, CRITICAL
    health_score = Column(Float, nullable=False) # 0 to 100
    alert_title = Column(String(200), nullable=False)
    detected_changes = Column(JSON, nullable=False) # {"milk": "16.2L -> 11.5L", "weight": "450kg -> 438kg", "vaccine": "Due Soon"}
    ai_observation = Column(Text, nullable=False)
    recommended_action = Column(Text, nullable=False)
    possible_reasons = Column(JSON, nullable=True) # ["Subclinical Mastitis", "Parasitic Infestation", ...]
    disclaimer = Column(Text, nullable=False, default="This is an automated AI risk assessment and early-warning alert, not a definitive veterinary diagnosis.")
    is_resolved = Column(String(20), default="Open")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    cattle = relationship("Cattle", back_populates="health_alerts")
