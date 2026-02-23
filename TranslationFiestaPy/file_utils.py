#!/usr/bin/env python3
"""
file_utils.py

Utility functions for loading and extracting text content from files.
Enhanced with comprehensive error handling and Result pattern.
"""

from __future__ import annotations

import os

from bs4 import BeautifulSoup

from enhanced_logger import get_logger
from exceptions import (
    FileFormatError,
    FilePermissionError,
    FileSizeError,
)
from exceptions import (
    FileNotFoundError as CustomFileNotFoundError,
)
from result import Failure, Result, Success

SUPPORTED_EXTENSIONS = {".txt", ".md", ".html"}


def read_text_file_utf8(path: str) -> Result[str, Exception]:
    """Read text file with comprehensive error handling"""
    logger = get_logger()

    try:
        # Check if file exists
        if not os.path.exists(path):
            error = CustomFileNotFoundError(path)
            logger.log_file_operation("read", path, False, error=str(error))
            return Failure(error)

        # Check file size (prevent loading extremely large files)
        file_size = os.path.getsize(path)
        max_size = 50 * 1024 * 1024  # 50MB limit
        if file_size > max_size:
            error = FileSizeError(path, file_size, max_size)
            logger.log_file_operation("read", path, False, file_size, str(error))
            return Failure(error)

        # Attempt to read file
        with open(path, "r", encoding="utf-8", errors="ignore") as handle:
            content = handle.read()

        logger.log_file_operation("read", path, True, file_size)
        return Success(content)

    except PermissionError:
        error = FilePermissionError(path, "read")
        logger.log_file_operation("read", path, False, error=str(error))
        return Failure(error)
    except OSError as e:
        error = FilePermissionError(path, "read", details=f"OS error: {e}")
        logger.log_file_operation("read", path, False, error=str(error))
        return Failure(error)
    except Exception as e:
        logger.log_file_operation("read", path, False, error=str(e))
        return Failure(e)


def extract_text_from_html(html_content: str) -> str:
    """
    Extract readable text from HTML, skipping script/style/code/pre blocks.
    Falls back to simple regex-based stripping on parser failure.
    """
    try:
        soup = BeautifulSoup(html_content, "html.parser")
        for node in soup(["script", "style", "code", "pre"]):
            node.decompose()
        text = soup.get_text()
        # Normalize whitespace
        lines = (line.strip() for line in text.splitlines())
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        return " ".join(chunk for chunk in chunks if chunk)
    except Exception:
        import re
        # Coarse fallback
        sanitized = re.sub(r"<script[^>]*>.*?</script>", "", html_content, flags=re.DOTALL | re.IGNORECASE)
        sanitized = re.sub(r"<style[^>]*>.*?</style>", "", sanitized, flags=re.DOTALL | re.IGNORECASE)
        sanitized = re.sub(r"<code[^>]*>.*?</code>", "", sanitized, flags=re.DOTALL | re.IGNORECASE)
        sanitized = re.sub(r"<pre[^>]*>.*?</pre>", "", sanitized, flags=re.DOTALL | re.IGNORECASE)
        sanitized = re.sub(r"<[^>]+>", "", sanitized)
        sanitized = " ".join(sanitized.split())
        return sanitized


def load_text_from_path(path: str) -> Result[str, Exception]:
    """
    Load text from supported files with comprehensive error handling.
    For HTML, extract readable text. Returns Result with processed content.
    """
    logger = get_logger()

    try:
        # Validate file path
        if not path or not isinstance(path, str):
            error = FileFormatError(path, "Valid file path", "empty or invalid")
            logger.log_file_operation("load", path, False, error=str(error))
            return Failure(error)

        # Check if file exists
        if not os.path.exists(path):
            error = CustomFileNotFoundError(path)
            logger.log_file_operation("load", path, False, error=str(error))
            return Failure(error)

        # Validate file extension
        ext = os.path.splitext(path)[1].lower()
        if ext not in SUPPORTED_EXTENSIONS:
            error = FileFormatError(
                path,
                f"One of: {', '.join(SUPPORTED_EXTENSIONS)}",
                ext or "no extension"
            )
            logger.log_file_operation("load", path, False, error=str(error))
            return Failure(error)

        # Read file content
        read_result = read_text_file_utf8(path)
        if read_result.is_failure():
            return read_result

        content = read_result.value  # type: ignore

        # Process content based on file type
        if ext == ".html":
            processed_content = extract_text_from_html(content)
            logger.log_file_operation(
                "load_html",
                path,
                True,
                len(content),
                extra={
                    "original_length": len(content),
                    "extracted_length": len(processed_content)
                }
            )
        else:
            processed_content = content.strip()
            logger.log_file_operation("load_text", path, True, len(content))

        return Success(processed_content)

    except Exception as e:
        logger.log_file_operation("load", path, False, error=str(e))
        return Failure(e)

