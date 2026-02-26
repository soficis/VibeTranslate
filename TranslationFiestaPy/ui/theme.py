"""Unified dark theme configuration for the TranslationFiesta Tkinter UI."""

from __future__ import annotations


def build_themes() -> dict[str, dict[str, str]]:
    return {
        "dark": {
            "bg": "#0F1419",
            "fg": "#E8ECF1",
            "text_bg": "#1A1F2E",
            "text_fg": "#E8ECF1",
            "button_bg": "#242A38",
            "button_fg": "#E8ECF1",
            "label_bg": "#0F1419",
            "label_fg": "#8B95A5",
            "accent": "#3B82F6",
            "accent_hover": "#2563EB",
            "accent_fg": "#FFFFFF",
            "border": "#2E3648",
            "amber": "#F59E0B",
            "green": "#10B981",
            "red": "#EF4444",
        },
        "light": {
            "bg": "#F8FAFC",
            "fg": "#1E293B",
            "text_bg": "#FFFFFF",
            "text_fg": "#1E293B",
            "button_bg": "#E2E8F0",
            "button_fg": "#1E293B",
            "label_bg": "#F8FAFC",
            "label_fg": "#64748B",
            "accent": "#3B82F6",
            "accent_hover": "#2563EB",
            "accent_fg": "#FFFFFF",
            "border": "#CBD5E1",
            "amber": "#F59E0B",
            "green": "#10B981",
            "red": "#EF4444",
        },
    }


def toggle_button_label(current_theme: str) -> str:
    return "☀️ Light" if current_theme == "dark" else "🌙 Dark"
