"""
AWS RDS PostgreSQL Table Creation Script for Cattle Milk Monitoring
Initializes all database tables automatically.
"""

from main import Base, engine, MilkProduction
from sqlalchemy import text

def init_tables():
    print("--------------------------------------------------")
    print("Creating tables in AWS RDS PostgreSQL Database...")
    print("--------------------------------------------------")
    
    # Create all ORM tables
    Base.metadata.create_all(bind=engine)
    
    # Execute raw schema for farms and cattle tables if needed
    with engine.connect() as conn:
        conn.execute(text("""
        CREATE TABLE IF NOT EXISTS farms (
            farm_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            farm_name VARCHAR(100) NOT NULL,
            farmer_name VARCHAR(100) NOT NULL,
            phone_number VARCHAR(15),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        """))
        
        conn.execute(text("""
        CREATE TABLE IF NOT EXISTS cattle (
            cattle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            farm_id UUID NOT NULL REFERENCES farms(farm_id) ON DELETE CASCADE,
            tag_number VARCHAR(50) UNIQUE NOT NULL,
            cattle_name VARCHAR(100),
            breed VARCHAR(50),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
        """))
        
        conn.commit()
        
        # Verify created tables
        tables = conn.execute(text("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public';
        """)).fetchall()
        
        print("[SUCCESS] Database Tables Initialized in AWS RDS!")
        print("Created Tables:", [row[0] for row in tables])

if __name__ == "__main__":
    init_tables()
