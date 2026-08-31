from fastapi import FastAPI, Response, Request, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
import uvicorn
import asyncio
import time
import json
import logging

# Configure logger
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("EC2_Relay_Server")

app = FastAPI(title="Kisan CattleVision AWS EC2 Relay Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-Memory Cache for Stream Frames and Telemetry/Alerts Data
camera_frames = {}       # {cam_id: bytes}
camera_frame_times = {}  # {cam_id: float}
system_status = {}       # Telemetry dict
active_alerts = []       # List of alerts
master_ids = []  # In-memory master cattle list

API_KEY = "kisan_secure_token_2026"

def verify_api_key(x_api_key: str = Header(None)):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized: Invalid X-API-KEY")

@app.get("/")
async def root():
    return {
        "status": "online",
        "message": "Kisan CattleVision AWS EC2 Relay Server is active.",
        "active_cameras": list(camera_frames.keys()),
        "last_status_update": system_status.get("timestamp", "Never")
    }

# ── JETSON UPLOAD ENDPOINTS ──

@app.post("/api/stream/upload/{cam_id}")
async def upload_frame(cam_id: str, request: Request, x_api_key: str = Header(None)):
    verify_api_key(x_api_key)
    body = await request.body()
    if not body:
        raise HTTPException(status_code=400, detail="Empty frame body")
    
    camera_frames[cam_id] = body
    camera_frame_times[cam_id] = time.time()
    return {"status": "success", "cam_id": cam_id}

@app.post("/api/status/upload")
async def upload_status(payload: dict, x_api_key: str = Header(None)):
    verify_api_key(x_api_key)
    global system_status, master_ids
    system_status = payload
    system_status["timestamp"] = time.time()
    
    # Sync and merge master IDs
    jetson_ids = payload.get("master_ids", [])
    if jetson_ids:
        merged = list(set(master_ids) | set(jetson_ids))
        if set(master_ids) != set(merged):
            master_ids = merged
        if set(jetson_ids) != set(merged):
            return {"status": "success", "update_master_ids": merged}
            
    return {"status": "success"}

@app.post("/api/alerts/upload")
async def upload_alerts(request: Request, x_api_key: str = Header(None)):
    verify_api_key(x_api_key)
    global active_alerts
    active_alerts = await request.json()
    return {"status": "success"}

# ── MOBILE CLIENT ENDPOINTS ──

def generate_mjpeg_stream(cam_id: str):
    """Generates the MJPEG stream from the in-memory frame cache."""
    fps_cap = 10.0
    frame_delay = 1.0 / fps_cap
    
    while True:
        loop_start = time.time()
        frame = camera_frames.get(cam_id)
        frame_time = camera_frame_times.get(cam_id, 0)
        
        # Check if the frame is stale (not updated for > 5 seconds)
        is_stale = (time.time() - frame_time) > 5.0
        
        if frame and not is_stale:
            # Yield the cached frame
            yield (b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + frame + b"\r\n")
        else:
            # If no frame or stale, we could yield an offline placeholder
            # Wait a little bit for the connection to recover
            pass
            
        elapsed = time.time() - loop_start
        # Yield control to allow other tasks to run
        time.sleep(max(0.01, frame_delay - elapsed))

@app.get("/video_feed/{cam_id}")
async def video_feed(cam_id: str):
    headers = {
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma":        "no-cache",
        "Expires":       "0",
        "X-Accel-Buffering": "no",
    }
    return StreamingResponse(
        generate_mjpeg_stream(cam_id),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers=headers,
    )

@app.get("/api/status")
async def get_status():
    if not system_status:
        return JSONResponse(
            content={"status": "offline", "message": "No telemetry data from Jetson yet"},
            status_code=404
        )
    return JSONResponse(content=system_status)

@app.get("/api/alerts")
async def get_alerts():
    return JSONResponse(content=active_alerts)

@app.get("/api/master_sheet")
async def get_master_sheet():
    global master_ids
    return {"status": "success", "ids": master_ids}

@app.post("/api/master_sheet")
async def post_master_sheet(payload: dict):
    global master_ids
    new_ids = payload.get("ids", [])
    import re
    cleaned = []
    for x in new_ids:
        s = str(x).strip().upper()
        if re.match(r"^[A-Z][0-9]{3}$", s):
            cleaned.append(s)
    master_ids = list(set(cleaned))
    return {"status": "success", "ids": master_ids}

if __name__ == "__main__":
    logger.info("Starting public EC2 Relay Server on port 8080...")
    uvicorn.run(app, host="0.0.0.0", port=8080)
