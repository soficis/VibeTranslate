"""Apple-Grade QSS (Qt Style Sheet) for TranslationFiesta PySide6."""

import platform
from PySide6.QtGui import QFont

def get_system_font(size: int, weight: QFont.Weight = QFont.Weight.Normal) -> QFont:
    """Return the system font based on the platform."""
    font = QFont()
    if platform.system() == "Darwin":
        font.setFamily(".AppleSystemUIFont")
    elif platform.system() == "Windows":
        font.setFamily("Segoe UI")
    else:
        font.setFamily("Helvetica Neue")
    
    font.setPointSize(size)
    font.setWeight(weight)
    return font

def get_qss(theme: str = "dark") -> str:
    """Return the global style sheet for the application."""
    if theme == "dark":
        colors = {
            "bg": "#1C1C1E",
            "surface": "#2C2C2E",
            "surface_hover": "#3A3A3C",
            "border": "#3A3A3C",
            "fg": "#FFFFFF",
            "fg_secondary": "#999999",
            "accent": "#0A84FF",
            "accent_hover": "#007AFF",
            "accent_fg": "#FFFFFF",
            "selection": "#0056B3",
        }
    else:
        colors = {
            "bg": "#F2F2F7",
            "surface": "#FFFFFF",
            "surface_hover": "#E5E5EA",
            "border": "#C7C7CC",
            "fg": "#000000",
            "fg_secondary": "#666666",
            "accent": "#007AFF",
            "accent_hover": "#0056B3",
            "accent_fg": "#FFFFFF",
            "selection": "#B3D7FF",
        }

    return f"""
    QMainWindow, QDialog {{
        background-color: {colors["bg"]};
        color: {colors["fg"]};
    }}

    QWidget {{
        color: {colors["fg"]};
    }}

    /* Global Label Styling */
    QLabel {{
        background: transparent;
    }}

    .HeaderLabel {{
        font-size: 18px;
        font-weight: bold;
    }}

    .SmallLabel {{
        font-size: 11px;
        color: {colors["fg_secondary"]};
        text-transform: uppercase;
    }}

    /* Buttons */
    QPushButton {{
        background-color: {colors["surface"]};
        border: none;
        border-radius: 6px;
        padding: 8px 16px;
        font-size: 13px;
    }}

    QPushButton:hover {{
        background-color: {colors["surface_hover"]};
    }}

    QPushButton:pressed {{
        background-color: {colors["border"]};
    }}

    .PrimaryButton {{
        background-color: {colors["accent"]};
        color: {colors["accent_fg"]};
        font-weight: bold;
    }}

    .PrimaryButton:hover {{
        background-color: {colors["accent_hover"]};
    }}

    /* Text Inputs */
    QTextEdit, QPlainTextEdit {{
        background-color: {colors["surface"]};
        border: 1px solid {colors["border"]};
        border-radius: 8px;
        gridline-color: transparent;
        padding: 8px;
        selection-background-color: {colors["selection"]};
        font-size: 14px;
    }}

    /* Combobox */
    QComboBox {{
        background-color: {colors["surface"]};
        border: 1px solid {colors["border"]};
        border-radius: 6px;
        padding: 4px 12px;
        min-width: 150px;
    }}

    QComboBox::drop-down {{
        border: none;
        width: 20px;
    }}

    QComboBox QAbstractItemView {{
        background-color: {colors["surface"]};
        border: 1px solid {colors["border"]};
        selection-background-color: {colors["accent"]};
    }}

    /* Scrollbars (Sleek Minimal Design) */
    QScrollBar:vertical {{
        border: none;
        background: transparent;
        width: 8px;
        margin: 0px;
    }}

    QScrollBar::handle:vertical {{
        background: {colors["border"]};
        min-height: 20px;
        border-radius: 4px;
    }}

    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
        height: 0px;
    }}

    /* Progress Bar */
    QProgressBar {{
        background-color: {colors["surface"]};
        border: none;
        border-radius: 4px;
        text-align: center;
        height: 8px;
    }}

    QProgressBar::chunk {{
        background-color: {colors["accent"]};
        border-radius: 4px;
    }}
    """
