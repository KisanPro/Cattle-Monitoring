"""
config_loader.py
Loads config.yaml from the project root and resolves all relative paths
to absolute paths based on the project root directory.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import yaml


# ---------------------------------------------------------------------------
# Locate the project root (two levels up from src/utils/)
# ---------------------------------------------------------------------------
_PROJECT_ROOT = Path(__file__).resolve().parents[2]


def load_config(config_path: str | Path | None = None) -> dict[str, Any]:
    """Load and return the YAML config, resolving all path values to absolute.

    Args:
        config_path: Path to config.yaml. Defaults to ``<project_root>/config.yaml``.

    Returns:
        Dictionary with the full configuration.
    """
    if config_path is None:
        config_path = _PROJECT_ROOT / "config.yaml"

    config_path = Path(config_path)
    if not config_path.exists():
        raise FileNotFoundError(
            f"Config file not found: {config_path}\n"
            "Make sure config.yaml exists in the project root."
        )

    with open(config_path, "r", encoding="utf-8") as fh:
        cfg = yaml.safe_load(fh)

    # Resolve every path entry to an absolute Path
    for key, rel_path in cfg.get("paths", {}).items():
        cfg["paths"][key] = str(_PROJECT_ROOT / rel_path)

    return cfg


def get_project_root() -> Path:
    """Return the absolute project root directory."""
    return _PROJECT_ROOT


def resolve_weight_path(cfg: dict, weight_filename: str) -> Path:
    """Return absolute path to a weight file inside weights_dir."""
    return Path(cfg["paths"]["weights_dir"]) / weight_filename


# ---------------------------------------------------------------------------
# Convenience: single-call access
# ---------------------------------------------------------------------------
_cfg: dict[str, Any] | None = None


def get_config() -> dict[str, Any]:
    """Return the singleton config (loaded once, cached)."""
    global _cfg
    if _cfg is None:
        _cfg = load_config()
    return _cfg
