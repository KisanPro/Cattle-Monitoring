# 🛠️ Technology Stack — Kisan Pro

## 1. Programming Languages

| Language | Standard / Version | Primary Usage in Project |
| :--- | :--- | :--- |
| **C++ / C (Arduino Framework)** | C++11 / C++14 | Collar edge transmitter node (`kisan_pro_sender.ino`) & farm gateway receiver (`kisan_pro_receiver.ino`) firmware. |
| **Dart** | Dart 3.5.0+ | Native Flutter mobile application logic, reactive state management, and UI rendering. |
| **Python** | Python 3.10+ | Cloud backend (`server.py`), 21-day baseline machine learning engine (`analytics.py`), and AWS S3 data pipeline. |
| **SQL** | SQLite 3 Standard | Relational schema definitions and queries for telemetry, cattle profiles, geofences, and alarms. |

---

## 2. Frameworks and SDKs

| Framework / SDK | Version | Ecosystem | Purpose |
| :--- | :--- | :--- | :--- |
| **Flutter** | 3.24.x (Channel Stable) | Google / Cross-Platform | Native Android client UI development with Material 3 theming. |
| **FastAPI** | 0.100.x+ | Python | High-performance asynchronous REST API & WebSocket server. |
| **Uvicorn** | 0.22.x+ | Python | Lightning-fast ASGI web server implementation. |
| **Boto3** | 1.28.x+ | Python | Official AWS SDK for S3 bucket ingestion and data lake synchronization. |
| **Arduino ESP32 Core** | 2.0.x / 3.0.x | Espressif Systems | Low-level hardware drivers, RTOS integration, and FreeRTOS task scheduling. |

---

## 3. Hardware Modules and Protocols

| Component / Protocol | Specification | Details |
| :--- | :--- | :--- |
| **ESP32-WROOM-32** | 240 MHz Dual-Core Tensilica LX6 | Edge computation, DSP filtering, Wi-Fi 802.11 b/g/n, and SPI/I2C/UART controllers. |
| **Semtech SX1278** | 433 MHz ISM Band | Ultra-long-range LoRa RF modulation (SF7, 125 kHz bandwidth, 17 dBm TX power). |
| **ST LSM6DSOX** | 6-Axis IMU (3D Accel + 3D Gyro) | High-speed 100 Hz kinematic sampling over I2C (`0x6A`). |
| **Quectel L89** | Multi-Constellation GNSS | GPS, GLONASS, Galileo, BeiDou sub-meter tracking at 9600 baud UART. |
| **Analog ADC** | 12-Bit Resolution (GPIO 35) | $100\text{k}\Omega / 100\text{k}\Omega$ voltage divider for 3.7V–4.2V LiPo battery monitoring. |

---

## 4. Cloud Infrastructure and Hosting

| Service | Provider | Configuration / Role |
| :--- | :--- | :--- |
| **Amazon EC2** | AWS (Amazon Web Services) | Virtual compute host with Elastic Public IP `15.206.32.94`, running FastAPI service on port 5000. |
| **Amazon S3** | AWS | Structured data lake (`s3://cattle-collar-sensor/`) with partitioned JSON, CSV, and JSONL streams. |
| **AWS IAM** | AWS | Policy-based role authentication for secure S3 object uploads. |

---

## 5. Build and Development Tools

| Tool | Version | Purpose |
| :--- | :--- | :--- |
| **Flutter CLI** | 3.24.x | Mobile app building, debugging, asset bundling, and release compilation. |
| **Arduino IDE / ESP-IDF** | 2.x | Microcontroller compilation, serial monitor diagnostics, and firmware flashing. |
| **pip / venv** | 23.x+ | Python package management and virtual environment isolation. |
| **Android SDK / Gradle** | Android 14 (API 34) | Native Android packaging and APK generation (`KisanPro_Cattle_Telemetry.apk`). |
| **Git** | 2.4x+ | Distributed version control. |

---

## 6. Testing Tools

| Tool | Scope | Purpose |
| :--- | :--- | :--- |
| **`flutter_test`** | Mobile Application | Unit testing and widget smoke testing. |
| **`flutter_lints`** | Mobile Application | Static code analysis and linting according to Dart style guidelines. |
| **Hardware Serial Monitor** | Firmware | Real-time diagnostic logging (115200 baud) for LoRa packet transmission and NMEA sentence feeds. |