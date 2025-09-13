#!/usr/bin/env python3
"""
settings_storage.py

Persistent storage for user preferences and application settings.
Enhanced with comprehensive error handling and Result pattern.
"""

import json
import os
import platform
from pathlib import Path
from typing import Dict, Any, Optional, Union

from exceptions import (
    SettingsStorageError,
    FilePermissionError,
    FileNotFoundError as CustomFileNotFoundError,
    ValidationError,
    get_user_friendly_message,
)
from result import Result, Success, Failure
from enhanced_logger import get_logger


class SettingsStorage:
    """Persistent storage for application settings and user preferences."""

    def __init__(self, app_name: str = "TranslationFiesta"):
        self.app_name = app_name
        self.system = platform.system().lower()
        self._settings_file = self._get_settings_file_path()
        self._defaults = self._get_default_settings()
        self._settings = self._load_settings()

    def _get_settings_file_path(self) -> Path:
        """Get the path for settings file."""
        if self.system == "windows":
            base_dir = Path(os.environ.get("APPDATA", "~/.config"))
        elif self.system == "darwin":  # macOS
            base_dir = Path.home() / "Library" / "Preferences"
        else:  # Linux and others
            base_dir = Path.home() / ".config"

        base_dir.mkdir(parents=True, exist_ok=True)
        return base_dir / f"{self.app_name.lower()}_settings.json"

    def _get_default_settings(self) -> Dict[str, Any]:
        """Get default settings values."""
        return {
            "theme": "light",
            "window_geometry": "820x640",
            "use_official_api": False,
            "max_retries": 4,
            "timeout_seconds": 15,
            "auto_save_results": False,
            "last_file_directory": "",
            "font_size": 10,
            "show_line_numbers": False,
            "auto_copy_results": False,
            "language_pairs": ["en-ja", "ja-en"],
            "recent_files": []
        }

    def _load_settings_enhanced(self) -> Result[Dict[str, Any], SettingsStorageError]:
        """Load settings from file with enhanced error handling."""
        logger = get_logger()

        if not self._settings_file.exists():
            logger.debug("Settings file does not exist, using defaults", extra={
                "file_path": str(self._settings_file)
            })
            return Success(self._defaults.copy())

        try:
            with open(self._settings_file, 'r', encoding='utf-8') as f:
                loaded_settings = json.load(f)

            if not isinstance(loaded_settings, dict):
                error = SettingsStorageError(
                    message="Invalid settings file format",
                    code="INVALID_SETTINGS_FORMAT",
                    details="Settings file must contain a JSON object"
                )
                logger.error("Invalid settings file format", extra={
                    "file_path": str(self._settings_file),
                    "error": str(error)
                })
                return Failure(error)

            # Merge with defaults to ensure all keys exist
            settings = self._defaults.copy()
            settings.update(loaded_settings)

            logger.debug("Settings loaded successfully", extra={
                "file_path": str(self._settings_file),
                "settings_count": len(settings)
            })
            return Success(settings)

        except json.JSONDecodeError as e:
            error = SettingsStorageError(
                message="Failed to parse settings file",
                code="SETTINGS_PARSE_ERROR",
                details=f"JSON decode error: {e}"
            )
            logger.error("Failed to parse settings file", extra={
                "file_path": str(self._settings_file),
                "error": str(error)
            })
            return Failure(error)

        except PermissionError as e:
            error = FilePermissionError(str(self._settings_file), "read")
            logger.error("Permission denied reading settings file", extra={
                "file_path": str(self._settings_file),
                "error": str(error)
            })
            return Failure(error)

        except Exception as e:
            error = SettingsStorageError(
                message="Unexpected error loading settings",
                code="SETTINGS_LOAD_ERROR",
                details=str(e)
            )
            logger.error("Unexpected error loading settings", extra={
                "file_path": str(self._settings_file),
                "error": str(error)
            })
            return Failure(error)

    def _load_settings(self) -> Dict[str, Any]:
        """Legacy load method for backward compatibility."""
        result = self._load_settings_enhanced()
        return result.value if result.is_success() else self._defaults.copy()  # type: ignore

    def _save_settings_enhanced(self) -> Result[bool, SettingsStorageError]:
        """Save current settings to file with enhanced error handling."""
        logger = get_logger()

        try:
            # Validate settings before saving
            if not isinstance(self._settings, dict):
                error = SettingsStorageError(
                    message="Invalid settings format",
                    code="INVALID_SETTINGS_DATA",
                    details="Settings must be a dictionary"
                )
                return Failure(error)

            # Ensure directory exists
            self._settings_file.parent.mkdir(parents=True, exist_ok=True)

            with open(self._settings_file, 'w', encoding='utf-8') as f:
                json.dump(self._settings, f, indent=2, ensure_ascii=False)

            logger.debug("Settings saved successfully", extra={
                "file_path": str(self._settings_file),
                "settings_count": len(self._settings)
            })
            return Success(True)

        except PermissionError as e:
            error = FilePermissionError(str(self._settings_file), "write")
            logger.error("Permission denied writing settings file", extra={
                "file_path": str(self._settings_file),
                "error": str(error)
            })
            return Failure(error)

        except Exception as e:
            error = SettingsStorageError(
                message="Failed to save settings",
                code="SETTINGS_SAVE_ERROR",
                details=str(e)
            )
            logger.error("Failed to save settings", extra={
                "file_path": str(self._settings_file),
                "error": str(error)
            })
            return Failure(error)

    def _save_settings(self) -> bool:
        """Legacy save method for backward compatibility."""
        result = self._save_settings_enhanced()
        return result.is_success()

    def get(self, key: str, default: Any = None) -> Any:
        """
        Get a setting value.

        Args:
            key: Setting key
            default: Default value if key doesn't exist

        Returns:
            The setting value or default
        """
        return self._settings.get(key, default if default is not None else self._defaults.get(key))

    def set_enhanced(self, key: str, value: Any) -> Result[bool, SettingsStorageError]:
        """
        Set a setting value with enhanced error handling.

        Args:
            key: Setting key
            value: Value to set

        Returns:
            Result containing success status or detailed error
        """
        logger = get_logger()

        # Validate inputs
        if not key or not isinstance(key, str):
            error = ValidationError("Invalid setting key provided")
            logger.error("Settings set failed: invalid key", extra={
                "key": str(key),
                "error": str(error)
            })
            return Failure(error)

        try:
            self._settings[key] = value
            save_result = self._save_settings_enhanced()
            if save_result.is_failure():
                return Failure(save_result.error)  # type: ignore

            logger.debug("Setting updated successfully", extra={
                "key": key,
                "value_type": type(value).__name__
            })
            return Success(True)

        except Exception as e:
            error = SettingsStorageError(
                message="Failed to set setting value",
                code="SETTING_SET_ERROR",
                details=str(e)
            )
            logger.error("Failed to set setting", extra={
                "key": key,
                "error": str(error)
            })
            return Failure(error)

    def set(self, key: str, value: Any) -> bool:
        """Legacy set method for backward compatibility."""
        result = self.set_enhanced(key, value)
        return result.is_success()

    def update(self, settings_dict: Dict[str, Any]) -> bool:
        """
        Update multiple settings at once.

        Args:
            settings_dict: Dictionary of settings to update

        Returns:
            bool: True if successful, False otherwise
        """
        self._settings.update(settings_dict)
        return self._save_settings()

    def reset(self, key: Optional[str] = None) -> bool:
        """
        Reset setting(s) to default values.

        Args:
            key: Specific key to reset, or None to reset all settings

        Returns:
            bool: True if successful, False otherwise
        """
        if key is not None:
            if key in self._defaults:
                self._settings[key] = self._defaults[key]
            else:
                return False  # Key doesn't exist in defaults
        else:
            self._settings = self._defaults.copy()

        return self._save_settings()

    def get_all(self) -> Dict[str, Any]:
        """Get all current settings."""
        return self._settings.copy()

    def get_file_info(self) -> Dict[str, Any]:
        """Get information about the settings file."""
        return {
            "settings_file": str(self._settings_file),
            "file_exists": self._settings_file.exists(),
            "file_size": self._settings_file.stat().st_size if self._settings_file.exists() else 0,
            "platform": self.system
        }

    # Convenience methods for common settings
    def get_theme(self) -> str:
        """Get current theme setting."""
        return self.get("theme", "light")

    def set_theme(self, theme: str) -> bool:
        """Set theme setting."""
        if theme not in ["light", "dark"]:
            return False
        return self.set("theme", theme)

    def get_window_geometry(self) -> str:
        """Get window geometry setting."""
        return self.get("window_geometry", "820x640")

    def set_window_geometry(self, geometry: str) -> bool:
        """Set window geometry setting."""
        return self.set("window_geometry", geometry)

    def get_use_official_api(self) -> bool:
        """Get official API usage setting."""
        return self.get("use_official_api", False)

    def set_use_official_api(self, use_official: bool) -> bool:
        """Set official API usage setting."""
        return self.set("use_official_api", use_official)

    def add_recent_file(self, file_path: str, max_recent: int = 10) -> bool:
        """Add a file to recent files list."""
        recent_files = self.get("recent_files", [])
        if file_path in recent_files:
            recent_files.remove(file_path)
        recent_files.insert(0, file_path)
        recent_files = recent_files[:max_recent]
        return self.set("recent_files", recent_files)

    def get_recent_files(self) -> list:
        """Get list of recent files."""
        return self.get("recent_files", [])

    def clear_recent_files(self) -> bool:
        """Clear the recent files list."""
        return self.set("recent_files", [])


# Global instance for easy access
_settings_storage = None

def get_settings_storage() -> SettingsStorage:
    """Get the global settings storage instance."""
    global _settings_storage
    if _settings_storage is None:
        _settings_storage = SettingsStorage()
    return _settings_storage


# Convenience functions
def get_setting(key: str, default: Any = None) -> Any:
    """Get a setting value."""
    return get_settings_storage().get(key, default)


def set_setting(key: str, value: Any) -> bool:
    """Set a setting value."""
    return get_settings_storage().set(key, value)


def get_theme() -> str:
    """Get current theme."""
    return get_settings_storage().get_theme()


def set_theme(theme: str) -> bool:
    """Set theme."""
    return get_settings_storage().set_theme(theme)


if __name__ == "__main__":
    # Test the settings storage
    settings = SettingsStorage()

    print("Settings Storage Test")
    print("=" * 50)
    print(json.dumps(settings.get_file_info(), indent=2))

    print(f"\nCurrent theme: {settings.get_theme()}")
    print(f"Setting theme to dark: {settings.set_theme('dark')}")
    print(f"New theme: {settings.get_theme()}")

    print(f"\nWindow geometry: {settings.get_window_geometry()}")
    print(f"Setting geometry: {settings.set_window_geometry('1024x768')}")
    print(f"New geometry: {settings.get_window_geometry()}")

    print(f"\nAll settings: {json.dumps(settings.get_all(), indent=2)}")