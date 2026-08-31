#!/bin/bash
# ============================================================
#  Kisan CattleVision - Jetson Orin Nano ONE-CLICK LAUNCHER
#  Handles: Setup + Model Export + Server Start automatically
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAG_FILE="$SCRIPT_DIR/.setup_done"

cd "$SCRIPT_DIR"

echo "============================================================"
echo " KISAN CattleVision Edge AI - Jetson Orin Nano Launcher"
echo "============================================================"
echo ""

# ── STEP 1: First-time setup ────────────────────────────────
if [ ! -f "$FLAG_FILE" ]; then
    echo "[*] First run detected. Installing dependencies..."
    echo "    This will take 10-20 minutes. Please wait..."
    echo ""

    # System packages
    sudo apt-get update -y
    sudo apt-get install -y python3-pip python3-dev libopenblas-dev \
        libopenmpi-dev cmake wget curl ffmpeg libavcodec-dev \
        libavformat-dev libswscale-dev libgtk-3-dev pkg-config \
        libatlas-base-dev gfortran libjpeg-dev zlib1g-dev

    # Upgrade pip
    python3 -m pip install --upgrade pip setuptools wheel

    # JetPack 6 (L4T 36.x) PyTorch 2.3.0 ARM64 wheel
    echo "[*] Installing NVIDIA JetPack 6 optimized PyTorch..."
    python3 -m pip install --no-cache-dir \
        https://developer.download.nvidia.com/compute/redist/jp/v60/pytorch/torch-2.3.0a0+ebedce2.nv24.02-cp310-cp310-linux_aarch64.whl

    # Core Python packages
    echo "[*] Installing core Python packages..."
    python3 -m pip install --no-cache-dir \
        fastapi uvicorn[standard] starlette jinja2 \
        numpy pandas requests urllib3 Pillow \
        ultralytics easyocr timm facenet-pytorch \
        pytz chromadb

    # Mark setup as done
    touch "$FLAG_FILE"
    echo ""
    echo "[OK] All dependencies installed successfully!"
    echo ""
fi

# ── STEP 2: Export TensorRT engines if not done ─────────────
if [ ! -f "$SCRIPT_DIR/yolo26.engine" ]; then
    echo "[*] TensorRT engines not found. Compiling now..."
    echo "    This takes 5-10 minutes. The fan will run loud. This is normal."
    echo ""
    # Max performance mode
    sudo nvpmodel -m 0 2>/dev/null || true
    sudo jetson_clocks 2>/dev/null || true
    # python3 "$SCRIPT_DIR/export_tensorrt.py"
    echo "[*] Skipped TensorRT compilation. Using highly optimized PyTorch FP16 engine (15+ FPS)."
    echo ""
fi

# ── STEP 3: Always set max performance ──────────────────────
sudo nvpmodel -m 0 2>/dev/null || true
sudo jetson_clocks 2>/dev/null || true

# ── STEP 4: Launch the server ───────────────────────────────
echo "[*] Starting Kisan CattleVision Edge AI Server..."
echo "[*] Starting background Stream Storing Service (writing to external HDD)..."
echo "[*] Open browser and go to: http://localhost:8000"
echo "[*] From phone/tablet use:  http://$(hostname -I | awk '{print $1}'):8000"
echo "============================================================"
echo ""

# Export log suppression environment variables
export OPENCV_LOG_LEVEL=OFF
export OPENCV_FFMPEG_LOGLEVEL=-8
export PYTHONWARNINGS=ignore

# Trap exit to kill the background stream storing and sync manager scripts when the shell exits
trap "kill 0" EXIT

python3 -u "$SCRIPT_DIR/stream_storing.py" > /tmp/stream_storing.log 2>&1 &
python3 -u "$SCRIPT_DIR/kisan_sync_manager.py" > /tmp/kisan_sync_manager.log 2>&1 &
python3 -u "$(dirname "$SCRIPT_DIR")/Kisan_Jetson_Mobile/stream_forwarder/forwarder.py" > /tmp/kisan_stream_forwarder.log 2>&1 &
python3 -u "$SCRIPT_DIR/jetson_app.py"



