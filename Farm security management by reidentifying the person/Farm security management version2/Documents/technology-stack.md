# Technology Stack

## Programming Languages
- **Dart (Flutter SDK)**: Used for compiling the cross-platform mobile enrollment application.
- **Python (v3.10 / v3.11)**: Used for PC local server, HPCWatcher, and Jetson Node synchronization scripts.

## Frameworks
- **Flutter Framework (v3.x)**: UI framework for the phone enrollment interface.
- **FastAPI / Uvicorn**: Lightweight REST API web framework on the PC emulator server.
- **PyTorch (v2.x)**: Machine learning framework used for executing model inference on the HPC.

## Infrastructure
- **Amazon Web Services (AWS S3)**: Cloud object storage for databases (`.pkl`, `.json`), datasets (`.mp4`, `.jpg`), and models (`.pth`).
- **Jetson Orin Nano Edge Platform**: Hardware target executing local gate re-identification.
- **Cloudflare Tunnel**: Secure reverse-proxy agent exposing local PC ports to the public internet.

## Build Tools
- **Gradle**: Build automation tool compiling the release APK inside the Android folder of the Flutter project.
- **pip**: Python package manager running standard PyPI scripts.

## Testing Tools
- **adb (Android Debug Bridge)**: Command-line debugging utility used to install and manage the release APK on physical mobile phones.
