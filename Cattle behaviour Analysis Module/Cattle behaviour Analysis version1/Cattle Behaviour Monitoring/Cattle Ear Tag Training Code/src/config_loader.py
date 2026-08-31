import os
from pathlib import Path
from typing import Any, Dict
import yaml


def get_project_root() -> Path:
    """Returns the absolute root directory path of the project."""
    return Path(__file__).resolve().parent.parent


def load_config(config_path: str = None) -> Dict[str, Any]:
    """
    Loads YAML configuration and resolves relative paths to absolute paths.
    
    Args:
        config_path: Path to config.yaml (optional, defaults to config/config.yaml)
        
    Returns:
        Dictionary containing project configurations.
    """
    project_root = get_project_root()
    
    if config_path is None:
        config_path = project_root / "config" / "config.yaml"
    else:
        config_path = Path(config_path)
        if not config_path.is_absolute():
            config_path = project_root / config_path

    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")

    with open(config_path, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)

    # Resolve paths in config to absolute paths based on project root
    if "paths" in config:
        for key, val in config["paths"].items():
            if isinstance(val, str) and not os.path.isabs(val):
                config["paths"][key] = str((project_root / val).resolve())
                
    if "training" in config and "data" in config["training"]:
        data_path = config["training"]["data"]
        if isinstance(data_path, str) and not os.path.isabs(data_path):
            config["training"]["data"] = str((project_root / data_path).resolve())

    return config
