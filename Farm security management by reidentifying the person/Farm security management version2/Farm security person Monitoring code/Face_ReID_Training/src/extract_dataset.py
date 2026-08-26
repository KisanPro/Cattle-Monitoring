import os
import zipfile
import shutil

def extract_zip(zip_path, extract_to):
    print(f"Extracting {zip_path} to {extract_to}...")
    os.makedirs(extract_to, exist_ok=True)
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_to)
    print(f"Extraction completed. Total files: {len(os.listdir(extract_to))}")

def main():
    base_dir = "data"
    raw_dir = os.path.join(base_dir, "raw")
    processed_dir = os.path.join(base_dir, "processed")
    
    # Clean up existing directories to avoid stale data
    for d in [raw_dir, processed_dir]:
        if os.path.exists(d):
            print(f"Cleaning existing directory: {d}")
            shutil.rmtree(d)
            
    os.makedirs(raw_dir, exist_ok=True)
    
    # Dynamically find all zip files in Dataset/
    for file_name in os.listdir(base_dir):
        if file_name.lower().endswith(".zip"):
            zip_path = os.path.join(base_dir, file_name)
            
            # Extract name by removing extension and '-samples' if present
            name = file_name[:-4] # Remove .zip
            if "-samples" in name:
                name = name.split("-samples")[0]
                
            extract_to = os.path.join(raw_dir, name)
            extract_zip(zip_path, extract_to)

if __name__ == "__main__":
    main()
