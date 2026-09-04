from sqlalchemy import create_engine, text

DATABASE_URL = "postgresql://postgres:%23kisanpro123@database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com:5432/kisan_pro_db"
engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    print("Running migration on AWS RDS PostgreSQL...")
    conn.execute(text("ALTER TABLE milk_production ADD COLUMN IF NOT EXISTS farmer_phone VARCHAR(20);"))
    conn.execute(text("ALTER TABLE milk_production ADD COLUMN IF NOT EXISTS farmer_name VARCHAR(100);"))
    conn.execute(text("ALTER TABLE milk_production ADD COLUMN IF NOT EXISTS farm_name VARCHAR(100);"))
    conn.execute(text("CREATE INDEX IF NOT EXISTS idx_milk_prod_farmer_phone ON milk_production(farmer_phone);"))
    conn.execute(text("UPDATE milk_production SET farmer_phone = '9876543210', farmer_name = 'Rajesh Kumar', farm_name = 'Green Valley Dairy' WHERE farmer_phone IS NULL;"))
    conn.commit()
    print("Schema migration complete! Columns and indexes created.")
