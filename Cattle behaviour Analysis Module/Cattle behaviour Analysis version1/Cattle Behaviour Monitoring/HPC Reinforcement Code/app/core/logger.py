import logging
import os
from pathlib import Path
from app.core.config import settings

def setup_logger():
    # Ensure log directory exists
    log_dir = Path(settings.log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)
    
    log_file = log_dir / "hub.log"
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            logging.StreamHandler()
        ]
    )
    
    logger = logging.getLogger("KisanHub")
    logger.info("📡 Hub Logging System Initialized.")
    return logger

# Custom FileHandler for Pydantic/Standard logging compatibility
class FileHeader(logging.FileHandler):
    def __init__(self, filename, mode='a', encoding=None, delay=False):
        super().__init__(os.fspath(filename), mode, encoding, delay)

def get_logger(name):
    return logging.getLogger(f"KisanHub.{name}")
