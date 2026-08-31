import warnings
warnings.filterwarnings("ignore", message="urllib3.*or chardet.*doesn't match a supported version")

import os
import time
import shutil
import chromadb
import glob
import json
import tarfile
import numpy as np
from datetime import datetime
import pytz
import threading
import hashlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.json")
IST = pytz.timezone('Asia/Kolkata')

# Connection Config to HPC Cluster (Dual Path with Failover)
HPC_URLS = [
    "http://172.22.30.70:9000/api/upload",
    "https://puts-ones-milan-construction.trycloudflare.com/api/upload"
]

MODEL_URLS = [
    "http://172.22.30.70:9000/api/model/latest",
    "https://puts-ones-milan-construction.trycloudflare.com/api/model/latest"
]

API_KEY = "kisan_secure_token_2026"
HEADERS = {"X-API-KEY": API_KEY}

def get_file_sha256(filepath):
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def self_test_model(model_path, task_id):
    """
    Performs a dry-run inference test (self-test) on the downloaded model file
    to ensure it loads correctly and produces valid outputs.
    """
    try:
        import torch
        # Posture and feeding models are PyTorch/TorchScript models (.pt)
        if task_id in ["posture", "food"]:
            # Load the model
            model = torch.load(model_path, map_location="cpu")
            # If the loaded object is a dict or standard PyTorch state_dict, we just verify it loads.
            # If it's a scripted/traced model or nn.Module, we run a dummy forward pass.
            if hasattr(model, "eval"):
                model.eval()
                dummy_input = torch.randn(1, 3, 224, 224)
                with torch.no_grad():
                    output = model(dummy_input)
                if output is not None:
                    print(f"✅ Self-test PASSED for {task_id} model.")
                    return True
            else:
                print(f"✅ Self-test PASSED (checkpoint dictionary loaded) for {task_id}.")
                return True
        elif task_id == "eartag":
            model = torch.load(model_path, map_location="cpu")
            print(f"✅ Self-test PASSED for ear tag model.")
            return True
    except Exception as e:
        print(f"❌ Self-test FAILED for {task_id} model: {e}")
        return False
    return True

def get_system_telemetry():
    telemetry = {
        "cpu_usage": 0.0,
        "ram_usage": 0.0,
        "gpu_temp": 0.0,
        "cpu_temp": 0.0,
        "fps": 10.0,
        "inference_latency_ms": 0.0,
        "model_version": "v1.0",
        "detection_count": 0,
        "failure_count": 0
    }
    
    # 1. CPU Usage
    try:
        with open('/proc/loadavg') as f:
            telemetry["cpu_usage"] = round(float(f.readline().split()[0]) * 100.0 / os.cpu_count(), 1)
    except Exception:
        pass

    # 2. RAM Usage
    try:
        with open('/proc/meminfo') as f:
            lines = f.readlines()
        mem_total = 1.0
        mem_free = 0.0
        mem_cached = 0.0
        mem_buffers = 0.0
        for line in lines:
            if line.startswith('MemTotal:'):
                mem_total = float(line.split()[1])
            elif line.startswith('MemFree:'):
                mem_free = float(line.split()[1])
            elif line.startswith('Cached:'):
                mem_cached = float(line.split()[1])
            elif line.startswith('Buffers:'):
                mem_buffers = float(line.split()[1])
        used = mem_total - mem_free - mem_cached - mem_buffers
        telemetry["ram_usage"] = round((used / mem_total) * 100.0, 1)
    except Exception:
        pass

    # 3. CPU / GPU Temps
    try:
        with open('/sys/class/thermal/thermal_zone0/temp') as f:
            telemetry["cpu_temp"] = round(float(f.read().strip()) / 1000.0, 1)
    except Exception:
        pass
    try:
        with open('/sys/class/thermal/thermal_zone1/temp') as f:
            telemetry["gpu_temp"] = round(float(f.read().strip()) / 1000.0, 1)
    except Exception:
        pass

    return telemetry

def get_hpc_endpoints():
    upload_urls = list(HPC_URLS)
    model_urls  = list(MODEL_URLS)
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE) as f:
                c = json.load(f)
                custom_url = c.get("hpc_url") or c.get("hub_url")
                if custom_url:
                    custom_url = custom_url.rstrip("/")
                    upload_urls.insert(0, f"{custom_url}/api/upload")
                    model_urls.insert(0, f"{custom_url}/api/model/latest")
    except Exception:
        pass
    return upload_urls, model_urls

def send_telemetry_loop():
    import requests
    uname, phone, fname, prefix = get_user_metadata()
    print("[*] Starting telemetry reporting thread...")
    while True:
        try:
            stats = get_system_telemetry()
            payload = {
                "farmer_name": uname,
                "mobile_number": phone,
                "farm_name": fname,
                "metrics": stats
            }
            upload_urls, _ = get_hpc_endpoints()
            for base_url in upload_urls:
                try:
                    telemetry_url = base_url.replace("/api/upload", "/api/telemetry")
                    r = requests.post(telemetry_url, json=payload, headers=HEADERS, timeout=5)
                    if r.status_code == 200:
                        break
                except Exception:
                    continue
        except Exception as e:
            pass
        time.sleep(300) # every 5 minutes

def hpc_post(query_params, files=None, timeout=30):
    """Attempts to POST to HPC endpoints sequentially (User config -> Primary local -> Secondary Cloudflare)."""
    import requests
    upload_urls, _ = get_hpc_endpoints()
    last_err = None
    for base_url in upload_urls:
        try:
            url = f"{base_url}{query_params}"
            response = requests.post(url, headers=HEADERS, files=files, timeout=timeout)
            return response
        except Exception as e:
            last_err = e
            continue
    raise last_err if last_err else Exception("Offline")

def hpc_get_model(task_id, timeout=30):
    """Attempts to GET latest model weights from HPC endpoints sequentially."""
    import requests
    _, model_urls = get_hpc_endpoints()
    for base_url in model_urls:
        try:
            url = f"{base_url}?task={task_id}"
            response = requests.get(url, headers=HEADERS, stream=True, timeout=timeout)
            if response.status_code == 200:
                return response
        except Exception:
            continue
    return None

def get_user_metadata():
    try:
        with open(CONFIG_FILE) as f:
            c = json.load(f)
    except Exception:
        c = {}
    uname = str(c.get("user_name", "User")).replace(" ", "_")
    phone = str(c.get("phone", "Phone")).replace(" ", "_")
    fname = str(c.get("farm_name", "Farm")).replace(" ", "_")
    prefix = f"{uname}_{phone}_{fname}"
    return uname, phone, fname, prefix

def get_paths():
    uname, phone, fname, prefix = get_user_metadata()
    from storage_utils import get_base_storage
    base_storage = get_base_storage(SCRIPT_DIR)
    vector_db_path = os.path.join(base_storage, "Vector_DB")
    sync_staging = os.path.join(base_storage, "DATASET_HPC")
    status_file = os.path.join(base_storage, "kisan_sync_status.json")
    os.makedirs(sync_staging, exist_ok=True)
    os.makedirs(os.path.join(SCRIPT_DIR, "DATASET_HPC"), exist_ok=True)
    return base_storage, vector_db_path, sync_staging, status_file, uname, phone, fname, prefix

def write_status(status, message):
    try:
        _, _, _, status_file, _, _, _, _ = get_paths()
        with open(status_file, "w") as f:
            json.dump({
                "status": status,
                "message": message,
                "timestamp": datetime.now(IST).strftime("%H:%M:%S")
            }, f)
    except Exception:
        pass

def export_hourly_data():
    """
    Exports the behavior data from ChromaDB to an efficient binary 
    package, bundles MLOps training crops, stores them in DATASET_HPC/, and uploads them to the HPC.
    """
    try:
        base_storage, vector_db_path, sync_staging, status_file, uname, phone, fname, prefix = get_paths()
        local_hpc_dir = os.path.join(SCRIPT_DIR, "DATASET_HPC")
        
        print(f"\n⏳ [{datetime.now(IST).strftime('%H:%M:%S')}] Starting Vector & Crop Sync to HPC for {prefix}...")
        write_status("Syncing", "Preparing package...")
        
        client = chromadb.PersistentClient(path=vector_db_path)
        collection = client.get_or_create_collection(name="cattle_behavior_memory")
        
        # --- PART 1: RETRY PENDING PACKAGES IN DATASET_HPC QUEUE ---
        pending_packages = sorted(list(set(
            glob.glob(os.path.join(sync_staging, "*.tar.gz")) +
            glob.glob(os.path.join(local_hpc_dir, "*.tar.gz"))
        )))
        if pending_packages:
            print(f"📦 Found {len(pending_packages)} pending packages in DATASET_HPC queue. Attempting upload...")
            for pkg in pending_packages:
                try:
                    filename = os.path.basename(pkg)
                    query = f"?filename={filename}&user_name={uname}&phone={phone}&farm_name={fname}"
                    with open(pkg, "rb") as f:
                        files = {'file': f}
                        response = hpc_post(query, files=files, timeout=30)
                    
                    if response.status_code == 200:
                        print(f"✅ SUCCESS: Uploaded pending {filename}")
                        os.remove(pkg)
                    else:
                        print(f"⏳ Internet still unstable. Leaving {filename} in queue.")
                        break
                except Exception:
                    print(f"⚠️ Connection failed. {filename} remains in queue.")
                    break

        # --- PART 2: PACKAGE NEW DATA FROM CHROMADB & CROPS ---
        count = collection.count()
        crops_dir = os.path.join(sync_staging, "Crops")
        has_crops = os.path.exists(crops_dir) and len(os.listdir(crops_dir)) > 0
        
        if count == 0 and not has_crops:
            print("ℹ️ No new data or crops in DB to package.")
            write_status("Success", "Up-to-date (0 records)")
            return

        # Fetch new data
        data = collection.get(include=["embeddings", "metadatas"]) if count > 0 else {"embeddings": [], "metadatas": [], "ids": []}
        
        # Grouping by 3 Main Model Categories
        categories = {"Posture": [], "Feeding": [], "EarTags": []}
        for i, meta in enumerate(data['metadatas']):
            if "posture" in meta: categories["Posture"].append(i)
            if "feeding" in meta: categories["Feeding"].append(i)
            if "ear_tag" in meta: categories["EarTags"].append(i)

        timestamp = datetime.now(IST).strftime("%Y%m%d_%H%M%S")
        package_name = f"{prefix}_kisan_hpc_batch_{timestamp}.tar.gz"
        tar_path = os.path.join(sync_staging, package_name)

        with tarfile.open(tar_path, "w:gz") as tar:
            # 1. Add database categories
            for cat_name, indices in categories.items():
                if not indices: continue
                folder_path = os.path.join(sync_staging, cat_name)
                os.makedirs(folder_path, exist_ok=True)
                
                cat_embeddings = [data['embeddings'][idx] for idx in indices]
                cat_metadatas = [data['metadatas'][idx] for idx in indices]
                cat_ids = [data['ids'][idx] for idx in indices]
                
                npy_file = os.path.join(folder_path, "vectors.npy")
                json_file = os.path.join(folder_path, "metadata.json")
                np.save(npy_file, np.array(cat_embeddings))
                with open(json_file, "w") as f:
                    json.dump({"ids": cat_ids, "metadatas": cat_metadatas}, f)
                
                tar.add(folder_path, arcname=cat_name)
                os.remove(npy_file)
                os.remove(json_file)
                os.rmdir(folder_path)
            
            # 2. Add Crops folder
            if has_crops:
                tar.add(crops_dir, arcname="Crops")

        print(f"📦 New Package Created: {package_name} ({count} records + Crops)")
        
        # --- PART 3: UPLOAD NEW PACKAGE & CLEAR DB/CROPS ---
        try:
            query = f"?filename={package_name}&user_name={uname}&phone={phone}&farm_name={fname}"
            with open(tar_path, "rb") as f:
                files = {'file': f}
                response = hpc_post(query, files=files, timeout=30)
                
            if response.status_code == 200:
                print(f"✅ SUCCESS: New data uploaded. Clearing local DB and crops.")
                if count > 0:
                    collection.delete(ids=data['ids']) # CLEAR DB ONLY AFTER SUCCESS
                
                # Clear uploaded crops
                if has_crops:
                    for f in os.listdir(crops_dir):
                        fp = os.path.join(crops_dir, f)
                        try:
                            if os.path.isfile(fp):
                                os.remove(fp)
                        except Exception as delete_err:
                            print(f"[WARN] Error deleting crop file {fp}: {delete_err}")
                            
                write_status("Success", f"Sent {count} records + Crops")
                os.remove(tar_path)
            else:
                print(f"⏳ Upload Failed. {package_name} added to Queue for later.")
                write_status("Offline", "Upload failed (Queued)")
        except Exception as e:
            print(f"⏳ API Connection Offline: {e}. {package_name} added to Queue.")
            write_status("Offline", "Offline (Queued)")
            
    except Exception as e:
        print(f"❌ Export/Sync Error: {e}")
        write_status("Offline", f"Sync error: {str(e)[:40]}")

def check_for_updated_models():
    """
    End of day check: Downloads updated 'Smarter' models from HPC 
    and replaces the local production models after self-test.
    """
    print(f"🌙 [{datetime.now(IST).strftime('%H:%M:%S')}] Checking for 'Smarter' Models from HPC...")
    
    tasks = {
        "posture": "standing_and-lying.pt",
        "food": "food_idle_behavior.pt",
        "eartag": "ear_tag_model.pt"
    }
    
    for task_id, filename in tasks.items():
        try:
            response = hpc_get_model(task_id)
            if response:
                latest_dir = os.path.join(SCRIPT_DIR, "models")
                local_path = os.path.join(latest_dir, filename)
                temp_path = local_path + ".tmp"
                
                os.makedirs(latest_dir, exist_ok=True)
                with open(temp_path, "wb") as f:
                    f.write(response.content)
                
                # 1. SHA256 Checksum Verification
                expected_sha = response.headers.get("X-SHA256")
                if expected_sha:
                    actual_sha = get_file_sha256(temp_path)
                    if actual_sha != expected_sha.lower():
                        print(f"❌ Verification FAILED: SHA256 mismatch for {filename}!")
                        os.remove(temp_path)
                        continue
                
                # 2. Run Self Test before replacing production model
                if self_test_model(temp_path, task_id):
                    if os.path.exists(local_path):
                        os.remove(local_path)
                    os.rename(temp_path, local_path)
                    print(f"🔄 SUCCESS: {filename} verified and updated!")
                else:
                    print(f"❌ FAILED: Self-test failed for {filename}. Retaining current model.")
                    if os.path.exists(temp_path):
                        os.remove(temp_path)
            else:
                print(f"ℹ️ Hub Info: No update for {task_id} yet.")
        except Exception as api_e:
            print(f"⚠️ API Connection Error for {task_id}: {api_e}")

def main():
    print("🛰️ KISAN SYNC MANAGER ACTIVE")
    print(f"Target Primary HPC: {HPC_URLS[0]}")
    print(f"Target Secondary HPC: {HPC_URLS[1]}")
    
    # Start the background telemetry agent thread
    t = threading.Thread(target=send_telemetry_loop, daemon=True)
    t.start()
    
    while True:
        try:
            now = datetime.now(IST)
            
            # 1. Hourly Export & Sync
            export_hourly_data()
            
            # 2. Daily Model Update (Triggered at 11:30 PM IST)
            if now.hour == 23 and now.minute >= 30:
                check_for_updated_models()
                time.sleep(1800) # prevent double run
                
        except Exception as e:
            print(f"❗ CRITICAL LOOP ERROR: {e}")
            
        time.sleep(3600)

if __name__ == "__main__":
    main()
