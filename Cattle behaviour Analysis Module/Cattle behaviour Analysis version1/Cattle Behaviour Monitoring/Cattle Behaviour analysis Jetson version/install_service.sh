#!/bin/bash
# ============================================================
#  Kisan CattleVision — Stream Storage Auto-Start Installer
#  Run this once with:  bash install_service.sh
# ============================================================

set -e

SERVICE_NAME="kisan-stream-store"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/Kisan_Jetson"
SCRIPT_PATH="$SCRIPT_DIR/stream_storing.py"
USER_NAME="$(whoami)"

echo "============================================================"
echo "  Installing Kisan Stream Storage as a systemd service"
echo "============================================================"
echo "  Script  : $SCRIPT_PATH"
echo "  User    : $USER_NAME"
echo ""

# ── 1. Write the service file ────────────────────────────────
cat > /tmp/${SERVICE_NAME}.service << EOF
[Unit]
Description=Kisan CattleVision CCTV Stream Storage
After=network-online.target local-fs.target
Wants=network-online.target

[Service]
Type=simple
User=${USER_NAME}
WorkingDirectory=${SCRIPT_DIR}
ExecStart=/usr/bin/python3 -u "${SCRIPT_PATH}"
Restart=always
RestartSec=5
Environment=PYTHONWARNINGS=ignore
Environment=OPENCV_LOG_LEVEL=OFF
Environment=OPENCV_FFMPEG_LOGLEVEL=-8
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "[1/4] Service file written."

# ── 2. Install it ────────────────────────────────────────────
sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/${SERVICE_NAME}.service
echo "[2/4] ✅ Service file installed to /etc/systemd/system/"

# ── 3. Reload systemd ────────────────────────────────────────
sudo systemctl daemon-reload
echo "[3/4] ✅ systemd daemon reloaded"

# ── 4. Enable + start ────────────────────────────────────────
sudo systemctl enable --now ${SERVICE_NAME}.service
echo "[4/4] ✅ Service enabled and started"

echo ""
echo "============================================================"
echo "  ✅ Done! Stream storage is now running in the background"
echo "     and will auto-start on every reboot."
echo ""
echo "  Useful commands:"
echo "    Status  : sudo systemctl status ${SERVICE_NAME}"
echo "    Logs    : journalctl -u ${SERVICE_NAME} -f"
echo "    Stop    : sudo systemctl stop ${SERVICE_NAME}"
echo "    Restart : sudo systemctl restart ${SERVICE_NAME}"
echo "============================================================"

# Show current status
echo ""
sudo systemctl status ${SERVICE_NAME}.service --no-pager
