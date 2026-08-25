# KisanPro Cattle Collar Sensor Module: Version 1

This repository contains the complete firmware, hardware pinouts, CAD schematics, and mobile monitoring client codebase for the KisanPro Livestock collar and farm gateway system.

---

## Technical Specifications

The system is split into two primary hardware nodes: the wearable collar transmitter and the farm gateway receiver, both using the ESP32 microcontroller platform.

### 1. Collar Transmitter Node (ESP32 Sender)
Wearable hardware unit deployed on individual livestock to monitor real-time location, body posture, and health indicators.
* **Microcontroller**: ESP32-WROOM-32D (240 MHz Dual-Core, 4MB Flash)
* **GPS Module**: Quectel L89 (UART interface, embedded patch antenna, support for GPS/GLONASS/Galileo/BDS)
* **IMU Sensor**: STMicroelectronics LSM6DSOX (6-axis accelerometer and gyroscope, I2C interface at address 0x6A)
* **LoRa Radio**: Semtech SX1278 (SPI interface, 433 MHz band, +20 dBm power output)
* **Power Source**: 3.7V - 4.2V LiPo battery monitored via a 100k ohm / 100k ohm analog voltage divider on GPIO 35.

### 2. Farm Gateway Node (ESP32 Receiver)
Stationary receiver unit deployed at the farm shed to capture telemetry packets and relay them to the cloud.
* **Microcontroller**: ESP32-WROOM-32D
* **LoRa Radio**: Semtech SX1278 (SPI interface, 433 MHz band)
* **Internet Link**: Dual-band Wi-Fi connection configured in Station (STA) mode.
* **Relay Target**: AWS REST API (API Gateway + AWS Lambda + Amazon DynamoDB).

---

## Pin Mapping Configuration

### Collar Transmitter Mappings
| Peripheral | Pin | ESP32 GPIO | Bus / Protocol | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Quectel L89 GPS** | `TXD` | `GPIO 16` (RXD2) | UART2 (9600 bps) | Captures NMEA sentences |
| **Quectel L89 GPS** | `RXD` | `GPIO 17` (TXD2) | UART2 (9600 bps) | Control configuration |
| **ST LSM6DSOX IMU** | `SDA` | `GPIO 21` | I2C (Fast Mode 400kHz) | 100 Hz Accel + Gyro stream |
| **ST LSM6DSOX IMU** | `SCL` | `GPIO 22` | I2C | Clock signal line |
| **Semtech SX1278** | `NSS / CS` | `GPIO 5` | SPI | Hardware Chip Select |
| **Semtech SX1278** | `RESET` | `GPIO 14` | Digital Output | Hardware Reset |
| **Semtech SX1278** | `DIO0` | `GPIO 26` | Digital Interrupt | Packet RX/TX trigger |
| **Semtech SX1278** | `SCK` | `GPIO 18` | SPI | SPI Bus Clock |
| **Semtech SX1278** | `MISO` | `GPIO 19` | SPI | Master Input line |
| **Semtech SX1278** | `MOSI` | `GPIO 23` | SPI | Master Output line |
| **Battery Divider** | `V_DIV` | `GPIO 35` | ADC1 (12-bit) | Voltage divider input |

### Farm Gateway Mappings
| Peripheral | Pin | ESP32 GPIO | Bus / Protocol | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Semtech SX1278** | `NSS` | `GPIO 5` | SPI | Hardware Chip Select |
| **Semtech SX1278** | `RST` | `GPIO 14` | Digital Output | Hardware Reset |
| **Semtech SX1278** | `DIO0` | `GPIO 26` | Digital Interrupt | Ingestion trigger |
| **Semtech SX1278** | `SCK` | `GPIO 18` | SPI | SPI Bus Clock |
| **Semtech SX1278** | `MISO` | `GPIO 19` | SPI | Master Input line |
| **Semtech SX1278** | `MOSI` | `GPIO 23` | SPI | Master Output line |
| **Activity LED** | `Anode` | `GPIO 2` | Digital Output | Blinks on valid packets |

---

## Power Calculation Formulas

To compute battery charge percentage from the analog pins, the following formulas are implemented in the C++ firmware:

$$\text{V}_{\text{ADC}} = \text{V}_{\text{battery}} \times \left(\frac{R_2}{R_1 + R_2}\right) = \frac{\text{V}_{\text{battery}}}{2}$$

$$\text{V}_{\text{battery}} = 2.0 \times \left(\frac{\text{AnalogRead}(\text{GPIO 35})}{4095.0}\right) \times 3.3\text{V}$$

$$\text{Battery Percentage} = \left(\frac{\text{V}_{\text{battery}} - 3.40\text{V}}{4.20\text{V} - 3.40\text{V}}\right) \times 100\%$$

* **Full Capacity**: 4.20V (100% capacity)
* **Nominal Capacity**: 3.70V (40% capacity)
* **Cutoff Voltage**: 3.40V (0% capacity)

---

## Repository Contents

* **`3D Casing/`**: Technical STL design files for custom printing the collar casing.
* **`Cattle Collar Sensor Code/`**:
  * `kisan_pro_sender/`: C++ Arduino firmware source code for the ESP32 transmitter collar.
  * `kisan_pro_receiver/`: C++ Arduino firmware source code for the ESP32 farm gateway.
  * `mobile_app/`: Complete Flutter mobile app project handling posture dashboard, maps, geofences, and alarms.
* **`Documents/`**: Detailed API specs, code quality, dependency, and setup docs.
* **`Outputs/`**:
  * `levels/Level 1 - Lab Environment/`: Local test logs and board layouts.
  * `levels/Level 2 - Lab Real time/`: Includes demonstration videos (`CattleVision_Mobile_App_GPS_Geofence_Navigation_Demo.mp4` and `Receiver data In IDE_.mp4`).
  * `levels/Level 3 - Field Real time/`: Farm field trial photographs.
* **`apk/`**: Built application package `Kisan Pro Telemetry.apk` (33.6 MB) for mobile testing.
* **`user_manual/`**: Detailed user guide files.

---

## Setup & Deployment Instructions

### 1. Firmware Compiling
1. Install the Arduino IDE or PlatformIO.
2. Load the ESP32 Arduino core library.
3. Import the dependencies: `LoRa`, `TinyGPS++`, and `Adafruit_LSM6DS`.
4. Open `kisan_pro_sender/kisan_pro_sender.ino` and upload it to the ESP32 collar board.
5. Open `kisan_pro_receiver/kisan_pro_receiver.ino`, configure your local Wi-Fi SSID/password, and upload it to the ESP32 gateway board.

### 2. Flutter Mobile Application
1. Install Flutter SDK (version 3.x is recommended).
2. Configure Android Studio / VS Code.
3. Navigate to `Cattle Collar Sensor Code/mobile_app` and run:
   ```bash
   flutter pub get
   flutter run
   ```
