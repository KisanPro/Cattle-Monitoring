#!/bin/bash
# ============================================================
#  Kisan CattleVision - AWS EC2 Relay Server Launcher
# ============================================================

echo "[*] Setting up EC2 Relay Server environment..."
python3 -m pip install -r requirements.txt

echo "[*] Starting FastAPI server on port 8080..."
python3 app.py
