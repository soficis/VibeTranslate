#!/usr/bin/env python3
"""
app_logger.py

Thread-safe logging configured for this application.
Writes to translationfiesta.log in the working directory.
"""

from __future__ import annotations

import logging
import os
import threading
from logging.handlers import RotatingFileHandler
from typing import Optional

from app_paths import get_logs_dir

DEFAULT_LOG_FILE = str(get_logs_dir() / "translationfiesta.log")


def create_logger(name: str = "translationfiesta", log_file: Optional[str] = None) -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    logger.setLevel(logging.INFO)

    file_path = log_file or DEFAULT_LOG_FILE
    os.makedirs(os.path.dirname(file_path) or ".", exist_ok=True)

    file_handler = RotatingFileHandler(file_path, maxBytes=512_000, backupCount=2, encoding="utf-8")
    formatter = logging.Formatter(fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
    file_handler.setFormatter(formatter)
    file_handler.setLevel(logging.INFO)
    file_handler.setLock(threading.Lock())

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.WARNING)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    logger.propagate = False
    return logger


