import sqlite3
from pathlib import Path
from app.core.config import settings, TenantContext

def get_db_path(tenant_id: str) -> Path:
    tenant = TenantContext(tenant_id, Path(settings.farms_dir))
    db_dir = tenant.base_dir / "behavior_database"
    db_dir.mkdir(parents=True, exist_ok=True)
    return db_dir / "farm.db"

def get_db_connection(tenant_id: str) -> sqlite3.Connection:
    db_path = get_db_path(tenant_id)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    return conn

def init_db(tenant_id: str):
    conn = get_db_connection(tenant_id)
    cursor = conn.cursor()
    
    # 1. Cow daily behavior logs
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS cow_daily_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cow_id TEXT NOT NULL,
            standing_duration INTEGER NOT NULL,
            lying_duration INTEGER NOT NULL,
            eating_duration INTEGER NOT NULL,
            rumination_duration INTEGER NOT NULL,
            activity_score REAL NOT NULL,
            timestamp TEXT NOT NULL,
            UNIQUE(cow_id, timestamp)
        )
    """)
    
    # 2. Behavioral alerts table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cow_id TEXT NOT NULL,
            reason TEXT NOT NULL,
            severity TEXT NOT NULL,
            evidence TEXT,
            timestamp TEXT NOT NULL,
            resolved INTEGER DEFAULT 0
        )
    """)
    
    # 3. Behavioral baseline parameters
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS baselines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cow_id TEXT NOT NULL,
            metric TEXT NOT NULL,
            mean REAL NOT NULL,
            std_dev REAL NOT NULL,
            last_updated TEXT NOT NULL,
            UNIQUE(cow_id, metric)
        )
    """)
    
    conn.commit()
    conn.close()
    print(f"📡 Isolated database initialized for tenant '{tenant_id}' at {get_db_path(tenant_id)}.")
