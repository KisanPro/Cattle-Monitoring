@echo off
title Kisan HPC S3 Auto-Watcher
echo ===================================================
echo   Kisan Face Recognition S3 Auto-Watcher Daemon
echo ===================================================
echo.
echo Starting S3 polling daemon (checking every 10 seconds)...
echo.
python -u s3_auto_watcher.py
pause
