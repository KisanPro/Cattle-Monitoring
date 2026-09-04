"""
AWS RDS PostgreSQL Connection Test Script
Run this script to verify that your AWS RDS PostgreSQL database is accessible.
"""

import sys
import psycopg2
from sqlalchemy import create_engine, text

def test_db_connection(db_url: str):
    print("--------------------------------------------------")
    print("Testing connection to AWS RDS PostgreSQL...")
    print(f"Target DB URL: {db_url.split('@')[-1] if '@' in db_url else db_url}")
    print("--------------------------------------------------")
    
    try:
        engine = create_engine(db_url)
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version();")).fetchone()
            print("[SUCCESS] Connected to AWS RDS PostgreSQL Database!")
            print(f"PostgreSQL Version: {result[0]}")
            
            # Check if kisan_pro_db exists
            tables_result = conn.execute(text("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public';
            """)).fetchall()
            
            tables = [row[0] for row in tables_result]
            print(f"Current Tables in Database: {tables}")
            
    except Exception as e:
        print("[CONNECTION FAILED]")
        print(f"Error details: {e}")
        print("\nTroubleshooting Checklist:")
        print("1. Did you paste the exact AWS RDS Endpoint URL?")
        print("2. Is your database status 'Available' in AWS Console?")
        print("3. Did you set Public Access to 'Yes' in AWS RDS?")
        print("4. Does your Inbound VPC Security Group allow Port 5432?")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        url = sys.argv[1]
    else:
        url = input("Enter your AWS RDS Database URL (or Endpoint): ").strip()
        
    if not url.startswith("postgresql://"):
        endpoint = url
        password = "%23kisanpro123"  # URL-encoded #kisanpro123
        url = f"postgresql://postgres:{password}@{endpoint}:5432/kisan_pro_db"
        
    test_db_connection(url)
