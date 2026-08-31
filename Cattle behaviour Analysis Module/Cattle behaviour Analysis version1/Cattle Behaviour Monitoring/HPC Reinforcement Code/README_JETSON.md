# 👁️ Jetson-to-HPC Intelligence Hub Integration Guide

This guide contains the instructions and code to connect your **Jetson Orin Nano** (The Eye) to the **HPC Intelligence Hub** (The Brain).

## 📡 Hub Connection Details
- **Hub URL**: `https://decisions-un-car-sydney.trycloudflare.com`
- **Security Token**: `kisan_secure_token_2026`
- **Port**: `8000` (Hub internally)

---

## 🛠️ Step 1: Update the Jetson Client
Your Jetson needs a modern sync manager that understands the new **FastAPI Security** and **Automated Training** logic.

### 🐍 New Client Script: `kisan_sync_client.py`
Create this file on your Jetson edge device:

```python
import requests
import os
import tarfile
import time
from datetime import datetime

# --- CONFIGURATION ---
HUB_URL = "https://decisions-un-car-sydney.trycloudflare.com"
API_KEY = "kisan_secure_token_2026"
LOCAL_DATA_DIR = "/mnt/kisan_storage/KisanPro_Storage/vectors"
LOCAL_MODEL_PATH = "models/smarter_behavior_model.pt"

HEADERS = {"X-API-KEY": API_KEY}

def upload_batch():
    """Compresses new vectors and sends them to the Brain."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    batch_name = f"kisan_batch_{timestamp}.tar.gz"
    
    print(f"📦 Creating batch: {batch_name}...")
    with tarfile.open(batch_name, "w:gz") as tar:
        # Change this to your actual vector subfolders
        tar.add(LOCAL_DATA_DIR, arcname="train") 
    
    print(f"📡 Uploading to Intelligence Hub...")
    url = f"{HUB_URL}/api/upload?filename={batch_name}"
    
    with open(batch_name, "rb") as f:
        response = requests.post(url, headers=HEADERS, data=f)
    
    if response.status_code == 200:
        print(f"✅ SUCCESS: {response.json()['message']}")
        os.remove(batch_name) # Clean up local zip
    else:
        print(f"❌ FAILED: {response.status_code} - {response.text}")

def download_smarter_model():
    """Checks for an upgraded brain and downloads it."""
    print("🧠 Checking for newly trained model...")
    url = f"{HUB_URL}/api/model/latest"
    
    response = requests.get(url, headers=HEADERS, stream=True)
    
    if response.status_code == 200:
        with open(LOCAL_MODEL_PATH, "wb") as f:
            f.write(response.content)
        print(f"🏆 UPGRADE COMPLETE: New model saved to {LOCAL_MODEL_PATH}")
    else:
        print(f"ℹ️ Hub Info: {response.json().get('error', 'No new model yet')}")

if __name__ == "__main__":
    # Example Workflow
    upload_batch()          # Done throughout the day
    download_smarter_model() # Done at night
```

---

## ⚡ Step 2: Running the Sync
You can automate this on your Jetson using a simple Cron Job:

1. **Morning/Every 4 Hours**: Push new behavioral vectors for the HPC to study.
2. **Midnight**: Download the upgraded model.

### 🧪 Test Connection
Run this simple command on your Jetson to verify it can see the HPC Brain:
```bash
curl -H "X-API-KEY: kisan_secure_token_2026" https://decisions-un-car-sydney.trycloudflare.com/api/health
```

---

## 📂 Expected Data Structure
The HPC Hub expects your `.tar.gz` to have the following structure inside:
```
train/
  ├── standing/
  │     └── img_001.jpg
  └── lying/
        └── img_002.jpg
```
The Hub will automatically detect these folders and integrate them into the training dataset.

---
> [!IMPORTANT]
> **Persistent Connection**: If the HPC Hub restarts, the URL may change. Always verify the current Hub URL before starting a long batch upload.
