# User Manual – Kisan Face Recognition Member Monitoring System

**Objective**: To provide a complete step-by-step guide for installation, configuration, operation, troubleshooting, maintenance, and reproduction of the project so that a new user or development team can independently deploy and use the system.

---

## 1. Purpose & Project Overview

### Project Purpose
The Kisan Face Recognition Member Monitoring System is a secure, decentralized access control platform designed for agricultural farms. It allows farm owners and administrators to manage and monitor authorized personnel entering and leaving farm premises.

### Problem Being Solved
* **Slow Enrollment (Resolved)**: Traditional systems required retraining the entire neural network (taking 5+ minutes) every time a new member registered. This system uses **Register-by-Inference**, reducing enrollment processing to **10–15 seconds**.
* **Decoupled Operation**: Edge devices at farm gates function independently of the registration server, syncing automatically via AWS S3.
* **Concurrency Conflicts**: Prevents read/write collisions and file-locking errors (`WinError 32`) on the server.

### System Architecture
The system consists of four primary blocks communicating through Amazon S3:
1. **`1_phone_deployment` (Flutter Mobile App)**: Enrolls members, captures face data, and displays the authorized members list.
2. **`2_aws_s3_local` (PC Emulator & Backup API Server)**: Simulates APIs and stores local database backups.
3. **`3_hpc_processor` (Registration Pipeline)**: Automatically aligns face images and extracts embeddings using a GPU.
4. **`4_jetson_connection` (Jetson Edge Node)**: Synchronizes edge node templates with the cloud database.

---

## 2. Required Hardware

To set up the complete system from scratch, the following hardware is required:

| Component | Description / Specifications |
|---|---|
| **Edge Processor** | NVIDIA Jetson Orin Nano (4GB or 8GB Developer Kit) |
| **Gate Camera** | USB Webcam (e.g., Logitech C920, 1080p) or RTSP-enabled IP Camera |
| **Power Supply** | 19V DC Power Adapter (supplied with Jetson Developer Kit) |
| **Network Router** | Router providing Ethernet / 2.4GHz Wi-Fi with active Internet access |
| **HPC GPU Server** | PC with NVIDIA GPU (CUDA-compatible, min 4GB VRAM) for watchers/processing |
| **Mobile Phone** | Android Device (Android 10+) connected via USB cable for APK debugging/install |
| **Cablings** | USB 3.0 cables, HDMI cable, Cat6 Ethernet cables |

---

## 3. Hardware Setup & Installation

### Step 1: Camera Installation
* Mount the USB webcam or RTSP IP camera at the farm entry gate.
* Positioning: Mount the camera at head height (5.5 to 6 feet), facing directly towards the entrance path. Ensure the face is evenly illuminated (avoid harsh background lighting).

### Step 2: Edge Node Connection
* Plug the webcam into one of the USB 3.0 ports on the NVIDIA Jetson Orin Nano.
* Connect the Jetson to the local router using an Ethernet cable (preferred) or configure its internal Wi-Fi adapter.
* Plug the 19V DC power adapter into the Jetson Orin Nano power port and switch on the mains.

### Step 3: Server & Mobile Setup
* Power on the HPC GPU Server and connect it to the same local network.
* Enable **USB Debugging** on the Android mobile phone under *Settings > Developer Options*. Connect it to the PC using a USB cable.

---

## 4. Software Installation & Environment Configuration

### 4.1 PC Local API Server & Jetson Node Requirements
Install Python 3.10 or 3.11 on the PC and Jetson:
```bash
pip install fastapi uvicorn boto3 urllib3 requests numpy opencv-python
```

### 4.2 HPC GPU Server Requirements
Install PyTorch with CUDA support and torchvision on the HPC server:
```bash
# PyTorch with CUDA 11.8/12.1
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
pip install facenet-pytorch opencv-python boto3 urllib3
```

### 4.3 Mobile App Build Requirements
1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Install the Android SDK Command-line Tools via Android Studio.
3. Verify the installation is correct:
   ```cmd
   flutter doctor
   ```

---

## 5. Running the System

### Step 1: Start the Local API Emulator Server (PC)
Open Command Prompt and run:
```cmd
cd "E:\Member Monitoring\Farm security person Monitoring\2_aws_s3_local"
python app.py
```

### Step 2: Start the HPC Auto-Watcher Daemon (HPC Server)
Open a terminal on the HPC server and run:
```cmd
cd "E:\Member Monitoring\Farm security person Monitoring\3_hpc_processor"
run_watcher.bat
```
*The watcher will now poll S3 every 10 seconds checking for new enrollment videos.*

### Step 3: Run the Jetson Sync Client (Jetson Edge Node)
Open a terminal on the Jetson Orin Nano and run:
```bash
cd /path/to/4_jetson_connection
python s3_sync_client.py
```
*The Jetson client will continuously poll S3 every 60 seconds and auto-download updated databases.*

### Step 4: Deploy the App (APK) onto the Phone via USB
Run these commands in your PC terminal with the phone connected:
```cmd
cd "E:\Member Monitoring\Farm security person Monitoring\1_phone_deployment"
flutter build apk --release
cd "C:\Users\GITAM\AppData\Local\Android\Sdk\platform-tools"
adb install -r "E:\Member Monitoring\Farm security person Monitoring\1_phone_deployment\build\app\outputs\flutter-apk\app-release.apk"
```

---

## 6. User Operations & Mobile App (APK) Usage

### 6.1 Admin Registration Settings Configuration
1. Open the **Member Monitoring** application on your phone.
2. Tap the **Settings (Gear Icon)** in the top right corner.
3. Configure the following parameters:
   * **Mobile Number**: The 10-digit mobile number associated with the farm (e.g. `8088327803`).
   * **Farm Name**: The name of the farm (e.g. `Samruddhi Farm`).
   * **S3 Credentials**: Enter your S3 access key, secret key, bucket name, and region.

### 6.2 Enrolling a New Member
1. Tap the teal **Add Farm Member** button on the home screen.
2. Enter the member's name (e.g. `Asha`) and select their role (e.g. `Worker`, `Manager`, `Owner`, `Veterinarian`, or `Visitor`).
3. Press **Start Enrollment**:
   * The app will take a quick front profile picture.
   * Hold the phone in front of the member's face. The app will record a short video clip (1,000 frames) automatically.
4. Once completed, the app will compress, bundle, and upload the video directly to S3.
5. In **15 seconds**, the HPC watcher will detect the video, align the faces, compute the embeddings, and update the list.

### 6.3 Deleting a Member
1. Under **Active Members** on the app homepage, locate the member's name card.
2. Tap the red **Delete** button.
3. Confirm the dialog. The member is removed from the S3 database, and their access is immediately revoked at the gate.

---

## 7. How the System Works

```
[Mobile App] ---> Uploads MP4 to S3 ---> [HPC Watcher] ---> [Face Extraction & Alignment] ---> [FaceNet Inference] ---> [Append to Pickled DB] ---> [Upload to S3] ---> [Sync to Jetson]
```

1. **Alignment**: The alignment pipeline [`preprocess.py`](file:///E:/Member%20Monitoring/Farm%20security%20person%20Monitoring/3_hpc_processor/preprocess.py) extracts frames from the video and uses MTCNN/YOLO-Face to crop and align the face regions, neutralizing head tilts and angles.
2. **Inference**: The script [`register_member_fast.py`](file:///E:/Member%20Monitoring/Farm%20security%20person%20Monitoring/3_hpc_processor/register_member_fast.py) runs the aligned face crops through the pre-trained FaceNet backbone.
3. **Template Calculation**: The 512-dimensional output vectors are averaged to produce a single representative face template for the member, which is then L2-normalized.
4. **Fast Appending**: The computed template is appended to the `known_embeddings.pkl` dictionary under the new key, and their chosen role is saved in `member_roles.json`.
5. **Edge Sync**: The Jetson client (`s3_sync_client.py`) polls S3 metadata. Once it detects a modified timestamp, it downloads the updated `known_embeddings.pkl` and `member_roles.json` to local storage for instant gate re-identification.

---

## 8. Reproduction & Deployment Procedure

### 8.1 Files Directory Structure
Ensure the repository matches this structural layout:
```
E:\Member Monitoring\Farm security person Monitoring\
├── 1_phone_deployment/       # Flutter application code
├── 2_aws_s3_local/           # API server, local cache folder & credentials
├── 3_hpc_processor/          # CUDA Preprocessing and Fast Inference scripts
├── 4_jetson_connection/      # Jetson Node cloud synchronization client
├── Documents/                # User Manual & Architecture Docs
├── README.md                 # Main setup manual
└── RUN_PLAYBOOK.md           # Quick commands reference list
```

### 8.2 Environment Configuration Variables (`.env`)
Both the PC server, HPC watcher, and Jetson Node need a `.env` file containing the AWS keys:
```env
AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
AWS_S3_BUCKET="kisan-person-registration-bucket"
AWS_DEFAULT_REGION="us-east-1"
FARM_ID="farm_8088327803_Samruddhi_Farm"
```

---

## 9. Troubleshooting Guide

### 9.1 S3 Connection Failures
* **Symptoms**: Watcher prints `Could not connect to the endpoint URL` or `ClientError: 403 Forbidden`.
* **Fix**: Open the `.env` file and check for typos in the access keys or bucket name. Ensure the host system has an active internet connection.

### 9.2 File-Locking Collisions (`WinError 32`)
* **Symptoms**: Watcher logs show `The process cannot access the file because it is being used by another process` during uploads or downloads.
* **Fix**: Ensure you have updated the code to the latest version that uses UUID temp files (`register_member_fast.py`). Kill any duplicate background python instances in Task Manager.

### 9.3 ADB Command Not Recognized
* **Symptoms**: CMD prints `'adb' is not recognized as an internal or external command`.
* **Fix**: Make sure you have navigated to the absolute path where the ADB executable is located before running install commands:
  `cd "C:\Users\GITAM\AppData\Local\Android\Sdk\platform-tools"`

### 9.4 Jetson Node Timeout
* **Symptoms**: Fast register script prints `Warning: Sync connection to Jetson failed`.
* **Fix**: This happens if the Jetson node is offline or has changed IP. The system will continue to function normally; the Jetson sync client will download the updated templates from S3 as soon as it is turned on.

---

## 10. Maintenance & Updates

### 10.1 Backup Procedures
All S3 files are backed up locally in the PC directory under:
`2_aws_s3_local\embeddings\farm_8088327803_Samruddhi_Farm\`
Additionally, every successful watcher training run uploads a timestamped copy to S3 (e.g. `known_embeddings_15_08_2026_12_00_PM.pkl`). Keep the last 5 backups on your drive for disaster recovery.

### 10.2 Updating Model Weights
To update the FaceNet backbone with newly fine-tuned weights:
1. Save the new PyTorch weights file as `best_checkpoint.pth`.
2. Upload this file to the S3 path: `embeddings/farm_8088327803_Samruddhi_Farm/best_checkpoint.pth`.
3. The Jetson client and HPC watcher will automatically download and apply the new weights on their next poll cycles.

---

## 11. Version & Metadata Info
* **Project Name**: Kisan Multi-Farm Member Monitoring System
* **Software Version**: v2.0 (Fast Register-by-Inference Edition)
* **Release Date**: August 23, 2026
* **Target Hardware Versions**: NVIDIA Jetson Orin Nano (Developer Kit) / Android OS v10+
* **Responsible Developer / Team**: Antigravity AI Implementation Team
