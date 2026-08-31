"""
stream_storing.py  —  Kisan CattleVision CCTV Stream Storage

Runs continuously in the background (launched by START.sh or systemd).
Auto-restarts for each camera if the stream drops — recording never stops.

Slot layout (8 slots × 3 hours, human-readable names):
  Camera_stream/
    2026-08-21/
      cam1/
        slot_12AM_3AM.mp4
        slot_3AM_6AM.mp4
        slot_6AM_9AM.mp4
        slot_9AM_12PM.mp4
        slot_12PM_3PM.mp4
        slot_3PM_6PM.mp4
        slot_6PM_9PM.mp4
        slot_9PM_12AM.mp4
      cam2/  (same)
      cam3/  (same)

Strategy per camera mode:
  RTSP        → FFmpeg pulls the stream directly and copies the raw H.264/H.265
                bitstream into a fragmented MP4.  Zero re-encoding.  Full quality.
  http_snap / → OpenCV polls JPEG snapshots and pipes raw BGR frames to FFmpeg
  https_snap    which encodes as H.264.  (Snapshot cameras have no continuous
                stream to copy.)

Crash-safety:
  Fragmented MP4 flags (frag_keyframe + empty_moov) are used for all files.
  The moov atom is written at the very start and updated at every keyframe,
  so the file is fully playable in any player even if the process is killed
  mid-recording.  No more "moov atom not found" errors.

Slot layout:
  <base>/Camera_stream/<YYYY-MM-DD>/<cam_name>/slot_NN_HHOO-HH59.mp4
"""

import os
os.environ["OPENCV_LOG_LEVEL"]       = "OFF"
os.environ["OPENCV_FFMPEG_LOGLEVEL"] = "-8"
os.environ["PYTHONWARNINGS"]         = "ignore"

import warnings
warnings.filterwarnings("ignore")

import cv2
import json
import time
import shutil
import subprocess
import threading
import numpy as np
from datetime import datetime
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ── Constants ─────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.json")

SLOT_HOURS  = 3      # hours per slot file
SNAP_FPS    = 10     # FPS for snapshot cameras (encoded)
SNAP_W      = 1280   # output width  for snapshot cameras
SNAP_H      = 720    # output height for snapshot cameras


# ── Config helpers ────────────────────────────────────────────────────────────
def get_base_storage_dir():
    from storage_utils import get_base_storage
    return os.path.join(get_base_storage(SCRIPT_DIR), "Camera_stream")


def get_cameras_config():
    try:
        with open(CONFIG_FILE) as f:
            conf = json.load(f)
    except Exception:
        return {}

    cameras = {}

    # cam1 — RTSP
    if conf.get("cam1_url"):
        cameras["cam1"] = {"mode": "rtsp", "url": conf["cam1_url"]}

    # cam2 … cam5 — snapshot or RTSP
    for i in range(2, 6):
        prefix = f"cam{i}"
        ip = conf.get(f"{prefix}_ip")
        if not ip:
            continue
        user  = conf.get(f"{prefix}_user", "admin")
        passw = conf.get(f"{prefix}_pass", "")
        path  = conf.get(f"{prefix}_path", "")
        mode  = conf.get(f"{prefix}_mode", "rtsp")

        if mode == "rtsp":
            if not path or "snapshot" in path or "onvif" in path:
                path = "video/live?channel=1&subtype=0"
            path = path.lstrip("/")
            url  = f"rtsp://{user}:{passw}@{ip}:554/{path}"
        else:
            if not path or "video" in path:
                path = "onvifsnapshot/media_service/snapshot?channel=1&subtype=0"
            path   = path.lstrip("/")
            scheme = "https" if mode == "https_snap" else "http"
            url    = f"{scheme}://{ip}/{path}"

        cameras[prefix] = {
            "mode": mode, "url": url,
            "user": user, "pass": passw,
        }

    return cameras


# ── Slot helpers ──────────────────────────────────────────────────────────────
# 8 fixed 3-hour slots with human-readable names
_SLOTS = [
    (0,  3,  "slot_12AM_3AM"),
    (3,  6,  "slot_3AM_6AM"),
    (6,  9,  "slot_6AM_9AM"),
    (9,  12, "slot_9AM_12PM"),
    (12, 15, "slot_12PM_3PM"),
    (15, 18, "slot_3PM_6PM"),
    (18, 21, "slot_6PM_9PM"),
    (21, 24, "slot_9PM_12AM"),
]


def get_slot_info(now=None):
    """Return (date_str, slot_label, slot_end_epoch) for the current moment."""
    if now is None:
        now = datetime.now()
    date_str = now.strftime("%Y-%m-%d")
    for start_h, end_h, label in _SLOTS:
        if start_h <= now.hour < end_h or (end_h == 24 and now.hour >= start_h):
            # end epoch: start of next day if end_h==24, else end_h:00:00 of today
            if end_h == 24:
                import calendar
                end_dt = datetime(now.year, now.month, now.day) \
                         + __import__('datetime').timedelta(days=1)
            else:
                end_dt = datetime(now.year, now.month, now.day, end_h, 0, 0)
            return date_str, label, end_dt.timestamp()
    # Fallback (should never happen)
    return date_str, "slot_unknown", time.time() + 3600


def slot_end_epoch(date_str, slot_label):
    """Return UNIX timestamp when the given slot ends."""
    _, _, end_ts = get_slot_info()   # use current time as proxy
    return end_ts


# ── Old data cleanup ──────────────────────────────────────────────────────────
def cleanup_old_data(base_dir):
    """Remove date-folders older than the previous calendar month."""
    now = datetime.now()
    cy, cm = now.year, now.month
    py, pm = (cy - 1, 12) if cm == 1 else (cy, cm - 1)
    keep_prefixes = [f"{cy:04d}-{cm:02d}-", f"{py:04d}-{pm:02d}-"]

    if not os.path.exists(base_dir):
        return
    for entry in os.listdir(base_dir):
        ep = os.path.join(base_dir, entry)
        if (os.path.isdir(ep)
                and len(entry) == 10
                and entry[4] == "-" and entry[7] == "-"
                and not any(entry.startswith(p) for p in keep_prefixes)):
            print(f"[-] Removing old folder: {ep}")
            try:
                shutil.rmtree(ep)
            except Exception as e:
                print(f"[WARN] {e}")


# ── RTSP worker (raw stream copy via FFmpeg) ──────────────────────────────────
def rtsp_store_worker(cam_name, url, stop_event):
    """
    Continuous 24/7 RTSP recording worker.

    - One FFmpeg process per 3-hour slot.
    - Copies raw H.264/H.265 bitstream directly — zero re-encoding.
    - When a slot ends, immediately starts the next slot.
    - If the camera drops mid-slot, waits 5 s and retries the same slot
      (so the partial file is kept and a new file is appended for the retry).
    - Runs until stop_event is set.
    """
    print(f"[RTSP] {cam_name} | continuous raw-copy | {url}")
    base_dir = get_base_storage_dir()
    os.makedirs(base_dir, exist_ok=True)
    retry_delay = 5   # seconds to wait after a camera error before retrying

    while not stop_event.is_set():
        date_str, slot_label, end_ts = get_slot_info()
        duration = max(10, int(end_ts - time.time()))

        out_dir  = os.path.join(base_dir, date_str, cam_name)
        os.makedirs(out_dir, exist_ok=True)

        # If the file already exists (retry within same slot), append a suffix
        # so the partial file from the previous attempt is not overwritten.
        base_path = os.path.join(out_dir, f"{slot_label}.mp4")
        out_path  = base_path
        if os.path.exists(out_path) and os.path.getsize(out_path) > 0:
            suffix   = int(time.time())
            out_path = os.path.join(out_dir, f"{slot_label}_{suffix}.mp4")

        cmd = [
            "ffmpeg", "-y",
            "-loglevel",       "error",
            # RTSP transport
            "-rtsp_transport", "tcp",
            # Socket/read timeout (microseconds): 10 seconds
            "-stimeout",       "10000000",
            # Max duration = remaining slot time
            "-t",              str(duration),
            "-i",              url,
            # Copy video bitstream as-is, re-encode audio to AAC (MP4-compatible)
            "-c:v",            "copy",
            "-c:a",            "aac",
            "-b:a",            "64k",
            # Crash-safe fragmented MP4
            "-movflags",       "frag_keyframe+empty_moov+default_base_moof",
            out_path,
        ]

        print(f"[REC] {cam_name} -> {out_path}  ({duration}s)")
        proc = subprocess.Popen(cmd,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.PIPE)

        # Poll FFmpeg; check stop_event every second
        while proc.poll() is None:
            if stop_event.is_set():
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                print(f"[*] {cam_name} recording stopped.")
                return
            time.sleep(1)

        rc         = proc.returncode
        stderr_out = proc.stderr.read(1000).decode(errors="replace").strip()

        if rc == 0:
            print(f"[OK] {cam_name} Slot complete: {os.path.basename(out_path)}")
            # Loop immediately — get_slot_info() will now return the next slot
        else:
            print(f"[WARN] {cam_name} FFmpeg exited ({rc}). "
                  f"Retrying in {retry_delay}s...")
            if stderr_out:
                print(f"      {stderr_out[:300]}")
            # Wait before retrying so we don't hammer a dead camera
            for _ in range(retry_delay * 2):
                if stop_event.is_set():
                    return
                time.sleep(0.5)

    print(f"[*] {cam_name} RTSP worker exited.")


# ── Snapshot worker (JPEG poll → FFmpeg encode) ───────────────────────────────
def snapshot_store_worker(cam_name, cam_cfg, stop_event):
    """
    For http_snap / https_snap cameras.
    Polls the snapshot URL at SNAP_FPS, pipes decoded BGR frames to FFmpeg
    which encodes as H.264 fragmented MP4.
    """
    url   = cam_cfg["url"]
    user  = cam_cfg.get("user", "")
    passw = cam_cfg.get("pass", "")

    print(f"[SNAP] {cam_name} | {url}")

    import requests
    from requests.auth import HTTPDigestAuth, HTTPBasicAuth
    session = requests.Session()
    session.verify = False
    auths    = [HTTPDigestAuth(user, passw), HTTPBasicAuth(user, passw)]
    auth_idx = 0

    base_dir = get_base_storage_dir()
    os.makedirs(base_dir, exist_ok=True)

    ffmpeg_proc  = None
    current_slot = None
    current_path = None

    def _open_writer(path):
        cmd = [
            "ffmpeg", "-y",
            "-f", "rawvideo", "-vcodec", "rawvideo",
            "-pix_fmt", "bgr24",
            "-s", f"{SNAP_W}x{SNAP_H}",
            "-r", str(SNAP_FPS),
            "-i", "pipe:0",
            "-vcodec", "libx264",
            "-preset", "ultrafast",
            "-crf", "28",
            "-pix_fmt", "yuv420p",
            "-movflags", "frag_keyframe+empty_moov+default_base_moof",
            path,
        ]
        return subprocess.Popen(cmd,
                                stdin=subprocess.PIPE,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)

    def _close_writer(proc, label=""):
        if proc is None:
            return
        try:
            proc.stdin.close()
        except Exception:
            pass
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()

    while not stop_event.is_set():
        t0 = time.time()
        try:
            # ── Fetch snapshot ─────────────────────────────────────────────
            frame = None
            try:
                r = session.get(url, auth=auths[auth_idx], timeout=4)
                if r.status_code == 401:
                    alt = 1 - auth_idx
                    r2  = session.get(url, auth=auths[alt], timeout=4)
                    if r2.status_code == 200:
                        auth_idx = alt
                        r = r2
                if r.status_code == 200 and len(r.content) > 500:
                    arr   = np.frombuffer(r.content, dtype=np.uint8)
                    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            except Exception:
                time.sleep(2)
                continue

            if frame is None:
                time.sleep(2)
                continue

            frame = cv2.resize(frame, (SNAP_W, SNAP_H), interpolation=cv2.INTER_LINEAR)

            # ── Rotate slot if needed ──────────────────────────────────────
            date_str, slot_label, _ = get_slot_info()
            slot_key = (date_str, slot_label)

            if slot_key != current_slot:
                _close_writer(ffmpeg_proc, cam_name)
                ffmpeg_proc = None
                if current_path:
                    print(f"[OK] {cam_name} Slot saved: {os.path.basename(current_path)}")

                out_dir      = os.path.join(base_dir, date_str, cam_name)
                os.makedirs(out_dir, exist_ok=True)
                current_path = os.path.join(out_dir, f"{slot_label}.mp4")
                current_slot = slot_key
                ffmpeg_proc  = _open_writer(current_path)
                print(f"[REC] {cam_name} -> {current_path}")

            # ── Write frame ────────────────────────────────────────────────
            if ffmpeg_proc is not None and ffmpeg_proc.poll() is None:
                try:
                    ffmpeg_proc.stdin.write(frame.tobytes())
                except (BrokenPipeError, OSError):
                    print(f"[WARN] {cam_name} pipe broken, reopening writer...")
                    ffmpeg_proc  = None
                    current_slot = None

            # ── Throttle to SNAP_FPS ───────────────────────────────────────
            elapsed = time.time() - t0
            time.sleep(max(0.0, (1.0 / SNAP_FPS) - elapsed))

        except Exception as e:
            print(f"[ERROR] {cam_name}: {e}")
            time.sleep(2)

    # Clean shutdown
    _close_writer(ffmpeg_proc, cam_name)
    if current_path:
        print(f"[OK] {cam_name} Final slot: {os.path.basename(current_path)}")
    print(f"[*] {cam_name} snapshot worker exited.")


# ── Supervisor / main ─────────────────────────────────────────────────────────
def main():
    running = {}   # cam_name -> (thread, stop_event, url)

    def _daily_cleanup():
        last_day = None
        while True:
            today = datetime.now().day
            if today != last_day:
                cleanup_old_data(get_base_storage_dir())
                last_day = today
            time.sleep(60)

    threading.Thread(target=_daily_cleanup, daemon=True).start()

    print("=" * 60)
    print("  Kisan CattleVision — CCTV Stream Storing Service")
    print(f"  Storage : {get_base_storage_dir()}")
    print(f"  Slots   : {SLOT_HOURS}h each")
    print(f"  RTSP    : raw H.264/H.265 copy — no re-encoding")
    print(f"  Snapshot: H.264 encode @ {SNAP_FPS}fps {SNAP_W}x{SNAP_H}")
    print("=" * 60)

    STOP_FILE = os.path.join(SCRIPT_DIR, ".stop_recording")

    while True:
        try:
            if os.path.exists(STOP_FILE):
                if running:
                    print("[STOP] .stop_recording flag detected. Stopping all streams...")
                    for name in list(running.keys()):
                        _, stop_ev, _ = running[name]
                        stop_ev.set()
                    running.clear()
                time.sleep(3)
                continue

            cameras = get_cameras_config()

            for name, cfg in cameras.items():
                url = cfg["url"]

                # Restart if URL changed
                if name in running:
                    _, stop_ev, prev_url = running[name]
                    if prev_url != url:
                        print(f"[*] Config changed for {name}. Restarting...")
                        stop_ev.set()
                        del running[name]

                if name not in running:
                    stop_ev = threading.Event()
                    mode    = cfg["mode"]

                    if mode == "rtsp":
                        target = rtsp_store_worker
                        args   = (name, url, stop_ev)
                    else:
                        target = snapshot_store_worker
                        args   = (name, cfg, stop_ev)

                    t = threading.Thread(target=target, args=args, daemon=True)
                    t.start()
                    running[name] = (t, stop_ev, url)
                    print(f"[+] Started [{mode}] recording thread for {name}")

            # Stop threads for removed cameras
            for name in list(running.keys()):
                if name not in cameras:
                    print(f"[-] {name} removed. Stopping...")
                    _, stop_ev, _ = running[name]
                    stop_ev.set()
                    del running[name]

        except Exception as e:
            print(f"[ERROR] Supervisor: {e}")

        time.sleep(10)


if __name__ == "__main__":
    main()
