# Technology Stack

**Project**: KisanPro — Cattle Milk Monitoring  
**Analysis Date**: 2026-09-04  
**Version**: 1.0 (Production Release)  

---

## Programming Languages

| Language | Version | Usage |
|:---|:---|:---|
| **Dart** | 3.4.0+ | Mobile client application, business domain logic, UI widgets |
| **Python** | 3.11 / 3.14 | Backend REST API server, database ORM, data seeding |
| **SQL** | PostgreSQL 18.3 DDL | Relational database schema, table indexing, constraints |
| **Kotlin / Java** | 21 (OpenJDK) | Android native build wrapper, Gradle execution |

---

## Frameworks & Libraries

### Mobile Client (Flutter / Dart)
| Framework / Library | Version | Purpose |
|:---|:---|:---|
| **Flutter SDK** | 3.x stable | Cross-platform UI toolkit and mobile framework |
| **Provider** | `^6.1.2` | Reactive state management and dependency injection |
| **fl_chart** | `^0.68.0` | High-performance interactive charts and data visualization |
| **pdf & printing** | `^3.10.8` / `^5.11.1` | Native PDF document generation and printing engine |
| **intl** | `^0.19.0` | Date/time parsing, formatting, and currency localization |
| **google_fonts** | `^6.2.1` | Material 3 typography rendering (Outfit typeface) |

### Cloud Backend (Python / FastAPI)
| Framework / Library | Version | Purpose |
|:---|:---|:---|
| **FastAPI** | `0.115.8` | High-performance asynchronous REST API framework |
| **Uvicorn** | `0.34.0` | Lightning-fast ASGI production server |
| **SQLAlchemy** | `2.0.38` | SQL toolkit and Object-Relational Mapping (ORM) engine |
| **psycopg2-binary** | `2.9.10` | High-performance PostgreSQL database adapter |
| **Pydantic** | `2.10.6` | Data validation, parsing, and serialization |

---

## Cloud Infrastructure & Services

| Service | Specification | Purpose |
|:---|:---|:---|
| **AWS EC2** | t3.micro (Ubuntu 24.04 LTS) | Hosts the FastAPI/Uvicorn application backend |
| **AWS Elastic IP** | `54.144.103.253` | Dedicated static IPv4 address for permanent API routing |
| **AWS RDS** | PostgreSQL 18.3 (`kisan_pro_db`) | Managed multi-AZ relational cloud database |
| **Security Groups** | Ports 22, 8082, 5432 | Inbound traffic filtering and network isolation |

---

## Build & Testing Tools

| Tool | Version | Purpose |
|:---|:---|:---|
| **Gradle** | 8.x | Android compilation and APK packaging |
| **Flutter CLI** | 3.x | Dart kernel compilation, static analysis (`flutter analyze`) |
| **ADB (Android Debug Bridge)** | 35.x | USB deployment and live device testing |
| **pytest & flake8** | 8.x / 7.x | Python unit testing and PEP-8 linting |
