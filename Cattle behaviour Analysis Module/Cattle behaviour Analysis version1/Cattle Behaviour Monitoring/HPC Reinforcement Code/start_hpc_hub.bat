@echo off
set PYTHONUTF8=1
echo Starting Kisan Intelligence Hub...
python -m uvicorn app.main:app --host 0.0.0.0 --port 9000 --reload
pause
