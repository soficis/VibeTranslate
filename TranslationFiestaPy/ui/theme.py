"""Theme configuration for the TranslationFiesta Tkinter UI."""

from __future__ import annotations


def build_themes() -> dict[str, dict[str, str]]:
    return {
        "light": {
            "bg": "#f0f0f0",
            "fg": "#000000",
            "text_bg": "#ffffff",
            "text_fg": "#000000",
            "button_bg": "#e0e0e0",
            "button_fg": "#000000",
            "label_bg": "#f0f0f0",
            "label_fg": "#000000",
        },
        "dark": {
            "bg": "#2b2b2b",
            "fg": "#ffffff",
            "text_bg": "#3c3c3c",
            "text_fg": "#ffffff",
            "button_bg": "#4a4a4a",
            "button_fg": "#ffffff",
            "label_bg": "#2b2b2b",
            "label_fg": "#ffffff",
        },
    }


def toggle_button_label(current_theme: str) -> str:
    return "☀️ Light" if current_theme == "dark" else "🌙 Dark"
