"""
jetson_pipeline.py  –  Kisan CattleVision GenZ AI Pipeline
Optimized for Jetson Orin Nano (JetPack 6, Ubuntu 22.04)
All paths are relative to this script's directory.
TensorRT .engine files are loaded automatically if present.
"""

import os
os.environ["OPENCV_LOG_LEVEL"] = "OFF"
os.environ["OPENCV_FFMPEG_LOGLEVEL"] = "-8"
os.environ["PYTHONWARNINGS"] = "ignore"

import warnings
warnings.filterwarnings("ignore")

import cv2
import torch
import numpy as np
import pandas as pd
from datetime import datetime
import time
import re
import json
import pytz
import requests
import csv
import pickle
from collections import deque, Counter, defaultdict
from threading import Thread, Lock
from ultralytics import YOLO
import easyocr
from torchvision import transforms
import timm
from adaptive_health import evaluate_current_behavior, compute_baselines

# ── Jetson thread configuration ───────────────────────────────────────────────
cv2.setNumThreads(4)
torch.set_num_threads(4)
os.environ["OMP_NUM_THREADS"] = "4"
os.environ["MKL_NUM_THREADS"] = "4"

# ── Paths (all relative to script directory) ──────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))

def load_config_raw():
    import json
    CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.json")
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
BASE_STORAGE = get_base_storage(SCRIPT_DIR)
os.makedirs(BASE_STORAGE, exist_ok=True)

DATABASE_FILE          = os.path.join(BASE_STORAGE, "behavior_logs.csv")
MASTER_CATTLE_LIST_FILE = os.path.join(BASE_STORAGE, "master_cattle_list.txt")
ATTENDANCE_LOG         = os.path.join(BASE_STORAGE, "farm_attendance_log.csv")
UNKNOWN_EMB_FILE       = os.path.join(BASE_STORAGE, "unknown_embeddings.pkl")
UNKNOWN_FACES_DIR      = os.path.join(SCRIPT_DIR, "static", "unknown_faces")
os.makedirs(UNKNOWN_FACES_DIR, exist_ok=True)

# Ensure attendance CSV has headers if it doesn't exist
if not os.path.exists(ATTENDANCE_LOG):
    with open(ATTENDANCE_LOG, "w", newline="") as f:
        csv.writer(f).writerow(["Name", "Date", "Time", "Type", "Track_ID"])

# Ensure master cattle list is initialized in BASE_STORAGE
if not os.path.exists(MASTER_CATTLE_LIST_FILE):
    src_list = os.path.join(SCRIPT_DIR, "storage", "master_cattle_list.txt")
    if os.path.exists(src_list):
        import shutil
        try:
            shutil.copy(src_list, MASTER_CATTLE_LIST_FILE)
            print(f"[OK] Initialized master cattle list in BASE_STORAGE from {src_list}")
        except Exception as e:
            print(f"[WARN] Failed to copy master cattle list: {e}")
    else:
        try:
            with open(MASTER_CATTLE_LIST_FILE, "w") as f:
                f.write("A145\nB643\nD675\nA675\n")
            print("[OK] Created default master cattle list in BASE_STORAGE")
        except Exception as e:
            print(f"[WARN] Failed to create default master cattle list: {e}")

# ── Model Paths ───────────────────────────────────────────────────────────────
def _engine_or_pt(name):
    """Return .engine path if it exists (compiled for local Jetson GPU), otherwise fall back to .pt"""
    engine = os.path.join(SCRIPT_DIR, name.replace(".pt", ".engine"))
    pt     = os.path.join(SCRIPT_DIR, name)
    
    has_trt = False
    try:
        import tensorrt
        has_trt = True
    except ImportError:
        pass
        
    if has_trt and os.path.exists(engine):
        print(f"[TRT] Using TensorRT engine: {engine}")
        return engine
    if os.path.exists(pt):
        print(f"[PT]  Using PyTorch weights:  {pt}")
        return pt
    return None

CATTLE_MODEL_PATH    = _engine_or_pt("yolo26.pt")
FALLBACK_MODEL_PATH  = _engine_or_pt("yolov8n.pt")
FACE_MODEL_PATH      = _engine_or_pt(os.path.join("models", "yolov8n-face.pt"))

# ── Face Embedding Subsystem ──────────────────────────────────────────────────
EMBEDDINGS_FILE = os.path.join(SCRIPT_DIR, "embeddings", "known_embeddings.pkl")

known_people        = {}
unknown_people      = {}
known_people_lock   = Lock()
unknown_people_lock = Lock()
face_backbone_lock  = Lock()
last_emb_mod_time   = 0

# Load face backbone (InceptionResnetV1 / ArcFace)
_face_backbone = None
try:
    from facenet_pytorch import InceptionResnetV1
    import torch
    from torchvision import transforms as T
    from PIL import Image

    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[GPU] ArcFace backbone using device: {DEVICE}")
    _face_backbone = InceptionResnetV1(pretrained="vggface2").eval().to(DEVICE)

    # Try loading fine-tuned weights
    ckpt = os.path.join(SCRIPT_DIR, "models", "best_checkpoint.pth")
    if os.path.exists(ckpt):
        state = torch.load(ckpt, map_location=DEVICE)
        _face_backbone.load_state_dict(state["backbone_state_dict"], strict=False)
        print("[OK] Loaded fine-tuned ArcFace weights.")
    else:
        print("[OK] Using pre-trained VGGFace2 ArcFace weights.")

    _face_norm = T.Compose([
        T.ToTensor(),
        T.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0),
    ])
    print("[OK] Face recognition backbone ready.")
except Exception as e:
    print(f"[WARN] Face backbone failed: {e}")
    DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

def load_embeddings(path):
    if os.path.exists(path):
        try:
            with open(path, "rb") as f:
                return pickle.load(f)
        except Exception as e:
            print(f"[WARN] Could not load embeddings from {path}: {e}")
    return {}

def _reload_known():
    global known_people, last_emb_mod_time
    if not os.path.exists(EMBEDDINGS_FILE):
        return
    mtime = os.path.getmtime(EMBEDDINGS_FILE)
    if mtime > last_emb_mod_time:
        data = load_embeddings(EMBEDDINGS_FILE)
        with known_people_lock:
            if "templates" in data:
                known_people = {name: {"mean": emb} for name, emb in data["templates"].items()}
            elif "people" in data:
                known_people = data.get("people", {})
            else:
                known_people = {name: {"mean": emb} for name, emb in data.items()}
        last_emb_mod_time = mtime

last_unk_emb_mod_time = 0.0

def _reload_unknown():
    global unknown_people, last_unk_emb_mod_time
    if not os.path.exists(UNKNOWN_EMB_FILE):
        return
    try:
        mtime = os.path.getmtime(UNKNOWN_EMB_FILE)
        if mtime > last_unk_emb_mod_time:
            data = load_embeddings(UNKNOWN_EMB_FILE)
            with unknown_people_lock:
                unknown_people = data.get("people", {})
            last_unk_emb_mod_time = mtime
    except Exception as e:
        print(f"[WARN] Could not reload unknown embeddings: {e}")

# Initial load
_data = load_embeddings(EMBEDDINGS_FILE)
if "templates" in _data:
    known_people = {name: {"mean": emb} for name, emb in _data["templates"].items()}
elif "people" in _data:
    known_people = _data.get("people", {})
else:
    known_people = {name: {"mean": emb} for name, emb in _data.items()}

if os.path.exists(EMBEDDINGS_FILE):
    last_emb_mod_time = os.path.getmtime(EMBEDDINGS_FILE)

if os.path.exists(UNKNOWN_EMB_FILE):
    _udata = load_embeddings(UNKNOWN_EMB_FILE)
    unknown_people = _udata.get("people", {})
    last_unk_emb_mod_time = os.path.getmtime(UNKNOWN_EMB_FILE)

print(f"[OK] Loaded {len(known_people)} known face embeddings.")
print(f"[OK] Loaded {len(unknown_people)} unknown face embeddings.")

def face_to_embedding(face_bgr):
    if _face_backbone is None:
        return None
    try:
        face_rgb     = cv2.cvtColor(face_bgr, cv2.COLOR_BGR2RGB)
        face_resized = cv2.resize(face_rgb, (160, 160))
        face_pil     = Image.fromarray(face_resized)
        tensor       = _face_norm(face_pil).unsqueeze(0).to(DEVICE)
        with face_backbone_lock:
            with torch.no_grad():
                emb = _face_backbone(tensor)
                emb = emb / torch.norm(emb, p=2, dim=1, keepdim=True)
            return emb[0].cpu().numpy()
    except Exception as e:
        return None

def get_best_match(emb, people_dict):
    if not people_dict or emb is None:
        return None, 0.0
    best_name, best_sim = None, -1.0
    for name, data in people_dict.items():
        mean_emb = data.get("mean")
        if mean_emb is not None:
            sim = float(np.dot(emb, mean_emb))
            if sim > best_sim:
                best_sim = sim
                best_name = name
    return best_name, best_sim

def get_top_two_matches(emb, people_dict):
    if not people_dict or emb is None:
        return (None, 0.0), (None, 0.0)
    matches = []
    for name, data in people_dict.items():
        mean_emb = data.get("mean")
        if mean_emb is not None:
            matches.append((name, float(np.dot(emb, mean_emb))))
    matches.sort(key=lambda x: x[1], reverse=True)
    best = matches[0] if matches else (None, 0.0)
    sec  = matches[1] if len(matches) > 1 else (None, 0.0)
    return best, sec

def clean_member_name(name):
    if not name:
        return name
    name_upper = name.upper()
    if name_upper.startswith("UNKNOWN"):
        parts = name.split("_")
        if len(parts) >= 3 and parts[-1].lower().startswith("v") and parts[-1][1:].isdigit():
            return "_".join(parts[:-1]).replace("_", " ")
        return name.replace("_", " ")
    parts = name.split("_")
    return parts[0]

# ── Face YOLO ─────────────────────────────────────────────────────────────────
face_yolo = None
if FACE_MODEL_PATH:
    try:
        face_yolo = YOLO(FACE_MODEL_PATH, task="detect")
        print(f"[OK] Face YOLO loaded: {FACE_MODEL_PATH}")
    except Exception as e:
        print(f"[WARN] Face YOLO failed: {e}")

# ── Audio System (uses espeak on Linux) ───────────────────────────────────────
import queue
import subprocess

class PipelineAudioSystem:
    def __init__(self):
        self.queue = queue.Queue()
        self.worker = Thread(target=self._process_queue, daemon=True)
        self.worker.start()

    def _process_queue(self):
        while True:
            text = self.queue.get()
            if text is None:
                break
            try:
                subprocess.run(["espeak", text],
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
            except Exception:
                pass
            finally:
                self.queue.task_done()

    def speak(self, text):
        self.queue.put(text)

pipeline_audio = PipelineAudioSystem()
spoken_today   = {}

def _spoken_path():
    return os.path.join(BASE_STORAGE, "spoken_today.json")

def load_spoken_today():
    global spoken_today
    p = _spoken_path()
    if os.path.exists(p):
        try:
            with open(p) as f:
                spoken_today = json.load(f)
        except Exception:
            spoken_today = {}

def save_spoken_today():
    try:
        with open(_spoken_path(), "w") as f:
            json.dump(spoken_today, f)
    except Exception:
        pass

from datetime import date as _date

def should_greet_today(name):
    today   = _date.today().isoformat()
    cleaned = clean_member_name(name)
    key     = cleaned.lower().strip()
    if key.startswith("unknown"):
        return False
    load_spoken_today()
    if spoken_today.get(key) == today:
        return False
    spoken_today[key] = today
    save_spoken_today()
    return True

# ── IST Timezone ──────────────────────────────────────────────────────────────
IST = pytz.timezone("Asia/Kolkata")

# ── Master Cattle List ────────────────────────────────────────────────────────
MASTER_CATTLE_LIST = []
last_master_mod_time = 0.0

def load_master_list():
    global MASTER_CATTLE_LIST, last_master_mod_time
    if os.path.exists(MASTER_CATTLE_LIST_FILE):
        try:
            mtime = os.path.getmtime(MASTER_CATTLE_LIST_FILE)
            if mtime > last_master_mod_time:
                with open(MASTER_CATTLE_LIST_FILE) as f:
                    MASTER_CATTLE_LIST = [l.strip().upper() for l in f if l.strip()]
                last_master_mod_time = mtime
                print(f"[OK] Loaded master cattle list. Total: {len(MASTER_CATTLE_LIST)}")
        except Exception as e:
            print(f"[WARN] Could not load master list: {e}")
    return MASTER_CATTLE_LIST

load_master_list()

# ── Telegram ──────────────────────────────────────────────────────────────────
TELEGRAM_TOKEN = "8674933208:AAGE_E2Eu3FmieMRtbpzyPsZzfJdwXBZcbs"
CHAT_ID        = "5137106552"

def send_telegram(message):
    return # Telegram alerts disabled

# ── Global Alert Callback ─────────────────────────────────────────────────────
global_alert_callback = None

def register_alert_callback(cb):
    global global_alert_callback
    global_alert_callback = cb

def add_alert(msg):
    if global_alert_callback:
        try:
            global_alert_callback(msg)
        except Exception:
            pass

# ── Track Histories ───────────────────────────────────────────────────────────
track_history = defaultdict(lambda: {
    "ocr_buffer":         deque(maxlen=20),
    "locked_id":          None,
    "last_seen":          datetime.now(IST),
    "status_start_time":  0,
    "posture_buffer":     deque(maxlen=7),
    "feed_buffer":        deque(maxlen=7),
    "latest_features":    None,
    "latest_posture_conf": 0.0,
    "latest_feed_conf":   0.0,
})

person_track_history = defaultdict(lambda: {
    "face_names":             deque(maxlen=15),
    "last_unknown_sec_log":   0,
    "locked_name":            None,
})

track_history_lock = Lock()
csv_lock           = Lock()
easyocr_lock       = Lock()
chromadb_lock      = Lock()
cattle_model_lock  = Lock()
tag_model_lock     = Lock()
face_model_lock    = Lock()
posture_model_lock = Lock()
feed_model_lock    = Lock()

# ── Helpers ───────────────────────────────────────────────────────────────────
def clean_ocr_tag(raw_val):
    """
    Sanitizes raw OCR values to conform to the strict format:
    1st char: Capital letter, next 3 chars: Digits (e.g. B642).
    Corrects common OCR substitutions (like 8 for B, O for 0).
    """
    s = str(raw_val).upper().strip()
    s = re.sub(r"[^A-Z0-9]", "", s)
    if not s:
        return None
        
    if len(s) == 4:
        first = s[0]
        rest = s[1:]
        
        # Repair first char (should be letter)
        digit_to_alpha = {
            '0': 'D', '1': 'I', '2': 'Z', '3': 'E', '4': 'A', 
            '5': 'S', '6': 'G', '7': 'T', '8': 'B', '9': 'P'
        }
        if first.isdigit():
            first = digit_to_alpha.get(first, 'X')
            
        # Repair rest of chars (should be digits)
        alpha_to_digit = {
            'O': '0', 'I': '1', 'Z': '2', 'E': '3', 'A': '4', 
            'S': '5', 'G': '6', 'T': '7', 'B': '8', 'P': '9',
            'D': '0', 'L': '1'
        }
        new_rest = ""
        for char in rest:
            if char.isalpha():
                new_rest += alpha_to_digit.get(char, '0')
            else:
                new_rest += char
        rest = new_rest
        
        cleaned = first + rest
        if len(cleaned) == 4 and cleaned[0].isalpha() and cleaned[1:].isdigit():
            return cleaned

    # Fallback to pattern search
    match = re.search(r"[A-Z]\d{3}", s)
    if match:
        return match.group(0)
    return None

def find_closest_master_id(ocr_id, master_list):
    ocr_id = ocr_id.upper().strip()
    if len(ocr_id) != 4 or not ocr_id[0].isalpha() or not ocr_id[1:].isdigit():
        return None
    if ocr_id in master_list:
        return ocr_id
    best_match, max_matches = None, 0
    for m_id in master_list:
        m_id = m_id.upper().strip()
        if len(m_id) != 4:
            continue
        matches = sum(c1 == c2 for c1, c2 in zip(ocr_id, m_id))
        if matches > max_matches:
            max_matches, best_match = matches, m_id
    return best_match if max_matches >= 3 else None

def update_master_cattle_list(cattle_id):
    try:
        lines = []
        if os.path.exists(MASTER_CATTLE_LIST_FILE):
            with open(MASTER_CATTLE_LIST_FILE) as f:
                lines = [l.strip().upper() for l in f]
        if cattle_id.upper() not in lines:
            with open(MASTER_CATTLE_LIST_FILE, "a") as f:
                f.write(f"{cattle_id.upper()}\n")
        load_master_list()
    except Exception as e:
        print(f"[WARN] Failed to update master list: {e}")

def merge_temp_cattle_id(old_id, new_id):
    # 1. Update CSV database
    if os.path.exists(DATABASE_FILE):
        try:
            with csv_lock:
                df = pd.read_csv(DATABASE_FILE, on_bad_lines="skip")
                if "Entity_ID" in df.columns:
                    mask  = df["Entity_ID"].astype(str) == str(old_id)
                    count = mask.sum()
                    if count > 0:
                        df.loc[mask, "Entity_ID"] = str(new_id)
                        df.to_csv(DATABASE_FILE, index=False)
                        print(f"[MERGE] {count} CSV records: {old_id} -> {new_id}")
        except Exception as e:
            print(f"[WARN] CSV Merge error: {e}")
            
    # 2. Update ChromaDB database
    try:
        global behavior_collection
        if behavior_collection is not None:
            with chromadb_lock:
                res = behavior_collection.get(where={"cattle_id": str(old_id)})
                if res and res["ids"]:
                    for idx, doc_id in enumerate(res["ids"]):
                        orig_meta = res["metadatas"][idx]
                        orig_meta["cattle_id"] = str(new_id)
                        orig_meta["ear_tag"] = str(new_id)
                        behavior_collection.update(
                            ids=[doc_id],
                            metadatas=[orig_meta]
                        )
                    print(f"[MERGE] {len(res['ids'])} vector DB records: {old_id} -> {new_id}")
    except Exception as e:
        print(f"[WARN] ChromaDB merge error: {e}")

# ── ChromaDB Vector DB ────────────────────────────────────────────────────────
behavior_collection = None
try:
    import chromadb
    chroma_client = chromadb.PersistentClient(
        path=os.path.join(BASE_STORAGE, "Vector_DB")
    )
    behavior_collection = chroma_client.get_or_create_collection("cattle_behavior_memory")
    print("[OK] ChromaDB Vector DB ready.")
except ImportError:
    print("[WARN] ChromaDB not installed - skipping vector DB.")
except Exception as e:
    print(f"[WARN] ChromaDB init error: {e}")

# ── Behavior Classifiers ──────────────────────────────────────────────────────
MODEL_DIR    = os.path.join(SCRIPT_DIR, "models")

def _find_model(candidates):
    for name in candidates:
        p = os.path.join(MODEL_DIR, name)
        if os.path.exists(p):
            return p
    return None

POSTURE_MODEL_PATH = _find_model([
    "standing_and-lying.pt",
    "best_efficientnetv2s_standing_lying.pt",
])
FEED_MODEL_PATH = _find_model([
    "food_idle_behavior.pt",
    "best_efficientnetv2s_feed_idle.pt",
])
EAR_TAG_MODEL_PATH = _engine_or_pt(os.path.join("models", "ear_tag_model.pt"))

POSTURE_THRESHOLDS = {"Lying": 0.90, "Standing": 0.40}
FEED_THRESHOLDS    = {"Feeding_Behaviour": 0.50, "Idle_Behaviour": 0.50}
CONF_CATTLE        = 0.5
CONF_EAR           = 0.3

class BehaviorClassifier:
    def __init__(self, model_path, labels):
        self.model  = None
        self.labels = labels
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.transform = transforms.Compose([
            transforms.ToPILImage(),
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406],
                                  [0.229, 0.224, 0.225]),
        ])
        if model_path and os.path.exists(model_path):
            try:
                self.model = timm.create_model(
                    "efficientnetv2_rw_s", pretrained=False,
                    num_classes=len(labels)
                )
                state = torch.load(model_path, map_location=self.device)
                self.model.load_state_dict(state, strict=False)
                self.model.to(self.device).eval()
                print(f"[OK] Behavior model: {os.path.basename(model_path)} on {self.device}")
            except Exception as e:
                print(f"[WARN] Behavior model load failed: {e}")

    def predict(self, img_crop, thresholds=None):
        if self.model is None or img_crop.size == 0:
            return "Uncertain", 0.0, []
        try:
            t = self.transform(img_crop).unsqueeze(0).to(self.device)
            with torch.no_grad():
                out  = self.model(t)
                try:
                    features = self.model.forward_features(t).mean(dim=[2, 3]).cpu().numpy()[0].tolist()
                except Exception:
                    features = []
            probs = torch.softmax(out, dim=1).cpu().numpy()[0]
            idx   = int(np.argmax(probs))
            label = self.labels[idx]
            conf  = float(probs[idx])
            if thresholds and label in thresholds and conf < thresholds[label]:
                return "Uncertain", conf, features
            return label, conf, features
        except Exception:
            return "Uncertain", 0.0, []

# ── Load Global Models (shared across all camera pipelines) ───────────────────
print("[*] Loading global AI models...")
global_cattle_model = None
global_tag_model    = None

if CATTLE_MODEL_PATH:
    try:
        global_cattle_model = YOLO(CATTLE_MODEL_PATH, task="detect")
        print(f"[OK] Cattle model: {CATTLE_MODEL_PATH}")
    except Exception as e:
        print(f"[WARN] Cattle model failed: {e}")

if not global_cattle_model and FALLBACK_MODEL_PATH:
    try:
        global_cattle_model = YOLO(FALLBACK_MODEL_PATH, task="detect")
        print(f"[OK] Fallback cattle model: {FALLBACK_MODEL_PATH}")
    except Exception as e:
        print(f"[WARN] Fallback model failed: {e}")

if EAR_TAG_MODEL_PATH:
    try:
        global_tag_model = YOLO(EAR_TAG_MODEL_PATH, task="detect")
        print(f"[OK] Ear tag model: {EAR_TAG_MODEL_PATH}")
    except Exception as e:
        print(f"[WARN] Ear tag model failed: {e}")

global_posture_ai = BehaviorClassifier(POSTURE_MODEL_PATH, ["Lying", "Standing"])
global_feed_ai    = BehaviorClassifier(FEED_MODEL_PATH,    ["Feeding_Behaviour", "Idle_Behaviour"])

global_reader = None
try:
    _easyocr_gpu = torch.cuda.is_available()
    global_reader = easyocr.Reader(["en"], gpu=_easyocr_gpu, quantize=True)
    print(f"[OK] EasyOCR reader ready (gpu={_easyocr_gpu}).")
except Exception as e:
    print(f"[WARN] EasyOCR failed: {e}")

# ── IoU Tracker ───────────────────────────────────────────────────────────────
class SimpleIoUTracker:
    def __init__(self, max_lost=30):
        self.next_id  = 1
        self.tracks   = {}
        self.max_lost = max_lost

    def update(self, dets):
        updated = {}
        matched = set()
        for tid, info in self.tracks.items():
            best_iou, best_idx = 0.0, -1
            for i, d in enumerate(dets):
                if i in matched:
                    continue
                iou = self._iou(info["box"][:4], d[:4])
                if iou > best_iou:
                    best_iou, best_idx = iou, i
            if best_iou > 0.15:
                updated[tid] = {"box": dets[best_idx], "lost": 0}
                matched.add(best_idx)
            else:
                lost = info["lost"] + 1
                if lost <= self.max_lost:
                    updated[tid] = {"box": info["box"], "lost": lost}
        for i, d in enumerate(dets):
            if i not in matched:
                updated[self.next_id] = {"box": d, "lost": 0}
                self.next_id += 1
        self.tracks = updated
        return [info["box"] + [tid] for tid, info in self.tracks.items() if info["lost"] == 0]

    def _iou(self, A, B):
        xA = max(A[0], B[0]); yA = max(A[1], B[1])
        xB = min(A[2], B[2]); yB = min(A[3], B[3])
        inter = max(0, xB - xA) * max(0, yB - yA)
        aA    = (A[2] - A[0]) * (A[3] - A[1])
        aB    = (B[2] - B[0]) * (B[3] - B[1])
        return inter / (aA + aB - inter + 1e-6)

def draw_sync_dashboard(frame):
    status_file = os.path.join(BASE_STORAGE, "kisan_sync_status.json")
    status_text = "Kisan CattleVision | Edge AI Running"
    color       = (255, 255, 255)
    if os.path.exists(status_file):
        try:
            with open(status_file) as f:
                data   = json.load(f)
                st     = data.get("status", "Unknown")
                ts     = data.get("timestamp", "")
                status_text = f"HPC SYNC: {st} ({ts})"
                color = (0, 255, 0) if st == "Success" else (0, 200, 255)
        except Exception:
            pass
    cv2.putText(frame, status_text, (20, 50), 0, 0.7, (0, 0, 0), 4)
    cv2.putText(frame, status_text, (20, 50), 0, 0.7, color, 2)

def save_training_crop(cow_crop, locked_id, posture, feeding, posture_conf, feed_conf, cam_id, is_stable, type_flag):
    """
    Saves the training crop and corresponding label JSON under Sync_Staging/Crops/
    for automated MLOps continuous learning.
    """
    try:
        crops_dir = os.path.join(BASE_STORAGE, "Sync_Staging", "Crops")
        os.makedirs(crops_dir, exist_ok=True)
        
        timestamp_int = int(time.time())
        filename_base = f"{locked_id}_{timestamp_int}_{type_flag}"
        crop_path = os.path.join(crops_dir, f"{filename_base}.jpg")
        meta_path = os.path.join(crops_dir, f"{filename_base}.json")
        
        # Write image crop
        cv2.imwrite(crop_path, cow_crop)
        
        # Write metadata JSON
        import json
        with open(meta_path, "w") as f:
            json.dump({
                "cattle_id": locked_id,
                "posture": posture,
                "feeding": feeding,
                "posture_confidence": round(posture_conf, 3),
                "feeding_confidence": round(feed_conf, 3),
                "camera_id": cam_id,
                "timestamp": timestamp_int,
                "is_stable": is_stable,
                "type": type_flag
            }, f)
        print(f"📦 [MLOPS CROP SAVED] Saved crop for {locked_id} -> {type_flag}")
    except Exception as e:
        print(f"[WARN] Failed to save training crop: {e}")

# ── GenZProcessor ─────────────────────────────────────────────────────────────
class GenZProcessor:
    def __init__(self, cam_id, behavior_collection_obj=behavior_collection):
        self.cam_id   = cam_id
        self.device   = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.cattle_model       = global_cattle_model
        self.tag_model          = global_tag_model
        self.posture_ai         = global_posture_ai
        self.feed_ai            = global_feed_ai
        self.reader             = global_reader
        self.behavior_collection = behavior_collection_obj
        self.tracker            = SimpleIoUTracker(max_lost=45)
        _reid_device = "cuda" if torch.cuda.is_available() else "cpu"
        from Genz_person_reid import GenzPersonReIDManager
        self.reid_manager = GenzPersonReIDManager(
            script_dir=SCRIPT_DIR,
            base_storage=BASE_STORAGE,
            face_backbone=_face_backbone,
            face_yolo=face_yolo,
            device=_reid_device
        )
        self.lock               = Lock()
        self.current_cows_count    = 0
        self.current_persons_count = 0

    def process(self, frame: np.ndarray):
        if frame is None:
            return frame

        h_orig, w_orig = frame.shape[:2]
        scale     = 640.0 / w_orig
        h_new     = int(h_orig * scale)
        small_frm = cv2.resize(frame, (640, h_new), interpolation=cv2.INTER_LINEAR)
        now_time  = time.time()

        raw_dets       = []
        cattle_cls_ids = [19]
        person_cls_ids = [0]

        # 1. Run Cattle Detection
        if self.cattle_model is not None:
            try:
                with cattle_model_lock:
                    for cid, cname in self.cattle_model.names.items():
                        n = cname.lower()
                        if "cow" in n or "cattle" in n:
                            cattle_cls_ids = [cid]
                    results = self.cattle_model(
                        small_frm, conf=CONF_CATTLE,
                        classes=cattle_cls_ids, verbose=False, device=0 if torch.cuda.is_available() else "cpu",
                        max_det=20
                    )[0]
                if results.boxes is not None:
                    for box, cls_id, conf in zip(
                        results.boxes.xyxy.cpu().numpy(),
                        results.boxes.cls.cpu().numpy().astype(int),
                        results.boxes.conf.cpu().numpy(),
                    ):
                        raw_dets.append(box.tolist() + [int(cls_id), float(conf)])
            except Exception as e:
                print(f"[WARN] Cattle detection error: {e}")

        # 2. Run Face Detection (track faces directly)
        if face_yolo is not None:
            try:
                with face_model_lock:
                    rf = face_yolo(small_frm, conf=0.55, verbose=False, device=0 if torch.cuda.is_available() else "cpu", max_det=5)[0]
                if rf.boxes is not None:
                    for fb, fc in zip(
                        rf.boxes.xyxy.cpu().numpy(),
                        rf.boxes.conf.cpu().numpy(),
                    ):
                        raw_dets.append(fb.tolist() + [0, float(fc)])
            except Exception as e:
                print(f"[WARN] Face detection error: {e}")

        # Track active keys before update to catch lost tracks
        active_before = set(self.tracker.tracks.keys())
        
        tracked = self.tracker.update(raw_dets)
        
        # Identify newly lost tracks for clothing profile caching
        active_after = set(self.tracker.tracks.keys())
        for lost_tid in (active_before - active_after):
            self.reid_manager.track_lost(lost_tid)

        tracked_cows = []
        persons_count = 0

        for det in tracked:
            x1, y1, x2, y2, cls_id, conf, tid = det
            x1o = int(x1 / scale); y1o = int(y1 / scale)
            x2o = int(x2 / scale); y2o = int(y2 / scale)

            if cls_id in cattle_cls_ids:
                tracked_cows.append([x1o, y1o, x2o, y2o, tid])
            elif cls_id in person_cls_ids:
                persons_count += 1
                self._process_person(frame, x1o, y1o, x2o, y2o, tid, conf)

        # ── Per-Cow Processing ────────────────────────────────────────────────
        for cow in tracked_cows:
            self._process_cow(frame, cow, now_time)

        with self.lock:
            self.current_cows_count    = len(tracked_cows)
            self.current_persons_count = persons_count

        draw_sync_dashboard(frame)
        return frame

    # ── Person / Face Re-id ───────────────────────────────────────────────────
    def _process_person(self, frame, x1, y1, x2, y2, tid, conf):
        h_frm, w_frm = frame.shape[:2]
        h_face = y2 - y1; w_face = x2 - x1
        fpy1 = max(0, int(y1 - 0.20 * h_face))
        fpy2 = min(h_frm, int(y2 + 0.10 * h_face))
        fpx1 = max(0, int(x1 - 0.10 * w_face))
        fpx2 = min(w_frm, int(x2 + 0.10 * w_face))
        face_crop = frame[fpy1:fpy2, fpx1:fpx2]
        
        by1 = max(0, int(y1 - 0.5 * h_face))
        by2 = min(h_frm, int(y2 + 5.0 * h_face))
        bx1 = max(0, int(x1 - 1.5 * w_face))
        bx2 = min(w_frm, int(x2 + 1.5 * w_face))
        body_crop = frame[by1:by2, bx1:bx2]

        p_hist = self.reid_manager.active_tracks[tid]
        identified_name = self.reid_manager.identify_person_track(tid, p_hist, face_crop, body_crop)
        display_name = self.reid_manager.clean_member_name(identified_name)

        if identified_name and identified_name not in ("Analyzing...", "PERSON"):
            if not identified_name.upper().startswith("UNK_") and not identified_name.upper().startswith("UNKNOWN"):
                cleaned = clean_member_name(identified_name)
                if should_greet_today(identified_name):
                    pipeline_audio.speak(f"Welcome {cleaned}")
                now_t = time.time()
                if now_t - p_hist.get("last_reg_log_time", 0) > 900:
                    p_hist["last_reg_log_time"] = now_t
                    try:
                        now_dt = datetime.now()
                        with open(ATTENDANCE_LOG, "a", newline="") as f_csv:
                            csv.writer(f_csv).writerow([
                                cleaned, now_dt.strftime("%Y-%m-%d"),
                                now_dt.strftime("%H:%M:%S"), "Worker",
                                f"{self.cam_id}_{tid}"
                            ])
                    except Exception:
                        pass
            else:
                now_t = time.time()
                if now_t - p_hist.get("last_unk_sec_log", 0) > 30:
                    p_hist["last_unk_sec_log"] = now_t
                    
                    face_to_save = face_crop if (face_crop is not None and face_crop.size > 100) else body_crop
                    if face_to_save is not None and face_to_save.size > 100:
                        now_dt      = datetime.now()
                        date_str    = now_dt.strftime("%Y-%m-%d")
                        time_str    = now_dt.strftime("%H:%M:%S")
                        time_f_str  = now_dt.strftime("%H-%M-%S")
                        img_name    = f"{display_name.replace(' ', '_')}_{date_str}_{time_f_str}.jpg"
                        img_path    = os.path.join(UNKNOWN_FACES_DIR, img_name)
                        cv2.imwrite(img_path, face_to_save)
                        try:
                            with open(ATTENDANCE_LOG, "a", newline="") as f_csv:
                                csv.writer(f_csv).writerow([
                                    display_name, date_str, time_str,
                                    "Alert", f"{self.cam_id}_{tid}"
                                ])
                        except Exception:
                            pass
                        farmer_phone = str(CONFIG_RAW.get("phone", "9876543210"))
                        add_alert({
                            "category": "FARM SECURITY",
                            "message": f"Unauthorized unknown person detected! ID: {display_name}.",
                            "severity": "high",
                            "photo_url": f"/static/unknown_faces/{img_name}",
                            "image": f"/static/unknown_faces/{img_name}",
                            "image_url": f"/static/unknown_faces/{img_name}",
                            "unknown_person_id": display_name,
                            "person_id": display_name,
                            "track_id": display_name,
                            "phone": farmer_phone,
                        })

        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 100), 2)
        label_str = f"{display_name} | {conf*100:.1f}%"
        fs = 0.9; th = 2
        (tw, thi), _ = cv2.getTextSize(label_str, cv2.FONT_HERSHEY_SIMPLEX, fs, th)
        cv2.rectangle(frame, (x1-2, max(0, y1-thi-18)), (x1+tw+10, y1), (0, 255, 100), -1)
        cv2.putText(frame, label_str, (x1+5, max(8, y1-8)),
                    cv2.FONT_HERSHEY_SIMPLEX, fs, (0, 0, 0), th, cv2.LINE_AA)

    # ── Cattle Processing ─────────────────────────────────────────────────────
    def _process_cow(self, frame, cow, now_time):
        load_master_list()
        x1, y1, x2, y2, tid = cow
        track_key = (self.cam_id, tid)

        with track_history_lock:
            hist = track_history[track_key]

        cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 0, 0), 2)
        cow_crop = frame[max(0,y1):min(frame.shape[0],y2),
                         max(0,x1):min(frame.shape[1],x2)]
        if cow_crop.size < 100:
            return

        raw_posture, p_conf, p_feat = "Uncertain", 0.0, []
        raw_feeding, f_conf, f_feat = "Uncertain", 0.0, []

        if self.posture_ai:
            try:
                with posture_model_lock:
                    raw_posture, p_conf, p_feat = self.posture_ai.predict(cow_crop)
                w_box = x2 - x1; h_box = y2 - y1
                if h_box > 0:
                    ar = float(w_box) / float(h_box)
                    if ar < 0.85:
                        raw_posture, p_conf = "Standing", 0.98
                    elif ar > 1.30:
                        raw_posture, p_conf = "Lying",    0.98
                if raw_posture in POSTURE_THRESHOLDS and p_conf < POSTURE_THRESHOLDS[raw_posture]:
                    raw_posture = "Uncertain"
            except Exception as e:
                print(f"[WARN] Posture error: {e}")

        if self.feed_ai:
            try:
                with feed_model_lock:
                    raw_feeding, f_conf, f_feat = self.feed_ai.predict(cow_crop, FEED_THRESHOLDS)
            except Exception:
                pass

        with track_history_lock:
            hist["posture_buffer"].append(raw_posture)
            hist["feed_buffer"].append(raw_feeding)
            hist["latest_posture_conf"] = p_conf
            hist["latest_feed_conf"]    = f_conf
            if p_feat or f_feat:
                base = p_feat if (p_feat and p_conf > 0.6) else f_feat
                if base:
                    ar  = float(max(1, x2-x1)) / float(max(1, y2-y1))
                    area = float((x2-x1)*(y2-y1)) / float(frame.shape[1]*frame.shape[0])
                    t_n = (datetime.now(IST).hour + datetime.now(IST).minute/60.0) / 24.0
                    raw_feat = base + [ar, area, p_conf, f_conf, t_n,
                                       1.0 if raw_posture=="Standing" else 0.0,
                                       1.0 if raw_feeding=="Feeding_Behaviour" else 0.0]
                    feat_arr = np.array(raw_feat, dtype=np.float32)
                    feat_norm = np.linalg.norm(feat_arr)
                    if feat_norm > 1e-6:
                        feat_arr = feat_arr / feat_norm
                    hist["latest_features"] = feat_arr.tolist()

        with track_history_lock:
            posture   = Counter(hist["posture_buffer"]).most_common(1)[0][0] if hist["posture_buffer"] else "Uncertain"
            feeding   = Counter(hist["feed_buffer"]).most_common(1)[0][0]   if hist["feed_buffer"]   else "Uncertain"
            locked_id = hist["locked_id"]

        # ── 1.4 Dynamic Visual Drift Verification Check (Disabled - Once permanent ID is fixed, do not re-verify) ──
        pass

        # ── 1.5 Cattle Re-identification based on Vector DB features (if ID is not yet locked) ──
        if not locked_id and self.behavior_collection is not None and hist.get("latest_features") is not None:
            last_reid = hist.get("last_reid_time", 0)
            if now_time - last_reid > 3.0:
                hist["last_reid_time"] = now_time
                try:
                    with chromadb_lock:
                        past_results = self.behavior_collection.query(
                            query_embeddings=[hist["latest_features"]],
                            n_results=3
                        )
                    if past_results and "distances" in past_results and past_results["distances"][0]:
                        best_dist = past_results["distances"][0][0]
                        best_metadata = past_results["metadatas"][0][0]
                        matched_cow_id = best_metadata.get("cattle_id")
                        
                        if best_dist < 1.8 and matched_cow_id:
                            if matched_cow_id in MASTER_CATTLE_LIST:
                                old_locked_id = None
                                with track_history_lock:
                                    old_locked_id = hist["locked_id"]
                                    hist["locked_id"] = matched_cow_id
                                    locked_id = matched_cow_id
                                print(f"🔍 [RE-ID SUCCESS] Cow {locked_id} identified via Vector DB! Distance: {best_dist}")
                                if old_locked_id is None:
                                    Thread(target=merge_temp_cattle_id,
                                           args=(f"Analysing_{tid}", locked_id),
                                           daemon=True).start()
                except Exception:
                    pass

        # ── Ear Tag OCR ───────────────────────────────────────────────────────
        if self.tag_model is not None:
            last_ocr = hist.get("last_ocr_time", 0)
            run_ocr  = (not locked_id and now_time - last_ocr > 0.5)
            if run_ocr:
                hist["last_ocr_time"] = now_time
                try:
                    with tag_model_lock:
                        tag_res = self.tag_model(cow_crop, conf=CONF_EAR, verbose=False, device=0 if torch.cuda.is_available() else "cpu", max_det=5)[0]
                    best_tb = None
                    if tag_res.boxes is not None:
                        for tb in tag_res.boxes:
                            if best_tb is None or tb.conf[0] > best_tb.conf[0]:
                                best_tb = tb
                    if best_tb is not None:
                        tx1, ty1, tx2, ty2 = map(int, best_tb.xyxy[0])
                        t_conf = float(best_tb.conf[0])
                        hist["last_ear_box"] = [tx1, ty1, tx2, ty2, t_conf]
                        tag_img = cow_crop[ty1:ty2, tx1:tx2]
                        if tag_img.size > 0:
                            gray = cv2.resize(cv2.cvtColor(tag_img, cv2.COLOR_BGR2GRAY), None, fx=2, fy=2)
                            with easyocr_lock:
                                ocr_raw = self.reader.readtext(gray, allowlist="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") if self.reader else []
                            if ocr_raw:
                                raw_val = re.sub(r"[^A-Za-z0-9]", "", ocr_raw[0][1]).upper().strip()
                                hist["last_ocr_val"] = raw_val
                                tag_val = clean_ocr_tag(raw_val)
                                if tag_val:
                                    corrected = find_closest_master_id(tag_val, MASTER_CATTLE_LIST)
                                    if corrected:
                                        hist["ocr_buffer"].append(corrected)
                                        best = Counter(hist["ocr_buffer"]).most_common(1)
                                        if best and best[0][1] >= 3:
                                            old_lock = hist["locked_id"]
                                            hist["locked_id"] = best[0][0]
                                            locked_id         = hist["locked_id"]
                                            if old_lock is None:
                                                Thread(target=merge_temp_cattle_id,
                                                       args=(f"Analysing_{tid}", locked_id),
                                                       daemon=True).start()
                                            elif old_lock != locked_id:
                                                print(f"🔄 [DYNAMIC CORRECTION] Swapping misidentified ID {old_lock} -> {locked_id} for track {tid}!")
                                                Thread(target=merge_temp_cattle_id,
                                                       args=(old_lock, locked_id),
                                                       daemon=True).start()
                except Exception as e:
                    print(f"[WARN] OCR error: {e}")

        current_id = locked_id if locked_id else f"Analysing_{tid}"

        # ── CSV Logging & Vector DB ───────────────────────────────────────────
        should_log = False
        if now_time - hist["status_start_time"] > 60:
            hist["status_start_time"] = now_time
            should_log = True

        if should_log and (posture != "Uncertain" or feeding != "Uncertain"):
            try:
                df = pd.DataFrame({
                    "Timestamp":  [datetime.now(IST).strftime("%d-%m-%Y %I:%M:%S %p")],
                    "Camera_ID":  [self.cam_id],
                    "Entity_ID":  [current_id],
                    "Posture":    [posture],
                    "Feeding":    [feeding],
                    "Duration_Sec": [60],
                })
                with csv_lock:
                    df.to_csv(DATABASE_FILE, mode="a",
                               header=not os.path.exists(DATABASE_FILE), index=False)
            except Exception as e:
                print(f"[WARN] CSV log error: {e}")

            # ── Adaptive Health Alert ─────────────────────────────────────────
            if locked_id:
                try:
                    eval_res   = evaluate_current_behavior(locked_id)
                    risk_score = eval_res.get("risk_score", 0)
                    status     = eval_res.get("status", "Healthy")
                    last_alert = hist.get("last_adaptive_alert_time", 0)
                    if (now_time - last_alert > 1200) and risk_score >= 41:
                        hist["last_adaptive_alert_time"] = now_time
                        devs = eval_res.get("deviations", {})
                        sev  = "high" if risk_score >= 61 else "warning"
                        add_alert({
                            "category": "CATTLE MONITORING",
                            "message":  f"Cattle {locked_id} health anomaly. Risk: {status} ({risk_score}/100). "
                                        f"Appetite drop: {devs.get('feeding_drop',0)}%, "
                                        f"Idle increase: {devs.get('idle_increase',0)}%.",
                            "severity": sev,
                        })
                        msg = (f"⚠️ *Adaptive Health Alert*\n\n"
                               f"🐄 *Cow ID:* `{locked_id}`\n"
                               f"🔴 *Status:* {status} ({risk_score}/100)")
                        Thread(target=send_telegram, args=(msg,), daemon=True).start()
                except Exception as e:
                    print(f"[WARN] Adaptive alert error: {e}")

            # ── Vector DB Anomaly & Log ───────────────────────────────────────
            with track_history_lock:
                latest_features = hist.get("latest_features")
                latest_posture_conf = hist.get("latest_posture_conf", 0.0)
                latest_feed_conf = hist.get("latest_feed_conf", 0.0)

            if self.behavior_collection and latest_features and current_id:
                timestamp_int = int(time.time())
                db_id = f"{current_id}_{datetime.now(IST).strftime('%Y%m%d_%H%M%S')}"
                anomaly_score_val = 0.0
                try:
                    with chromadb_lock:
                        past_results = self.behavior_collection.query(
                            query_embeddings=[latest_features],
                            n_results=5,
                            where={"cattle_id": current_id}
                        )
                    if past_results and "distances" in past_results and past_results["distances"][0]:
                        raw_dist = sum(past_results["distances"][0]) / len(past_results["distances"][0])
                        # Handle both normalized (0..2) and legacy unnormalized distances safely
                        if raw_dist > 10.0:
                            import math
                            norm_dist = min(2.0, math.log10(raw_dist) / 5.0)
                        else:
                            norm_dist = min(2.0, float(raw_dist))

                        deviation_pct = int(round(min(100.0, (norm_dist / 1.5) * 100.0)))
                        anomaly_score_val = round(norm_dist, 2)

                        # Only alert on anomaly for locked/identified cows to prevent temporary ID noise
                        if deviation_pct >= 60 and locked_id:
                            severity_label = "High Risk" if deviation_pct >= 80 else "Moderate Risk"
                            print(f"⚠️ ANOMALY DETECTED for Cow {locked_id}! Deviation: {deviation_pct}%")
                            
                            farmer_msg = (
                                f"Cattle {locked_id}: Abnormal behavior activity detected ({deviation_pct}% deviation). "
                                f"Posture: {posture}, Feeding: {feeding} on camera {self.cam_id}."
                            )
                            telegram_msg = (
                                f"⚠️ *Kisan Pro AI Behavior Alert*\n\n"
                                f"🐄 *Cattle ID:* `{locked_id}`\n"
                                f"📡 *Camera:* `{self.cam_id}`\n"
                                f"🔴 *Behavior Deviation:* `{deviation_pct}%` ({severity_label})\n"
                                f"🛌 *Posture:* `{posture}`\n"
                                f"🌾 *Feeding:* `{feeding}`\n\n"
                                f"💡 *Farmer Advice:* Please check cattle in person for signs of discomfort or unusual behavior."
                            )
                            Thread(target=send_telegram, args=(telegram_msg,), daemon=True).start()
                            add_alert({
                                "category": "CATTLE MONITORING",
                                "message": farmer_msg,
                                "severity": "high" if deviation_pct >= 80 else "warning"
                            })
                except Exception as e:
                    print(f"ChromaDB Query Error: {e}")

                try:
                    with chromadb_lock:
                        self.behavior_collection.add(
                            ids=[db_id],
                            embeddings=[latest_features],
                            metadatas=[{
                                "cattle_id": current_id,
                                "posture": posture,
                                "feeding": feeding,
                                "ear_tag": current_id,
                                "posture_confidence": round(latest_posture_conf, 2),
                                "feeding_confidence": round(latest_feed_conf, 2),
                                "camera_ip": self.cam_id,
                                "timestamp": timestamp_int,
                                "anomaly_score": anomaly_score_val
                            }]
                        )
                    print(f"🟢 [VECTOR DB] Logged Cow {current_id} | Behavior Deviation: {deviation_pct}%")

                    # --- MLOps Crop Exporter (Temporal Consistency & Active Learning) ---
                    if cow_crop is not None and cow_crop.size > 0:
                        posture_buffer = list(hist.get("posture_buffer", []))
                        feed_buffer = list(hist.get("feed_buffer", []))
                        
                        stable_posture = (len(posture_buffer) >= 30 and len(set(posture_buffer[-30:])) == 1 and posture_buffer[-1] != "Uncertain")
                        stable_feed = (len(feed_buffer) >= 30 and len(set(feed_buffer[-30:])) == 1 and feed_buffer[-1] != "Uncertain")
                        
                        is_pseudo = False
                        is_active = False
                        type_flag = ""
                        
                        if (stable_posture and latest_posture_conf > 0.98) or (stable_feed and latest_feed_conf > 0.98):
                            is_pseudo = True
                            type_flag = "pseudo_label"
                        elif (0.40 <= latest_posture_conf <= 0.70 and posture != "Uncertain") or (0.40 <= latest_feed_conf <= 0.70 and feeding != "Uncertain"):
                            is_active = True
                            type_flag = "active_learning"
                            
                        if is_pseudo or is_active:
                            save_training_crop(
                                cow_crop=cow_crop,
                                locked_id=locked_id,
                                posture=posture,
                                feeding=feeding,
                                posture_conf=latest_posture_conf,
                                feed_conf=latest_feed_conf,
                                cam_id=self.cam_id,
                                is_stable=(stable_posture or stable_feed),
                                type_flag=type_flag
                            )
                except Exception as e:
                    print(f"🔴 [VECTOR DB / CROP ERROR]: {e}")

        # ── Visual Overlay ────────────────────────────────────────────────────
        c = (0, 255, 255) if locked_id else (200, 200, 200)
        cv2.putText(frame, f"ID: {current_id}",       (x1, y1-35), 0, 1.0, c, 3)
        cv2.putText(frame, f"{posture} | {feeding}",  (x1, y1-10), 0, 0.9, (0, 255, 0), 3)

        cached_box = hist.get("last_ear_box")
        cached_ocr = hist.get("last_ocr_val")
        if cached_box:
            cx1, cy1, cx2, cy2, c_conf = cached_box
            fx1 = x1+cx1; fy1 = y1+cy1; fx2 = x1+cx2; fy2 = y1+cy2
            fh, fw = frame.shape[:2]
            fx1, fy1 = max(0, fx1), max(0, fy1)
            fx2, fy2 = min(fw, fx2), min(fh, fy2)
            cv2.rectangle(frame, (fx1, fy1), (fx2, fy2), (255, 100, 0), 2)
            if cached_ocr:
                cv2.putText(frame, f"OCR: {cached_ocr}", (fx1+3, min(fh-3, fy2+13)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

    def get_summary_status(self):
        with self.lock:
            keys = [k for k in track_history if k[0] == self.cam_id]
            if not keys:
                return "Uncertain", "Uncertain", "Uncertain", 0.0
            keys.sort(key=lambda k: track_history[k]["last_seen"], reverse=True)
            hist     = track_history[keys[0]]
            posture  = Counter(hist["posture_buffer"]).most_common(1)[0][0] if hist["posture_buffer"] else "Uncertain"
            feeding  = Counter(hist["feed_buffer"]).most_common(1)[0][0]   if hist["feed_buffer"]   else "Uncertain"
            lock_id  = hist["locked_id"]

            anomaly_score = 0.0
            if lock_id and self.behavior_collection and hist.get("latest_features") is not None:
                try:
                    with chromadb_lock:
                        past_results = self.behavior_collection.query(
                            query_embeddings=[hist["latest_features"]],
                            n_results=1,
                            where={"cattle_id": lock_id}
                        )
                    if past_results and "distances" in past_results and past_results["distances"][0]:
                        anomaly_score = float(past_results["distances"][0][0])
                except Exception:
                    pass
            return posture, feeding, lock_id or "Uncertain", anomaly_score

    def get_counts(self):
        with self.lock:
            return self.current_cows_count, self.current_persons_count
