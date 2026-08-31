# 🧠 Kisan Intelligence Hub - HPC Server

Welcome to the central brain of the Cattle Monitoring System. This server receives behavioral data from farm-based Jetson devices, performs automated fine-tuning, and prepares updated models for deployment.

## 📁 System Architecture
- `app/`: Production FastAPI backend.
- `data/`: Automated dataset management (Incoming -> Extracted -> Train).
- `models/`: Versioned AI models (`smarter_behavior_model.pt`).
- `logs/`: Integrated activity tracking.

## 🚀 Getting Started
To launch the Hub, simply run the setup script:
```batch
start_hpc_hub.bat
```

## 📡 Networking & Security
The server is currently exposed via Cloudflare Tunnel.
- **Protocol**: HTTP (FastAPI)
- **Port**: 8000
- **Security**: X-API-KEY Token Required.

## 🛠️ Operations
- **API Documentation**: Once running, visit `http://localhost:8000/docs`.
- **Health Monitoring**: Check `/api/health` for GPU and system metrics.
- **Model Registry**: View `models/trained/` for a history of smarter models.

---
*Developed for professional Edge-to-HPC continuous learning workflows.*
