# KisanPro Farm Security Management by Person Re-Identification: Version 2

This repository contains the source code, training pipelines, local AWS S3 emulators, and user manuals for the Version 2 implementation of the KisanPro Biometric Person/Member Re-Identification and Security system.

---

## System Overview

The system is a distributed edge-cloud member recognition system designed for agricultural properties. It allows administrators to register staff and members via video, process embeddings in the cloud or on local high-performance computers (HPC), and synchronize weights to edge gateway nodes (like Nvidia Jetson) for real-time security alerts.

### System Components
1. **Mobile Admin Client (`1_phone_deployment`)**: Flutter mobile application allowing administrators to fill member profiles, record face enrollment videos, and upload them directly to an S3 bucket via Minio SDK.
2. **Local Emulator API (`2_aws_s3_local`)**: Python FastAPI server simulating AWS S3 services locally for testing and local network backup.
3. **HPC Watcher Processor (`3_hpc_processor`)**: Background watcher monitoring S3 uploads, extracting and aligning face frames using MTCNN/YOLO, extracting embeddings using FaceNet, and compiling database profiles.
4. **Jetson Edge Connector (`4_jetson_connection`)**: Synchronizing client script deployed on Jetson gate nodes to poll S3 and download the latest embedding weights for real-time classification.

---

## Technical Architecture

```text
  [ Admin Mobile App ] ---> [ AWS S3 Bucket ] <--- [ HPC Processor ]
                                    |
                                    v
                          [ Jetson Edge Node ]
```

### Ingestion & Sync Flow
1. **Registration**: Admin enrolls a member on the Flutter App. Photos and enrollment videos are uploaded to the S3 bucket.
2. **Processing**: The HPC Watcher detects the new upload, aligns the face frames (`preprocess.py`), runs FaceNet to extract embeddings (`register_member_fast.py`), and uploads the updated `known_embeddings.pkl` and `member_roles.json` to S3.
3. **Edge Sync**: The Jetson Edge Node polls S3 (`s3_sync_client.py`), detects the updated databases, and pulls them locally to update the gates.

---

## Directory Structure

* **`Farm security person Monitoring code/`**:
  * `Face_ReID_Training/`: PyTorch pipelines to train the Face Re-Identification models.
  * `Farm security person Monitoring/`: Core deployment components:
    * `1_phone_deployment/`: Flutter mobile app.
    * `2_aws_s3_local/`: Local FastAPI S3 gateway emulator.
    * `3_hpc_processor/`: S3 watcher preprocess and registration scripts.
    * `4_jetson_connection/`: Edge gateway synchronization clients.
* **`Documents/`**: In-depth API, database, and setup spec sheets.
* **`Output/`**: Verification benchmarks and demo outputs.
* **`apk/`**: Built application installers.
* **`User Manual/`**: Step-by-step installation and reproduction guide.
* **`requirements.txt`**: Complete list of Python dependencies.

---

## Setup & Deployment Instructions

### 1. Python Environment Setup
Install the dependencies listed in `requirements.txt`:
```bash
pip install -r requirements.txt
```

### 2. Local S3 Emulator Launch
Expose local test endpoints:
```bash
cd "Farm security person Monitoring code/Farm security person Monitoring/2_aws_s3_local"
uvicorn app:app --host 0.0.0.0 --port 8000
```

### 3. HPC Watcher Launch
Start the automatic watchdog:
```bash
cd "Farm security person Monitoring code/Farm security person Monitoring/3_hpc_processor"
python s3_auto_watcher.py
```

### 4. Edge Sync Launch
Start the edge synchronization daemon on the Nvidia Jetson:
```bash
cd "Farm security person Monitoring code/Farm security person Monitoring/4_jetson_connection"
python s3_sync_client.py
```

---

## Repository Exclusions Notice

To maintain optimal git speeds and adhere to GitHub's file size limits, the following files are excluded from direct version tracking:
* **Model Checkpoints (`best_checkpoint.pth`)**: Heavy PyTorch weight checkpoints exceeding 100 MB.
* **Extracted Video Frames (`s3_storage`)**: Subdirectories containing thousands of raw `.jpg` face frames extracted during registration.

Ensure these folders and checkpoints are restored from local backups or designated Google Drive folders when initializing the project locally.
