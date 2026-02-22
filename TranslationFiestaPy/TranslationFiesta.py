#!/usr/bin/env python3
"""Application entry point for TranslationFiestaPy."""

from __future__ import annotations

import platform
import sys
import tkinter as tk

from ui.main_window import TranslationFiesta

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
        root = tk.Tk()
        TranslationFiesta(root)
        root.mainloop()
    except KeyboardInterrupt:
        print("\nApplication interrupted by user")
        sys.exit(0)
    except Exception as error:
        print(f"Application error: {error}")
        sys.exit(1)


if __name__ == "__main__":
    main()
