-- ============================================================
-- PostgreSQL Database Schema for Cattle Milk Monitoring
-- Compatible with AWS RDS / AWS EC2 PostgreSQL
-- ============================================================

-- Enable UUID Extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Farms Table
CREATE TABLE IF NOT EXISTS farms (
    farm_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_name VARCHAR(100) NOT NULL,
    farmer_name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15),
    location VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Cattle Table
CREATE TABLE IF NOT EXISTS cattle (
    cattle_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID NOT NULL REFERENCES farms(farm_id) ON DELETE CASCADE,
    tag_number VARCHAR(50) UNIQUE NOT NULL,
    cattle_name VARCHAR(100),
    breed VARCHAR(50),
    age_years INT,
    lactation_stage VARCHAR(50),
    health_status VARCHAR(50) DEFAULT 'Healthy',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Milk Production Table
CREATE TABLE IF NOT EXISTS milk_production (
    record_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cattle_id UUID NOT NULL REFERENCES cattle(cattle_id) ON DELETE CASCADE,
    farm_id UUID NOT NULL REFERENCES farms(farm_id) ON DELETE CASCADE,
    quantity_liters FLOAT NOT NULL,
    quality_grade VARCHAR(20) DEFAULT 'Grade A',
    fat_percentage FLOAT,
    snf_percentage FLOAT,
    milking_time VARCHAR(10) NOT NULL CHECK (milking_time IN ('morning', 'evening')),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Milk Analytics Summary Table (Optional aggregated cache)
CREATE TABLE IF NOT EXISTS milk_analytics (
    analytics_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id UUID UNIQUE NOT NULL REFERENCES farms(farm_id) ON DELETE CASCADE,
    daily_total FLOAT DEFAULT 0.0,
    morning_total FLOAT DEFAULT 0.0,
    evening_total FLOAT DEFAULT 0.0,
    avg_daily FLOAT DEFAULT 0.0,
    weekly_total FLOAT DEFAULT 0.0,
    monthly_total FLOAT DEFAULT 0.0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for ultra-fast queries by farm and cattle ID
CREATE INDEX IF NOT EXISTS idx_milk_prod_farm ON milk_production(farm_id);
CREATE INDEX IF NOT EXISTS idx_milk_prod_cattle ON milk_production(cattle_id);
CREATE INDEX IF NOT EXISTS idx_milk_prod_time ON milk_production(recorded_at);
