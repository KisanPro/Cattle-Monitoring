# 🚀 Commands Run & Execution Guide

This guide details how to launch, operate, and maintain all components of the **Cattle Weight Monitoring System**. The system consists of 4 decoupled services running across:
1. **AWS EC2** (Cloud REST Gateway)
2. **WSL2 Linux** (Local TRELLIS.2 3D Reconstruction Server)
3. **Windows PowerShell** (Local PC PyTorch GPU Worker)
4. **Android Device** (Flutter Mobile Client Application)

---

## 🛰️ 1. Cloud Gateway Server (AWS EC2 Instance)

The Cloud Gateway receives API requests from the mobile app, manages task state in SQLite, and handles AWS S3 storage for input photos and output `.glb` 3D meshes.

### Operating Commands:

1. **Connect to your EC2 Instance** (via AWS Console EC2 Instance Connect or SSH):
   ```bash
   ssh -i C:\Users\GITAM\Downloads\cattle-gateway-key.pem ec2-user@35.153.224.84
   ```
2. **Stop any old background server instances**:
   ```bash
   pkill -f gunicorn
   ```
3. **Navigate to the gateway directory**:
   ```bash
   cd /home/ec2-user/cloud_gateway
   ```
4. **Activate the Python virtual environment**:
   ```bash
   source venv/bin/activate
   ```
5. **Start Gunicorn Production Gateway Server**:
   ```bash
   gunicorn -w 4 -b 0.0.0.0:5000 app_cloud:app
   ```
   *The server listens on Port `5000` for HTTPS/HTTP API requests.*

---

## 🧬 2. 3D Reconstruction Engine (Local PC WSL2 Linux)

The WSL 3D Server runs **TRELLIS.2** + **BiRefNet** foreground segmentation to reconstruct interactive 3D GLB meshes from cattle photos.

### Operating Commands:

1. **Open Windows PowerShell** and launch the WSL2 Linux environment:
   ```powershell
   wsl
   ```
2. **Navigate to the 3D server directory**:
   ```bash
   cd /mnt/e/Weight_monitoring_production_code_without_AWS/wsl_3d_server
   ```
3. **Launch the server in auto-restart loop**:
   ```bash
   bash run_forever.sh
   ```
   *Runs on `http://localhost:9090`. If GPU memory exceeds 12 GB, the daemon automatically recycles VRAM and restarts within 2 seconds.*

---

## 🖥️ 3. GPU Inference Worker (Local PC Windows PowerShell)

The local PyTorch worker polls pending jobs from the EC2 Cloud Gateway, performs keypoint detection, calculates physical & scaled dimensions, computes weight estimates, and calls the 3D engine.

### Operating Commands:

1. **Open a new Windows PowerShell window**.
2. **Navigate to the project root directory**:
   ```powershell
   E:
   cd E:\Weight_monitoring_production_code_without_AWS
   ```
3. **Launch the Worker Daemon**:
   ```powershell
   python local_pc_worker/gpu_worker.py
   ```
   *The worker continuously polls EC2 for tasks and processes jobs using local CUDA GPU acceleration.*

---

## 📱 4. Mobile Client Application (Flutter Android)

The farmer's mobile interface for cattle registration, tape measurement entry, photo upload, weight history, health alerts, and interactive 3D model viewing.

### Operating Commands:

1. **Connect your Android Smartphone via USB** (with USB Debugging enabled).
2. **Verify device connection**:
   ```powershell
   C:\Users\GITAM\AppData\Local\Android\Sdk\platform-tools\adb.exe devices
   ```
3. **Navigate to the Flutter app directory**:
   ```powershell
   E:
   cd E:\Weight_monitoring_production_code_without_AWS\cattle_weight_app
   ```
4. **Compile & Install Release APK to Device**:
   ```powershell
   C:\flutter\bin\flutter.bat run -d TOOJ6HXOW4NBKVS8 --release
   ```
   *(Or build standalone APK: `flutter build apk --release` and install: `adb install -r build/app/outputs/flutter-apk/app-release.apk`).*
