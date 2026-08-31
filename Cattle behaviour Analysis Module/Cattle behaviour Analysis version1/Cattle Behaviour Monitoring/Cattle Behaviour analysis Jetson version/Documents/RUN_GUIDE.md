# Kisan CattleVision: Terminal Execution & Run Guide

This document provides step-by-step terminal commands to launch, monitor, and manage each component of the Kisan CattleVision system.

---

## Quick Reference: Run All Components

### Option 1: Using Systemd Background Services (Production - Recommended)
To run the background services on boot or manage them via systemctl:

```bash
# 1. Install and enable production systemd services
cd "/home/mr/Documents/Cattle Behaviour analysis Jetson version"
sudo bash install_service.sh

# 2. Start the core Jetson AI & Web Application service
sudo systemctl start kisan_ai.service

# 3. Start the 24/7 CCTV Recording service
sudo systemctl start kisan-stream-store.service

# 4. Check status of services
sudo systemctl status kisan_ai.service
sudo systemctl status kisan-stream-store.service
```

---

## Option 2: Running Components Manually in Terminal

If you are debugging or running services manually in terminal windows:

### Step 1: Start Main Jetson Application (Edge AI + Local Dashboard)
Open **Terminal 1**:
```bash
cd "/home/mr/Documents/Cattle Behaviour analysis Jetson version/Kisan_Jetson"
python3 jetson_app.py
```
- **Local Web Dashboard**: `http://localhost:8000`
- **Flutter Web App**: `http://localhost:8000/app`

---

### Step 2: Start Telemetry & Live Stream Forwarder (Jetson -> AWS Cloud)
Open **Terminal 2**:
```bash
cd "/home/mr/Documents/Cattle Behaviour analysis Jetson version/Kisan_Jetson_Mobile/stream_forwarder"
python3 forwarder.py
```
- Relays local telemetry status, alerts, and live camera frames to the AWS EC2 cloud relay server.

---

### Step 3: Start AWS EC2 Cloud Relay Server (Cloud Server / Relay Host)
Open **Terminal 3** (or on EC2 instance):
```bash
cd "/home/mr/Documents/Cattle Behaviour analysis Jetson version/Kisan_Jetson_Mobile/ec2_server"
python3 app.py
```
- Starts public relay server on port `8080` for remote Flutter mobile client access (`http://<EC2_IP>:8080`).

---

### Step 4: Start 24/7 CCTV Video Stream Storing Service
Open **Terminal 4**:
```bash
cd "/home/mr/Documents/Cattle Behaviour analysis Jetson version/Kisan_Jetson"
python3 stream_storing.py
```
- Records raw camera RTSP streams into 3-hour fragmented MP4 slots (`slot_12AM_3AM.mp4`, etc.) with zero corruption risk.

---

### Step 5: Start Mobile App (Flutter Client)
Open **Terminal 5**:
```bash
cd "/home/mr/Documents/Cattle Behaviour analysis Jetson version/Kisan_Jetson_Mobile/flutter_app/flutter_app"
/home/mr/flutter/bin/flutter run -d chrome
```
*(Or launch on Android/iOS device connected via USB)*

---

## Terminal Command Cheat Sheet

| Task | Command | Directory |
| :--- | :--- | :--- |
| **Start Jetson App** | `python3 jetson_app.py` | `Kisan_Jetson/` |
| **Start Forwarder** | `python3 forwarder.py` | `Kisan_Jetson_Mobile/stream_forwarder/` |
| **Start EC2 Relay** | `python3 app.py` | `Kisan_Jetson_Mobile/ec2_server/` |
| **Start Stream Recording** | `python3 stream_storing.py` | `Kisan_Jetson/` |
| **Build Flutter Web** | `/home/mr/flutter/bin/flutter build web` | `Kisan_Jetson_Mobile/flutter_app/flutter_app/` |
| **View Live Systemd Logs** | `sudo journalctl -u kisan_ai.service -f` | Any |
| **Stop All Running Python Services** | `pkill -f "python3 jetson_app.py"` | Any |

---

## Stopping Services

To stop all active services cleanly in terminal:
```bash
# Stop systemd services if running
sudo systemctl stop kisan_ai.service kisan-stream-store.service cctv_recorder.service

# Terminate manual terminal processes
pkill -f jetson_app.py
pkill -f forwarder.py
pkill -f stream_storing.py
```
