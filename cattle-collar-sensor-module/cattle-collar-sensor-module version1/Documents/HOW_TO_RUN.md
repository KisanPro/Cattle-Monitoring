# 🚀 Kisan Pro: Step-by-Step Execution & Deployment Guide

This guide provides end-to-end instructions for running all hardware firmware, backend servers, AWS cloud storage pipelines, and the Android mobile application.

---

## 📋 1. Prerequisites & Required Tools

| Component | Software Required | Version / Notes |
| :--- | :--- | :--- |
| **Firmware Flashing** | [Arduino IDE](https://www.arduino.cc/en/software) | Version `2.x` or `1.8.19` with ESP32 Board Package `v2.0.14+` |
| **Cloud / Server** | [Python](https://www.python.org/) | Python `3.10+` with `pip` |
| **Mobile App** | [Flutter SDK](https://docs.flutter.dev/get-started/install) | Flutter `3.x` with Android SDK platform-tools (`adb`) |
| **Device Connection** | USB-to-MicroUSB / USB-C Cable | Android Phone with **USB Debugging** enabled |

---

## ⚡ 2. Flashing ESP32 Hardware Firmware

### A. Collar Transmitter Node (`kisan_pro_sender.ino`)
1. Open Arduino IDE.
2. Go to **Tools &rarr; Board &rarr; esp32 &rarr; ESP32 Dev Module**.
3. Select your serial COM port under **Tools &rarr; Port** (e.g. `COM5`).
4. Install the required libraries via **Sketch &rarr; Include Library &rarr; Manage Libraries...**:
   * `LoRa` by Sandeep Mistry
   * `TinyGPSPlus` by Mikal Hart
   * `Adafruit LSM6DSOX`
   * `Adafruit Unified Sensor`
   * `Adafruit BusIO`
5. Open `kisan_pro_sender/kisan_pro_sender.ino`.
6. Click **Upload** (Hold `BOOT` button on ESP32 if uploading pauses at `Connecting...`).
7. Open **Serial Monitor** at `115200 Baud` to verify:
   ```text
   === Kisan Pro Collar: Master Node Started ===
   ID: KA_1989
   [OK] LoRa Radio Initialized at 433 MHz (SF7, 125kHz).
   [OK] LSM6DSOX Sensor Initialized.
   [OK] Quectel L89 GNSS Initialized on RX2:16, TX2:17.
   ```

---

### B. Farm Gateway Node (`kisan_pro_receiver.ino`)
1. Connect the Gateway ESP32 board via USB.
2. Select the corresponding serial COM port (e.g. `COM7`).
3. Open `kisan_pro_receiver/kisan_pro_receiver.ino`.
4. Verify your local Wi-Fi credentials in lines 15-16:
   ```cpp
   const char* ssid = "Geetha Shivaiah";
   const char* password = "your_password";
   ```
5. Click **Upload**.
6. Open **Serial Monitor** at `115200 Baud` to verify:
   ```text
   === Kisan Pro Collar: AWS Master Gateway ===
   [WiFi] Connecting to 'Geetha Shivaiah'.....
   [OK] Connected to WiFi! IP Address: 192.168.0.xxx
   [OK] LoRa Gateway Ready on 433 MHz. Listening for Collar packets...
   ```

---

## 🐍 3. Running Cloud Server & Backend

### A. Environment Configuration (`.env`)
Ensure `.env` in the root workspace contains your AWS S3 credentials:
```ini
AWS_ACCESS_KEY_ID=AKIAZATDVTTQIDYIJYOS
AWS_SECRET_ACCESS_KEY=QyDJsboPPyXiJJ8bzlMpkPBohA82CTog+fWyfDRL
AWS_S3_BUCKET=cattle-collar-sensor
AWS_REGION=us-east-1
```

### B. Install Python Dependencies
Open PowerShell or Terminal and run:
```powershell
pip install fastapi uvicorn pydantic requests websockets boto3
```

### C. Start FastAPI Backend Server
```powershell
python server/server.py
```
* **Local API URL**: `http://localhost:5005` (or `http://192.168.0.xxx:5005`)
* **AWS Cloud API URL**: `http://15.206.32.94:5000`
* **Swagger Interactive Docs**: `http://localhost:5005/docs`
* **WebSocket Endpoint**: `ws://localhost:5005/ws/live`

---

## 📱 4. Building & Installing Mobile App on Android Device

### A. Enable USB Debugging on Android Phone
1. Go to **Settings &rarr; About Phone**.
2. Tap **Build Number** 7 times to enable **Developer Options**.
3. In **Developer Options**, turn ON **USB Debugging**.
4. Connect phone to laptop with USB cable and tap **Allow USB Debugging**.

### B. Verify ADB Connection
In PowerShell, run:
```powershell
adb devices
```
*Output should display your device ID:*
```text
List of devices attached
TOOJ6HXOW4NBKVS8    device
```

### C. Compile & Install Release APK
Navigate to the `mobile_app` folder and build:
```powershell
cd mobile_app
flutter build apk --release --no-tree-shake-icons
```

### D. Stream Install Directly to Phone
```powershell
adb install -r -d build/app/outputs/flutter-apk/app-release.apk
adb shell monkey -p com.kisanpro.cattlecollar.mobile_app -c android.intent.category.LAUNCHER 1
```

---

## 🧪 5. Testing & Verification

1. **Collar & Gateway Check**: Ensure the collar transmitter sends a packet every 5 seconds. The gateway serial monitor will print:
   ```text
   [LoRa RX] Received packet (48 bytes) | RSSI: -42 dBm | SNR: 9.5 dB
   [HTTP Success] AWS Cloud Code: 200
   ```
2. **AWS S3 Console Check**: Open AWS S3 Console &rarr; Bucket `cattle-collar-sensor` &rarr; `farm_8088327803_Samruddi/KA_1989/`. Verify that `latest_telemetry.json` and `telemetry_YYYY-MM-DD.csv` are updated in real time.
3. **Mobile App Check**: Open **Kisan Pro** on your phone.
   * **Posture Tab**: Shows real-time posture (Standing, Grazing, Walking, etc.) and step odometer.
   * **GPS Tab**: Displays live pasture marker, geofence boundary circle, and turn-by-turn navigation.
   * **Fertility Tab**: Displays the 24-hour Behavior Breakdown Donut Chart with percentage pill badges.
   * **Tags Tab**: Displays your livestock directory with live vs offline status pills and registration form.
