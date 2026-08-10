// DOM Elements
const video = document.getElementById('webcam');
const canvas = document.getElementById('canvas-overlay');
const ctx = canvas.getContext('2d');
const placeholder = document.getElementById('viewport-placeholder');
const btnStartCamera = document.getElementById('btn-start-camera');
const btnToggleCamera = document.getElementById('btn-toggle-camera');
const statusBadge = document.getElementById('status-badge');
const statsFps = document.getElementById('stats-fps');
const statsLatency = document.getElementById('stats-latency');
const thresholdSlider = document.getElementById('threshold-slider');
const thresholdVal = document.getElementById('threshold-val');
const membersList = document.getElementById('members-list');
const consoleLogs = document.getElementById('console-logs');
const btnClearLogs = document.getElementById('btn-clear-logs');

// App State
let isStreaming = false;
let serverOnline = false;
let activeProcess = false;
let lastResult = null;
let threshold = parseFloat(thresholdSlider.value);
let lastLogTime = 0;
let lastLoggedIdentity = "";
let frameCount = 0;
let lastFpsUpdate = 0;
let fps = 0.0;
let currentLatency = 0;

// Offscreen Canvas for capturing frames
const offscreenCanvas = document.createElement('canvas');
const offscreenCtx = offscreenCanvas.getContext('2d');

// Configure dimensions
const VIEW_WIDTH = 640;
const VIEW_HEIGHT = 480;
canvas.width = VIEW_WIDTH;
canvas.height = VIEW_HEIGHT;
offscreenCanvas.width = VIEW_WIDTH;
offscreenCanvas.height = VIEW_HEIGHT;

// Font rendering settings
ctx.font = '16px Inter, sans-serif';

// 1. Connection & Initial Setup
async function checkServerConnection() {
    try {
        const response = await fetch('/api/members');
        if (response.ok) {
            const data = await response.json();
            serverOnline = true;
            updateStatusBadge(true);
            renderMembers(data.members);
            enableCameraControls(true);
        } else {
            throw new Error();
        }
    } catch (err) {
        serverOnline = false;
        updateStatusBadge(false);
        enableCameraControls(false);
        renderLoadingMembersError();
    }
}

function updateStatusBadge(online) {
    const dot = statusBadge.querySelector('.dot');
    const text = statusBadge.querySelector('.text');
    if (online) {
        dot.className = 'dot green';
        text.textContent = 'Server Online';
    } else {
        dot.className = 'dot red';
        text.textContent = 'Server Offline';
    }
}

function renderMembers(members) {
    if (members.length === 0) {
        membersList.innerHTML = '<div class="member-tag">No templates registered</div>';
        return;
    }
    membersList.innerHTML = members
        .map(m => `<div class="member-tag">${m}</div>`)
        .join('');
}

function renderLoadingMembersError() {
    membersList.innerHTML = '<div class="member-tag loading">Failed to connect...</div>';
}

function enableCameraControls(enable) {
    btnStartCamera.disabled = !enable;
    if (enable) {
        btnToggleCamera.disabled = !isStreaming;
    } else {
        btnToggleCamera.disabled = true;
        if (isStreaming) {
            stopCamera();
        }
    }
}

// 2. Camera Controls
async function startCamera() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: {
                width: { ideal: VIEW_WIDTH },
                height: { ideal: VIEW_HEIGHT }
            },
            audio: false
        });
        video.srcObject = stream;
        video.play().catch(err => console.error("Error playing video stream:", err));
        isStreaming = true;
        placeholder.style.display = 'none';
        btnToggleCamera.disabled = false;
        btnToggleCamera.textContent = 'Stop Feed';
        
        logEntry("Webcam stream started. Accessing frame buffer...", "system");
        
        // Start rendering loops
        requestAnimationFrame(tick);
    } catch (err) {
        console.error("Camera access error:", err);
        logEntry("Error: Webcam access denied or unavailable.", "unknown");
    }
}

function stopCamera() {
    if (video.srcObject) {
        const tracks = video.srcObject.getTracks();
        tracks.forEach(track => track.stop());
        video.srcObject = null;
    }
    isStreaming = false;
    placeholder.style.display = 'flex';
    btnToggleCamera.textContent = 'Start Feed';
    btnToggleCamera.disabled = true;
    lastResult = null;
    
    // Clear canvas
    ctx.clearRect(0, 0, VIEW_WIDTH, VIEW_HEIGHT);
    logEntry("Webcam stream stopped.", "system");
}

// 3. Processing and Drawing Loop
async function processFrame() {
    if (activeProcess || !isStreaming) return;
    
    activeProcess = true;
    const startTime = performance.now();
    
    // Draw current video state to offscreen canvas
    offscreenCtx.drawImage(video, 0, 0, VIEW_WIDTH, VIEW_HEIGHT);
    const dataUrl = offscreenCanvas.toDataURL('image/jpeg', 0.6); // 60% quality compression
    
    try {
        const response = await fetch('/api/recognize', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ image: dataUrl })
        });
        
        if (response.ok) {
            const result = await response.json();
            lastResult = result;
            currentLatency = Math.round(performance.now() - startTime);
            statsLatency.textContent = `${currentLatency} ms`;
            
            // Handle logging logic (avoid flooding console)
            if (result.face_found) {
                let identity = result.similarity >= threshold ? result.best_match : "Unknown";
                let now = Date.now();
                if (identity !== lastLoggedIdentity || (now - lastLogTime) > 3000) {
                    let simText = result.similarity.toFixed(2);
                    if (identity === "Unknown") {
                        logEntry(`Stranger detected (Best Match: ${result.best_match} @ ${simText} similarity)`, "unknown");
                    } else {
                        logEntry(`Member recognized: ${identity} (Similarity Score: ${simText})`, "match");
                    }
                    lastLoggedIdentity = identity;
                    lastLogTime = now;
                }
            } else {
                lastLoggedIdentity = "";
            }
        }
    } catch (err) {
        console.error("Frame recognition error:", err);
    } finally {
        activeProcess = false;
    }
}

function tick(timestamp) {
    if (!isStreaming) return;
    
    // 1. Clear the canvas overlay (video renders natively underneath)
    ctx.clearRect(0, 0, VIEW_WIDTH, VIEW_HEIGHT);
    
    // 2. Measure FPS
    frameCount++;
    if (timestamp - lastFpsUpdate >= 1000) {
        fps = (frameCount * 1000) / (timestamp - lastFpsUpdate);
        statsFps.textContent = `${fps.toFixed(1)} FPS`;
        frameCount = 0;
        lastFpsUpdate = timestamp;
    }
    
    // 3. Process backend recognition (async fire-and-forget, processed in parallel)
    if (!activeProcess) {
        processFrame();
    }
    
    // 4. Draw overlays
    if (lastResult && lastResult.face_found) {
        const [x1, y1, x2, y2] = lastResult.bbox;
        const width = x2 - x1;
        const height = y2 - y1;
        
        // Threshold check
        const isMatch = lastResult.similarity >= threshold;
        const label = isMatch ? lastResult.best_match : "Unknown";
        const score = lastResult.similarity.toFixed(2);
        
        // Colors: Green for known, Red for unknown
        const primaryColor = isMatch ? '#10b981' : '#ef4444';
        
        // Draw tracking box corners
        ctx.strokeStyle = primaryColor;
        ctx.lineWidth = 3;
        ctx.lineJoin = 'round';
        ctx.strokeRect(x1, y1, width, height);
        
        // Draw text label box
        ctx.fillStyle = primaryColor;
        const text = `${label} (${score})`;
        const textWidth = ctx.measureText(text).width + 12;
        ctx.fillRect(x1, y1 - 25, textWidth, 25);
        
        // Draw text
        ctx.fillStyle = '#000000';
        ctx.fillText(text, x1 + 6, y1 - 7);
    }
    
    requestAnimationFrame(tick);
}

// 4. Log console helper
function logEntry(message, type = "info") {
    const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    entry.textContent = `[${time}] ${message}`;
    consoleLogs.appendChild(entry);
    
    // Scroll to bottom
    consoleLogs.scrollTop = consoleLogs.scrollHeight;
}

// 5. Event Listeners
btnStartCamera.addEventListener('click', () => {
    startCamera();
});

btnToggleCamera.addEventListener('click', () => {
    if (isStreaming) {
        stopCamera();
    } else {
        startCamera();
    }
});

thresholdSlider.addEventListener('input', (e) => {
    threshold = parseFloat(e.target.value);
    thresholdVal.textContent = threshold.toFixed(2);
});

btnClearLogs.addEventListener('click', () => {
    consoleLogs.innerHTML = '';
    logEntry("Log console cleared.", "system");
});

// Run connection check immediately and poll
checkServerConnection();
setInterval(checkServerConnection, 5000);
logEntry("Connecting to backend server...", "system");
