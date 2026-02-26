#!/usr/bin/env python3
"""Application entry point for TranslationFiestaPy."""

from __future__ import annotations

import platform
import sys
import tkinter as tk
import traceback
from datetime import datetime, timezone
from tkinter import messagebox

from app_paths import get_logs_dir

if platform.system() == "Windows":
    import ctypes


def main() -> None:
    """Run the TranslationFiesta desktop application."""
    if platform.system() == "Windows":
        try:
            ctypes.windll.shcore.SetProcessDpiAwareness(1)
        except Exception as error:  # pragma: no cover - platform-specific safeguard
            print(f"Warning: Could not set DPI awareness: {error}")

    try:
        from ui.main_window import TranslationFiesta

        root = tk.Tk()
        TranslationFiesta(root)
        root.mainloop()
    except KeyboardInterrupt:
        print("\nApplication interrupted by user")
        sys.exit(0)
    except Exception as error:
        details = traceback.format_exc()
        log_path = write_startup_error_log(details)
        message = f"Application error: {error}"
        if log_path:
            message = f"{message}\n\nSee log: {log_path}"
        show_startup_error(message)
        print(message)
        sys.exit(1)


def write_startup_error_log(details: str) -> str:
    """Persist startup errors so windowed builds can be diagnosed."""
    try:
        log_path = get_logs_dir() / "startup_error.log"
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(f"\n[{datetime.now(timezone.utc).isoformat()}] Startup failure\n{details}\n")
        return str(log_path)
    except Exception:
        return ""


def show_startup_error(message: str) -> None:
    """Display startup failures even when running as a windowed executable."""
    dialog_root: tk.Tk | None = None
    try:
        dialog_root = tk.Tk()
        dialog_root.withdraw()
        messagebox.showerror("TranslationFiesta Python Startup Error", message, parent=dialog_root)
    except Exception:
        pass
    finally:
        if dialog_root is not None:
            try:
                dialog_root.destroy()
            except Exception:
                pass


if __name__ == "__main__":
    main()
