# Component Inventory

**Project**: KisanPro — Cattle Milk Monitoring  
**Analysis Date**: 2026-09-04  
**Version**: 1.0 (Production Release)  

---

## Application Packages

- **`com.kisanpro.kisan_pro_milk_monitoring` (Flutter Mobile App)**: Main client-facing Android application delivering milking entry forms, real-time telemetry dashboards, interactive analytics charts, logbook searches, and PDF report generation.
- **`backend.main:app` (FastAPI REST Service)**: High-performance Python REST API server hosted on AWS EC2 (`54.144.103.253:8082`) serving CRUD endpoints and server-side aggregation.

---

## Infrastructure Packages

- **`AWS EC2: kisan-milk-server`**: Cloud compute instance (t3.micro, Ubuntu 24.04 LTS) executing the FastAPI/Uvicorn daemon with security groups for ports 22 (SSH) and 8082 (API).
- **`AWS RDS: kisan_pro_db`**: Managed PostgreSQL 18.3 relational database engine executing on `database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com:5432` with automated backups and ACID transactional durability.
- **`AWS Elastic IP: 54.144.103.253`**: Static public IPv4 address associated with the EC2 host ensuring persistent client connectivity.

---

## Shared Packages & Feature Modules

- **`integrated_feature_module`**: Reusable Dart feature package containing clean architecture layers (`data/`, `domain/`, `presentation/`, `core/theme/`) designed for seamless embedding into host farm applications.
- **`standalone_source_lib`**: Standalone, self-contained Flutter project source providing an independent entry point (`main.dart`) for standalone deployment.
- **`backend`**: Python database management scripts including `schema.sql`, `init_db.py`, `seed_cloud_data.py`, and `test_connection.py`.

---

## Test & Verification Artifacts

- **`test_connection.py`**: Automated database connectivity and query validation script.
- **`flutter_test` suite**: Static analysis and widget verification suite in Flutter.
- **`pytest` suite**: Python test execution framework.

---

## Total Count

- **Total Packages / Major Components**: 7
  - **Application Packages**: 2 (Flutter Mobile Client, FastAPI Cloud Server)
  - **Infrastructure Packages**: 3 (AWS EC2 Instance, AWS RDS PostgreSQL, AWS Elastic IP)
  - **Shared / Feature Packages**: 1 (Integrated Feature Module)
  - **Test Packages**: 1 (Database & API Verification Suite)
