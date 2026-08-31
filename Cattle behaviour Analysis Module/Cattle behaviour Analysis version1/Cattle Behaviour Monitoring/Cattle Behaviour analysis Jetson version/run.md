# Kisan CattleVision Operational & Running Guide

This document describes how to run the different components of the **Kisan CattleVision** system.

---

## 💻 1. Running the Live Application (Edge AI Server)
This launches the camera feeds, cattle behavior monitoring, ear-tag OCR, and person Re-ID.

1. Open your terminal (or command prompt).
2. Navigate to the application directory:
   ```bash
   cd "E:\Cattle Behaviour analysis Jetson\Kisan_Jetson"
   ```
3. Start the server:
   ```bash
   python jetson_app.py
   ```
4. Access the web dashboard in your browser:
   * **URL:** `http://localhost:8000` or `http://0.0.0.0:8000`

---

## ☁️ 2. Running S3 Cloud Sync (Attendance & Updates)
This syncs attendance logs and downloads newly registered member templates from AWS S3.

1. Open a new terminal.
2. Navigate to the connection monitoring directory:
   ```bash
   cd "E:\Cattle Behaviour analysis Jetson\4_jetson_connection_member_monitoring"
   ```
3. Start the client sync script:
   ```bash
   python s3_sync_client.py
   ```

---

## ⚙️ 3. Retraining or Syncing the Face Re-ID Model (HPC Processor)
Run these steps in order when retraining the face model on the training server.

1. Navigate to the HPC training folder:
   ```bash
   cd "E:\Member Monitoring\Farm security person Monitoring\3_hpc_processor"
   ```
2. **Crop raw images:**
   ```bash
   python preprocess.py
   ```
3. **Train the ArcFace representation model (requires GPU/CUDA):**
   ```bash
   python train.py
   ```
4. **Compile templates & Deploy database:**
   ```bash
   python database.py
   ```
5. Deploy `best_checkpoint.pth` and `embeddings_db.pkl` (renamed to `known_embeddings.pkl`) to `Kisan_Jetson/models/` and `Kisan_Jetson/embeddings/`.

---

## 🧹 4. How to Start from Scratch (Reset Unknowns Database)
To clear all dynamically registered unknown visitors (wipe face crops and reset dynamic database):

1. Stop the application server (`python jetson_app.py`).
2. Run the following Python command to wipe the image caches and reset the pickle templates database:
   ```bash
   python -c "import os, pickle; [os.remove(os.path.join(d, f)) for d in [r'E:\Cattle Behaviour analysis Jetson\Kisan_Jetson\static\unknown_faces'] if os.path.exists(d) for f in os.listdir(d) if os.path.isfile(os.path.join(d, f))]; pickle.dump({'people': {}}, open(r'C:\Users\GITAM\KisanPro_Storage\Farmer_Geetha_9876543210_Kisan_Gitam_Farm\unknown_embeddings.pkl', 'wb')); print('Wiped successfully.')"
   ```
3. Start the application server again.
