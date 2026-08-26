import os
import cv2
import torch
import numpy as np
import pickle
import json
import time
from datetime import datetime
from collections import deque, Counter, defaultdict
from threading import Lock

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


class GenzPersonReIDManager:
    def __init__(self, script_dir, base_storage, face_backbone=None, face_yolo=None, device="cpu"):
        self.script_dir = script_dir
        self.base_storage = base_storage
        self.face_backbone = face_backbone
        self.face_yolo = face_yolo
        self.device = torch.device(device)
        self.lock = Lock()
        
        # Files
        self.embeddings_dir = os.path.join(self.script_dir, "embeddings")
        self.known_emb_file = os.path.join(self.embeddings_dir, "known_embeddings.pkl")
        self.known_roles_file = os.path.join(self.embeddings_dir, "member_roles.json")
        self.unknown_emb_file = os.path.join(self.base_storage, "unknown_embeddings.pkl")
        self.attendance_log = os.path.join(self.base_storage, "farm_attendance_log.csv")
        self.unknown_faces_dir = os.path.join(self.script_dir, "static", "unknown_faces")
        
        os.makedirs(self.embeddings_dir, exist_ok=True)
        os.makedirs(self.base_storage, exist_ok=True)
        os.makedirs(self.unknown_faces_dir, exist_ok=True)
        
        # In-Memory Stores
        self.known_people = {}
        self.unknown_people = {}
        self.last_known_mtime = 0.0
        self.last_unknown_mtime = 0.0
        
        # Load Databases
        self.reload_known_db()
        self.reload_unknown_db()
        
        # Track Databases
        self.tracker = SimpleIoUTracker(max_lost=45)
        self.active_tracks = defaultdict(lambda: {
            "face_names": deque(maxlen=15),
            "locked_name": None,
            "clothing_hist": None,
            "last_seen": time.time(),
            "last_reg_log_time": 0.0,
            "last_unk_sec_log": 0.0,
            "face_similarity_history": [],
            "frames_since_face": 0
        })
        
        # Lost Tracks Cache for Re-entry (keeps track of recently lost tracks for 15 seconds)
        self.lost_tracks = {} # tid -> { locked_name, clothing_hist, timestamp }
        
        # Face Normalization Transforms
        try:
            from torchvision import transforms as T
            self.face_norm = T.Compose([
                T.ToTensor(),
                T.Lambda(lambda x: (x * 255.0 - 127.5) / 128.0),
            ])
        except ImportError:
            self.face_norm = None

    def reload_known_db(self):
        if not os.path.exists(self.known_emb_file):
            return
        try:
            mtime = os.path.getmtime(self.known_emb_file)
            if mtime > self.last_known_mtime:
                with open(self.known_emb_file, "rb") as f:
                    data = pickle.load(f)
                with self.lock:
                    if "templates" in data:
                        self.known_people = {name: {"mean": emb} for name, emb in data["templates"].items()}
                    elif "people" in data:
                        self.known_people = data.get("people", {})
                    else:
                        self.known_people = {name: {"mean": emb} for name, emb in data.items()}
                self.last_known_mtime = mtime
                print(f"[GenzReID] Loaded {len(self.known_people)} known templates.")
        except Exception as e:
            print(f"[GenzReID] Error loading known database: {e}")

    def reload_unknown_db(self):
        if not os.path.exists(self.unknown_emb_file):
            return
        try:
            mtime = os.path.getmtime(self.unknown_emb_file)
            if mtime > self.last_unknown_mtime:
                with open(self.unknown_emb_file, "rb") as f:
                    data = pickle.load(f)
                with self.lock:
                    self.unknown_people = data.get("people", {})
                self.last_unknown_mtime = mtime
                print(f"[GenzReID] Loaded {len(self.unknown_people)} unknown templates.")
        except Exception as e:
            print(f"[GenzReID] Error loading unknown database: {e}")

    def save_unknown_db(self):
        try:
            with open(self.unknown_emb_file, "wb") as f:
                pickle.dump({"people": self.unknown_people}, f)
            self.last_unknown_mtime = os.path.getmtime(self.unknown_emb_file)
        except Exception as e:
            print(f"[GenzReID] Error saving unknown database: {e}")

    def get_clothing_histogram(self, body_crop):
        """Computes a multi-region HSV color histogram to profile a person's clothing."""
        if body_crop is None or body_crop.size == 0:
            return None
        try:
            h, w = body_crop.shape[:2]
            # Divide vertically into upper body (60%) and lower body (40%)
            split_y = int(h * 0.6)
            upper_crop = body_crop[0:split_y, 0:w]
            lower_crop = body_crop[split_y:h, 0:w]
            
            hists = []
            for crop in [upper_crop, lower_crop]:
                if crop.size == 0:
                    continue
                hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
                # Compute 3D HSV histogram: 8 Hue bins, 4 Saturation bins, 4 Value bins
                hist = cv2.calcHist([hsv], [0, 1, 2], None, [8, 4, 4], [0, 180, 0, 256, 0, 256])
                cv2.normalize(hist, hist)
                hists.append(hist.flatten())
                
            if len(hists) == 2:
                return np.concatenate(hists)
            elif len(hists) == 1:
                return np.concatenate([hists[0], hists[0]])
            return None
        except Exception as e:
            return None

    def match_clothing(self, hist1, hist2):
        if hist1 is None or hist2 is None:
            return 0.0
        try:
            # Compute correlation: higher is more similar (1.0 = perfect match)
            return float(cv2.compareHist(
                hist1.astype(np.float32), 
                hist2.astype(np.float32), 
                cv2.HISTCMP_CORREL
            ))
        except Exception:
            return 0.0

    def face_to_embedding(self, face_bgr):
        if self.face_backbone is None or face_bgr is None or face_bgr.size == 0:
            return None
        try:
            face_rgb = cv2.cvtColor(face_bgr, cv2.COLOR_BGR2RGB)
            face_resized = cv2.resize(face_rgb, (160, 160))
            from PIL import Image
            face_pil = Image.fromarray(face_resized)
            tensor = self.face_norm(face_pil).unsqueeze(0).to(self.device)
            with torch.no_grad():
                emb = self.face_backbone(tensor)
                emb = emb / torch.norm(emb, p=2, dim=1, keepdim=True)
            return emb[0].cpu().numpy()
        except Exception as e:
            print(f"[GenzReID] Face embed error: {e}")
            return None

    def get_matches(self, emb):
        if emb is None:
            return (None, 0.0), (None, 0.0), (None, 0.0)
            
        # 1. Match Knowns
        (best_k, k_sim), (_, k_sec_sim) = self._get_best_matches_dict(emb, self.known_people)
        
        # 2. Match Unknowns
        (best_u, u_sim), _ = self._get_best_matches_dict(emb, self.unknown_people)
        
        return (best_k, k_sim), (best_u, u_sim), k_sec_sim

    def _get_best_matches_dict(self, emb, people_dict):
        if not people_dict:
            return (None, 0.0), (None, 0.0)
        matches = []
        for name, data in people_dict.items():
            mean_emb = data.get("mean")
            if mean_emb is not None:
                sim = float(np.dot(emb, mean_emb))
                matches.append((name, sim))
        matches.sort(key=lambda x: x[1], reverse=True)
        best = matches[0] if matches else (None, 0.0)
        sec  = matches[1] if len(matches) > 1 else (None, 0.0)
        return best, sec

    def clean_member_name(self, name):
        if not name:
            return name
        name_upper = name.upper()
        if name_upper.startswith("UNK_") or name_upper.startswith("UNKNOWN"):
            parts = name.split("_")
            if len(parts) >= 3 and parts[-1].lower().startswith("v") and parts[-1][1:].isdigit():
                return "_".join(parts[:-1]).replace("_", " ")
            return name.replace("_", " ")
        parts = name.split("_")
        return parts[0]

    def _assign_next_sequential_unknown_id(self, emb):
        with self.lock:
            existing_ids = set()
            for k in self.unknown_people.keys():
                base = k.rsplit("_v", 1)[0] # e.g. UNK_001_v1 -> UNK_001
                if base.startswith("UNK_"):
                    try:
                        num = int(base.split("_")[1])
                        existing_ids.add(num)
                    except (IndexError, ValueError):
                        pass
            next_num = 1
            while next_num in existing_ids:
                next_num += 1
            new_name = f"UNK_{next_num:03d}"
            
            # Register first template
            self.unknown_people[f"{new_name}_v1"] = {"mean": emb}
            self.save_unknown_db()
            print(f"[GenzReID] Registered and saved new unknown: {new_name}_v1")
            return new_name

    def identify_person_track(self, tid, p_hist, face_crop, body_crop):
        """Redesigned hybrid re-identification logic: Face + Clothing."""
        # 1. Update Clothing Profile
        new_hist = self.get_clothing_histogram(body_crop)
        if new_hist is not None:
            p_hist["clothing_hist"] = new_hist
            
        # 2. Check Lost Tracks Cache for Re-entry
        if not p_hist["locked_name"] and new_hist is not None:
            best_match_tid, best_corr = None, -1.0
            now = time.time()
            for old_tid, info in list(self.lost_tracks.items()):
                if now - info["timestamp"] > 15.0: # Lost for more than 15 seconds -> expire
                    del self.lost_tracks[old_tid]
                    continue
                corr = self.match_clothing(new_hist, info["clothing_hist"])
                if corr > best_corr:
                    best_corr = corr
                    best_match_tid = old_tid
            
            # If high clothing correlation (e.g. > 0.88)
            if best_corr >= 0.88 and best_match_tid is not None:
                restored_name = self.lost_tracks[best_match_tid]["locked_name"]
                p_hist["locked_name"] = restored_name
                print(f"[Re-ID Re-Entry] Restored identity '{restored_name}' for track {tid} from lost track {best_match_tid} (clothing match: {best_corr:.3f})")
                del self.lost_tracks[best_match_tid]
                return restored_name

        # If already locked, return
        if p_hist["locked_name"]:
            return p_hist["locked_name"]

        # 3. Process Face Recognition if face is found
        if face_crop is not None and face_crop.size > 100:
            p_hist["frames_since_face"] = 0
            emb = self.face_to_embedding(face_crop)
            if emb is not None:
                # Reload DBs dynamically to pick up any changes
                self.reload_known_db()
                self.reload_unknown_db()
                
                (best_k, k_sim), (best_u, u_sim), k_sec_sim = self.get_matches(emb)
                
                margin = (k_sim - k_sec_sim) if (k_sim and k_sec_sim) else 0.0
                
                # 1. Prioritize Registered Members
                # If there is a reasonable match to a registered person, focus on it and ignore unknown DB templates
                if k_sim >= 0.58 and margin >= 0.10:
                    if k_sim >= 0.75:
                        p_hist["locked_name"] = best_k.upper()
                        return best_k.upper()
                    vote = best_k.upper()
                # 2. Direct lock for high confidence unknown matches
                elif u_sim >= 0.75:
                    p_hist["locked_name"] = best_u.upper()
                    
                    # Active learning template views
                    base_unk = best_u.upper().rsplit("_V", 1)[0]
                    if u_sim < 0.85:
                        with self.lock:
                            count = sum(1 for k in self.unknown_people if k.upper().startswith(base_unk))
                            new_key = f"{base_unk}_v{count + 1}"
                            self.unknown_people[new_key] = {"mean": emb}
                            self.save_unknown_db()
                            print(f"[GenzReID Active Learning] Added template {new_key} (similarity: {u_sim:.3f})")
                    return best_u.upper()
                # 3. Fallback voting
                else:
                    if u_sim >= 0.68:
                        vote = best_u.upper()
                    else:
                        vote = "UNKNOWN"
                    
                p_hist["face_names"].append((vote, max(k_sim, u_sim)))
                votes = list(p_hist["face_names"])
                
                # Require 10 votes for steadier consensus and filter transient noise
                if len(votes) >= 10:
                    valid_votes = [v[0] for v in votes if v[0] != "UNKNOWN"]
                    if valid_votes:
                        top, cnt = Counter(valid_votes).most_common(1)[0]
                        # Require 6 out of 10 votes (strict majority)
                        if cnt >= 6:
                            p_hist["locked_name"] = top
                            
                            # Active learning template view for vote match
                            if top.startswith("UNK_"):
                                base_unk = top.rsplit("_V", 1)[0]
                                with self.lock:
                                    count = sum(1 for k in self.unknown_people if k.upper().startswith(base_unk))
                                    new_key = f"{base_unk}_v{count + 1}"
                                    self.unknown_people[new_key] = {"mean": emb}
                                    self.save_unknown_db()
                            return top
                            
                    # Assign a new sequential Unknown ID if majority (6 out of 10) is UNKNOWN
                    all_counts = Counter([v[0] for v in votes])
                    if all_counts["UNKNOWN"] >= 6:
                        new_unk = self._assign_next_sequential_unknown_id(emb)
                        p_hist["locked_name"] = new_unk
                        return new_unk
        else:
            p_hist["frames_since_face"] += 1
            
        return p_hist.get("locked_name") or "Analyzing..."

    def track_lost(self, tid):
        """Called when a tracker is lost to save their clothing profile for future re-entry."""
        if tid in self.active_tracks:
            info = self.active_tracks[tid]
            locked_name = info.get("locked_name")
            clothing_hist = info.get("clothing_hist")
            
            # Only cache lost tracks that have resolved identities and clothing profiles
            if locked_name and locked_name != "Analyzing..." and clothing_hist is not None:
                self.lost_tracks[tid] = {
                    "locked_name": locked_name,
                    "clothing_hist": clothing_hist,
                    "timestamp": time.time()
                }
                print(f"[GenzReID] Cached track {tid} ('{locked_name}') for potential re-entry.")
            del self.active_tracks[tid]
