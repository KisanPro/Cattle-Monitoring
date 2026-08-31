# Technology Stack

## Programming Languages
- **Python** - Version `3.10` / `3.11` - Used for all Edge AI processing, FastAPI server operations, database scripts, and sync daemons.
- **Dart (Flutter)** - Used for mobile monitoring and registration dashboard applications.

## Frameworks
- **FastAPI** - Version `>=0.95.0` - Powers the Edge web dashboard REST endpoints and live WebSocket MJPEG streams.
- **PyTorch** - Version `>=2.0.0` - Deep learning framework executing face representation embeddings and behavior classification.
- **Ultralytics YOLO** - Version `>=8.0.0` - Object detection framework mapping cattle, ear tags, and human faces in real time.

## Infrastructure
- **AWS S3** - Standard cloud object storage backing up CSV logs and syncing worker face photo registrations.
- **NVIDIA Jetson JetPack** - Version `6.0` (Ubuntu 22.04 LTS) - Hardware runtime environment compiling CUDA/TensorRT models.

## Build Tools
- **Pip** - Python package installer.
- **NVIDIA TensorRT** - Optimizes raw PyTorch models into `.engine` formats to speed up processing.

## Testing Tools
- **Sklearn Metrics** - Computes ROC AUC evaluation curves and confusion classification metrics.
