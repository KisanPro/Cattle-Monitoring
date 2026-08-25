# 📦 Component Inventory — Kisan Pro

## 1. Application Packages

| Component / Package Name | Path / Context | Purpose | Key Responsibilities |
| :--- | :--- | :--- | :--- |
| **`kisan_pro_sender`** | `kisan_pro_sender/` | Collar Edge Transmitter Node | 100 Hz IMU acquisition, edge step counting DSP, 7-state posture classifier, GPS parsing, battery ADC measurement, and 433 MHz LoRa RF packet transmission. |
| **`kisan_pro_receiver`** | `kisan_pro_receiver/` | Farm Gateway Receiver Node | 433 MHz LoRa frame reception, CRC check, RF bit-flip auto-correction, JSON formatting, Wi-Fi reconnection watchdog, and 4-tier HTTP POST failover. |
| **`mobile_app`** | `mobile_app/` | Flutter Android Mobile Client | Multi-screen application for cattle telemetry, behavioral donut visualization, GIS radar, dynamic geofencing, heat fertility tracking, alerts triage, and cloud configuration. |
| **`server`** | `server/` | AWS Cloud & AI Backend | Asynchronous FastAPI service, WebSocket live stream hub, 21-day rolling baseline AI engine, and multi-condition anomaly alarm generator. |

---

## 2. Infrastructure Packages

| Component Name | Type | Purpose | Key Technologies |
| :--- | :--- | :--- | :--- |
| **AWS EC2 Backend Host** | Cloud Compute | Hosts the public FastAPI ASGI service and WebSocket engine on Elastic IP `15.206.32.94:5000`. | Ubuntu Linux, Uvicorn, FastAPI, Python 3.10+ |
| **AWS S3 Storage Lake** | Cloud Storage | Multi-tier structured bucket archiving real-time snapshots, daily CSVs, and continuous JSONL streams. | AWS S3, Boto3, AWS IAM |
| **SQLite Data Store** | Embedded Relational DB | Local transactional database (`kisan_pro.db`) for telemetry records, baselines, alerts, cows, and geofence state. | SQLite 3, Python `sqlite3` / SQLAlchemy |

---

## 3. Shared Packages and Drivers

| Library / Module | Source / Ecosystem | Purpose |
| :--- | :--- | :--- |
| **`Adafruit_LSM6DSOX`** | Arduino / C++ | Hardware I2C communication with ST LSM6DSOX 6-DoF IMU. |
| **`TinyGPSPlus`** | Arduino / C++ | Non-blocking NMEA sentence parser for Quectel L89 multi-GNSS. |
| **`LoRa` (Sandeep Mistry)** | Arduino / C++ | Semtech SX1278 SPI driver and packet framing. |
| **`provider`** | Flutter / Dart | Reactive state management (`CattleProvider`). |
| **`http`** | Flutter / Dart | HTTP REST client with async timeout management (`ApiService`). |
| **`google_fonts`** | Flutter / Dart | Inter typography rendering. |
| **`intl`** | Flutter / Dart | Date, time, and numeric formatting. |
| **`url_launcher`** | Flutter / Dart | External URL and Google Maps navigation intent launcher. |

---

## 4. Test Packages

| Package Name | Ecosystem | Purpose |
| :--- | :--- | :--- |
| **`flutter_test`** | Flutter SDK | Unit and widget test runner for mobile application components. |
| **`flutter_lints`** | Dart Pub | Static analysis and style enforcement for Dart codebase. |

---

## 5. Total Inventory Summary

- **Total Application Packages**: 4 (`kisan_pro_sender`, `kisan_pro_receiver`, `mobile_app`, `server`)
- **Total Infrastructure Packages**: 3 (AWS EC2 Compute, AWS S3 Lake, SQLite DB)
- **Total Shared / Third-Party Libraries**: 8
- **Total Test Packages**: 2