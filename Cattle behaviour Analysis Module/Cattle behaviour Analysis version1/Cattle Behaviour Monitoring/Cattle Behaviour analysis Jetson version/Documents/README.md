# Kisan CattleVision: Edge AI & Mobile Farm Telemetry System

## Overview
**Kisan CattleVision** is an edge-AI powered livestock monitoring and farm security system designed for deployment on Nvidia Jetson devices. The system combines multi-camera computer vision (YOLOv8 & Person/Cattle ReID), real-time behavior analytics, local web dashboard monitoring, fragmented 24/7 stream recording, cloud telemetry forwarding, and a Flutter mobile application.

---

## Key Features

### 1. Cattle Identification & Behavior Tracking
- **Ear Tag Recognition & ReID**: Automatically identifies individual cattle using visual ear tags and ReID feature matching.
- **Behavior Monitoring**: Analyzes cattle posture (Standing, Lying) and feeding activity (Feeding, Idle) with temporal rolling window smoothing.
- **Deviation Alerts**: Detects behavioral anomalies (e.g. prolonged lying or inactivity) and pushes alerts to the dashboard.

### 2. Farm Security & Worker Attendance
- **Person Re-Identification**: Identifies registered workers and family members, maintaining a daily Attendance Board (`In-Time`, `Out-Time`, `Current Status`).
- **Unknown Intruder Alerts**: Detects unverified persons on farm boundaries, assigns a unique `Unknown_X` ID, captures a snapshot crop, and broadcasts high-severity alerts.
- **Rich Telemetry Payload**: Security alerts transmit base64-encoded face snapshots, unique unknown IDs, severity level, and registered farmer contact details.

### 3. Continuous CCTV Stream Recording
- **FFmpeg Engine**: Captures RTSP camera streams using FFmpeg with fragmented MP4 flags (`-movflags frag_keyframe+empty_moov`) to prevent file corruption in case of power loss or pipeline crashes.
- **Time Slot Management**: Rotates recordings into structured 3-hour time slots (e.g. `slot_12AM_3AM.mp4`).
- **Auto-Cleanup Watchdog**: Automatically purges historical recordings older than retention limits.

### 4. Telemetry Forwarding & Cloud Mobile App
- **Secure Forwarder Service**: Polls local Jetson APIs and streams MJPEG frames, telemetry status, and rich alerts to the AWS EC2 Relay Server (`http://<EC2_IP>:8080`).
- **Flutter Mobile App**: Cross-platform application providing live multi-camera feeds, real-time attendance board, intruder face gallery, and interactive alert popups.

---

## Directory Structure

```
├── Documents/
│   ├── README.md               # Main documentation entry point
│   ├── IMPLEMENTATION.md       # Detailed technical implementation breakdown
│   └── ARCHITECTURE.md         # System architecture & Mermaid dataflow diagrams
├── Kisan_Jetson/
│   ├── jetson_pipeline.py      # Core AI computer vision pipeline (YOLOv8 + DeepSORT + ReID)
│   ├── jetson_app.py           # FastAPI local server & WebSocket telemetry engine
│   ├── Genz_person_reid.py     # Person ReID feature extraction & embedding matcher
│   ├── stream_storing.py       # Robust FFmpeg stream recording service
│   ├── templates/index.html    # Local web dashboard UI (HTML5/Vanilla JS)
│   └── static/                 # Static assets & unknown face snapshot storage
├── Kisan_Jetson_Mobile/
│   ├── stream_forwarder/       # Telemetry & stream forwarding service to cloud
│   ├── ec2_server/             # AWS EC2 FastAPI relay server
│   └── flutter_app/            # Cross-platform Flutter mobile client
├── models/                     # Deep learning weights (YOLO, ReID models)
└── install_service.sh          # Systemd production service installer
```

---

## System Requirements

- **Edge Hardware**: Nvidia Jetson Xavier NX / Orin Nano / AGX Orin with JetPack 5.x/6.x
- **Python**: Python 3.8+ with PyTorch, OpenCV, CUDA support, FastAPI, uvicorn
- **External Tools**: `ffmpeg` (for stream storage)
- **Mobile Stack**: Flutter SDK (3.x+) for Android/iOS/Web deployment

---

## Quick Start Guide

### 1. Local Jetson Application Startup
To start the local edge server and AI inference pipeline:
```bash
cd Kisan_Jetson
python3 jetson_app.py
```
- Access the local web dashboard at: `http://localhost:8000`
- Access the local web mobile view at: `http://localhost:8000/app`

### 2. Telemetry Forwarder Startup
To relay telemetry and live streams to the cloud EC2 server:
```bash
cd Kisan_Jetson_Mobile/stream_forwarder
python3 forwarder.py
```

### 3. AWS EC2 Relay Server (Cloud)
To run the EC2 relay server handling mobile client traffic:
```bash
cd Kisan_Jetson_Mobile/ec2_server
python3 app.py
```

### 4. Continuous Recording Service
To run 24/7 CCTV stream storing manually:
```bash
cd Kisan_Jetson
python3 stream_storing.py
```

---

## Systemd Production Services

Production deployments utilize systemd services managed via `install_service.sh`:

- **`kisan_ai.service`**: Auto-starts `jetson_app.py` on system boot.
- **`kisan-stream-store.service`**: Auto-starts `stream_storing.py` for continuous 24/7 video recording.

### Managing Services
```bash
# Check service status
sudo systemctl status kisan_ai.service
sudo systemctl status kisan-stream-store.service

# Stop / Restart services
sudo systemctl stop kisan_ai.service
sudo systemctl restart kisan_ai.service
```

---

## Documentation Links
- Detailed Implementation Guide: [IMPLEMENTATION.md](file:///home/mr/Documents/Cattle%20Behaviour%20analysis%20Jetson%20version/Documents/IMPLEMENTATION.md)
- System Architecture & Diagrams: [ARCHITECTURE.md](file:///home/mr/Documents/Cattle%20Behaviour%20analysis%20Jetson%20version/Documents/ARCHITECTURE.md)
