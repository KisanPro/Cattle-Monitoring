#!/bin/bash
cd /mnt/f/2D_to_3D_final_version2/backend
export PYTHONPATH=/mnt/f/2D_to_3D_final_version2
export HF_TOKEN=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
nohup /home/kisan_pro/miniconda3/envs/trellis2/bin/python3 app.py > server.log 2>&1 &
echo $! > server.pid
