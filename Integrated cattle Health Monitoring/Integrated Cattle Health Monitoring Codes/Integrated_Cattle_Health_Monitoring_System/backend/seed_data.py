import os
import sys
from datetime import date, timedelta

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import Base, engine, SessionLocal
from app.models.registry_models import Farm, Cattle
from app.models.timeseries_models import MilkLog, WeightLog, VaccinationLog
from app.models.alert_models import HealthAlert

def seed():
    print("=== Initializing Integrated Cattle Database ===")
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    # Clear existing data for clean demo
    db.query(HealthAlert).delete()
    db.query(MilkLog).delete()
    db.query(WeightLog).delete()
    db.query(VaccinationLog).delete()
    db.query(Cattle).delete()
    db.query(Farm).delete()
    db.commit()

    print("1. Creating Farms...")
    farm_samruddhi = Farm(
        farm_id="8088032780_Samruddhi_Farm",
        farm_name="Samruddhi Dairy & Livestock Farm",
        farmer_name="Shri Basavaraj",
        contact_number="8088032780",
        location="Mandya / Bangalore Rural, Karnataka"
    )
    db.add(farm_samruddhi)
    db.commit()

    print("2. Registering Primary Test Cattle (KA-1989 - Geetha)...")
    geetha = Cattle(
        cattle_id="KA-1989",
        name="Geetha",
        breed="HF", # Holstein Friesian
        farm_id=farm_samruddhi.farm_id,
        age_years="4",
        gender="Female"
    )
    db.add(geetha)

    # Add 2 other reference cattles
    lakshmi = Cattle(
        cattle_id="KA-1021",
        name="Lakshmi",
        breed="Gir",
        farm_id=farm_samruddhi.farm_id,
        age_years="5",
        gender="Female"
    )
    ganga = Cattle(
        cattle_id="KA-3045",
        name="Ganga",
        breed="Hallikar",
        farm_id=farm_samruddhi.farm_id,
        age_years="3",
        gender="Female"
    )
    db.add_all([lakshmi, ganga])
    db.commit()

    print("3. Seeding 30-Day Historical Data for KA-1989 (Geetha)...")
    # Base reference date: 2026-09-04
    end_date = date(2026, 9, 4)
    start_date = end_date - timedelta(days=29) # 30 days total

    # Baseline for healthy days (Aug 6 to Aug 31): ~16.5 - 17.5 L milk, 450 - 455 kg weight
    cur_date = start_date
    while cur_date < date(2026, 9, 1):
        # Stable healthy period
        milk_qty = 16.5 + (hash(str(cur_date)) % 10) * 0.1
        weight_val = 450.0 + (hash(str(cur_date)) % 6) * 0.5
        
        # Morning shift
        db.add(MilkLog(
            cattle_id="KA-1989",
            record_date=cur_date,
            shift="morning",
            quantity_liters=round(milk_qty * 0.55, 1),
            fat_percentage=4.1,
            snf_percentage=8.6,
            source_app="Milk_Monitoring_APK"
        ))
        # Evening shift
        db.add(MilkLog(
            cattle_id="KA-1989",
            record_date=cur_date,
            shift="evening",
            quantity_liters=round(milk_qty * 0.45, 1),
            fat_percentage=4.2,
            snf_percentage=8.7,
            source_app="Milk_Monitoring_APK"
        ))
        # Weight entry
        db.add(WeightLog(
            cattle_id="KA-1989",
            record_date=cur_date,
            weight_kg=round(weight_val, 1),
            body_length_cm=142.0,
            heart_girth_cm=178.0,
            withers_height_cm=132.0,
            bcs_score=3.25,
            source_app="Weight_Monitoring_APK"
        ))
        cur_date += timedelta(days=1)

    # Specific Target Days from prompt specification:
    # 01-09-2026: 16.2 L, 450 kg, Up to Date
    # 02-09-2026: 15.8 L, 449 kg, Up to Date
    # 03-09-2026: 13.9 L, 443 kg, Up to Date
    # 04-09-2026: 11.5 L, 438 kg, Due Soon
    target_data = [
        (date(2026, 9, 1), 16.2, 450.0),
        (date(2026, 9, 2), 15.8, 449.0),
        (date(2026, 9, 3), 13.9, 443.0),
        (date(2026, 9, 4), 11.5, 438.0),
    ]

    for d, m_qty, w_kg in target_data:
        db.add(MilkLog(
            cattle_id="KA-1989",
            record_date=d,
            shift="morning",
            quantity_liters=round(m_qty * 0.55, 1),
            fat_percentage=3.8,
            snf_percentage=8.2,
            source_app="Milk_Monitoring_APK"
        ))
        db.add(MilkLog(
            cattle_id="KA-1989",
            record_date=d,
            shift="evening",
            quantity_liters=round(m_qty * 0.45, 1),
            fat_percentage=3.9,
            snf_percentage=8.3,
            source_app="Milk_Monitoring_APK"
        ))
        db.add(WeightLog(
            cattle_id="KA-1989",
            record_date=d,
            weight_kg=w_kg,
            body_length_cm=141.0,
            heart_girth_cm=175.0,
            withers_height_cm=132.0,
            bcs_score=2.75 if d == date(2026, 9, 4) else 3.0,
            source_app="Weight_Monitoring_APK"
        ))

    print("4. Seeding Vaccination History for KA-1989...")
    # Administered earlier in the year
    db.add(VaccinationLog(
        cattle_id="KA-1989",
        vaccine_name="Raksha-HS (Hemorrhagic Septicemia)",
        administered_date=date(2026, 3, 10),
        next_due_date=date(2027, 3, 10),
        status="Up to Date",
        disease_targeted="Hemorrhagic Septicemia",
        source_app="Vaccination_Monitoring_APK"
    ))
    db.add(VaccinationLog(
        cattle_id="KA-1989",
        vaccine_name="Raksha-BQ (Black Quarter)",
        administered_date=date(2026, 4, 15),
        next_due_date=date(2027, 4, 15),
        status="Up to Date",
        disease_targeted="Black Quarter",
        source_app="Vaccination_Monitoring_APK"
    ))
    # Due Soon Booster (Due on 2026-09-08, 4 days from 2026-09-04)
    db.add(VaccinationLog(
        cattle_id="KA-1989",
        vaccine_name="NADCP FMD Trivalent Booster",
        administered_date=date(2026, 3, 8),
        next_due_date=date(2026, 9, 8),
        status="Due Soon",
        disease_targeted="Foot-and-Mouth Disease",
        source_app="Vaccination_Monitoring_APK"
    ))

    # Seed Healthy Data for Lakshmi KA-1021
    for day_offset in range(15):
        d = date(2026, 9, 4) - timedelta(days=day_offset)
        db.add(MilkLog(cattle_id="KA-1021", record_date=d, shift="morning", quantity_liters=7.5, source_app="Milk_Monitoring_APK"))
        db.add(MilkLog(cattle_id="KA-1021", record_date=d, shift="evening", quantity_liters=6.5, source_app="Milk_Monitoring_APK"))
        db.add(WeightLog(cattle_id="KA-1021", record_date=d, weight_kg=380.0, source_app="Weight_Monitoring_APK"))
    
    db.add(VaccinationLog(
        cattle_id="KA-1021",
        vaccine_name="FMD + HS Annual",
        administered_date=date(2026, 5, 1),
        next_due_date=date(2027, 5, 1),
        status="Up to Date",
        source_app="Vaccination_Monitoring_APK"
    ))

    db.commit()
    db.close()
    print("=== Database Seeding Completed Successfully! ===")

if __name__ == "__main__":
    seed()
