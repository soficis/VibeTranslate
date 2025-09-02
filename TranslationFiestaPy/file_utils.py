#!/usr/bin/env python3
"""
file_utils.py

Utility functions for loading and extracting text content from files.
Designed for clarity and single-responsibility per Clean Code principles.
"""

from __future__ import annotations

import os
from typing import Optional

from bs4 import BeautifulSoup


SUPPORTED_EXTENSIONS = {".txt", ".md", ".html"}


def read_text_file_utf8(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="ignore") as handle:
        return handle.read()


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


def load_text_from_path(path: str) -> str:
    """
    Load text from supported files. For HTML, extract readable text.
    Returns stripped content (may be empty).
    """
    if not os.path.isfile(path):
        raise FileNotFoundError(f"File not found: {path}")
    ext = os.path.splitext(path)[1].lower()
    content = read_text_file_utf8(path)
    if ext == ".html":
        return extract_text_from_html(content)
    return content.strip()


