# Kisan Face Recognition: 4-Step Run Playbook

This playbook contains the exact commands to run the entire system end-to-end.

---

### 📂 Step 1: Start S3 Emulator Server (Local PC Server)
Open **Command Prompt**, switch drives, and start the local emulator:
```cmd
E:
cd "E:\Member Monitoring\Farm security person Monitoring\2_aws_s3_local"
python app.py
```

---

### 📱 Step 2: Build & Install Flutter App (PC with phone via USB)
Open a new **Command Prompt**, build the APK, and deploy it to your device:
```cmd
E:
cd "E:\Member Monitoring\Farm security person Monitoring\1_phone_deployment"
flutter clean
flutter pub get
flutter build apk --release

:: 1. Navigate to the Android SDK tools directory where adb.exe is located
cd "C:\Users\GITAM\AppData\Local\Android\Sdk\platform-tools"

:: 2. Uninstall the old application from your connected phone
adb uninstall com.kisanpro.faceregister.kisan_face_register_app

:: 3. Install the newly built APK onto your phone
adb install "E:\Member Monitoring\Farm security person Monitoring\1_phone_deployment\build\app\outputs\flutter-apk\app-release.apk"
```

---

### 💻 Step 3: Start the HPC Auto-Watcher Daemon (HPC GPU Server)
Open a new **Command Prompt** and run the watcher to auto-process new registrations:
```cmd
E:
cd "E:\Member Monitoring\Farm security person Monitoring\3_hpc_processor"
run_watcher.bat
```

---

### 📸 Step 4: Run the Jetson Sync Client (Jetson Orin Nano Node)
Open a terminal on your **Jetson Orin Nano** and start the cloud synchronization client:

* **Background Sync Service (Auto-polls S3 every 60s):**
  ```bash
  python s3_sync_client.py
  ```

* **Force Immediate Sync (One-time download):**
  ```bash
  python s3_sync_client.py --once
  ```
