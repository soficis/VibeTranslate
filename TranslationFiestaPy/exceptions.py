#!/usr/bin/env python3
"""
exceptions.py

Custom exception classes and error taxonomy for TranslationFiestaPy.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional


class TranslationFiestaError(Exception):
    """Base exception class for all TranslationFiesta errors"""

    def __init__(
        self,
        message: str,
        code: Optional[str] = None,
        details: Optional[str] = None,
        timestamp: Optional[datetime] = None
    ):
        super().__init__(message)
        self.message = message
        self.code = code
        self.details = details
        self.timestamp = timestamp or datetime.now(timezone.utc)

    def __str__(self) -> str:
        parts = [self.message]
        if self.code:
            parts.append(f"(Code: {self.code})")
        if self.details:
            parts.append(f"Details: {self.details}")
        return " ".join(parts)

    def to_dict(self) -> dict:
        """Convert exception to dictionary for logging/serialization"""
        return {
            "type": self.__class__.__name__,
            "message": self.message,
            "code": self.code,
            "details": self.details,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
        }


# Network-related exceptions
class NetworkError(TranslationFiestaError):
    """Base class for network-related errors"""
    pass


class HttpError(NetworkError):
    """HTTP request/response errors"""

    def __init__(
        self,
        status_code: int,
        message: str,
        response_body: Optional[str] = None,
        headers: Optional[dict] = None,
        **kwargs
    ):
        super().__init__(
            message=f"HTTP {status_code}: {message}",
            code=f"HTTP_{status_code}",
            details=response_body,
            **kwargs
        )
        self.status_code = status_code
        self.response_body = response_body
        self.headers = headers or {}


class ConnectionError(NetworkError):
    """Network connection errors"""
    pass


class TimeoutError(NetworkError):
    """Request timeout errors"""
    pass


class SSLError(NetworkError):
    """SSL/TLS related errors"""
    pass


# Translation-related exceptions
class TranslationError(TranslationFiestaError):
    """Base class for translation-related errors"""
    pass


class TranslationServiceError(TranslationError):
    """Translation service specific errors"""
    pass


class RateLimitedError(TranslationServiceError):
    """Provider rate limiting errors"""

    def __init__(self, retry_after: Optional[int] = None, details: Optional[str] = None, **kwargs):
        super().__init__(
            message="Provider rate limited",
            code="rate_limited",
            details=details,
            **kwargs
        )
        self.retry_after = retry_after


class BlockedError(TranslationServiceError):
    """Provider blocked or captcha errors"""

    def __init__(self, details: Optional[str] = None, **kwargs):
        super().__init__(
            message="Provider blocked or captcha detected",
            code="blocked",
            details=details,
            **kwargs
        )


class InvalidTranslationResponseError(TranslationError):
    """Invalid response from translation service"""

    def __init__(self, details: str, **kwargs):
        super().__init__(
            message="Invalid response format from translation service",
            code="invalid_response",
            details=details,
            **kwargs
        )


class NoTranslationFoundError(TranslationError):
    """No translation found in response"""

    def __init__(self, **kwargs):
        super().__init__(
            message="No translation found in response",
            code="NO_TRANSLATION",
            **kwargs
        )


class UnsupportedLanguageError(TranslationError):
    """Unsupported language code"""

    def __init__(self, language_code: str, **kwargs):
        super().__init__(
            message=f"Unsupported language code: {language_code}",
            code="UNSUPPORTED_LANGUAGE",
            details=f"Language '{language_code}' is not supported",
            **kwargs
        )
        self.language_code = language_code


# File operation exceptions
class FileError(TranslationFiestaError):
    """Base class for file-related errors"""
    pass


class FileNotFoundError(FileError):
    """File not found"""

    def __init__(self, file_path: str, **kwargs):
        super().__init__(
            message=f"File not found: {file_path}",
            code="FILE_NOT_FOUND",
            details=f"The file '{file_path}' does not exist",
            **kwargs
        )
        self.file_path = file_path


class FilePermissionError(FileError):
    """File permission errors"""

    def __init__(self, file_path: str, operation: str, **kwargs):
        super().__init__(
            message=f"Permission denied for file operation: {operation}",
            code="PERMISSION_DENIED",
            details=f"Cannot {operation} file '{file_path}' due to insufficient permissions",
            **kwargs
        )
        self.file_path = file_path
        self.operation = operation


class FileFormatError(FileError):
    """Invalid file format errors"""

    def __init__(
        self,
        file_path: str,
        expected_format: str,
        actual_format: Optional[str] = None,
        **kwargs
    ):
        details = f"Expected format: {expected_format}"
        if actual_format:
            details += f", got: {actual_format}"

        super().__init__(
            message=f"Invalid file format for {file_path}",
            code="INVALID_FORMAT",
            details=details,
            **kwargs
        )
        self.file_path = file_path
        self.expected_format = expected_format
        self.actual_format = actual_format


class FileSizeError(FileError):
    """File size related errors"""

    def __init__(
        self,
        file_path: str,
        actual_size: int,
        max_size: int,
        **kwargs
    ):
        super().__init__(
            message=f"File too large: {file_path}",
            code="FILE_TOO_LARGE",
            details=f"File size {actual_size} bytes exceeds maximum {max_size} bytes",
            **kwargs
        )
        self.file_path = file_path
        self.actual_size = actual_size
        self.max_size = max_size


# Storage-related exceptions
class StorageError(TranslationFiestaError):
    """Base class for storage-related errors"""
    pass


class SettingsStorageError(StorageError):
    """Settings storage specific errors"""
    pass


class EncryptionError(StorageError):
    """Encryption/decryption errors"""
    pass


# Application exceptions
class AppError(TranslationFiestaError):
    """Base class for application-level errors"""
    pass


class ConfigurationError(AppError):
    """Configuration-related errors"""
    pass


class InitializationError(AppError):
    """Component initialization errors"""

    def __init__(self, component: str, details: Optional[str] = None, **kwargs):
        message = f"Failed to initialize {component}"
        if details:
            message += f": {details}"

        super().__init__(
            message=message,
            code="INIT_FAILED",
            details=details,
            **kwargs
        )
        self.component = component


class ValidationError(AppError):
    """Input validation errors"""
    pass


class UnexpectedError(AppError):
    """Unexpected application errors"""

    def __init__(self, details: str, **kwargs):
        super().__init__(
            message="An unexpected error occurred",
            code="UNEXPECTED_ERROR",
            details=details,
            **kwargs
        )


# Retry-related exceptions
class RetryError(TranslationFiestaError):
    """Base class for retry-related errors"""
    pass


class MaxRetriesExceededError(RetryError):
    """Maximum retry attempts exceeded"""

    def __init__(self, max_attempts: int, operation: str, **kwargs):
        super().__init__(
            message=f"Maximum retry attempts ({max_attempts}) exceeded for {operation}",
            code="MAX_RETRIES_EXCEEDED",
            details=f"Failed to complete {operation} after {max_attempts} attempts",
            **kwargs
        )
        self.max_attempts = max_attempts
        self.operation = operation


# User-friendly error messages
def get_user_friendly_message(error: Exception) -> str:
    """Convert technical errors to user-friendly messages"""

    if isinstance(error, HttpError):
        if error.status_code == 400:
            return "Invalid request. Please check your input and try again."
        elif error.status_code == 401:
            return "Authentication failed. Please try again."
        elif error.status_code == 403:
            return "Access denied by the translation service."
        elif error.status_code == 404:
            return "Translation service not found. Please try again later."
        elif error.status_code == 429:
            return "Too many requests. Please wait a moment and try again."
        elif error.status_code >= 500:
            return "Translation service is temporarily unavailable. Please try again later."
        else:
            return f"Network error occurred. Please try again. (Error: {error.status_code})"

    elif isinstance(error, ConnectionError):
        return "Unable to connect to translation service. Please check your internet connection."

    elif isinstance(error, TimeoutError):
        return "Request timed out. The translation service may be busy. Please try again."

    elif isinstance(error, FileNotFoundError):
        return "The selected file was not found. Please check the file path and try again."

    elif isinstance(error, FilePermissionError):
        return "Permission denied. Please check file permissions and try again."

    elif isinstance(error, FileFormatError):
        return "Unsupported file format. Please select a supported file type (txt, md, html)."

    elif isinstance(error, MaxRetriesExceededError):
        return "Operation failed after multiple attempts. Please try again later."

    elif isinstance(error, TranslationError):
        return "Translation failed. Please check your input and try again."

    else:
        return "An unexpected error occurred. Please try again or contact support if the problem persists."
