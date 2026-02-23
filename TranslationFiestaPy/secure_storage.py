#!/usr/bin/env python3
"""
secure_storage.py

Platform-specific secure storage for API keys.
"""

from __future__ import annotations

import platform
from typing import Any, Dict, Optional, TypeVar

try:
    import keyring
    import keyring.errors
    KEYRING_AVAILABLE = True
except ImportError:
    keyring = None  # type: ignore[assignment]
    KEYRING_AVAILABLE = False

from enhanced_logger import get_logger
from exceptions import SecureStorageError
from result import Failure, Result, Success

T = TypeVar("T")


class SecureStorage:
    """Cross-platform secure storage backed only by keyring."""

    def __init__(self, service_name: str = "TranslationFiesta"):
        self.service_name = service_name
        self.system = platform.system().lower()
        self._keyring_available = self._check_keyring_availability()

    def _check_keyring_availability(self) -> bool:
        """Check if keyring is installed and can store/retrieve values."""
        if not KEYRING_AVAILABLE:
            return False

        logger = get_logger()
        test_key = "__tf_secure_storage_test_key__"
        test_value = "__tf_secure_storage_test_value__"

        try:
            keyring.set_password(self.service_name, test_key, test_value)  # type: ignore[union-attr]
            retrieved = keyring.get_password(self.service_name, test_key)  # type: ignore[union-attr]
            try:
                keyring.delete_password(self.service_name, test_key)  # type: ignore[union-attr]
            except keyring.errors.PasswordDeleteError:  # type: ignore[union-attr]
                logger.debug("SecureStorage test key already deleted", extra={"service_name": self.service_name})
            return retrieved == test_value
        except keyring.errors.KeyringError as error:  # type: ignore[union-attr]
            logger.warning("SecureStorage keyring backend unavailable", extra={
                "service_name": self.service_name,
                "error_type": type(error).__name__,
                "error": str(error),
            })
            return False

    def _keyring_unavailable_error(self) -> SecureStorageError:
        details = (
            "Install and configure a supported keyring backend. "
            "Linux users typically need SecretService (e.g. gnome-keyring) and the Python keyring package."
        )
        if not KEYRING_AVAILABLE:
            details = (
                "Python package 'keyring' is not installed. "
                "Install it with: pip install keyring"
            )

        return SecureStorageError(
            message="Secure storage is unavailable on this system",
            code="KEYRING_UNAVAILABLE",
            details=details,
        )

    def _require_keyring(self) -> Result[None, SecureStorageError]:
        if not KEYRING_AVAILABLE or not self._keyring_available:
            return Failure(self._keyring_unavailable_error())
        return Success(None)

    def store_api_key(self, key_name: str, api_key: str) -> Result[bool, SecureStorageError]:
        """Store an API key securely using the configured keyring backend."""
        logger = get_logger()

        if not key_name or not isinstance(key_name, str):
            return Failure(
                SecureStorageError(
                    message="Invalid key name provided",
                    code="INVALID_KEY_NAME",
                    details="Key name must be a non-empty string",
                )
            )

        if not api_key or not api_key.strip():
            return Failure(
                SecureStorageError(
                    message="Invalid API key provided",
                    code="INVALID_API_KEY",
                    details="API key must be a non-empty string",
                )
            )

        availability = self._require_keyring()
        if availability.is_failure():
            return Failure(availability.error)  # type: ignore[arg-type]

        try:
            keyring.set_password(self.service_name, key_name, api_key.strip())  # type: ignore[union-attr]
            logger.info("API key stored in keyring", extra={
                "service_name": self.service_name,
                "key_name": key_name,
            })
            return Success(True)
        except keyring.errors.KeyringError as error:  # type: ignore[union-attr]
            storage_error = SecureStorageError(
                message="Failed to store API key in keyring",
                code="KEYRING_WRITE_FAILED",
                details=str(error),
            )
            logger.error("Secure storage write failed", extra={
                "service_name": self.service_name,
                "key_name": key_name,
                "error": str(storage_error),
            })
            return Failure(storage_error)

    def get_api_key(self, key_name: str) -> Result[Optional[str], SecureStorageError]:
        """Retrieve an API key from keyring-backed secure storage."""
        availability = self._require_keyring()
        if availability.is_failure():
            return Failure(availability.error)  # type: ignore[arg-type]

        try:
            value = keyring.get_password(self.service_name, key_name)  # type: ignore[union-attr]
            return Success(value)
        except keyring.errors.KeyringError as error:  # type: ignore[union-attr]
            return Failure(
                SecureStorageError(
                    message="Failed to retrieve API key from keyring",
                    code="KEYRING_READ_FAILED",
                    details=str(error),
                )
            )

    def delete_api_key(self, key_name: str) -> Result[bool, SecureStorageError]:
        """Delete an API key from keyring-backed secure storage."""
        availability = self._require_keyring()
        if availability.is_failure():
            return Failure(availability.error)  # type: ignore[arg-type]

        try:
            keyring.delete_password(self.service_name, key_name)  # type: ignore[union-attr]
            return Success(True)
        except keyring.errors.PasswordDeleteError:  # type: ignore[union-attr]
            return Success(False)
        except keyring.errors.KeyringError as error:  # type: ignore[union-attr]
            return Failure(
                SecureStorageError(
                    message="Failed to delete API key from keyring",
                    code="KEYRING_DELETE_FAILED",
                    details=str(error),
                )
            )

    def get_storage_info(self) -> Dict[str, Any]:
        """Get information about secure storage backend status."""
        return {
            "platform": self.system,
            "keyring_available": self._keyring_available,
            "keyring_library_available": KEYRING_AVAILABLE,
            "service_name": self.service_name,
        }


_secure_storage: Optional[SecureStorage] = None


def get_secure_storage() -> SecureStorage:
    """Get the global secure storage instance."""
    global _secure_storage
    if _secure_storage is None:
        _secure_storage = SecureStorage()
    return _secure_storage


def _unwrap_result(result: Result[T, SecureStorageError]) -> T:
    if result.is_failure():
        raise result.error  # type: ignore[misc]
    return result.value  # type: ignore[misc]


def store_api_key(key_name: str, api_key: str) -> bool:
    """Store an API key or raise SecureStorageError on failure."""
    return bool(_unwrap_result(get_secure_storage().store_api_key(key_name, api_key)))


def get_api_key(key_name: str) -> Optional[str]:
    """Retrieve an API key or raise SecureStorageError on failure."""
    return _unwrap_result(get_secure_storage().get_api_key(key_name))


def delete_api_key(key_name: str) -> bool:
    """Delete an API key or raise SecureStorageError on failure."""
    return bool(_unwrap_result(get_secure_storage().delete_api_key(key_name)))


def store_api_key_enhanced(key_name: str, api_key: str) -> Result[bool, SecureStorageError]:
    """Store an API key and return a Result."""
    return get_secure_storage().store_api_key(key_name, api_key)


def get_api_key_enhanced(key_name: str) -> Result[Optional[str], SecureStorageError]:
    """Retrieve an API key and return a Result."""
    return get_secure_storage().get_api_key(key_name)


def delete_api_key_enhanced(key_name: str) -> Result[bool, SecureStorageError]:
    """Delete an API key and return a Result."""
    return get_secure_storage().delete_api_key(key_name)


if __name__ == "__main__":
    storage = SecureStorage()
    print("Secure Storage Test")
    print("=" * 50)
    print(storage.get_storage_info())
