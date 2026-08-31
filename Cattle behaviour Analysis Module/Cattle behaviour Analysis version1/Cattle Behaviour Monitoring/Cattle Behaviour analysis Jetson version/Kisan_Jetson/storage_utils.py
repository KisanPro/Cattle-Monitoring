import os
import json
import getpass

def load_config_raw(script_dir):
    config_file = os.path.join(script_dir, "config.json")
    try:
        with open(config_file) as f:
            return json.load(f)
    except Exception:
        return {}

def get_base_storage(script_dir):
    config = load_config_raw(script_dir)
    uname = str(config.get("user_name", "User")).replace(" ", "_")
    phone = str(config.get("phone", "Phone")).replace(" ", "_")
    fname = str(config.get("farm_name", "Farm")).replace(" ", "_")
    folder_prefix = f"{uname}_{phone}_{fname}"
    
    # 1. Custom path from config
    custom_path = config.get("storage_path")
    if custom_path:
        return os.path.join(custom_path, folder_prefix)
        
    # 2. Default developer path
    dev_path = "/media/mr/My Passport/KisanPro_Storage"
    if os.path.exists(dev_path) and os.access(os.path.dirname(dev_path), os.W_OK):
        return os.path.join(dev_path, folder_prefix)
        
    # 3. Dynamic scan for other media mounts on Linux
    if os.name != "nt":
        try:
            username = getpass.getuser()
            user_media = f"/media/{username}"
            if os.path.exists(user_media):
                for drive in os.listdir(user_media):
                    drive_path = os.path.join(user_media, drive, "KisanPro_Storage")
                    parent = os.path.dirname(drive_path)
                    if os.path.exists(parent) and os.access(parent, os.W_OK):
                        return os.path.join(user_media, drive, "KisanPro_Storage", folder_prefix)
        except Exception:
            pass
            
    # 4. Fallback to user home directory
    home_dir = os.path.expanduser("~")
    return os.path.join(home_dir, "KisanPro_Storage", folder_prefix)
