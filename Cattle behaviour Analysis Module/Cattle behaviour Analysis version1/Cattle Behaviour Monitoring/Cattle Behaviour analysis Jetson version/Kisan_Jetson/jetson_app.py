"""
jetson_app.py  –  Kisan CattleVision Edge AI Server
Optimized for Jetson Orin Nano (JetPack 6 / Ubuntu 22.04)
All paths are relative to this script directory.
Run: python3 jetson_app.py
"""

import os
os.environ["OPENCV_LOG_LEVEL"] = "OFF"
os.environ["OPENCV_FFMPEG_LOGLEVEL"] = "-8"
os.environ["PYTHONWARNINGS"] = "ignore"

import warnings
warnings.filterwarnings("ignore")

import cv2
import threading
import time
import datetime
import math
import numpy as np
import os
import json
import pickle

import requests
from requests.auth import HTTPDigestAuth, HTTPBasicAuth
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from fastapi import FastAPI, Response, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.requests import Request
import uvicorn

# Pre-load heavy modules to prevent route latency
import jetson_pipeline
import adaptive_health

# ── Paths (all relative to this script) ──────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE  = os.path.join(SCRIPT_DIR, "config.json")

def load_config_raw():
    import json
    try:
        with open(CONFIG_FILE) as f:
            return json.load(f)
    except Exception:
        return {}

CONFIG_RAW = load_config_raw()
uname  = str(CONFIG_RAW.get("user_name", "User")).replace(" ", "_")
phone  = str(CONFIG_RAW.get("phone", "Phone")).replace(" ", "_")
fname  = str(CONFIG_RAW.get("farm_name", "Farm")).replace(" ", "_")
folder_prefix = f"{uname}_{phone}_{fname}"

from storage_utils import get_base_storage
STORAGE_DIR  = get_base_storage(SCRIPT_DIR)
STATIC_DIR   = os.path.join(SCRIPT_DIR, "static")
TEMPLATE_DIR = os.path.join(SCRIPT_DIR, "templates")
EMBED_DIR    = os.path.join(SCRIPT_DIR, "embeddings")
ATTENDANCE_LOG = os.path.join(STORAGE_DIR, "farm_attendance_log.csv")

os.makedirs(STORAGE_DIR, exist_ok=True)
os.makedirs(os.path.join(STATIC_DIR, "unknown_faces"), exist_ok=True)

# ── FastAPI App ───────────────────────────────────────────────────────────────
app = FastAPI(title="Kisan CattleVision Edge AI Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
app.mount("/app", StaticFiles(directory=os.path.join(SCRIPT_DIR, "web"), html=True), name="flutter_app")
templates = Jinja2Templates(directory=TEMPLATE_DIR)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(telemetry_broadcaster())
    
    # Periodic system status publisher (every 5 seconds)
    async def periodic_status_publisher():
        while True:
            try:
                stats = get_system_stats()
                queue_telemetry("status", stats)
            except Exception:
                pass
            await asyncio.sleep(5.0)
            
    asyncio.create_task(periodic_status_publisher())

DEFAULT_CONFIG = {
    "user_name": "Farmer_Geetha",
    "phone":     "9876543210",
    "farm_name": "Kisan_Gitam_Farm",
    "cam1_url":  "rtsp://admin:GeethaCam1234_@192.168.0.162:554/video/live?channel=1&subtype=0",
    "cam2_ip":   "192.168.0.112",
    "cam2_user": "admin",
    "cam2_pass": "GeethaCam1234_",
    "cam2_path": "onvifsnapshot/media_service/snapshot?channel=1&subtype=0",
    "cam2_mode": "https_snap",
    "cam3_ip":   "192.168.0.110",
    "cam3_user": "admin",
    "cam3_pass": "GeethaCam1234_",
    "cam3_path": "onvifsnapshot/media_service/snapshot?channel=1&subtype=0",
    "cam3_mode": "https_snap",
    "cam4_ip":   "",
    "cam4_user": "admin",
    "cam4_pass": "GeethaCam1234_",
    "cam4_path": "",
    "cam4_mode": "rtsp",
    "cam5_ip":   "",
    "cam5_user": "admin",
    "cam5_pass": "GeethaCam1234_",
    "cam5_path": "",
    "cam5_mode": "rtsp",
}

if not os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE, "w") as f:
        json.dump(DEFAULT_CONFIG, f, indent=4)

def load_config():
    conf_updated = False
    try:
        with open(CONFIG_FILE) as f:
            conf = json.load(f)
    except Exception:
        conf = DEFAULT_CONFIG.copy()
        conf_updated = True
        
    for k in ["user_name", "phone", "farm_name"]:
        if k not in conf:
            conf[k] = DEFAULT_CONFIG.get(k, "")
            conf_updated = True
            
    if conf_updated:
        try:
            with open(CONFIG_FILE, "w") as f:
                json.dump(conf, f, indent=4)
        except Exception:
            pass
    return conf

def build_cam_url(conf, prefix):
    ip    = conf.get(f"{prefix}_ip",   "192.168.0.112")
    user  = conf.get(f"{prefix}_user", "admin")
    passw = conf.get(f"{prefix}_pass", "GeethaCam1234_")
    path  = conf.get(f"{prefix}_path", "")
    mode  = conf.get(f"{prefix}_mode", "rtsp")
    if mode == "rtsp":
        if not path or "snapshot" in path or "onvif" in path:
            path = "video/live?channel=1&subtype=0"
    else:
        if not path or "video" in path:
            path = "onvifsnapshot/media_service/snapshot?channel=1&subtype=0"
    if path.startswith("/"):
        path = path[1:]
    if mode == "https_snap":
        return f"https://{ip}/{path}"
    if mode == "http_snap":
        return f"http://{ip}/{path}"
    return f"rtsp://{user}:{passw}@{ip}:554/{path}"

CONFIG  = load_config()
CAMERAS = {}
if CONFIG.get("cam1_url"):
    CAMERAS["cam1"] = CONFIG.get("cam1_url")
for i in range(2, 6):
    prefix = f"cam{i}"
    if CONFIG.get(f"{prefix}_ip"):
        CAMERAS[prefix] = build_cam_url(CONFIG, prefix)

# ── Logging & Telemetry ───────────────────────────────────────────────────────
import queue
import asyncio
import psutil
import shutil
import base64

logs     = []
alerts   = []
log_lock = threading.Lock()

active_telemetry_connections = set()
telemetry_lock = threading.Lock()
telemetry_queue = queue.Queue()

def queue_telemetry(event_type: str, data: dict):
    try:
        telemetry_queue.put({
            "type": event_type,
            "data": data,
            "timestamp": datetime.datetime.now().isoformat()
        })
    except Exception:
        pass

def get_system_stats():
    # CPU
    cpu = psutil.cpu_percent(interval=None)
    # RAM
    ram = psutil.virtual_memory().percent
    
    # Disk Storage
    disk_percent = 0.0
    try:
        total, used, free = shutil.disk_usage("/")
        disk_percent = round((used / total) * 100, 1)
    except Exception:
        pass
    
    # GPU load
    gpu_percent = 0.0
    for path in [
        "/sys/devices/gpu.0/load",
        "/sys/devices/platform/17000000.ga10b/load", # Orin ga10b
        "/sys/class/devfreq/17000000.gp10b/device/load"
    ]:
        if os.path.exists(path):
            try:
                with open(path, "r") as f:
                    gpu_percent = float(f.read().strip()) / 10.0
                break
            except Exception:
                pass
                
    return {
        "cpu_usage": cpu,
        "ram_usage": ram,
        "gpu_usage": gpu_percent,
        "storage_usage": disk_percent,
        "internet_online": True
    }

async def telemetry_broadcaster():
    while True:
        while not telemetry_queue.empty():
            try:
                item = telemetry_queue.get_nowait()
                msg = json.dumps(item)
                with telemetry_lock:
                    targets = list(active_telemetry_connections)
                for ws in targets:
                    try:
                        await ws.send_text(msg)
                    except Exception:
                        with telemetry_lock:
                            active_telemetry_connections.discard(ws)
            except queue.Empty:
                break
            except Exception as e:
                print(f"[WARN] Telemetry broadcaster exception: {e}")
        await asyncio.sleep(0.5)

def add_log(msg, level="INFO"):
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    with log_lock:
        logs.insert(0, f"[{ts}] {level}: {msg}")
        if len(logs) > 50:
            logs.pop()

def add_alert(msg, category="CATTLE MONITORING", severity="warning"):
    import base64
    now = datetime.datetime.now()
    if isinstance(msg, dict):
        p_url = msg.get("photo_url", None) or msg.get("image", None) or msg.get("image_url", None)
        if p_url and p_url.startswith("/static/"):
            rel_path = p_url.replace("/static/", "")
            file_path = os.path.join(STATIC_DIR, rel_path)
            if os.path.exists(file_path):
                try:
                    with open(file_path, "rb") as f_img:
                        p_url = "data:image/jpeg;base64," + base64.b64encode(f_img.read()).decode("utf-8")
                except Exception:
                    pass
        obj = {
            "timestamp": msg.get("timestamp", now.isoformat()),
            "category":  msg.get("category",  "FARM SECURITY" if (msg.get("unknown_person_id") or msg.get("person_id")) else "CATTLE MONITORING"),
            "message":   msg.get("message",   ""),
            "severity":  msg.get("severity",  "warning"),
            "photo_url": p_url,
            "image":     p_url,
            "image_url": p_url,
            "unknown_person_id": msg.get("unknown_person_id", msg.get("person_id", None)),
            "person_id": msg.get("person_id", msg.get("unknown_person_id", None)),
            "phone":     msg.get("phone", CONFIG.get("phone", "9876543210")),
            "track_id":  msg.get("track_id", msg.get("unknown_person_id", None)),
        }
    else:
        s   = "warning"
        cat = "CATTLE MONITORING"
        ms  = str(msg)
        if "anomaly scoe is" in ms.lower() or "anomaly score is" in ms.lower():
            import re
            match = re.search(r"Entity\s+([A-Za-z0-9_]+)\s+anomaly\s+sc[oe]+r?e?\s+is\s+([0-9\.e\+]+)", ms, re.IGNORECASE)
            if match:
                cow_id = match.group(1)
                try:
                    val = float(match.group(2))
                    if val > 10.0:
                        import math
                        val = min(2.0, math.log10(val) / 5.0)
                    dev_pct = int(round(min(100.0, (val / 1.5) * 100.0)))
                except Exception:
                    dev_pct = 75
                ms = f"Cattle {cow_id}: Abnormal behavior activity detected ({dev_pct}% deviation). Please inspect cattle."

        if "ANOMALY" in ms or "ALERT" in ms or "intruder" in ms or "Abnormal behavior" in ms:
            s = "high"
        elif "crossed" in ms or "perimeter" in ms:
            s, cat = "high", "CATTLE TRACKING"
        elif "INFO" in ms or "returned" in ms:
            s, cat = "info", "CATTLE TRACKING"
        obj = {"timestamp": now.isoformat(), "category": cat, "message": ms, "severity": s}
    with log_lock:
        alerts.insert(0, obj)
        if len(alerts) > 50:
            alerts.pop()
            
    # Broadcast alert to all listening WebSockets
    queue_telemetry("alert", obj)

# ── GenZ Pipeline ─────────────────────────────────────────────────────────────
try:
    from jetson_pipeline import GenZProcessor, register_alert_callback
    register_alert_callback(add_alert)
    add_log("Jetson AI Pipeline loaded and alert callback registered!", "SUCCESS")
except Exception as e:
    GenZProcessor = None
    add_log(f"Jetson AI Pipeline load failed: {e}", "WARNING")

# ── YOLO (shared fallback, GenZ uses TRT engines) ────────────────────────────
yolo_model = None
try:
    from ultralytics import YOLO
    yolo_path = os.path.join(SCRIPT_DIR, "yolo26.engine")
    if not os.path.exists(yolo_path):
        yolo_path = os.path.join(SCRIPT_DIR, "yolo26.pt")
    if os.path.exists(yolo_path):
        yolo_model = YOLO(yolo_path, task="detect")
        add_log(f"Fallback YOLO loaded: {os.path.basename(yolo_path)}", "INFO")
except Exception as e:
    add_log(f"Fallback YOLO failed: {e}", "WARNING")

frame_counters = {name: 0 for name in CAMERAS}

# ── CameraStream ──────────────────────────────────────────────────────────────
class CameraStream:
    def __init__(self, name, url):
        self.name           = name
        self.url            = url
        self.frame          = None
        self.annotated_frame = None
        self.lock           = threading.Lock()
        self.stopped        = False
        self.cap            = None
        self.is_connected   = False
        self.auth_failed    = False
        self.latency_ms     = 0
        self.cattle_count   = 0
        self.person_count   = 0
        self.fps            = 0.0
        self.width          = 0
        self.height         = 0
        self.frame_times    = []
        self.yolo_busy      = False
        self.yolo_lock      = threading.Lock()
        self.last_viewed    = time.time()
        self.is_active      = True
        self.session        = requests.Session()
        self.session.verify = False
        self.pipeline       = None
        if GenZProcessor:
            try:
                self.pipeline = GenZProcessor(cam_id=name)
            except Exception as e:
                add_log(f"Pipeline init failed for {name}: {e}", "WARNING")

    def start(self):
        threading.Thread(target=self.update, daemon=True).start()
        return self

    def _trigger_yolo_async(self, frame):
        if self.pipeline is None:
            with self.lock:
                self.annotated_frame = frame
            return
        with self.yolo_lock:
            if self.yolo_busy:
                return
            self.yolo_busy = True

        def worker():
            try:
                annotated = self.pipeline.process(frame.copy())
                cows, persons = self.pipeline.get_counts()
                self.cattle_count = cows
                self.person_count = persons
                with self.lock:
                    self.annotated_frame = annotated
            except Exception:
                pass
            finally:
                with self.yolo_lock:
                    self.yolo_busy = False

        threading.Thread(target=worker, daemon=True).start()

    def update(self):
        working_auth = "Digest"
        auth_cache   = {}

        while not self.stopped:
            # Standby if no viewer for 25s
            if time.time() - self.last_viewed > 25.0:
                self.is_active    = False
                self.is_connected = True
                if self.cap:
                    try:
                        self.cap.release()
                    except Exception:
                        pass
                    self.cap = None
                time.sleep(1.0)
                continue

            self.is_active = True
            url = self.url
            conf = CONFIG

            if url and ("snapshot" in url or url.startswith("http")):
                # HTTP / HTTPS snapshot mode
                try:
                    start_t = time.time()
                    cam_key = self.name
                    user    = conf.get(f"{cam_key}_user", "admin")
                    passw   = conf.get(f"{cam_key}_pass", "GeethaCam1234_")
                    key     = f"{user}:{passw}"
                    if key not in auth_cache:
                        auth_cache[key] = {
                            "Digest": HTTPDigestAuth(user, passw),
                            "Basic":  HTTPBasicAuth(user, passw),
                        }
                    r = self.session.get(url, auth=auth_cache[key][working_auth], timeout=3)
                    if r.status_code == 401:
                        alt = "Basic" if working_auth == "Digest" else "Digest"
                        r   = self.session.get(url, auth=auth_cache[key][alt], timeout=3)
                        if r.status_code == 200:
                            working_auth = alt
                    if r.status_code == 200 and len(r.content) > 1000:
                        img_arr = np.frombuffer(r.content, dtype=np.uint8)
                        frame   = cv2.imdecode(img_arr, cv2.IMREAD_COLOR)
                        if frame is not None:
                            self.is_connected = True
                            self.auth_failed  = False
                            self.latency_ms   = int((time.time() - start_t) * 1000)
                            if frame.shape[1] != 1280 or frame.shape[0] != 720:
                                frame = cv2.resize(frame, (1280, 720))
                            self.width, self.height = 1280, 720
                            t_now = time.time()
                            self.frame_times.append(t_now)
                            if len(self.frame_times) > 25:
                                self.frame_times.pop(0)
                            self.fps = 10.0
                            with self.lock:
                                self.frame = frame
                            self._trigger_yolo_async(frame)
                            elapsed = time.time() - start_t
                            time.sleep(max(0.001, 0.100 - elapsed))
                            continue
                    else:
                        self.is_connected = False
                        self.auth_failed  = (r.status_code == 401)
                except Exception as e:
                    self.is_connected = False
                    add_log(f"Snapshot error {self.name}: {str(e)[:50]}", "WARNING")
                time.sleep(3)

            else:
                # RTSP stream
                if self.cap is None or not self.cap.isOpened():
                    self.is_connected = False
                    add_log(f"Connecting {self.name.upper()} RTSP...")
                    self.cap = cv2.VideoCapture(url)
                    if self.cap.isOpened():
                        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1280)
                        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
                        self.is_connected = True
                        add_log(f"{self.name.upper()} RTSP connected!", "SUCCESS")
                    else:
                        self.cap = None
                        time.sleep(3)
                        continue

                # Rate-limit decode to ~6 FPS on Jetson (saves memory)
                t_now     = time.time()
                last_proc = getattr(self, "_last_proc", 0.0)
                if t_now - last_proc < 0.100:
                    try:
                        self.cap.grab()
                    except Exception:
                        pass
                    time.sleep(0.005)
                    continue

                try:
                    ret, frame = self.cap.read()
                except Exception as e:
                    add_log(f"Read error {self.name}: {e}", "ERROR")
                    self.is_connected = False
                    if self.cap:
                        self.cap.release()
                        self.cap = None
                    time.sleep(3)
                    continue

                if not ret:
                    self.is_connected = False
                    if self.cap:
                        self.cap.release()
                        self.cap = None
                    time.sleep(3)
                    continue

                self._last_proc = time.time()
                self.latency_ms = int((time.time() - t_now) * 1000)
                if frame.shape[1] != 1280 or frame.shape[0] != 720:
                    frame = cv2.resize(frame, (1280, 720))
                self.width, self.height = 1280, 720
                self.fps = 10.0
                with self.lock:
                    self.frame = frame
                self._trigger_yolo_async(frame)

    def get_frame(self, annotated=True):
        with self.lock:
            if annotated and self.annotated_frame is not None:
                return self.annotated_frame.copy()
            if self.frame is not None:
                return self.frame.copy()
        return None

    def reload(self, new_url):
        with self.lock:
            self.url          = new_url
            self.is_connected = False
            if self.cap:
                self.cap.release()
                self.cap = None
            try:
                self.session.close()
            except Exception:
                pass
            self.session        = requests.Session()
            self.session.verify = False

    def stop(self):
        self.stopped = True
        if self.cap:
            self.cap.release()
        try:
            self.session.close()
        except Exception:
            pass

# ── Start Streams ─────────────────────────────────────────────────────────────
streams = {name: CameraStream(name, url).start() for name, url in CAMERAS.items()}

# Recalculate baselines on startup
try:
    from adaptive_health import compute_baselines
    threading.Thread(target=compute_baselines, daemon=True).start()
except Exception as e:
    add_log(f"Baseline startup error: {e}", "WARNING")

# Dynamic camera stream anomaly/error detector
def camera_anomaly_detector():
    time.sleep(10)  # Wait for initial stream connection attempts
    offline_status = {}
    
    while True:
        try:
            # Dynamically identify all cameras currently configured in streams
            active_stream_keys = list(streams.keys())
            
            # Sync offline status trackers dynamically (handles runtime changes)
            for name in active_stream_keys:
                if name not in offline_status:
                    offline_status[name] = False
            for name in list(offline_status.keys()):
                if name not in active_stream_keys:
                    del offline_status[name]
            for name in active_stream_keys:
                stream = streams.get(name)
                if not stream:
                    continue
                
                is_connected = stream.is_connected
                
                # Format friendly display name (e.g., "cam1" -> "Camera 1", "front_gate" -> "Front Gate")
                if name.lower().startswith("cam") and name[3:].isdigit():
                    cam_label = f"Camera {name[3:]}"
                else:
                    cam_label = " ".join(word.capitalize() for word in name.replace("_", " ").split())
                if not is_connected and not offline_status[name]:
                    # Stream went offline
                    offline_status[name] = True
                    add_alert({
                        "message": f"{cam_label} is not working - not getting stream",
                        "category": "CAMERA MONITORING",
                        "severity": "high"
                    })
                    add_log(f"ALERT: {cam_label} went offline!", "WARNING")
                elif is_connected and offline_status[name]:
                    # Stream recovered
                    offline_status[name] = False
                    add_alert({
                        "message": f"{cam_label} is back online - stream recovered",
                        "category": "CAMERA MONITORING",
                        "severity": "info"
                    })
                    add_log(f"SUCCESS: {cam_label} is back online", "SUCCESS")
            time.sleep(5)
        except Exception:
            time.sleep(5)

# Start anomaly detector thread
threading.Thread(target=camera_anomaly_detector, daemon=True).start()


# ── Diagnostic Offline Frame ──────────────────────────────────────────────────
def generate_diagnostic_frame(name):
    w, h = 640, 360
    frame = np.zeros((h, w, 3), dtype=np.uint8)
    frame_counters[name] += 1
    c = frame_counters[name]

    # Grid
    for y in range(0, h, 80):
        cv2.line(frame, (0, y), (w, y), (35, 25, 20), 1)
    for x in range(0, w, 80):
        cv2.line(frame, (x, 0), (x, h), (35, 25, 20), 1)

    # Scanning line
    scan_y = (c * 6) % h
    cv2.line(frame, (0, scan_y), (w, scan_y), (0, 0, 150), 2)

    # Offline badge
    if (c // 15) % 2 == 0:
        cv2.rectangle(frame, (50, 50), (320, 110), (0, 0, 180), -1)
        cv2.putText(frame, "SIGNAL LOST", (75, 92), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 255, 255), 2)
    else:
        cv2.rectangle(frame, (50, 50), (320, 110), (35, 35, 35), -1)
        cv2.putText(frame, "OFFLINE", (120, 92), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (150, 150, 150), 2)

    cv2.putText(frame, f"CAMERA ID: {name.upper()}", (50, 180),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 210, 255), 2)
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    cv2.putText(frame, ts, (w - 360, h - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (150, 150, 150), 1)
    return frame

def get_camera_ip(cam_key):
    conf = load_config()
    if cam_key == "cam1":
        import re
        m = re.search(r"@([\d\.]+)", conf.get("cam1_url", ""))
        return m.group(1) if m else "192.168.0.162"
    return conf.get(f"{cam_key}_ip", "")

# ── Streaming ─────────────────────────────────────────────────────────────────
def generate_frames(cam_id, overlay=True, mobile=False):
    stream     = streams.get(cam_id)
    frame_rate = 0.10   # ~10 FPS cap for Jetson Orin Nano
    mobile_sz  = (640, 360)
    jpeg_q     = 45 if mobile else 60

    while True:
        t_start = time.time()
        if stream:
            stream.last_viewed = time.time()
        try:
            if stream and stream.is_connected:
                frame = stream.get_frame(annotated=overlay)
                if frame is not None:
                    if mobile:
                        frame = cv2.resize(frame, mobile_sz, interpolation=cv2.INTER_LINEAR)
                    ret, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), jpeg_q])
                    if ret:
                        yield (b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + buf.tobytes() + b"\r\n")
                else:
                    time.sleep(0.1)
            else:
                frame = generate_diagnostic_frame(cam_id)
                if mobile:
                    frame = cv2.resize(frame, mobile_sz, interpolation=cv2.INTER_LINEAR)
                ret, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), jpeg_q])
                if ret:
                    yield (b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + buf.tobytes() + b"\r\n")
        except Exception as e:
            add_log(f"Stream error {cam_id}: {str(e)[:50]}", "WARNING")
            time.sleep(0.1)

        elapsed = time.time() - t_start
        if elapsed < frame_rate:
            time.sleep(frame_rate - elapsed)

# ── Routes ────────────────────────────────────────────────────────────────────
@app.get("/")
async def index(request: Request):
    return templates.TemplateResponse(request=request, name="index.html", context={"request": request, "cameras": CAMERAS.keys()})

@app.get("/video_feed/{cam_id}")
async def video_feed(cam_id: str, overlay: bool = True, mobile: bool = False):
    headers = {
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma":        "no-cache",
        "Expires":       "0",
        "X-Accel-Buffering": "no",
    }
    return StreamingResponse(
        generate_frames(cam_id, overlay, mobile),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers=headers,
    )

@app.get("/api/frame/{cam_id}")
def get_single_frame(cam_id: str, overlay: bool = True, mobile: bool = True):
    stream = streams.get(cam_id)
    if stream:
        # If the stream is active, update the last_viewed time to keep it alive
        stream.last_viewed = time.time()
        if stream.is_connected:
            frame = stream.get_frame(annotated=overlay)
            if frame is not None:
                if mobile:
                    # Resize to mobile size (640x360) and lower quality to save bandwidth
                    frame = cv2.resize(frame, (640, 360), interpolation=cv2.INTER_LINEAR)
                ret, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 45])
                if ret:
                    return Response(content=buf.tobytes(), media_type="image/jpeg")
    
    # Fallback to diagnostic offline frame
    frame = generate_diagnostic_frame(cam_id)
    if mobile:
        frame = cv2.resize(frame, (640, 360), interpolation=cv2.INTER_LINEAR)
    ret, buf = cv2.imencode(".jpg", frame, [int(cv2.IMWRITE_JPEG_QUALITY), 45])
    if ret:
        return Response(content=buf.tobytes(), media_type="image/jpeg")
    return Response(status_code=404)


@app.get("/api/status")
async def get_status(request: Request):
    base = str(request.base_url).rstrip("/")
    data = {}
    for name, stream in streams.items():
        stream.last_viewed = time.time()
        fps = stream.fps if stream.is_connected else 0
        posture = feeding = ear_tag_id = "Uncertain"
        anomaly = 0.0
        if stream.pipeline:
            posture, feeding, ear_tag_id, anomaly = stream.pipeline.get_summary_status()
        cam_info = {
            "online":     stream.is_connected,
            "latency":    stream.latency_ms if stream.is_connected else 0,
            "resolution": "1280 x 720",
            "fps":        fps,
            "cows":       stream.cattle_count if stream.is_connected else 0,
            "persons":    stream.person_count if stream.is_connected else 0,
            "stream_url": f"{base}/video_feed/{name}",
            "posture":    posture,
            "feeding":    feeding,
            "ear_tag_id": ear_tag_id,
            "anomaly_score": anomaly,
        }
        data[name] = cam_info
        ip = get_camera_ip(name)
        if ip:
            data[ip] = cam_info
    return JSONResponse(content=data)

@app.get("/api/logs")
async def get_logs():
    with log_lock:
        return JSONResponse(content=list(logs))

@app.get("/api/alerts")
async def get_alerts():
    with log_lock:
        return JSONResponse(content=list(alerts))

@app.post("/api/trigger_alert")
async def trigger_alert(payload: dict):
    message = payload.get("message", "Manual alarm triggered!")
    add_alert(f"USER ALERT: {message}")
    return JSONResponse(content={"status": "success", "message": "Alert raised."})

@app.get("/api/config_camera")
async def get_config():
    return JSONResponse(content=load_config())

@app.post("/api/config_camera")
async def config_camera(payload: dict):
    try:
        conf = load_config()
        if "cam1_url" in payload:
            conf["cam1_url"] = payload["cam1_url"]
            
        prefixes = ["cam2", "cam3", "cam4", "cam5"]
        for prefix in prefixes:
            for k in ["_ip", "_user", "_pass", "_path", "_mode"]:
                key = f"{prefix}{k}"
                if key in payload:
                    conf[key] = payload[key]
        with open(CONFIG_FILE, "w") as f:
            json.dump(conf, f, indent=4)
            
        # Dynamically reload, start, or stop streams
        if "cam1_url" in payload:
            new_url = conf.get("cam1_url")
            if new_url:
                if "cam1" in streams:
                    streams["cam1"].reload(new_url)
                else:
                    streams["cam1"] = CameraStream("cam1", new_url).start()
            else:
                if "cam1" in streams:
                    streams["cam1"].stop()
                    del streams["cam1"]
                    
        for prefix in prefixes:
            ip = conf.get(f"{prefix}_ip")
            if ip:
                new_url = build_cam_url(conf, prefix)
                if prefix in streams:
                    streams[prefix].reload(new_url)
                else:
                    streams[prefix] = CameraStream(prefix, new_url).start()
            else:
                if prefix in streams:
                    streams[prefix].stop()
                    del streams[prefix]
                    
        add_log("Cameras reconfigured!", "SUCCESS")
        return JSONResponse(content={"status": "success"})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/api/cattle")
async def get_cattle_list():
    from jetson_pipeline import MASTER_CATTLE_LIST_FILE, MASTER_CATTLE_LIST
    cattle_ids = set(MASTER_CATTLE_LIST)
    db_file = os.path.join(STORAGE_DIR, "behavior_logs.csv")
    if os.path.exists(db_file):
        try:
            import pandas as pd
            df = pd.read_csv(db_file, on_bad_lines="skip")
            if "Entity_ID" in df.columns:
                for v in df["Entity_ID"].dropna().unique():
                    vs = str(v).strip()
                    if vs and "Analysing" not in vs and vs != "Uncertain":
                        cattle_ids.add(vs)
        except Exception:
            pass
    if not cattle_ids:
        cattle_ids = {"A145", "B643", "D675"}
    return JSONResponse(content=sorted(list(cattle_ids)))

@app.get("/api/cattle/summary")
def get_cattle_summary():
    from collections import Counter
    import pandas as pd
    from adaptive_health import evaluate_current_behavior, load_behavior_df
    from jetson_pipeline import MASTER_CATTLE_LIST, MASTER_CATTLE_LIST_FILE

    summary     = {}
    master_ids  = set(MASTER_CATTLE_LIST)
    db_file     = os.path.join(STORAGE_DIR, "behavior_logs.csv")

    def empty_entry(cid, identified=True):
        return {
            "cattle_id":         cid,
            "is_identified":     identified,
            "first_seen":        "Not logged yet",
            "last_seen":         "Not logged yet",
            "total_records":     0,
            "most_common_posture": "Uncertain",
            "most_common_feeding": "Uncertain",
            "posture_counts":    {},
            "feeding_counts":    {},
            "lying_pct":         0.0,
            "standing_pct":      0.0,
            "feeding_pct":       0.0,
            "idle_pct":          0.0,
            "cameras_seen":      ["CAM1"],
            "anomaly_score":     0.0,
            "behavior_sessions": {"Lying":{"sessions":[],"total_duration_sec":0},
                                  "Standing":{"sessions":[],"total_duration_sec":0},
                                  "Feeding":{"sessions":[],"total_duration_sec":0},
                                  "Idle":{"sessions":[],"total_duration_sec":0}},
            "risk_score":        0,
            "health_status":     "Healthy",
            "learning_mode":     True,
            "days_learned":      0,
            "deviations":        {},
            "baseline":          {},
            "current_daily":     {},
        }

    for mid in master_ids:
        summary[mid] = empty_entry(mid)

    try:
        raw_df = load_behavior_df()
        if raw_df is not None and not raw_df.empty:
            df = raw_df.copy()
            cam_col = "Camera_ID" if "Camera_ID" in df.columns else ("Camera_IP" if "Camera_IP" in df.columns else None)
            if "Entity_ID" in df.columns:
                df["Entity_ID_Clean"] = df["Entity_ID"].astype(str).str.strip().str.upper()
                for cid, grp in df.groupby("Entity_ID_Clean"):
                    cs = str(cid)
                    if not cs or cs == "NAN" or cs == "UNCERTAIN" or "ANALYSING" in cs:
                        continue
                    postures  = grp["Posture"].dropna().astype(str).tolist()
                    feedings  = grp["Feeding"].dropna().astype(str).tolist()
                    cameras   = grp[cam_col].dropna().astype(str).unique().tolist() if cam_col else ["CAM1"]
                    pc        = Counter(postures)
                    fc        = Counter(feedings)
                    ts_list   = grp["Timestamp"].dropna().astype(str).tolist()

                    total_recs = len(grp)
                    lying_cnt = sum(1 for p in postures if p.strip().lower() == "lying")
                    standing_cnt = sum(1 for p in postures if p.strip().lower() == "standing")
                    feeding_cnt = sum(1 for f in feedings if "feed" in f.strip().lower())
                    idle_cnt = sum(1 for f in feedings if "idle" in f.strip().lower())

                    lying_p = round((lying_cnt / total_recs) * 100.0, 1) if total_recs > 0 else 0.0
                    standing_p = round((standing_cnt / total_recs) * 100.0, 1) if total_recs > 0 else 0.0
                    feeding_p = round((feeding_cnt / total_recs) * 100.0, 1) if total_recs > 0 else 0.0
                    idle_p = round((idle_cnt / total_recs) * 100.0, 1) if total_recs > 0 else 0.0

                    entry = empty_entry(cs)
                    entry.update({
                        "first_seen":          ts_list[0] if (ts_list and ts_list[0]) else "Not logged yet",
                        "last_seen":           ts_list[-1] if (ts_list and ts_list[-1]) else "Not logged yet",
                        "total_records":       total_recs,
                        "most_common_posture": pc.most_common(1)[0][0] if pc else "Uncertain",
                        "most_common_feeding": fc.most_common(1)[0][0] if fc else "Uncertain",
                        "posture_counts":      dict(pc),
                        "feeding_counts":      dict(fc),
                        "lying_pct":           lying_p,
                        "standing_pct":        standing_p,
                        "feeding_pct":         feeding_p,
                        "idle_pct":            idle_p,
                        "cameras_seen":        cameras if cameras else ["CAM1"],
                    })
                    try:
                        er = evaluate_current_behavior(cs)
                        entry["risk_score"]    = er.get("risk_score", 0)
                        entry["health_status"] = er.get("status", "Healthy")
                        entry["learning_mode"] = er.get("learning_mode", True)
                        entry["days_learned"]  = er.get("days_learned", 0)
                        entry["deviations"]    = er.get("deviations", {})
                        entry["baseline"]      = er.get("baseline", {})
                        entry["current_daily"] = er.get("current", {})
                    except Exception:
                        pass
                    summary[cs] = entry
    except Exception as e:
        add_log(f"Cattle summary error: {e}", "WARNING")

    return JSONResponse(content=summary)

@app.get("/api/dashboard")
def get_dashboard_summary():
    import pandas as pd
    from adaptive_health import evaluate_current_behavior
    from jetson_pipeline import MASTER_CATTLE_LIST
    
    total_cattle = len(MASTER_CATTLE_LIST)
    healthy = 0
    warning = 0
    critical = 0
    
    for cid in MASTER_CATTLE_LIST:
        try:
            er = evaluate_current_behavior(cid)
            status = er.get("status", "Healthy").upper()
            if "CRITICAL" in status:
                critical += 1
            elif "OBSERVE" in status or "WARNING" in status:
                warning += 1
            else:
                healthy += 1
        except Exception:
            healthy += 1
            
    # Calculate attendance
    attendance_today = 0
    db_file = os.path.join(STORAGE_DIR, "behavior_logs.csv")
    if os.path.exists(db_file):
        try:
            df = pd.read_csv(db_file, on_bad_lines="skip")
            if "Entity_ID" in df.columns and "Timestamp" in df.columns:
                today_str = datetime.datetime.now().strftime("%d-%m-%Y")
                df_today = df[df["Timestamp"].astype(str).str.contains(today_str)]
                attendance_today = df_today["Entity_ID"].dropna().nunique()
        except Exception:
            pass
            
    sys_stats = {}
    try:
        sys_stats = get_system_stats()
    except Exception:
        pass
        
    return JSONResponse(content={
        "total_cattle": total_cattle,
        "healthy": healthy,
        "warning": warning,
        "critical": critical,
        "attendance": attendance_today,
        "model_version": "YOLOv8-CattleVision-v2.6",
        "system_status": sys_stats
    })

@app.get("/api/cattle/{cattle_id}/metrics")
async def get_cattle_metrics(cattle_id: str):
    try:
        from adaptive_health import evaluate_current_behavior
        res = evaluate_current_behavior(cattle_id)
        current = res.get("current", {})
        risk_score = res.get("risk_score", 0)
        health_score = max(0, 100 - risk_score)
        
        return JSONResponse(content={
            "id": cattle_id,
            "standing": round(current.get("standing_hours", 0.0), 2),
            "lying": round(current.get("lying_hours", 0.0), 2),
            "feeding": round(current.get("feeding_hours", 0.0), 2),
            "idle": round(current.get("idle_hours", 0.0), 2),
            "health_score": health_score,
            "learning_mode": res.get("learning_mode", True),
            "status": res.get("status", "Healthy")
        })
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.websocket("/ws/telemetry")
async def ws_telemetry(websocket: WebSocket):
    await websocket.accept()
    with telemetry_lock:
        active_telemetry_connections.add(websocket)
    try:
        # Send initial status
        stats = get_system_stats()
        await websocket.send_text(json.dumps({
            "type": "status",
            "data": stats,
            "timestamp": datetime.datetime.now().isoformat()
        }))
        
        # Send initial alerts
        with log_lock:
            recent_alerts = list(alerts)
        await websocket.send_text(json.dumps({
            "type": "alerts_initial",
            "data": recent_alerts,
            "timestamp": datetime.datetime.now().isoformat()
        }))
        
        while True:
            # Maintain connection, check for disconnects
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        with telemetry_lock:
            active_telemetry_connections.discard(websocket)

@app.get("/api/cattle/{cattle_id}/export")
async def export_cattle_csv(cattle_id: str):
    import io, pandas as pd
    out = io.StringIO()
    out.write("Timestamp,Camera_ID,Entity_ID,Posture,Feeding,Duration_Sec\n")
    db_file = os.path.join(STORAGE_DIR, "behavior_logs.csv")
    if os.path.exists(db_file):
        try:
            df = pd.read_csv(db_file, on_bad_lines="skip")
            cam_col = "Camera_ID" if "Camera_ID" in df.columns else ("Camera_IP" if "Camera_IP" in df.columns else None)
            if "Entity_ID" in df.columns:
                for _, row in df[df["Entity_ID"].astype(str) == cattle_id].iterrows():
                    cv = str(row.get(cam_col, "")) if cam_col else ""
                    out.write(f"{row.get('Timestamp','')},{cv},{row.get('Entity_ID','')},{row.get('Posture','')},{row.get('Feeding','')},{row.get('Duration_Sec',60)}\n")
        except Exception:
            pass
    return Response(
        content=out.getvalue().encode("utf-8"),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=cattle_{cattle_id}_history.csv"},
    )

@app.get("/api/cattle/{cattle_id}/baseline")
async def get_cattle_baseline(cattle_id: str):
    try:
        from adaptive_health import evaluate_current_behavior
        return JSONResponse(content=evaluate_current_behavior(cattle_id))
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.get("/api/cattle/{cattle_id}")
async def get_cattle_history(cattle_id: str):
    import pandas as pd
    db_file = os.path.join(STORAGE_DIR, "behavior_logs.csv")
    history = []
    if os.path.exists(db_file):
        try:
            df = pd.read_csv(db_file, on_bad_lines="skip")
            if "Entity_ID" in df.columns:
                cam_col = "Camera_ID" if "Camera_ID" in df.columns else ("Camera_IP" if "Camera_IP" in df.columns else None)
                for _, row in df[df["Entity_ID"].astype(str) == cattle_id].iterrows():
                    history.append({
                        "timestamp": str(row.get("Timestamp", "")),
                        "camera_id": str(row.get(cam_col, "")) if cam_col else "",
                        "posture":   str(row.get("Posture", "Uncertain")),
                        "feeding":   str(row.get("Feeding", "Uncertain")),
                        "duration":  int(row.get("Duration_Sec", 60)),
                    })
        except Exception:
            pass
    history.sort(key=lambda x: x["timestamp"], reverse=True)
    return JSONResponse(content=history)

@app.get("/api/master_sheet")
async def get_master_sheet():
    from jetson_pipeline import MASTER_CATTLE_LIST_FILE
    ids = []
    if os.path.exists(MASTER_CATTLE_LIST_FILE):
        try:
            with open(MASTER_CATTLE_LIST_FILE) as f:
                for line in f:
                    v = line.strip().upper()
                    if v and len(v) == 4 and v.isalnum():
                        ids.append(v)
        except Exception:
            pass
    return JSONResponse(content={"status": "success", "ids": ids})

@app.post("/api/master_sheet")
async def post_master_sheet(payload: dict):
    import re
    from jetson_pipeline import MASTER_CATTLE_LIST_FILE, load_master_list
    new_ids   = payload.get("ids", [])
    valid_ids = []
    for x in new_ids:
        s = str(x).strip().upper()
        if re.match(r"^[A-Z][0-9]{3}$", s):
            valid_ids.append(s)
    try:
        with open(MASTER_CATTLE_LIST_FILE, "w") as f:
            for cid in valid_ids:
                f.write(f"{cid}\n")
        add_log(f"Master Sheet updated with {len(valid_ids)} IDs", "SUCCESS")
        load_master_list()
        return JSONResponse(content={"status": "success", "ids": valid_ids})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

@app.post("/api/sync_camera_times")
async def trigger_sync_camera_times():
    import subprocess
    import sys
    try:
        script_path = os.path.join(SCRIPT_DIR, "camera_services", "sync_camera_times.py")
        subprocess.Popen([sys.executable, script_path, "--headless"])
        add_log("Camera time synchronization triggered", "INFO")
        return JSONResponse(content={"status": "success", "message": "Time synchronization triggered in background."})
    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)

def _clean_name(name):
    if not name:
        return name
    parts = name.split("_")
    return name if parts[0].upper() == "UNKNOWN" else parts[0]

@app.get("/api/security/logs")
def get_security_logs():
    import csv
    if not os.path.exists(ATTENDANCE_LOG):
        return JSONResponse(content=[])
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    result = []
    try:
        with open(ATTENDANCE_LOG) as f:
            for row in csv.DictReader(f):
                if row.get("Date", "").strip() != today:
                    continue
                result.append({
                    "name":     _clean_name(row.get("Name", "Unknown").strip()),
                    "date":     row.get("Date", "").strip(),
                    "time":     row.get("Time", "").strip(),
                    "type":     row.get("Type", "Alert").strip(),
                    "track_id": row.get("Track_ID", "").strip(),
                })
        result.sort(key=lambda x: f"{x['date']} {x['time']}", reverse=True)
        return JSONResponse(content=result[:100])
    except Exception:
        return JSONResponse(content=[])

@app.get("/api/security/attendance")
def get_security_attendance():
    import csv
    if not os.path.exists(ATTENDANCE_LOG):
        return JSONResponse(content=[])
    today      = datetime.datetime.now().strftime("%Y-%m-%d")
    attendance = {}
    try:
        with open(ATTENDANCE_LOG) as f:
            for row in csv.DictReader(f):
                name     = _clean_name(row.get("Name", "").strip())
                date_val = row.get("Date", "").strip()
                time_val = row.get("Time", "").strip()
                if date_val != today or not name:
                    continue
                nl = name.lower()
                if nl.startswith("unknown") or nl in ("analyzing", "person"):
                    continue
                role = "Registered Member" if nl in ("geetha", "family") else "Authorized Farm Worker"
                if name not in attendance:
                    attendance[name] = {"name": name, "role": role, "in_time": time_val, "out_time": time_val}
                else:
                    if time_val < attendance[name]["in_time"]:
                        attendance[name]["in_time"]  = time_val
                    if time_val > attendance[name]["out_time"]:
                        attendance[name]["out_time"] = time_val
        now_t = datetime.datetime.now()
        result = []
        for name, info in attendance.items():
            try:
                out_dt  = datetime.datetime.strptime(f"{today} {info['out_time']}", "%Y-%m-%d %H:%M:%S")
                diff    = (now_t - out_dt).total_seconds()
                info["status"] = "Active" if diff <= 300 else "Away"
            except Exception:
                info["status"] = "Away"
            result.append(info)
        result.sort(key=lambda x: x["name"].lower())
        return JSONResponse(content=result)
    except Exception:
        return JSONResponse(content=[])

@app.get("/api/security/unknown")
def get_unknown_visitors():
    import glob
    import base64
    unk_dir  = os.path.join(STATIC_DIR, "unknown_faces")
    today    = datetime.datetime.now().strftime("%Y-%m-%d")
    raw_list = []
    for fp in glob.glob(os.path.join(unk_dir, "Unknown_*.jpg")):
        fn    = os.path.basename(fp)
        parts = fn.replace(".jpg", "").split("_")
        if len(parts) >= 4:
            date_s = parts[2]
            if date_s != today:
                continue
            raw_list.append((fp, fn, parts))
    # Sort by modification time to get latest first
    raw_list.sort(key=lambda x: os.path.getmtime(x[0]), reverse=True)
    # Take only the top 10 latest visitors
    latest = raw_list[:10]
    visitors = []
    for fp, fn, parts in latest:
        try:
            with open(fp, "rb") as image_file:
                b64_str = "data:image/jpeg;base64," + base64.b64encode(image_file.read()).decode("utf-8")
        except Exception:
            b64_str = ""
        visitors.append({
            "name":      f"Unknown {parts[1]}",
            "track_id":  parts[1],
            "date":      parts[2],
            "time":      parts[3].replace("-", ":"),
            "photo_url": f"/static/unknown_faces/{fn}",
            "image":     b64_str,
            "mtime":     os.path.getmtime(fp),
        })
    return JSONResponse(content=visitors)

# ── Face Registration Subsystem ───────────────────────────────────────────────
import base64
REG_EMBEDDINGS_FILE = os.path.join(EMBED_DIR, "known_embeddings.pkl")
REG_ROLES_FILE      = os.path.join(EMBED_DIR, "member_roles.json")

reg_session      = {"name": "", "role": "", "active": False, "capturing": False,
                    "count": 0, "progress": 0, "embeddings": []}
reg_session_lock = threading.Lock()

def _load_roles():
    if os.path.exists(REG_ROLES_FILE):
        try:
            with open(REG_ROLES_FILE) as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def _save_role(name, role):
    roles = _load_roles()
    roles[name.strip().replace(" ", "_")] = role
    os.makedirs(os.path.dirname(REG_ROLES_FILE), exist_ok=True)
    try:
        with open(REG_ROLES_FILE, "w") as f:
            json.dump(roles, f)
    except Exception:
        pass

def _auto_save():
    global reg_session
    with reg_session_lock:
        name = reg_session["name"]
        role = reg_session["role"]
        embs = reg_session["embeddings"]
        if not embs:
            return
        arr  = np.stack(embs)
        mean = np.mean(arr, axis=0)
        mean = mean / (np.linalg.norm(mean) + 1e-10)
        _save_role(name, role)
        db = {}
        if os.path.exists(REG_EMBEDDINGS_FILE):
            try:
                with open(REG_EMBEDDINGS_FILE, "rb") as f:
                    db = pickle.load(f)
            except Exception:
                db = {}
        people = db.get("people", {})
        for angle in ["Front", "Left", "Right", "Up", "Down"]:
            people[f"{name}_{angle}"] = {"mean": mean, "samples": len(embs)}
        db["version"] = 1
        db["people"]  = people
        os.makedirs(os.path.dirname(REG_EMBEDDINGS_FILE), exist_ok=True)
        with open(REG_EMBEDDINGS_FILE, "wb") as f:
            pickle.dump(db, f)
        add_log(f"Face registration saved for {name}", "SUCCESS")
        reg_session["active"] = False

@app.post("/api/start_scan")
async def start_scan(payload: dict):
    global reg_session
    name = payload.get("name", "").strip().replace(" ", "_")
    role = payload.get("role", "").strip()
    if not name or not role:
        return JSONResponse(content={"status": "error", "message": "Name and Role required!"}, status_code=400)
    roles    = _load_roles()
    existing = [k.lower() for k in roles.keys()]
    if os.path.exists(REG_EMBEDDINGS_FILE):
        try:
            with open(REG_EMBEDDINGS_FILE, "rb") as f:
                db = pickle.load(f)
            people_keys = []
            if "templates" in db:
                people_keys.extend(list(db.get("templates", {}).keys()))
            if "people" in db:
                people_keys.extend(list(db.get("people", {}).keys()))
            for pk in people_keys:
                base = pk.rsplit("_", 1)[0].lower()
                if base not in existing:
                    existing.append(base)
        except Exception:
            pass
    if name.lower() in existing:
        return JSONResponse(content={"status": "error", "message": "Name already exists, enter a new name."}, status_code=400)
    with reg_session_lock:
        reg_session = {"name": name, "role": role, "active": True, "capturing": False,
                       "count": 0, "progress": 0, "embeddings": []}
    return JSONResponse(content={"status": "success", "message": "Session initialized. Hold Record to capture."})

@app.post("/api/set_capturing")
async def set_capturing(payload: dict):
    with reg_session_lock:
        if not reg_session["active"]:
            return JSONResponse(content={"status": "error", "message": "No active session!"}, status_code=400)
        reg_session["capturing"] = payload.get("capturing", False)
    return JSONResponse(content={"status": "success"})

@app.get("/api/scan_status")
async def scan_status():
    with reg_session_lock:
        return JSONResponse(content={
            "active":    reg_session["active"],
            "capturing": reg_session["capturing"],
            "progress":  reg_session["progress"],
            "count":     reg_session["count"],
            "name":      reg_session["name"],
        })

@app.websocket("/ws/register_frames")
async def ws_register(websocket: WebSocket):
    await websocket.accept()
    try:
        from jetson_pipeline import face_yolo, face_to_embedding
    except Exception:
        face_yolo = None
        face_to_embedding = None

    try:
        while True:
            data = await websocket.receive_text()
            with reg_session_lock:
                if not reg_session["active"] or not reg_session["capturing"]:
                    continue
            try:
                _, encoded = data.split(",", 1)
                img_data   = base64.b64decode(encoded)
                np_arr     = np.frombuffer(img_data, np.uint8)
                frame      = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
                if frame is not None and face_yolo is not None:
                    h, w = frame.shape[:2]
                    cx, cy = w // 2, h // 2
                    rad    = min(w, h) // 4
                    small  = cv2.resize(frame, (640, 480))
                    res    = face_yolo(small, conf=0.45, verbose=False, device=0 if torch.cuda.is_available() else "cpu")[0]
                    if res.boxes is not None and len(res.boxes.xyxy) > 0:
                        fb = res.boxes.xyxy[0].cpu().numpy()
                        fx1 = int(fb[0] * w / 640); fy1 = int(fb[1] * h / 480)
                        fx2 = int(fb[2] * w / 640); fy2 = int(fb[3] * h / 480)
                        if ((fx1+fx2)//2 - cx)**2 + ((fy1+fy2)//2 - cy)**2 < rad**2:
                            fh_c = fy2 - fy1; fw_c = fx2 - fx1
                            crop = frame[max(0,int(fy1-0.2*fh_c)):min(h,int(fy2+0.1*fh_c)),
                                         max(0,int(fx1-0.1*fw_c)):min(w,int(fx2+0.1*fw_c))]
                            if crop.size > 100 and face_to_embedding:
                                emb = face_to_embedding(crop)
                                if emb is not None:
                                    with reg_session_lock:
                                        reg_session["embeddings"].append(emb)
                                        cnt = len(reg_session["embeddings"])
                                        reg_session["count"]    = cnt
                                        reg_session["progress"] = min(100, int(cnt / 1000.0 * 100))
                                        if cnt >= 1000:
                                            reg_session["capturing"] = False
                                            reg_session["progress"]  = 100
                                            threading.Thread(target=_auto_save, daemon=True).start()
            except Exception:
                pass
    except WebSocketDisconnect:
        pass

@app.get("/api/registered_members")
async def get_registered_members():
    db = {}
    if os.path.exists(REG_EMBEDDINGS_FILE):
        try:
            with open(REG_EMBEDDINGS_FILE, "rb") as f:
                db = pickle.load(f)
        except Exception:
            pass
    if "templates" in db:
        people = {name: {"mean": emb} for name, emb in db["templates"].items()}
    else:
        people = db.get("people", {})
    roles   = _load_roles()
    members = {}
    for key in people:
        name = key.rsplit("_", 1)[0] if "_" in key else key
        if name not in members:
            members[name] = {
                "name":     name.replace("_", " "),
                "raw_name": name,
                "role":     roles.get(name, "Authorized Worker"),
                "status":   "Authorized",
            }
    return JSONResponse(content={"members": list(members.values())})

@app.post("/api/delete_member")
async def delete_member(payload: dict):
    raw_name = payload.get("name", "").strip()
    if not raw_name:
        return JSONResponse(content={"status": "error", "message": "Name required!"}, status_code=400)
    roles = _load_roles()
    if raw_name in roles:
        del roles[raw_name]
        try:
            with open(REG_ROLES_FILE, "w") as f:
                json.dump(roles, f)
        except Exception:
            pass
    if os.path.exists(REG_EMBEDDINGS_FILE):
        try:
            with open(REG_EMBEDDINGS_FILE, "rb") as f:
                db = pickle.load(f)
            
            # Delete from templates if new format
            if "templates" in db:
                templates = db.get("templates", {})
                for k in [k for k in templates if k == raw_name]:
                    del templates[k]
                db["templates"] = templates
                
            # Delete from people if old format
            people = db.get("people", {})
            for k in [k for k in people if k.startswith(f"{raw_name}_") or k == raw_name]:
                del people[k]
            db["people"] = people
            
            with open(REG_EMBEDDINGS_FILE, "wb") as f:
                pickle.dump(db, f)
        except Exception:
            pass
    return JSONResponse(content={"status": "success", "message": f"Member {raw_name} deleted."})

@app.post("/api/run_ai")
async def run_ai_pipeline(payload: dict):
    cam_id_raw = payload.get("camera_id", "cam1")
    cam_key    = cam_id_raw if cam_id_raw in streams else "cam1"
    stream     = streams.get(cam_key)
    if not stream:
        return JSONResponse(content={"status": "error", "message": "Camera not found"}, status_code=404)
    frame = stream.get_frame(annotated=False) or generate_diagnostic_frame(cam_key)
    if stream.pipeline:
        try:
            annotated = stream.pipeline.process(frame.copy())
            with stream.lock:
                stream.annotated_frame = annotated
            posture, feeding, ear_id, anom = stream.pipeline.get_summary_status()
            return JSONResponse(content={"status": "success", "metadata": {
                "cattle_id": ear_id, "posture": posture, "feeding": feeding, "anomaly_score": anom
            }})
        except Exception as e:
            return JSONResponse(content={"status": "error", "message": str(e)}, status_code=500)
    return JSONResponse(content={"status": "success", "message": "AI pipeline not available (mocked)"})

if __name__ == "__main__":
    print(f"\n[Kisan CattleVision] Starting on http://0.0.0.0:8000\n")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="warning")
