import os
import sys
import json
import pickle
import threading
import numpy as np
import cv2
import requests
import uvicorn
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware

# Append the parent directory to sys.path so we can import genz_pipeline
PARENT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if PARENT_DIR not in sys.path:
    sys.path.append(PARENT_DIR)

try:
    import genz_pipeline
    face_yolo = getattr(genz_pipeline, 'face_yolo', None)
    face_to_embedding = getattr(genz_pipeline, 'face_to_embedding', None)
    print("[SUCCESS] Loaded face detection and embedding pipeline from genz_pipeline.")
except Exception as e:
    print(f"[ERROR] Failed to import genz_pipeline: {e}")
    face_yolo = None
    face_to_embedding = None

app = FastAPI(title="Kisan Multi-Farm Face Registration Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SERVER_DIR = os.path.dirname(os.path.abspath(__file__))
S3_STORAGE_DIR = os.path.join(SERVER_DIR, "s3_storage")
REGISTRY_FILE = os.path.join(SERVER_DIR, "farm_jetson_registry.json")

# Ensure directories exist
os.makedirs(S3_STORAGE_DIR, exist_ok=True)

# Load .env file manually if exists
env_path = os.path.join(SERVER_DIR, ".env")
if os.path.exists(env_path):
    with open(env_path, "r") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                parts = line.split("=", 1)
                os.environ[parts[0].strip()] = parts[1].strip().strip('"').strip("'")

# S3 Configuration
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_S3_BUCKET = os.getenv("AWS_S3_BUCKET")
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")

s3_client = None
if AWS_ACCESS_KEY and AWS_SECRET_KEY and AWS_S3_BUCKET:
    try:
        import boto3
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        s3_client = boto3.client(
            "s3",
            aws_access_key_id=AWS_ACCESS_KEY,
            aws_secret_access_key=AWS_SECRET_KEY,
            region_name=AWS_REGION,
            verify=False
        )
        print(f"[AWS S3] Successfully connected to S3 Bucket: {AWS_S3_BUCKET}")
    except Exception as e:
        print(f"[AWS S3] Failed to connect S3 client: {e}")


# Load registry mapping: farm_id -> jetson_base_url
def load_registry():
    if os.path.exists(REGISTRY_FILE):
        try:
            with open(REGISTRY_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_registry(registry):
    try:
        with open(REGISTRY_FILE, "w") as f:
            json.dump(registry, f, indent=4)
    except Exception as e:
        print(f"Error saving registry: {e}")

# Initialize registry with template if not exists
if not os.path.exists(REGISTRY_FILE):
    save_registry({
        "farm_9876543210_GreenAcres": "http://192.168.0.200:8080"
    })

# In-memory registration session state
reg_session = {
    "farm_id": "",
    "name": "",
    "role": "",
    "active": False,
    "capturing": False,
    "count": 0,
    "progress": 0,
    "embeddings": []
}
reg_session_lock = threading.Lock()

# Helper function to get paths to database files segregated per farm_id
def get_farm_db_paths(farm_id: str):
    # Sanitize farm_id for filesystem safety
    safe_farm_id = "".join([c if c.isalnum() or c in ("_", "-") else "_" for c in farm_id])
    farm_dir = os.path.join(SERVER_DIR, "embeddings", safe_farm_id)
    os.makedirs(farm_dir, exist_ok=True)
    pkl_file = os.path.join(farm_dir, "known_embeddings.pkl")
    roles_file = os.path.join(farm_dir, "member_roles.json")
    return pkl_file, roles_file

def load_member_roles(farm_id: str):
    _, roles_file = get_farm_db_paths(farm_id)
    if os.path.exists(roles_file):
        try:
            with open(roles_file, 'r') as f:
                return json.load(f)
        except:
            pass
    return {}

def save_member_role(farm_id: str, name: str, role: str):
    _, roles_file = get_farm_db_paths(farm_id)
    roles = load_member_roles(farm_id)
    roles[name.strip().replace(" ", "_")] = role
    try:
        with open(roles_file, 'w') as f:
            json.dump(roles, f)
    except Exception as e:
        print(f"Error saving role for {farm_id}: {e}")

def sync_to_jetson(farm_id: str):
    """Pushes compiled embeddings to the Jetson mapped to this farm_id."""
    registry = load_registry()
    jetson_url = registry.get(farm_id)
    if not jetson_url:
        print(f"[WARNING] No Jetson URL registered for farm_id: {farm_id}")
        return
        
    pkl_file, roles_file = get_farm_db_paths(farm_id)
    if not os.path.exists(pkl_file) or not os.path.exists(roles_file):
        print(f"[WARNING] Embeddings/roles database files not found for farm_id: {farm_id}")
        return
        
    print(f"Syncing embeddings to Jetson for {farm_id} at {jetson_url}...")
    try:
        sync_endpoint = f"{jetson_url.rstrip('/')}/api/sync_embeddings"
        
        # Prepare the files to upload
        files = {
            "embeddings_file": ("known_embeddings.pkl", open(pkl_file, "rb"), "application/octet-stream"),
            "roles_file": ("member_roles.json", open(roles_file, "rb"), "application/json")
        }
        
        response = requests.post(sync_endpoint, files=files, timeout=15)
        if response.status_code == 200:
            print(f"[SUCCESS] Embeddings successfully synced to Jetson for {farm_id}!")
        else:
            print(f"[ERROR] Jetson sync failed with status {response.status_code}: {response.text}")
    except Exception as e:
        print(f"[ERROR] Failed to connect to Jetson sync service: {e}")

def auto_save_registration_data():
    global reg_session
    with reg_session_lock:
        farm_id = reg_session["farm_id"]
        name = reg_session["name"]
        role = reg_session["role"]
        embs = reg_session["embeddings"]
        
        if len(embs) == 0:
            return

        print(f"Compiling {len(embs)} embeddings for {name} ({farm_id})...")
        arr = np.stack(embs, axis=0)
        mean = np.mean(arr, axis=0)
        mean = mean / (np.linalg.norm(mean) + 1e-10)
        
        save_member_role(farm_id, name, role)

        # Save locally to PC farm embeddings database
        pkl_file, _ = get_farm_db_paths(farm_id)
        db_data = {}
        if os.path.exists(pkl_file):
            try:
                with open(pkl_file, "rb") as f_pkl:
                    db_data = pickle.load(f_pkl)
            except Exception:
                db_data = {}
        
        people = db_data.get("people", {})
        for angle in ["Front", "Left", "Right", "Up", "Down"]:
            people[f"{name}_{angle}"] = {
                'mean': mean,
                'samples': len(embs)
            }
            
        db_data["version"] = 1
        db_data["people"] = people
        
        try:
            with open(pkl_file, "wb") as f_pkl:
                pickle.dump(db_data, f_pkl)
            print(f"[SUCCESS] Saved new embeddings locally to: {pkl_file}")
            
            # Upload databases to real AWS S3 if client is active
            if s3_client is not None:
                try:
                    _, roles_file = get_farm_db_paths(farm_id)
                    s3_pkl_key = f"{farm_id}/known_embeddings.pkl"
                    s3_roles_key = f"{farm_id}/member_roles.json"
                    
                    s3_client.upload_file(pkl_file, AWS_S3_BUCKET, s3_pkl_key)
                    s3_client.upload_file(roles_file, AWS_S3_BUCKET, s3_roles_key)
                    print(f"[AWS S3] Uploaded database files successfully to S3 under key: {farm_id}/")
                except Exception as e:
                    print(f"[AWS S3] Error uploading database files to S3: {e}")
            
            # Start sync to the corresponding Jetson in background
            threading.Thread(target=sync_to_jetson, args=(farm_id,)).start()
        except Exception as e:
            print(f"[ERROR] Failed saving embeddings locally: {e}")
            
        reg_session["active"] = False

@app.post("/api/start_scan")
async def start_scan(payload: dict):
    global reg_session
    mobile_number = payload.get("mobile_number", "").strip()
    farm_name = payload.get("farm_name", "").strip().replace(" ", "_")
    name = payload.get("name", "").strip().replace(" ", "_")
    role = payload.get("role", "").strip()
    
    if not mobile_number or not farm_name or not name or not role:
        return JSONResponse(content={"status": "error", "message": "All fields (Mobile, Farm, Name, Role) are required!"}, status_code=400)

    farm_id = f"farm_{mobile_number}_{farm_name}"

    with reg_session_lock:
        reg_session = {
            "farm_id": farm_id,
            "name": name,
            "role": role,
            "active": True,
            "capturing": False,
            "count": 0,
            "progress": 0,
            "embeddings": []
        }
    
    # Create directory for farm & user under s3_storage
    farm_user_dir = os.path.join(S3_STORAGE_DIR, farm_id, name)
    os.makedirs(farm_user_dir, exist_ok=True)
    
    return JSONResponse(content={"status": "success", "message": f"Session initialized for farm {farm_id}. Ready for upload."})

@app.post("/api/set_capturing")
async def set_capturing(payload: dict):
    global reg_session
    is_capturing = payload.get("capturing", False)
    with reg_session_lock:
        if not reg_session["active"]:
            return JSONResponse(content={"status": "error", "message": "No active registration session!"}, status_code=400)
        reg_session["capturing"] = is_capturing
    return JSONResponse(content={"status": "success", "message": f"Capturing state set to {is_capturing}"})

@app.get("/api/scan_status")
async def get_scan_status():
    global reg_session
    with reg_session_lock:
        return JSONResponse(content={
            "active": reg_session["active"],
            "capturing": reg_session["capturing"],
            "progress": reg_session["progress"],
            "count": reg_session["count"],
            "name": reg_session["name"],
            "farm_id": reg_session["farm_id"]
        })

@app.post("/api/s3/upload")
async def s3_upload(
    farm_id: str = Form(...),
    member_name: str = Form(...),
    frame_index: int = Form(...),
    file: UploadFile = File(...)
):
    global reg_session
    with reg_session_lock:
        if not reg_session["active"] or not reg_session["capturing"]:
            raise HTTPException(status_code=400, detail="Registration session is not active or capturing is paused.")
        if reg_session["farm_id"] != farm_id or reg_session["name"] != member_name:
            raise HTTPException(status_code=400, detail="Data mismatch with active session.")

    try:
        # 1. Save frame locally (acting as S3 bucket)
        farm_user_dir = os.path.join(S3_STORAGE_DIR, farm_id, member_name)
        os.makedirs(farm_user_dir, exist_ok=True)
        
        file_path = os.path.join(farm_user_dir, f"frame_{frame_index}.jpg")
        contents = await file.read()
        with open(file_path, "wb") as f:
            f.write(contents)

        # Upload to real AWS S3 if client is initialized
        if s3_client is not None:
            try:
                s3_key = f"{farm_id}/{member_name}/frame_{frame_index}.jpg"
                s3_client.put_object(
                    Bucket=AWS_S3_BUCKET,
                    Key=s3_key,
                    Body=contents,
                    ContentType="image/jpeg"
                )
            except Exception as e:
                print(f"[AWS S3] Error uploading frame {frame_index}: {e}")

        # 2. Extract Embedding in real-time
        np_arr = np.frombuffer(contents, np.uint8)
        frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        
        if frame is not None and face_yolo is not None:
            h, w = frame.shape[:2]
            center_x, center_y = w // 2, h // 2
            radius = min(w, h) // 4
            
            small_frame = cv2.resize(frame, (640, 480))
            scale_x, scale_y = w / 640.0, h / 480.0
            results = face_yolo(small_frame, conf=0.45, verbose=False)[0]
            
            if results.boxes is not None and len(results.boxes.xyxy) > 0:
                f_box = results.boxes.xyxy[0].cpu().numpy()
                fx1, fy1, fx2, fy2 = int(f_box[0]*scale_x), int(f_box[1]*scale_y), int(f_box[2]*scale_x), int(f_box[3]*scale_y)
                
                face_center_x = (fx1 + fx2) // 2
                face_center_y = (fy1 + fy2) // 2
                dist = np.sqrt((face_center_x - center_x)**2 + (face_center_y - center_y)**2)
                
                if dist < radius:
                    fh_crop = fy2 - fy1
                    fw_crop = fx2 - fx1
                    py1 = max(0, int(fy1 - 0.2 * fh_crop))
                    py2 = min(h, int(fy2 + 0.1 * fh_crop))
                    px1 = max(0, int(fx1 - 0.1 * fw_crop))
                    px2 = min(w, int(fx2 + 0.1 * fw_crop))
                    
                    face_crop = frame[py1:py2, px1:px2]
                    if face_crop.size > 100 and face_to_embedding is not None:
                        emb = face_to_embedding(face_crop)
                        if emb is not None:
                            with reg_session_lock:
                                reg_session["embeddings"].append(emb)
                                count = len(reg_session["embeddings"])
                                reg_session["count"] = count
                                reg_session["progress"] = min(100, int((count / 1000.0) * 100))
                                
                                if count >= 1000:
                                    reg_session["capturing"] = False
                                    reg_session["progress"] = 100
                                    threading.Thread(target=auto_save_registration_data).start()
                                    
        return {"status": "success", "count": reg_session["count"], "progress": reg_session["progress"]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/registered_members")
async def get_registered_members(farm_id: str):
    pkl_file, _ = get_farm_db_paths(farm_id)
    db_data = {}
    if os.path.exists(pkl_file):
        try:
            with open(pkl_file, "rb") as f_pkl:
                db_data = pickle.load(f_pkl)
        except:
            pass
            
    people = db_data.get("people", {})
    templates = db_data.get("templates", {})
    roles = load_member_roles(farm_id)
    
    members_map = {}
    
    # 1. Load from templates (HPC compilation format)
    for name in templates.keys():
        if name not in members_map:
            role = roles.get(name, "Worker")
            members_map[name] = {
                "name": name.replace("_", " "),
                "raw_name": name,
                "role": role,
                "status": "Authorized"
            }
            
    # 2. Load from people (Mobile registration format)
    for key in people.keys():
        name = key.rsplit("_", 1)[0] if "_" in key else key
        if name not in members_map:
            role = roles.get(name, "Worker")
            members_map[name] = {
                "name": name.replace("_", " "),
                "raw_name": name,
                "role": role,
                "status": "Authorized"
            }
            
    return JSONResponse(content={"members": list(members_map.values())})

@app.post("/api/delete_member")
async def delete_member(payload: dict):
    raw_name = payload.get("name", "").strip()
    farm_id = payload.get("farm_id", "").strip()
    
    if not raw_name or not farm_id:
         return JSONResponse(content={"status": "error", "message": "Name and farm_id are required!"}, status_code=400)
         
    roles = load_member_roles(farm_id)
    if raw_name in roles:
        del roles[raw_name]
        _, roles_file = get_farm_db_paths(farm_id)
        try:
            with open(roles_file, 'w') as f:
                json.dump(roles, f)
        except:
            pass
            
    pkl_file, _ = get_farm_db_paths(farm_id)
    if os.path.exists(pkl_file):
        try:
            with open(pkl_file, "rb") as f_pkl:
                db_data = pickle.load(f_pkl)
            people = db_data.get("people", {})
            keys_to_remove = [k for k in people.keys() if k.startswith(f"{raw_name}_") or k == raw_name]
            for k in keys_to_remove:
                del people[k]
            db_data["people"] = people
            with open(pkl_file, "wb") as f_pkl:
                pickle.dump(db_data, f_pkl)
        except:
            pass
            
    # Attempt to delete raw S3 frames directory for this user on this specific farm
    user_dir = os.path.join(S3_STORAGE_DIR, farm_id, raw_name)
    if os.path.exists(user_dir):
        try:
            import shutil
            shutil.rmtree(user_dir)
        except:
            pass
                
    return JSONResponse(content={"status": "success", "message": f"Member {raw_name} successfully deleted."})

# Endpoint to register/link a new Jetson device
@app.post("/api/register_jetson")
async def register_jetson(payload: dict):
    mobile_number = payload.get("mobile_number", "").strip()
    farm_name = payload.get("farm_name", "").strip().replace(" ", "_")
    jetson_url = payload.get("jetson_url", "").strip()
    
    if not mobile_number or not farm_name or not jetson_url:
        return JSONResponse(content={"status": "error", "message": "Mobile, Farm, and Jetson URL are required!"}, status_code=400)
        
    farm_id = f"farm_{mobile_number}_{farm_name}"
    
    registry = load_registry()
    registry[farm_id] = jetson_url
    save_registry(registry)
    
    return {"status": "success", "message": f"Jetson registered for {farm_id} at {jetson_url}"}

@app.get("/api/registry")
async def get_registry():
    return load_registry()

@app.get("/api/download_embeddings")
async def download_embeddings(farm_id: str):
    from fastapi.responses import FileResponse
    pkl_file, _ = get_farm_db_paths(farm_id)
    if os.path.exists(pkl_file):
        return FileResponse(pkl_file, filename="known_embeddings.pkl")
    raise HTTPException(status_code=404, detail="Embeddings file not found.")

@app.get("/api/download_roles")
async def download_roles(farm_id: str):
    from fastapi.responses import FileResponse
    _, roles_file = get_farm_db_paths(farm_id)
    if os.path.exists(roles_file):
        return FileResponse(roles_file, filename="member_roles.json")
    raise HTTPException(status_code=404, detail="Roles file not found.")

if __name__ == "__main__":

    print("\n[Kisan Multi-Farm Face Registration PC Server] Starting on port 8080...\n")
    uvicorn.run(app, host="0.0.0.0", port=8080)
