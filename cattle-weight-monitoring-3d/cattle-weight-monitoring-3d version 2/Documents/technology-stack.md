# Technology Stack

## Programming Languages
- **Dart** - Version `3.4+` - Used for Flutter mobile client development.
- **Python** - Version `3.10` - Used for Cloud Gateway, GPU Worker, and 3D Server.
- **Bash** - Version `5.x` - Used for WSL auto-restart management.

## Frameworks
- **Flutter** - Version `3.22.x` - Mobile application UI framework.
- **Flask** - Version `3.0.x` - Cloud REST API server framework.
- **PyTorch** - Version `2.x (CUDA 12)` - Deep learning framework for pose detection & TRELLIS.2.
- **Scikit-Learn** - Version `1.4.x` - ExtraTrees regressor model for dairy cattle weight estimation.

## Infrastructure
- **AWS EC2** - Virtual cloud server running Gunicorn daemon on port 5000.
- **AWS S3** - Cloud object storage (`kisanpro-cattle-weight-data`).
- **SQLite** - Relational database engine (`cattle_app.db`).
- **WSL2 (Ubuntu 22.04 LTS)** - Windows Subsystem for Linux environment hosting CUDA 3D engine.

## Build & Deployment Tools
- **Flutter CLI** - Version `3.22` - Mobile APK compilation (`flutter build apk --release`).
- **Gunicorn** - Version `21.2` - WSGI HTTP server for production Flask gateway.
- **Android ADB** - Android Debug Bridge for USB device deployment (`adb install -r`).

## Testing & Asset Tools
- **Pillow (PIL)** & **OpenCV** - Image processing, cropping, and matrix transformations.
- **Trimesh** & **o-voxel** - 3D mesh processing and `.glb` exporter.
