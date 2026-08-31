import os
import sys
import tarfile
import requests
from datetime import datetime
import numpy as np
import json

# --- CONFIGURATION ---
HUB_URL = "https://embedded-cited-painting-thompson.trycloudflare.com"
if len(sys.argv) > 1:
    HUB_URL = sys.argv[1]

API_KEY = "kisan_secure_token_2026"

# Farmer credentials and specific farm name to isolate data on the server
FARMER_NAME = "Farmer_Geetha"
MOBILE_NUMBER = "9876543210"
FARM_NAME = "Kisan_Gitam_Farm"  # Name of the farm if this user has multiple farms

# Local paths on the Jetson Orin Nano (aligned to Passport drive)
LOCAL_DATA_DIR = "/media/mr/My Passport/KisanPro_Storage/Farmer_Geetha_9876543210_Kisan_Gitam_Farm/vectors"
LOCAL_MODEL_PATH = "models/smarter_behavior_model.pt"

HEADERS = {"X-API-KEY": API_KEY}

def prepare_mock_vectors():
    """Generates mock behavioral vectors to ensure there is test data to package."""
    os.makedirs(LOCAL_DATA_DIR, exist_ok=True)
    npy_path = os.path.join(LOCAL_DATA_DIR, "vectors.npy")
    json_path = os.path.join(LOCAL_DATA_DIR, "metadata.json")
    
    if not os.path.exists(npy_path) or not os.path.exists(json_path):
        print("📦 Creating mock behavior vectors for testing...")
        # 5 mock embeddings of size 128
        mock_embeddings = np.random.randn(5, 128).astype(np.float32).tolist()
        np.save(npy_path, np.array(mock_embeddings))
        
        mock_metadata = {
            "ids": [f"cow_test_{i}" for i in range(5)],
            "metadatas": [
                {"posture": "standing", "timestamp": datetime.now().isoformat()},
                {"posture": "lying", "timestamp": datetime.now().isoformat()},
                {"feeding": "eating", "timestamp": datetime.now().isoformat()},
                {"feeding": "idle", "timestamp": datetime.now().isoformat()},
                {"ear_tag": "tag_091", "timestamp": datetime.now().isoformat()}
            ]
        }
        with open(json_path, "w") as f:
            json.dump(mock_metadata, f, indent=4)
        print("✅ Mock data prepared successfully.")

def upload_batch():
    """Compresses local behavioral vectors and sends them to the Kisan Intelligence Hub."""
    if not os.path.exists(LOCAL_DATA_DIR):
        print(f"❌ Error: Local vectors directory {LOCAL_DATA_DIR} does not exist.")
        return
        
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    # Clean farm name for filename formatting
    safe_farm_name = "".join(c for c in FARM_NAME if c.isalnum()).lower()
    batch_name = f"kisan_batch_{safe_farm_name}_{timestamp}.tar.gz"
    
    tar_dir = os.path.dirname(LOCAL_DATA_DIR)
    os.makedirs(tar_dir, exist_ok=True)
    tar_path = os.path.join(tar_dir, batch_name)
    
    print(f"📦 Creating batch archive: {tar_path}...")
    try:
        with tarfile.open(tar_path, "w:gz") as tar:
            # Adds the local vector folder to the archive
            tar.add(LOCAL_DATA_DIR, arcname="vectors")
    except Exception as e:
        print(f"❌ FAILED to create archive: {e}")
        return
    
    print(f"📡 Uploading dataset to Kisan Intelligence Hub at: {HUB_URL}...")
    # Pass farmer name, mobile number, and farm name as query parameters
    url = (
        f"{HUB_URL}/api/upload"
        f"?filename={batch_name}"
        f"&farmer_name={FARMER_NAME}"
        f"&mobile_number={MOBILE_NUMBER}"
        f"&farm_name={FARM_NAME}"
    )
    
    try:
        with open(tar_path, "rb") as f:
            files = {'file': f}
            response = requests.post(url, headers=HEADERS, files=files, timeout=15)
        
        if response.status_code == 200:
            print(f"✅ SUCCESS: {response.json().get('message', 'Uploaded successfully!')}")
            if os.path.exists(tar_path):
                os.remove(tar_path) # Clean up local zip file after successful upload
        else:
            print(f"❌ FAILED: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Connection Error during upload: {e}")

def download_smarter_model():
    """Checks for an upgraded behavior model and downloads it."""
    print("🧠 Checking for newly trained model...")
    # Query the server for the farm-specific model
    url = (
        f"{HUB_URL}/api/model/latest"
        f"?farmer_name={FARMER_NAME}"
        f"&mobile_number={MOBILE_NUMBER}"
        f"&farm_name={FARM_NAME}"
    )
    
    try:
        response = requests.get(url, headers=HEADERS, stream=True, timeout=15)
        if response.status_code == 200:
            os.makedirs(os.path.dirname(LOCAL_MODEL_PATH), exist_ok=True)
            with open(LOCAL_MODEL_PATH, "wb") as f:
                f.write(response.content)
            print(f"🏆 UPGRADE COMPLETE: New model saved to {LOCAL_MODEL_PATH}")
        else:
            try:
                err_msg = response.json().get('error', 'No new model yet')
            except Exception:
                err_msg = response.text
            print(f"ℹ️ Hub Info: {err_msg}")
    except Exception as e:
        print(f"❌ Connection Error during model download: {e}")

if __name__ == "__main__":
    # Prepare mock vectors if needed
    prepare_mock_vectors()
    
    # 1. Push local vectors to the server
    upload_batch()
    
    # 2. Check for and download any upgraded model
    download_smarter_model()
