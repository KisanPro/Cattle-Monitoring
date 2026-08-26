# Technology Stack

**Project**: KisanPro — Cattle Milk Monitoring  
**Version**: 1.0

---

## Programming Languages

| Language | Version | Usage |
|:---------|:--------|:------|
| **Dart** | 3.x | Flutter mobile app — all business logic, UI, and data layer |
| **Python** | 3.14 | FastAPI backend server on AWS EC2 |
| **SQL (PostgreSQL dialect)** | — | Database schema definitions and queries via SQLAlchemy |

---

## Frameworks

| Framework | Version | Purpose |
|:----------|:--------|:--------|
| **Flutter** | 3.x stable | Cross-platform mobile UI framework (Android APK target) |
| **FastAPI** | 0.141.1 | Python REST API framework with auto Swagger docs |
| **SQLAlchemy** | 2.0.52 | Python ORM for PostgreSQL — declarative model definitions |
| **Pydantic** | 2.13.4 | Data validation and schema serialization for FastAPI |
| **Material Design 3** | — | UI design system used in Flutter app |

---

## Flutter Packages (pubspec.yaml dependencies)

| Package | Purpose |
|:--------|:--------|
| `provider` | State management (ChangeNotifier / Consumer pattern) |
| `google_fonts` | Outfit font family for branded typography |
| `intl` | International date/number formatting |
| `firebase_core` | Firebase SDK initialization (legacy — still present in standalone_source_lib) |
| `cloud_firestore` | Firebase Firestore (legacy — integrated_feature_module MilkRecordModel still imports it) |
| `dart:io` | Native HTTP client used by PostgresMilkService |
| `dart:convert` | JSON encoding/decoding |
| `dart:async` | StreamController, Timer for polling |

---

## Infrastructure

| Service | Provider | Purpose |
|:--------|:---------|:--------|
| **EC2 (kisan-milk-server)** | AWS | Runs FastAPI + Uvicorn on port 8082 |
| **RDS PostgreSQL 18.3** | AWS | Primary persistent database (kisan_pro_db) |
| **Ubuntu 24.x (Noble)** | AWS | OS for EC2 instance |
| **PEP 668 environment** | Ubuntu | Externally managed Python — uses `--break-system-packages` |

### AWS Infrastructure Details

| Item | Value |
|:-----|:------|
| EC2 Instance Type | t3.micro |
| EC2 Region | us-east-1a |
| EC2 Public IP | 100.31.238.245 |
| EC2 Key Pair | kisan-milk-key.pem |
| RDS Endpoint | database-1.cqtisasy6e6b.us-east-1.rds.amazonaws.com |
| RDS Port | 5432 |
| RDS Instance Class | db.t3.micro |
| Database Name | kisan_pro_db |
| DB User | postgres |

---

## Build Tools

| Tool | Version | Purpose |
|:-----|:--------|:--------|
| **Gradle** | 8.x | Android build system for Flutter APK |
| **Kotlin Gradle Plugin** | — | Kotlin compilation for Android platform code |
| **Android NDK** | 25.1.8937393 | Native code compilation (required by printing plugin) |
| **JDK** | 17.0.19 (Temurin) | Java runtime for Gradle build |
| **pip3** | 25.1.1 | Python package installer |
| **Uvicorn** | 0.52.4 | ASGI server running FastAPI in production |

---

## Testing Tools

| Tool | Version | Purpose | Status |
|:-----|:--------|:--------|:-------|
| `test_connection.py` | — | Manual AWS RDS connectivity verification | Basic — exists |
| Flutter DevTools | — | Widget inspection, performance profiling | Available but not configured |
| FastAPI Swagger UI | — | Auto-generated REST API testing interface at `/docs` | Active at `http://100.31.238.245:8082/docs` |
| MockMilkService | — | Built-in simulation for offline/no-network testing | Integrated |

---

## Development Tools

| Tool | Purpose |
|:-----|:--------|
| **VS Code / Cursor** | Primary IDE |
| **Android Studio** | APK signing and build verification |
| **PowerShell** | Windows scripting for build/copy tasks |
| **SSH (OpenSSH)** | EC2 remote access |
| **SCP** | File transfer to EC2 |
| **Postman / Browser** | REST API manual testing |
