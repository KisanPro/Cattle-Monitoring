import unittest
from datetime import date
import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal, engine, Base
from app.models.registry_models import Farm, Cattle
from app.models.timeseries_models import MilkLog, WeightLog, VaccinationLog
from app.ai_engine.feature_extractor import FeatureExtractor
from app.ai_engine.risk_classifier import RiskClassifier
from app.ai_engine.alert_generator import AlertGenerator
from seed_data import seed

class TestIntegratedHealthSystem(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        seed()

    def setUp(self):
        self.db = SessionLocal()

    def tearDown(self):
        self.db.close()

    def test_01_registry_linkage(self):
        """Test that farm and cattle registry are interconnected by Cattle_ID"""
        cattle = self.db.query(Cattle).filter(Cattle.cattle_id == "KA-1989").first()
        self.assertIsNotNone(cattle)
        self.assertEqual(cattle.name, "Geetha")
        self.assertEqual(cattle.breed, "HF")
        self.assertEqual(cattle.farm_id, "8088032780_Samruddhi_Farm")

    def test_02_feature_extraction_geetha_prompt_case(self):
        """
        Verify mathematical feature extraction for KA-1989 (Geetha):
        Target Case:
        01-09-2026: 16.2 L, 450 kg, Up to Date
        02-09-2026: 15.8 L, 449 kg, Up to Date
        03-09-2026: 13.9 L, 443 kg, Up to Date
        04-09-2026: 11.5 L, 438 kg, Due Soon
        """
        milk_logs = self.db.query(MilkLog).filter(MilkLog.cattle_id == "KA-1989").order_by(MilkLog.record_date.asc()).all()
        weight_logs = self.db.query(WeightLog).filter(WeightLog.cattle_id == "KA-1989").order_by(WeightLog.record_date.asc()).all()
        vac_logs = self.db.query(VaccinationLog).filter(VaccinationLog.cattle_id == "KA-1989").order_by(VaccinationLog.administered_date.asc()).all()

        milk_data = [{"record_date": str(m.record_date), "quantity_liters": m.quantity_liters} for m in milk_logs]
        weight_data = [{"record_date": str(w.record_date), "weight_kg": w.weight_kg} for w in weight_logs]
        vac_data = [{"vaccine_name": v.vaccine_name, "administered_date": str(v.administered_date), "next_due_date": str(v.next_due_date), "status": v.status} for v in vac_logs]

        features = FeatureExtractor.extract_features(milk_data, weight_data, vac_data, as_of_date=date(2026, 9, 4))
        
        self.assertEqual(features["current_milk"], 11.5)
        self.assertEqual(features["current_weight"], 438.0)
        self.assertEqual(features["vaccine_status"], "Due Soon")
        self.assertLess(features["delta_milk_pct_7d"], -15.0)
        self.assertLess(features["delta_weight_pct_7d"], -1.5)

    def test_03_ai_risk_assessment_geetha_high_risk(self):
        """
        Verify AI Risk Classifier categorizes Geetha (KA-1989) as HIGH RISK with proper alert payload
        """
        milk_logs = self.db.query(MilkLog).filter(MilkLog.cattle_id == "KA-1989").order_by(MilkLog.record_date.asc()).all()
        weight_logs = self.db.query(WeightLog).filter(WeightLog.cattle_id == "KA-1989").order_by(WeightLog.record_date.asc()).all()
        vac_logs = self.db.query(VaccinationLog).filter(VaccinationLog.cattle_id == "KA-1989").order_by(VaccinationLog.administered_date.asc()).all()

        milk_data = [{"record_date": str(m.record_date), "quantity_liters": m.quantity_liters} for m in milk_logs]
        weight_data = [{"record_date": str(w.record_date), "weight_kg": w.weight_kg} for w in weight_logs]
        vac_data = [{"vaccine_name": v.vaccine_name, "administered_date": str(v.administered_date), "next_due_date": str(v.next_due_date), "status": v.status} for v in vac_logs]

        features = FeatureExtractor.extract_features(milk_data, weight_data, vac_data, as_of_date=date(2026, 9, 4))

        farm_info = {"farm_id": "8088032780_Samruddhi_Farm", "farmer_name": "Shri Basavaraj"}
        cattle_info = {"cattle_id": "KA-1989", "name": "Geetha", "breed": "HF"}

        report = AlertGenerator.generate_assessment_report(farm_info, cattle_info, features)

        self.assertIn(report["risk_level"], ["HIGH RISK", "CRITICAL"])
        self.assertEqual(report["cattle_name"], "Geetha")
        self.assertEqual(report["breed"], "HF")
        self.assertIn("11.5", report["detected_changes"]["Milk Production"])
        self.assertIn("438", report["detected_changes"]["Weight"])
        self.assertEqual(report["detected_changes"]["Vaccination"], "Due Soon")
        self.assertIn("decrease in milk production", report["ai_observation"])
        self.assertIn("feeding behaviour", report["recommended_action"])

    def test_04_ai_risk_assessment_lakshmi_normal(self):
        """
        Verify AI Risk Classifier categorizes Lakshmi (KA-1021) as NORMAL
        """
        milk_logs = self.db.query(MilkLog).filter(MilkLog.cattle_id == "KA-1021").order_by(MilkLog.record_date.asc()).all()
        weight_logs = self.db.query(WeightLog).filter(WeightLog.cattle_id == "KA-1021").order_by(WeightLog.record_date.asc()).all()
        vac_logs = self.db.query(VaccinationLog).filter(VaccinationLog.cattle_id == "KA-1021").order_by(VaccinationLog.administered_date.asc()).all()

        milk_data = [{"record_date": str(m.record_date), "quantity_liters": m.quantity_liters} for m in milk_logs]
        weight_data = [{"record_date": str(w.record_date), "weight_kg": w.weight_kg} for w in weight_logs]
        vac_data = [{"vaccine_name": v.vaccine_name, "administered_date": str(v.administered_date), "next_due_date": str(v.next_due_date), "status": v.status} for v in vac_logs]

        features = FeatureExtractor.extract_features(milk_data, weight_data, vac_data, as_of_date=date(2026, 9, 4))
        farm_info = {"farm_id": "8088032780_Samruddhi_Farm", "farmer_name": "Shri Basavaraj"}
        cattle_info = {"cattle_id": "KA-1021", "name": "Lakshmi", "breed": "Gir"}

        report = AlertGenerator.generate_assessment_report(farm_info, cattle_info, features)
        self.assertEqual(report["risk_level"], "NORMAL")
        self.assertGreaterEqual(report["health_score"], 80.0)

if __name__ == "__main__":
    unittest.main(verbosity=2)
