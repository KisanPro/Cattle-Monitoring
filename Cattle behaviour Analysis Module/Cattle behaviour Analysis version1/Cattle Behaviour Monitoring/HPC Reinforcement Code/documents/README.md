# 🧠 Kisan Intelligence Hub (HPC) - Master Documentation

Welcome to the central brain of the **Cattle Monitoring System**. This server receives behavioral vector data from farm-based **Jetson Orin Nano** edge devices, performs automated fine-tuning, establishes 21-day rolling behavioral baselines, generates health alerts, and delivers updated model weights back to edge devices.

---

## 🚀 Quick Start Guide

### 1. Launching the HPC Server
To start the FastAPI backend server on port `9000` with UTF-8 console support:
```batch
start_hpc_hub.bat
```
Alternatively, launch via command line:
```bash
set PYTHONUTF8=1
python -m uvicorn app.main:app --host 0.0.0.0 --port 9000 --reload
```

### 2. Exposing Server via Cloudflare Tunnel (Remote Jetson Connections)
If your Jetson device connects over the internet, start a Cloudflare Tunnel:
```bash
cloudflared tunnel --url http://localhost:9000
```
This generates a live public URL (e.g., `https://<random-subdomain>.trycloudflare.com`).

---

## 📡 API Endpoint Reference

All routes require authentication via the `X-API-KEY` HTTP header.

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/health` | `GET` | System health check (CPU, RAM, GPU status). |
| `/api/upload` | `POST` | Ingest compressed vector batch (`.tar.gz`). |
| `/api/telemetry` | `POST` | Log daily cow behavior telemetry metrics (JSON). |
| `/api/model/latest` | `GET` | Download the latest fine-tuned model for the farm. |
| `/api/model/versions` | `GET` | List available versioned model checkpoints. |

---

## 🛠️ Jetson Client Integration Setup

### Step 1: Update `config.json` on Jetson
On the Jetson Orin Nano device (`/home/mr/Documents/Deployment/Kisan_Jetson/config.json`), set the active URL:
```json
{
  "user_name": "Farmer_Geetha",
  "phone": "9876543210",
  "farm_name": "Kisan_Gitam_Farm",
  "hpc_url": "https://<your-active-tunnel>.trycloudflare.com"
}
```

### Step 2: Ingest Tokens Mapping
| API Key (`X-API-KEY`) | Resolved Tenant Workspace |
| :--- | :--- |
| `kisan_secure_token_2026` | `Geetha_8796547890_Blessing_Farm` |
| `kisan_secure_token_sunita` | `Sunita_7775533221_Samruddhi_Farm` |
| `kisan_secure_token_anand` | `Anand_9876543210_Green_Farm` |

---

## 📁 Workspace Directory Structure

```text
incoming_jetson_data/
├── app/
│   ├── api/                  # FastAPI router endpoints
│   ├── core/                 # Config, security, database & logging handlers
│   └── services/             # Extraction, training, baseline & alert engines
├── documents/                # System documentation
│   ├── ARCHITECTURE.md
│   ├── README.md
│   └── IMPLEMENTATION.md
├── farms/                    # Multi-tenant farm workspaces
├── global_workspace/         # Distilled anonymized global models
├── logs/                     # Application logs (hub.log)
├── models/                   # Standby model checkpoints
├── start_hpc_hub.bat         # Windows startup script
└── tests/                    # E2E integration test scripts
```

---

## 🧪 Testing & Verification
To execute the automated verification test suite:
```bash
python tests/verify_multitenancy.py
python tests/verify_complete_hub.py
```
