#!/usr/bin/env python3
"""
enhanced_logger.py

Enhanced logging system with structured data, levels, and file output.
"""

from __future__ import annotations

import json
import logging
import logging.handlers
import sys
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, Optional


class LogLevel(Enum):
    """Log levels"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARN"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"

    def __str__(self) -> str:
        return self.value


class StructuredLogger:
    """Enhanced logger with structured data and file output"""

    _instance: Optional[StructuredLogger] = None
    _log_file: Optional[Path] = None
    _file_handler: Optional[logging.Handler] = None

    def __init__(self):
        self._logger = logging.getLogger("TranslationFiesta")
        self._logger.setLevel(logging.DEBUG)

        # Remove any existing handlers to avoid duplicates
        for handler in self._logger.handlers[:]:
            self._logger.removeHandler(handler)

        # Console handler for immediate feedback
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_formatter = logging.Formatter(
            '[%(asctime)s] %(levelname)s: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_formatter)
        self._logger.addHandler(console_handler)

        # Initialize file logging
        self._initialize_file_logging()

    @classmethod
    def get_instance(cls) -> StructuredLogger:
        """Get singleton instance"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _initialize_file_logging(self) -> None:
        """Initialize file logging with rotation"""
        try:
            # Create logs directory if it doesn't exist
            log_dir = Path("logs")
            log_dir.mkdir(exist_ok=True)

            log_file_path = log_dir / "translationfiesta.log"
            self._log_file = log_file_path

            # Rotating file handler (10MB max, keep 5 backups)
            file_handler = logging.handlers.RotatingFileHandler(
                log_file_path,
                maxBytes=10 * 1024 * 1024,  # 10MB
                backupCount=5,
                encoding='utf-8'
            )
            file_handler.setLevel(logging.DEBUG)

            # JSON formatter for structured logging
            file_formatter = StructuredFormatter()
            file_handler.setFormatter(file_formatter)

            self._file_handler = file_handler
            self._logger.addHandler(file_handler)

            self.info("Logger initialized successfully", extra={
                "component": "StructuredLogger",
                "log_file": str(log_file_path)
            })

        except Exception as e:
            # Fallback to console-only logging
            print(f"Failed to initialize file logging: {e}", file=sys.stderr)
            self._log_file = None

    def _log(
        self,
        level: LogLevel,
        message: str,
        extra: Optional[Dict[str, Any]] = None,
        exc_info: Optional[Any] = None
    ) -> None:
        """Internal logging method with structured data"""
        log_data = extra or {}
        log_data.update({
            "timestamp": datetime.utcnow().isoformat(),
            "level": level.value
        })

        # Convert log level to logging module level
        logging_level = getattr(logging, level.name)

        self._logger.log(logging_level, message, extra=log_data, exc_info=exc_info)

    def debug(self, message: str, extra: Optional[Dict[str, Any]] = None) -> None:
        """Log debug message"""
        self._log(LogLevel.DEBUG, message, extra)

    def info(self, message: str, extra: Optional[Dict[str, Any]] = None) -> None:
        """Log info message"""
        self._log(LogLevel.INFO, message, extra)

    def warning(self, message: str, extra: Optional[Dict[str, Any]] = None) -> None:
        """Log warning message"""
        self._log(LogLevel.WARNING, message, extra)

    def error(
        self,
        message: str,
        extra: Optional[Dict[str, Any]] = None,
        exc_info: Optional[Any] = None
    ) -> None:
        """Log error message"""
        self._log(LogLevel.ERROR, message, extra, exc_info)

    def critical(
        self,
        message: str,
        extra: Optional[Dict[str, Any]] = None,
        exc_info: Optional[Any] = None
    ) -> None:
        """Log critical message"""
        self._log(LogLevel.CRITICAL, message, extra, exc_info)

    def log_translation_attempt(
        self,
        source_lang: str,
        target_lang: str,
        text_length: int,
        use_official: bool,
        attempt: int,
        success: bool,
        error: Optional[str] = None,
        provider_id: Optional[str] = None,
    ) -> None:
        """Log translation attempt with structured data"""
        extra = {
            "operation": "translation",
            "source_language": source_lang,
            "target_language": target_lang,
            "text_length": text_length,
            "use_official_api": use_official,
            "attempt": attempt,
            "success": success,
        }
        if provider_id:
            extra["provider_id"] = provider_id

        if error:
            extra["error"] = error

        if success:
            self.info("Translation completed successfully", extra=extra)
        else:
            self.warning("Translation attempt failed", extra=extra)

    def log_backtranslation_completed(
        self,
        original_length: int,
        intermediate_length: int,
        final_length: int,
        duration_seconds: float,
        total_attempts: int
    ) -> None:
        """Log successful backtranslation completion"""
        self.info("Backtranslation completed successfully", extra={
            "operation": "backtranslation",
            "original_length": original_length,
            "intermediate_length": intermediate_length,
            "final_length": final_length,
            "duration_seconds": duration_seconds,
            "total_attempts": total_attempts,
        })

    def log_file_operation(
        self,
        operation: str,
        file_path: str,
        success: bool,
        file_size: Optional[int] = None,
        error: Optional[str] = None
    ) -> None:
        """Log file operations"""
        extra = {
            "operation": operation,
            "file_path": file_path,
            "success": success,
        }

        if file_size is not None:
            extra["file_size"] = file_size

        if error:
            extra["error"] = error

        if success:
            self.info(f"File {operation} completed", extra=extra)
        else:
            self.error(f"File {operation} failed", extra=extra)

    def log_api_call(
        self,
        endpoint: str,
        method: str,
        status_code: Optional[int] = None,
        duration_ms: Optional[float] = None,
        success: bool = True,
        error: Optional[str] = None
    ) -> None:
        """Log API calls with performance metrics"""
        extra = {
            "operation": "api_call",
            "endpoint": endpoint,
            "method": method,
            "success": success,
        }

        if status_code is not None:
            extra["status_code"] = status_code

        if duration_ms is not None:
            extra["duration_ms"] = duration_ms

        if error:
            extra["error"] = error

        if success:
            self.debug("API call completed", extra=extra)
        else:
            self.warning("API call failed", extra=extra)

    def get_log_file_path(self) -> Optional[str]:
        """Get the current log file path"""
        return str(self._log_file) if self._log_file else None

    def get_recent_logs(self, max_lines: int = 100) -> list[str]:
        """Get recent log entries"""
        if not self._log_file or not self._log_file.exists():
            return []

        try:
            with open(self._log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            # Return the most recent lines
            return [line.strip() for line in lines[-max_lines:]]
        except Exception as e:
            print(f"Failed to read log file: {e}", file=sys.stderr)
            return []

    def clear_logs(self) -> bool:
        """Clear the log file"""
        if not self._log_file:
            return False

        try:
            with open(self._log_file, 'w', encoding='utf-8') as f:
                f.write("")
            self.info("Log file cleared")
            return True
        except Exception as e:
            print(f"Failed to clear log file: {e}", file=sys.stderr)
            return False


class StructuredFormatter(logging.Formatter):
    """JSON formatter for structured logging"""

    def format(self, record: logging.LogRecord) -> str:
        # Extract structured data from record
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }

        # Add any extra structured data
        if hasattr(record, '__dict__'):
            for key, value in record.__dict__.items():
                if key not in ['name', 'msg', 'args', 'levelname', 'levelno',
                             'pathname', 'filename', 'module', 'exc_info',
                             'exc_text', 'stack_info', 'lineno', 'funcName',
                             'created', 'msecs', 'relativeCreated', 'thread',
                             'threadName', 'processName', 'process', 'message']:
                    # Convert non-serializable objects to strings
                    if isinstance(value, (datetime, Path)):
                        log_entry[key] = str(value)
                    elif isinstance(value, Exception):
                        log_entry[key] = str(value)
                    else:
                        try:
                            json.dumps(value)  # Test serializability
                            log_entry[key] = value
                        except (TypeError, ValueError):
                            log_entry[key] = str(value)

        # Add exception info if present
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_entry, ensure_ascii=False)


# Global logger instance
_logger_instance: Optional[StructuredLogger] = None

def get_logger() -> StructuredLogger:
    """Get the global logger instance"""
    global _logger_instance
    if _logger_instance is None:
        _logger_instance = StructuredLogger.get_instance()
    return _logger_instance


# Convenience functions for easy logging
def log_debug(message: str, extra: Optional[Dict[str, Any]] = None) -> None:
    """Log debug message"""
    get_logger().debug(message, extra)

def log_info(message: str, extra: Optional[Dict[str, Any]] = None) -> None:
    """Log info message"""
    get_logger().info(message, extra)

def log_warning(message: str, extra: Optional[Dict[str, Any]] = None) -> None:
    """Log warning message"""
    get_logger().warning(message, extra)

def log_error(
    message: str,
    extra: Optional[Dict[str, Any]] = None,
    exc_info: Optional[Any] = None
) -> None:
    """Log error message"""
    get_logger().error(message, extra, exc_info)

def log_critical(
    message: str,
    extra: Optional[Dict[str, Any]] = None,
    exc_info: Optional[Any] = None
) -> None:
    """Log critical message"""
    get_logger().critical(message, extra, exc_info)
