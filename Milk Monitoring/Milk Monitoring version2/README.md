# KisanPro Cattle Milk Monitoring & Precision Dairy System: Version 2

This repository contains the source code, training configurations, FastAPI REST endpoints, and user manuals for the Version 2 implementation of the KisanPro Cattle Milk Monitoring and Precision Dairy system.

---

## System Overview

The Cattle Milk Monitoring Platform is a three-tier mobile-first system designed to track, log, and analyze milk production metrics across herds. 

### Key Version 2 Enhancements
* **Dual Operating Modes**:
  * **Simulation Mode**: Run completely offline using a local mock repository pre-populated with 10 days of historical data for 4 cattle.
  * **Cloud Sync Mode**: Connect to a live FastAPI microservice deployed on AWS EC2.
* **AWS RDS PostgreSQL Engine**: Upgraded backend from legacy Firebase to a robust relational database (PostgreSQL 18.3) hosted on AWS RDS.
* **Aggregated Dairy Analytics**: Automatic calculations for Fat content, Solid-Not-Fat (SNF) metrics, and custom quality pricing parameters.

---

## Technical Architecture

```text
  [ Flutter Mobile App ] <---> [ FastAPI Server ] <---> [ AWS RDS PostgreSQL ]
```

1. **Presentation Layer (Mobile App)**: Native Flutter client displaying logbooks, dashboard analytics, and exporting production logs to PDF.
2. **Application Layer (FastAPI Backend)**: Python REST API handling ORM schema validations, secure migrations, and data routing.
3. **Data Layer (AWS RDS PostgreSQL)**: Secure database cluster storing daily session logs, cow registry info, and farm analytics.

---

## Directory Structure

* **`cattle_milk_monitoring code/`**:
  * `backend/`: FastAPI Python server files, SQLAlchemy database schemas, and data seeding scripts.
  * `standalone_source_lib/`: Independent Dart/Flutter state providers and network clients.
  * `integrated_feature_module/`: Complete UI screens and data logging components.
  * `apks/`: Standard and universal compiled installation files under 50 MB.
* **`Documents/`**: Technical architectures, reverse engineering notes, and dependency logs.
* **`Output/`**: Verification reports, analytical logs, and video walkthroughs.
* **`apk/`**: Folder reserved for compiled installer packages exceeding repository limitations.
* **`user_manual/`**: Detailed reproduction, setup, and deployment manuals.
* **`requirements.txt`**: Complete list of Python backend dependencies.

---

## Setup & Deployment Guide

### 1. Python Environment Setup
Install the Python packages:
```bash
pip install -r requirements.txt
```

### 2. Database Initialization
Seed the AWS RDS PostgreSQL database with default schemas and test records:
```bash
cd "cattle_milk_monitoring code/backend"
python init_db.py
python seed_cloud_data.py
```

### 3. Backend REST Server Launch
Start the FastAPI server on port 8082:
```bash
python main.py
```

---

## Repository Exclusions Notice

To maintain optimal git speeds and adhere to GitHub's file size limits, the following files are excluded from direct version control:
* **Compiled Installers**: Built Android APKs exceeding 100 MB (`kisan_pro_milk_monitoring.apk`, `KisanPro_Universal_v1.0.apk`, and `milk_monitoring_debug.apk`).

Please refer to the designated Google Drive folder linked in the `apk/` directory to download these installer binaries.
