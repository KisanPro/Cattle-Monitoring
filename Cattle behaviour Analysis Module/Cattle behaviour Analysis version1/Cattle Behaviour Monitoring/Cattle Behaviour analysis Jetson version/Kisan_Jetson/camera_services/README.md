# Kisan CattleVision Camera Services

This folder contains utilities for automating IP Camera tasks, specifically resolving the clock synchronization issue where camera overlays revert to standard NTP defaults (e.g. year `2000`).

## The Problem
Many IP cameras (Dahua, Hikvision, etc.) reset their internal system clocks to factory default (e.g. `01-01-2000`) upon reboot or power cycle. When you log into the camera web portal via a browser, the camera automatically syncs its clock with the computer/client system clock.

## The Solution
The `sync_camera_times.py` script automates this login flow using Selenium & Firefox.

### Installation
Ensure Selenium is installed in the Python environment:
```bash
pip install selenium
```

### How to Run

#### 1. Visual Mode (Default)
Runs Firefox visually on the desktop, allowing you to watch the automation input the credentials and submit:
```bash
python3 sync_camera_times.py
```

#### 2. Headless Mode
Runs the browser silently in the background (perfect for servers, system startup scripts, or cron jobs):
```bash
python3 sync_camera_times.py --headless
```

## Scheduling Automatic Daily Synchronization
To prevent the time from drifting or resetting, you can schedule the script to run daily at 5:00 AM using `cron`:

1. Open the crontab editor:
   ```bash
   crontab -e
   ```
2. Add the following line at the bottom of the file (specifying headless mode):
   ```text
   0 5 * * * /usr/bin/python3 /home/mr/Documents/Deployment/Kisan_Jetson/camera_services/sync_camera_times.py --headless > /home/mr/Documents/Deployment/Kisan_Jetson/camera_services/sync_sync.log 2>&1
   ```
3. Save and close. The Jetson will now automatically refresh and sync all camera clocks every morning.
