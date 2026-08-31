import requests
import tarfile
import os
import io

# Use localhost since it's an internal test
HUB_URL = "http://127.0.0.1:9000"
API_KEY = "kisan_secure_token_2026"

def run_test_sync():
    print("🚀 Simulating Jetson Sync...")
    
    # 1. Create a mock batch
    mock_batch = "test_batch.tar.gz"
    with tarfile.open(mock_batch, "w:gz") as tar:
        content = b"fake image data"
        # Nested folders to test extraction
        info1 = tarfile.TarInfo("standing/cow1.jpg")
        info1.size = len(content)
        tar.addfile(info1, io.BytesIO(content))

    # 2. Upload with Security Token (Multipart)
    print(f"📡 Sending mock batch to Hub...")
    headers = {"X-API-KEY": API_KEY}
    url = f"{HUB_URL}/api/upload?filename={mock_batch}"
    
    try:
        with open(mock_batch, "rb") as f:
            # Send as multipart/form-data with 'file' field
            response = requests.post(url, headers=headers, files={"file": f})
        
        if response.status_code == 200:
            print(f"✅ HUB RESPONSE: {response.json()['message']}")
        else:
            print(f"❌ FAILED: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ CONNECTION ERROR: {e}")
    
    # Clean up mock file
    if os.path.exists(mock_batch):
        os.remove(mock_batch)

if __name__ == "__main__":
    run_test_sync()
