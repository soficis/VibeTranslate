#!/usr/bin/env python3
"""
secure_storage.py

Platform-specific secure storage for API keys and sensitive data.
Enhanced with comprehensive error handling and Result pattern.
"""

import json
import os
import platform
import sys
from pathlib import Path
from typing import Optional, Dict, Any

try:
    import keyring
    import keyring.errors
    KEYRING_AVAILABLE = True
except ImportError:
    KEYRING_AVAILABLE = False

from exceptions import (
    SecureStorageError,
    EncryptionError,
    FilePermissionError,
    FileNotFoundError as CustomFileNotFoundError,
    get_user_friendly_message,
)
from result import Result, Success, Failure
from enhanced_logger import get_logger


class SecureStorage:
    """Cross-platform secure storage for sensitive data like API keys."""

    def __init__(self, service_name: str = "TranslationFiesta"):
        self.service_name = service_name
        self.system = platform.system().lower()
        self._fallback_file = self._get_fallback_file_path()

        # Check if keyring backend is available
        self._keyring_available = self._check_keyring_availability()

    def _get_fallback_file_path(self) -> Path:
        """Get the path for fallback storage file."""
        if self.system == "windows":
            base_dir = Path(os.environ.get("APPDATA", "~/.config"))
        elif self.system == "darwin":  # macOS
            base_dir = Path.home() / "Library" / "Application Support"
        else:  # Linux and others
            base_dir = Path.home() / ".config"

        base_dir.mkdir(parents=True, exist_ok=True)
        return base_dir / f"{self.service_name.lower()}_secure.json"

    def _check_keyring_availability(self) -> bool:
        """Check if keyring is available and working."""
        if not KEYRING_AVAILABLE:
            return False

        try:
            # Test keyring functionality
            test_key = "__test_key__"
            test_value = "__test_value__"

            keyring.set_password(self.service_name, test_key, test_value)
            retrieved = keyring.get_password(self.service_name, test_key)

            # Clean up test data
            try:
                keyring.delete_password(self.service_name, test_key)
            except:
                pass

            return retrieved == test_value

        except (keyring.errors.KeyringError, Exception):
            return False

    def store_api_key(self, key_name: str, api_key: str) -> Result[bool, SecureStorageError]:
        """
        Store an API key securely with comprehensive error handling.

        Args:
            key_name: Identifier for the API key (e.g., 'google_translate')
            api_key: The API key to store

        Returns:
            Result containing success status or detailed error
        """
        logger = get_logger()

        # Validate inputs
        if not key_name or not isinstance(key_name, str):
            error = SecureStorageError(
                message="Invalid key name provided",
                code="INVALID_KEY_NAME",
                details="Key name must be a non-empty string"
            )
            logger.error("API key storage failed: invalid key name", extra={
                "key_name": str(key_name),
                "error": str(error)
            })
            return Failure(error)

        if not api_key or not api_key.strip():
            error = SecureStorageError(
                message="Invalid API key provided",
                code="INVALID_API_KEY",
                details="API key must be a non-empty string"
            )
            logger.error("API key storage failed: invalid API key", extra={
                "key_name": key_name,
                "error": str(error)
            })
            return Failure(error)

        api_key_clean = api_key.strip()

        try:
            if self._keyring_available:
                keyring.set_password(self.service_name, key_name, api_key_clean)
                logger.info("API key stored successfully in keyring", extra={
                    "key_name": key_name,
                    "storage_type": "keyring"
                })
                return Success(True)
            else:
                fallback_result = self._store_fallback_enhanced(key_name, api_key_clean)
                if fallback_result.is_success():
                    logger.info("API key stored successfully in fallback storage", extra={
                        "key_name": key_name,
                        "storage_type": "fallback"
                    })
                    return Success(True)
                else:
                    return Failure(fallback_result.error)  # type: ignore

        except keyring.errors.KeyringError as e:
            logger.warning("Keyring storage failed, attempting fallback", extra={
                "key_name": key_name,
                "keyring_error": str(e)
            })
            # Try fallback storage
            fallback_result = self._store_fallback_enhanced(key_name, api_key_clean)
            if fallback_result.is_success():
                logger.info("API key stored successfully in fallback after keyring failure", extra={
                    "key_name": key_name,
                    "storage_type": "fallback_fallback"
                })
                return Success(True)
            else:
                error = SecureStorageError(
                    message="Failed to store API key in both keyring and fallback storage",
                    code="STORAGE_FAILED",
                    details=f"Keyring error: {e}, Fallback error: {fallback_result.error}"
                )
                return Failure(error)

        except Exception as e:
            error = SecureStorageError(
                message="Unexpected error during API key storage",
                code="UNEXPECTED_ERROR",
                details=str(e)
            )
            logger.error("Unexpected error in API key storage", extra={
                "key_name": key_name,
                "error": str(error)
            })
            return Failure(error)

    def get_api_key(self, key_name: str) -> Optional[str]:
        """
        Retrieve an API key from secure storage.

        Args:
            key_name: Identifier for the API key

        Returns:
            The API key if found, None otherwise
        """
        try:
            if self._keyring_available:
                api_key = keyring.get_password(self.service_name, key_name)
                return api_key
            else:
                return self._get_fallback(key_name)
        except Exception:
            # Try fallback if keyring fails
            return self._get_fallback(key_name)

    def delete_api_key(self, key_name: str) -> bool:
        """
        Delete an API key from secure storage.

        Args:
            key_name: Identifier for the API key

        Returns:
            bool: True if successful, False otherwise
        """
        try:
            if self._keyring_available:
                keyring.delete_password(self.service_name, key_name)
                return True
            else:
                return self._delete_fallback(key_name)
        except Exception:
            # Try fallback if keyring fails
            return self._delete_fallback(key_name)

    def _store_fallback_enhanced(self, key_name: str, value: str) -> Result[bool, SecureStorageError]:
        """Store data in fallback file storage with enhanced error handling."""
        logger = get_logger()

        try:
            data = self._load_fallback_data_enhanced()
            if data.is_failure():
                return Failure(data.error)  # type: ignore

            data.value[key_name] = value  # type: ignore
            save_result = self._save_fallback_data_enhanced(data.value)  # type: ignore
            if save_result.is_failure():
                return Failure(save_result.error)  # type: ignore

            return Success(True)

        except Exception as e:
            error = SecureStorageError(
                message="Failed to store data in fallback storage",
                code="FALLBACK_STORE_FAILED",
                details=str(e)
            )
            logger.error("Fallback storage failed", extra={
                "key_name": key_name,
                "error": str(error)
            })
            return Failure(error)

    def _store_fallback(self, key_name: str, value: str) -> bool:
        """Legacy fallback method for backward compatibility."""
        result = self._store_fallback_enhanced(key_name, value)
        return result.is_success()

    def _get_fallback(self, key_name: str) -> Optional[str]:
        """Get data from fallback file storage."""
        try:
            data = self._load_fallback_data()
            return data.get(key_name)
        except Exception:
            return None

    def _delete_fallback(self, key_name: str) -> bool:
        """Delete data from fallback file storage."""
        try:
            data = self._load_fallback_data()
            if key_name in data:
                del data[key_name]
                self._save_fallback_data(data)
                return True
            return False
        except Exception:
            return False

    def _load_fallback_data_enhanced(self) -> Result[Dict[str, Any], SecureStorageError]:
        """Load data from fallback file with enhanced error handling."""
        logger = get_logger()

        if not self._fallback_file.exists():
            logger.debug("Fallback file does not exist, returning empty data")
            return Success({})

        try:
            with open(self._fallback_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            if not isinstance(data, dict):
                error = SecureStorageError(
                    message="Invalid fallback file format",
                    code="INVALID_FALLBACK_FORMAT",
                    details="Fallback file must contain a JSON object"
                )
                logger.error("Invalid fallback file format", extra={
                    "file_path": str(self._fallback_file),
                    "error": str(error)
                })
                return Failure(error)

            logger.debug("Fallback data loaded successfully", extra={
                "file_path": str(self._fallback_file),
                "keys_count": len(data)
            })
            return Success(data)

        except json.JSONDecodeError as e:
            error = SecureStorageError(
                message="Failed to parse fallback file",
                code="FALLBACK_PARSE_ERROR",
                details=f"JSON decode error: {e}"
            )
            logger.error("Failed to parse fallback file", extra={
                "file_path": str(self._fallback_file),
                "error": str(error)
            })
            return Failure(error)

        except PermissionError as e:
            error = FilePermissionError(str(self._fallback_file), "read")
            logger.error("Permission denied reading fallback file", extra={
                "file_path": str(self._fallback_file),
                "error": str(error)
            })
            return Failure(error)

        except Exception as e:
            error = SecureStorageError(
                message="Unexpected error loading fallback data",
                code="FALLBACK_LOAD_ERROR",
                details=str(e)
            )
            logger.error("Unexpected error loading fallback data", extra={
                "file_path": str(self._fallback_file),
                "error": str(error)
            })
            return Failure(error)

    def _save_fallback_data_enhanced(self, data: Dict[str, Any]) -> Result[None, SecureStorageError]:
        """Save data to fallback file with enhanced error handling."""
        logger = get_logger()

        try:
            # Ensure directory exists
            self._fallback_file.parent.mkdir(parents=True, exist_ok=True)

            # Validate data before saving
            if not isinstance(data, dict):
                error = SecureStorageError(
                    message="Invalid data format for fallback storage",
                    code="INVALID_DATA_FORMAT",
                    details="Data must be a dictionary"
                )
                return Failure(error)

            with open(self._fallback_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

            logger.debug("Fallback data saved successfully", extra={
                "file_path": str(self._fallback_file),
                "keys_count": len(data)
            })
            return Success(None)

        except PermissionError as e:
            error = FilePermissionError(str(self._fallback_file), "write")
            logger.error("Permission denied writing fallback file", extra={
                "file_path": str(self._fallback_file),
                "error": str(error)
            })
            return Failure(error)

        except Exception as e:
            error = SecureStorageError(
                message="Failed to save fallback data",
                code="FALLBACK_SAVE_ERROR",
                details=str(e)
            )
            logger.error("Failed to save fallback data", extra={
                "file_path": str(self._fallback_file),
                "error": str(error)
            })
            return Failure(error)

    def _load_fallback_data(self) -> Dict[str, Any]:
        """Legacy load method for backward compatibility."""
        result = self._load_fallback_data_enhanced()
        return result.value if result.is_success() else {}  # type: ignore

    def _save_fallback_data(self, data: Dict[str, Any]) -> None:
        """Legacy save method for backward compatibility."""
        result = self._save_fallback_data_enhanced(data)
        if result.is_failure():
            raise result.error  # type: ignore

    def get_storage_info(self) -> Dict[str, Any]:
        """Get information about the current storage configuration."""
        return {
            "platform": self.system,
            "keyring_available": self._keyring_available,
            "keyring_library_available": KEYRING_AVAILABLE,
            "fallback_file": str(self._fallback_file),
            "service_name": self.service_name
        }


# Global instance for easy access
_secure_storage = None

def get_secure_storage() -> SecureStorage:
    """Get the global secure storage instance."""
    global _secure_storage
    if _secure_storage is None:
        _secure_storage = SecureStorage()
    return _secure_storage


def store_api_key(key_name: str, api_key: str) -> bool:
    """Convenience function to store an API key (legacy for backward compatibility)."""
    result = get_secure_storage().store_api_key(key_name, api_key)
    return result.is_success()


def get_api_key(key_name: str) -> Optional[str]:
    """Convenience function to retrieve an API key."""
    return get_secure_storage().get_api_key(key_name)


def delete_api_key(key_name: str) -> bool:
    """Convenience function to delete an API key."""
    return get_secure_storage().delete_api_key(key_name)


# Enhanced versions with Result pattern
def store_api_key_enhanced(key_name: str, api_key: str) -> Result[bool, SecureStorageError]:
    """Enhanced convenience function to store an API key with detailed error handling."""
    return get_secure_storage().store_api_key(key_name, api_key)


def get_api_key_enhanced(key_name: str) -> Result[Optional[str], SecureStorageError]:
    """Enhanced convenience function to retrieve an API key with detailed error handling."""
    storage = get_secure_storage()
    try:
        api_key = storage.get_api_key(key_name)
        return Success(api_key)
    except Exception as e:
        error = SecureStorageError(
            message="Failed to retrieve API key",
            code="API_KEY_RETRIEVAL_FAILED",
            details=str(e)
        )
        return Failure(error)


def delete_api_key_enhanced(key_name: str) -> Result[bool, SecureStorageError]:
    """Enhanced convenience function to delete an API key with detailed error handling."""
    storage = get_secure_storage()
    try:
        success = storage.delete_api_key(key_name)
        return Success(success)
    except Exception as e:
        error = SecureStorageError(
            message="Failed to delete API key",
            code="API_KEY_DELETION_FAILED",
            details=str(e)
        )
        return Failure(error)


if __name__ == "__main__":
    # Test the secure storage
    storage = SecureStorage()

    print("Secure Storage Test")
    print("=" * 50)
    print(json.dumps(storage.get_storage_info(), indent=2))

    # Test API key storage
    test_key = "test_api_key"
    test_value = "sk-test123456789"

    print(f"\nStoring test API key: {store_api_key(test_key, test_value)}")
    print(f"Retrieving test API key: {get_api_key(test_key)}")
    print(f"Deleting test API key: {delete_api_key(test_key)}")
    print(f"Retrieving deleted API key: {get_api_key(test_key)}")