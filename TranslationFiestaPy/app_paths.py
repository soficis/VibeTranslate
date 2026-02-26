#!/usr/bin/env python3
"""Portable runtime paths for TranslationFiestaPy."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def _default_app_root() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def get_data_root() -> Path:
    override = os.environ.get("TF_APP_HOME", "").strip()
    data_root = Path(override).expanduser() if override else (_default_app_root() / "data")
    data_root.mkdir(parents=True, exist_ok=True)
    return data_root


def get_logs_dir() -> Path:
    logs_dir = get_data_root() / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    return logs_dir


def get_exports_dir() -> Path:
    exports_dir = get_data_root() / "exports"
    exports_dir.mkdir(parents=True, exist_ok=True)
    return exports_dir


def get_settings_file() -> Path:
    return get_data_root() / "settings.json"


def get_tm_cache_file() -> Path:
    return get_data_root() / "tm_cache.json"
