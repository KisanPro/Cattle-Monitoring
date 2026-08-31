# Kisan CattleVision | Jetson Orin Nano — COMPLETE PACKAGE

## HOW TO RUN (Only 2 steps, ever)

### First time only:
```bash
cd ~/Desktop/Kisan_Jetson
bash START.sh
```
That's it. The script will:
1. Install all dependencies automatically
2. Compile YOLO models to TensorRT (takes 5–10 min, normal)
3. Start the server on port 8000

### Every time after:
```bash
bash START.sh
```
(Dependencies & model compilation are already done — it just boots the server)

---

## Open the Dashboard
- On Jetson monitor: Open Chromium → `http://localhost:8000`
- From your phone: `http://<JETSON_IP>:8000`

---

## Package Contents
```
Kisan_Jetson/
├── START.sh              ← THE ONLY FILE YOU NEED TO RUN
├── jetson_app.py         ← Optimized FastAPI Edge Server
├── jetson_pipeline.py    ← TensorRT + Face Re-id AI Pipeline
├── adaptive_health.py    ← Cattle Adaptive Health Engine
├── export_tensorrt.py    ← One-time model compiler (called by START.sh)
├── config.json           ← Camera IP / RTSP credentials
├── yolo26.pt             ← Cattle YOLO model (auto-compiled to .engine)
├── yolov8n.pt            ← Fallback YOLO model (auto-compiled to .engine)
├── models/
│   ├── yolov8n-face.pt   ← Face detection model (auto-compiled to .engine)
│   └── best_checkpoint.pth ← ArcFace embedding weights
├── embeddings/
│   ├── known_embeddings.pkl ← Your registered farm workers
│   └── member_roles.json
├── static/               ← Web dashboard assets
├── templates/            ← Web UI (index.html)
└── storage/              ← Behavior logs, baselines, cattle data
```
