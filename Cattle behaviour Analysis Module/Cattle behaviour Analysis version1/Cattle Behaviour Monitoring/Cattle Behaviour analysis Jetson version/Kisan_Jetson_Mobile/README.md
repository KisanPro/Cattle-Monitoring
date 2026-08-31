# Kisan CattleVision Mobile App & AWS EC2 Relay System

This directory contains the codebase for connecting your local **Kisan CattleVision** camera streams, telemetry, and security alerts to a mobile app APK through a public **AWS EC2 Relay Server**.

## 📁 Folder Structure

* **`ec2_server/`**: Contains the FastAPI relay server script (`app.py`), requirements list, and running script. You will deploy this on your public AWS EC2 instance.
* **`stream_forwarder/`**: Contains the daemon script (`forwarder.py`) that runs on the Jetson in the background, forwarding frames and telemetry to EC2.
* **`flutter_app/`**: Contains the Dart/Flutter codebase for the mobile app UI.

---

## 🚀 How to Run the System

### Phase 1: Deploy the EC2 Relay Server (AWS)

1. Launch a basic Ubuntu EC2 instance on AWS and make sure security groups allow incoming traffic on port **`8080`**.
2. Copy the `ec2_server/` folder to the EC2 instance.
3. SSH into your EC2 instance and execute:
   ```bash
   cd ec2_server/
   chmod +x run_server.sh
   ./run_server.sh
   ```
4. Note your EC2 instance's **Public IP address**.

### Phase 2: Start the Stream Forwarder (Jetson)

1. Open `/home/mr/Documents/Deployment/Kisan_Jetson_Mobile/stream_forwarder/forwarder_config.json` on the Jetson.
2. Edit `"ec2_url"` to point to your public EC2 address:
   ```json
   {
       "ec2_url": "http://<YOUR-EC2-PUBLIC-IP>:8080",
       "forward_cameras": ["cam1", "cam2", "cam3"],
       ...
   }
   ```
3. Restart the Jetson server using `START.sh` in the `Kisan_Jetson` folder:
   ```bash
   cd /home/mr/Documents/Deployment/Kisan_Jetson
   ./START.sh
   ```
   *Note: Starting `START.sh` will now automatically spin up the `forwarder.py` daemon in the background to send frames to AWS!*

### Phase 3: Compile and Install the Mobile App (APK)

1. Copy the `flutter_app/` directory to your development machine (laptop/PC) where Flutter is installed.
2. Edit `flutter_app/lib/config.dart` to specify your public EC2 Relay IP:
   ```dart
   class AppConfig {
     static const String ec2ServerUrl = "http://<YOUR-EC2-PUBLIC-IP>:8080";
     ...
   }
   ```
3. Open your terminal in the `flutter_app/` directory and execute:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
4. Find the compiled APK in `build/app/outputs/flutter-apk/app-release.apk` and transfer/install it on the farmer's Android phone.

---

## 🔒 Security & Optimization Note
* An API key authentication header (`X-API-KEY`) is configured between the Jetson forwarder and the EC2 server to ensure only authorized edge nodes can upload camera streams.
* The system is rate-limited to **10 FPS** and resizes frames to mobile resolution **(640x360)** to minimize network consumption.
