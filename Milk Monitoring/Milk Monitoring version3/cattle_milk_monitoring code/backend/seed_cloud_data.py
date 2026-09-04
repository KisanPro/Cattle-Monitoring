"""
Reseed live realistic data in AWS RDS PostgreSQL - INCLUDING TODAY (2026-08-25)
"""

from main import engine, Base, SessionLocal, MilkProduction
from sqlalchemy import text
from datetime import datetime, timedelta
import uuid

def reseed_data():
    print("--------------------------------------------------")
    print("Reseeding AWS RDS PostgreSQL with fresh current data...")
    print("--------------------------------------------------")

    db = SessionLocal()

    # Delete old seed data (keep manually added records)
    existing = db.query(MilkProduction).count()
    print(f"Existing records: {existing} - clearing all seed data...")
    db.query(MilkProduction).delete()
    db.commit()
    print("Cleared. Inserting fresh records with today's date...")

    cattle_list = [
        {"id": "KP-201", "name": "Lakshmi"},
        {"id": "KP-202", "name": "Ganga"},
        {"id": "KP-203", "name": "Gowri"},
        {"id": "KP-204", "name": "Saraswati"},
    ]

    farm_ids = [
        "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
        "default_farm",
        "farmer_kisan_pro_default"
    ]

    # Use UTC time so app timestamps match
    now_utc = datetime.utcnow()
    records_to_add = []

    # Generate past 10 days of data INCLUDING TODAY (days_ago=0 = today)
    for days_ago in range(9, -1, -1):
        record_date = now_utc - timedelta(days=days_ago)

        for cow in cattle_list:
            h = len(cow["name"])

            # Morning Milking entry
            morning_time = record_date.replace(hour=6, minute=30, second=0, microsecond=0)
            morning_qty = round(8.0 + (days_ago % 3) + (h % 3) * 1.5, 1)
            morning_fat = round(4.0 + (days_ago % 2) * 0.4 + (h % 2) * 0.5, 1)
            morning_snf = round(8.3 + (days_ago % 3) * 0.1 + (h % 3) * 0.1, 1)

            for f_id in farm_ids:
                records_to_add.append(MilkProduction(
                    record_id=uuid.uuid4(),
                    cattle_id=cow["id"],
                    cattle_name=cow["name"],
                    farm_id=f_id,
                    quantity_liters=morning_qty,
                    quality_grade="Grade A",
                    fat_percentage=morning_fat,
                    snf_percentage=morning_snf,
                    milking_time="morning",
                    recorded_at=morning_time
                ))

            # Evening Milking entry  
            evening_time = record_date.replace(hour=18, minute=0, second=0, microsecond=0)
            evening_qty = round(6.5 + (days_ago % 2) + (h % 2) * 1.2, 1)
            evening_fat = round(4.2 + (days_ago % 3) * 0.3 + (h % 2) * 0.4, 1)
            evening_snf = round(8.4 + (days_ago % 2) * 0.1 + (h % 3) * 0.1, 1)

            for f_id in farm_ids:
                records_to_add.append(MilkProduction(
                    record_id=uuid.uuid4(),
                    cattle_id=cow["id"],
                    cattle_name=cow["name"],
                    farm_id=f_id,
                    quantity_liters=evening_qty,
                    quality_grade="Grade A",
                    fat_percentage=evening_fat,
                    snf_percentage=evening_snf,
                    milking_time="evening",
                    recorded_at=evening_time
                ))

    db.bulk_save_objects(records_to_add)
    db.commit()

    total = db.query(MilkProduction).count()
    today_str = now_utc.strftime('%Y-%m-%d')
    today_records = db.query(MilkProduction).filter(
        MilkProduction.farm_id == 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d'
    ).all()
    today_count = sum(1 for r in today_records if r.recorded_at.strftime('%Y-%m-%d') == today_str)

    print(f"[SUCCESS] Seeded {len(records_to_add)} records!")
    print(f"Total records now: {total}")
    print(f"Today's date (UTC): {today_str}")
    print(f"Today's records (farm_id filter): {today_count}")
    db.close()

if __name__ == "__main__":
    reseed_data()
