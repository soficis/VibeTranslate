#!/usr/bin/env python3
"""Application entry point for TranslationFiestaPy (PySide6)."""

from __future__ import annotations

import sys
import traceback
import platform
from datetime import datetime, timezone

# PySide6 Imports
from PySide6.QtWidgets import QApplication, QMessageBox
from PySide6.QtCore import Qt

from app_paths import get_logs_dir

def main() -> None:
    """Run the TranslationFiesta desktop application using PySide6."""
    # Logic for macOS high-DPI scaling is handled by Qt 6 automatically.
    # However, we can set some attributes if needed for cross-platform consistency.
    if platform.system() == "Windows":
        # Enable dynamic DPI scaling
        try:
            from ctypes import windll
            windll.shcore.SetProcessDpiAwareness(1)
        except Exception:
            pass

    app = QApplication(sys.argv)
    app.setApplicationName("TranslationFiesta")
    app.setOrganizationName("VibeTranslate")
    
    # Set high DPI attributes (Qt 6 enables these by default, but let's be explicit)
    app.setAttribute(Qt.AA_EnableHighDpiScaling)
    app.setAttribute(Qt.AA_UseHighDpiPixmaps)

    try:
        from ui.qt_window import QtTranslationFiesta

        window = QtTranslationFiesta()
        window.show()
        
        sys.exit(app.exec())

    except Exception as error:
        details = traceback.format_exc()
        log_path = write_startup_error_log(details)
        message = f"Application error: {error}"
        if log_path:
            message = f"{message}\n\nSee log: {log_path}"
        
        show_startup_error(message)
        print(details)
        sys.exit(1)

def write_startup_error_log(details: str) -> str:
    """Persist startup errors so windowed builds can be diagnosed."""
    try:
        log_dir = get_logs_dir()
        log_dir.mkdir(parents=True, exist_ok=True)
        log_path = log_dir / "startup_error.log"
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(f"\n[{datetime.now(timezone.utc).isoformat()}] Startup failure\n{details}\n")
        return str(log_path)
    except Exception:
        return ""

def show_startup_error(message: str) -> None:
    """Display startup failures using a native QMessageBox."""
    # We may need a temp app if the main one crashed
    temp_app = QApplication.instance() or QApplication(sys.argv)
    QMessageBox.critical(None, "TranslationFiesta Startup Error", message)

if __name__ == "__main__":
    main()
