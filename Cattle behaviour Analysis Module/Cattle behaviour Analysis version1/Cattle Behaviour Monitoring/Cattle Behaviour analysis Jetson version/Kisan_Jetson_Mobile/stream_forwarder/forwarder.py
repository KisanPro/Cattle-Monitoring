import time
import json
import os
import requests
import threading

CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "forwarder_config.json")

# Default values if config file is missing/broken
EC2_URL = "http://127.0.0.1:8080"
CAMERAS = ["cam1", "cam2", "cam3"]
FORWARD_INTERVAL = 0.1  # 10 FPS
STATUS_INTERVAL = 2.0   # 2 seconds
API_KEY = "kisan_secure_token_2026"

def load_config():
    global EC2_URL, CAMERAS, FORWARD_INTERVAL, STATUS_INTERVAL, API_KEY
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                config = json.load(f)
                EC2_URL = config.get("ec2_url", EC2_URL).rstrip("/")
                CAMERAS = config.get("forward_cameras", CAMERAS)
                FORWARD_INTERVAL = config.get("forward_interval_sec", FORWARD_INTERVAL)
                STATUS_INTERVAL = config.get("status_interval_sec", STATUS_INTERVAL)
                API_KEY = config.get("api_key", API_KEY)
                print(f"[FORWARDER] Config loaded. Relay Server: {EC2_URL}")
        except Exception as e:
            print(f"[FORWARDER] Error loading config: {e}")

class StreamForwarder:
    def __init__(self):
        load_config()
        self.headers = {
            "X-API-KEY": API_KEY,
            "Content-Type": "application/octet-stream"
        }
        self.json_headers = {
            "X-API-KEY": API_KEY,
            "Content-Type": "application/json"
        }
        self.stopped = False
        self.session = requests.Session()

    def forward_camera_loop(self, cam_id):
        print(f"[FORWARDER] Starting stream forwarding thread for {cam_id}...")
        local_url = f"http://127.0.0.1:8000/api/frame/{cam_id}?mobile=true"
        remote_url = f"{EC2_URL}/api/stream/upload/{cam_id}"

        while not self.stopped:
            start_time = time.time()
            try:
                # 1. Fetch frame from local server
                r = self.session.get(local_url, timeout=2)
                if r.status_code == 200 and len(r.content) > 100:
                    # 2. Upload frame to EC2 server
                    self.session.post(remote_url, headers=self.headers, data=r.content, timeout=2)
            except Exception as e:
                print(f"[FORWARDER ERROR in camera {cam_id}] {e}")
                time.sleep(1.0)
            
            elapsed = time.time() - start_time
            time.sleep(max(0.001, FORWARD_INTERVAL - elapsed))

    def forward_status_loop(self):
        print("[FORWARDER] Starting status/alerts forwarding thread...")
        local_dashboard_url = "http://127.0.0.1:8000/api/dashboard"
        local_alerts_url = "http://127.0.0.1:8000/api/alerts"
        remote_status_url = f"{EC2_URL}/api/status/upload"
        remote_alerts_url = f"{EC2_URL}/api/alerts/upload"

        while not self.stopped:
            try:
                # 1. Fetch dashboard telemetry summary
                status_res = self.session.get(local_dashboard_url, timeout=3)
                if status_res.status_code == 200:
                    payload = status_res.json()
                    
                    # Fetch and append cattle summary
                    try:
                        res = self.session.get("http://127.0.0.1:8000/api/cattle/summary", timeout=3)
                        if res.status_code == 200:
                            payload["cattle_summary"] = res.json()
                    except Exception as e:
                        print(f"[FORWARDER ERROR fetching cattle summary] {e}")

                    # Fetch and append daily security attendance
                    try:
                        res = self.session.get("http://127.0.0.1:8000/api/security/attendance", timeout=3)
                        if res.status_code == 200:
                            payload["security_attendance"] = res.json()
                    except Exception as e:
                        print(f"[FORWARDER ERROR fetching security attendance] {e}")

                    # Fetch and append unknown visitors
                    try:
                        res = self.session.get("http://127.0.0.1:8000/api/security/unknown", timeout=3)
                        if res.status_code == 200:
                            payload["security_unknown"] = res.json()
                    except Exception as e:
                        print(f"[FORWARDER ERROR fetching security unknown] {e}")

                    # Fetch and append security logs
                    try:
                        res = self.session.get("http://127.0.0.1:8000/api/security/logs", timeout=3)
                        if res.status_code == 200:
                            payload["security_logs"] = res.json()
                    except Exception as e:
                        print(f"[FORWARDER ERROR fetching security logs] {e}")

                    # Fetch and append master sheet IDs
                    try:
                        res = self.session.get("http://127.0.0.1:8000/api/master_sheet", timeout=3)
                        if res.status_code == 200:
                            payload["master_ids"] = res.json().get("ids", [])
                    except Exception as e:
                        print(f"[FORWARDER ERROR fetching master sheet] {e}")

                    # Upload consolidated payload to EC2
                    res_status = self.session.post(
                        remote_status_url, 
                        headers=self.json_headers, 
                        json=payload, 
                        timeout=10
                    )
                    if res_status.status_code == 200:
                        res_data = res_status.json()
                        if "update_master_ids" in res_data:
                            update_ids = res_data["update_master_ids"]
                            try:
                                local_res = self.session.post(
                                    "http://127.0.0.1:8000/api/master_sheet",
                                    json={"ids": update_ids},
                                    timeout=3
                                )
                                if local_res.status_code == 200:
                                    print(f"[FORWARDER] Local Jetson master sheet updated with: {update_ids}")
                            except Exception as e:
                                print(f"[FORWARDER ERROR updating local master sheet] {e}")
                
                # 2. Get alerts and send
                alerts_res = self.session.get(local_alerts_url, timeout=3)
                if alerts_res.status_code == 200:
                    self.session.post(
                        remote_alerts_url, 
                        headers=self.json_headers, 
                        json=alerts_res.json(), 
                        timeout=3
                    )
            except Exception as e:
                print(f"[FORWARDER ERROR in status] {e}")
            
            time.sleep(STATUS_INTERVAL)

    def start(self):
        # Start a thread for each camera
        for cam_id in CAMERAS:
            t = threading.Thread(target=self.forward_camera_loop, args=(cam_id,), daemon=True)
            t.start()

        # Start status forward thread
        t_status = threading.Thread(target=self.forward_status_loop, daemon=True)
        t_status.start()

        # Keep main thread alive
        try:
            while not self.stopped:
                time.sleep(1.0)
        except KeyboardInterrupt:
            print("[FORWARDER] Stopping stream forwarder...")
            self.stopped = True

if __name__ == "__main__":
    print("[FORWARDER] Starting Kisan Stream Forwarder Service...")
    forwarder = StreamForwarder()
    forwarder.start()
