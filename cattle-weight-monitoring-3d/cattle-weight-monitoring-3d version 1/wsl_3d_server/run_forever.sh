#!/bin/bash
echo "Starting 3D server in auto-restart loop..."
while true; do
    export HF_TOKEN=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
    export CUDA_VISIBLE_DEVICES=0
    /home/thipp/miniconda3/envs/trellis2/bin/python3 -u app.py
    echo "Server process exited with code $?. Restarting in 2 seconds..."
    sleep 2
done
