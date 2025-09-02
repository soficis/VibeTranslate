#!/usr/bin/env python3
"""
translation_services.py

Clean, testable translation utilities with retry logic.

Implements both the unofficial Google endpoint (default) and the official
Google Cloud Translation API (via API key) to align with the FSharpTranslate
features and Clean Code principles.
"""

from __future__ import annotations

import json
import random
import time
import urllib.parse
from typing import Callable, Optional

import requests


DEFAULT_MAX_ATTEMPTS = 4
DEFAULT_INITIAL_BACKOFF_SECONDS = 0.5
DEFAULT_BACKOFF_MULTIPLIER = 2.0


def _sleep_with_jitter(seconds: float) -> None:
    jitter = random.uniform(0, seconds * 0.25)
    time.sleep(seconds + jitter)


def _extract_text_from_unofficial_response(data: object) -> str:
    if not isinstance(data, list) or not data:
        return ""
    if not isinstance(data[0], list):
        return ""
    translated_parts = []
    for sentence in data[0]:
        if isinstance(sentence, list) and sentence:
            part = sentence[0]
            if isinstance(part, str) and part:
                translated_parts.append(part)
    return "".join(translated_parts)


def _translate_unofficial(session: requests.Session, text: str, source_lang: str, target_lang: str) -> str:
    if not text or text.isspace():
        return ""
    encoded_text = urllib.parse.quote(text)
    url = (
        f"https://translate.googleapis.com/translate_a/single"
        f"?client=gtx&sl={source_lang}&tl={target_lang}&dt=t&q={encoded_text}"
    )
    response = session.get(url, timeout=10)
    response.raise_for_status()
    try:
        data = response.json()
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse response: {exc}") from exc
    return _extract_text_from_unofficial_response(data)


def _translate_official(session: requests.Session, api_key: str, text: str, source_lang: str, target_lang: str) -> str:
    if not api_key:
        raise ValueError("API key required for official endpoint")
    if not text or text.isspace():
        return ""
    # Google Translation API v2 endpoint using API key
    # https://cloud.google.com/translate/docs/basic/translating-text
    url = "https://translation.googleapis.com/language/translate/v2"
    params = {
        "key": api_key,
        "q": text,
        "source": source_lang,
        "target": target_lang,
        "format": "text",
    }
    response = session.post(url, params=params, timeout=15)
    response.raise_for_status()
    try:
        payload = response.json()
    except json.JSONDecodeError as exc:
        raise ValueError(f"Failed to parse official response: {exc}") from exc
    if not isinstance(payload, dict):
        return ""
    data = payload.get("data")
    if not isinstance(data, dict):
        return ""
    translations = data.get("translations")
    if not isinstance(translations, list) or not translations:
        return ""
    first = translations[0]
    if not isinstance(first, dict):
        return ""
    translated_text = first.get("translatedText", "")
    if not isinstance(translated_text, str):
        return ""
    return translated_text


def translate_text(
    session: requests.Session,
    text: str,
    source_lang: str,
    target_lang: str,
    *,
    use_official_api: bool = False,
    api_key: Optional[str] = None,
    max_attempts: int = DEFAULT_MAX_ATTEMPTS,
    initial_backoff_seconds: float = DEFAULT_INITIAL_BACKOFF_SECONDS,
    backoff_multiplier: float = DEFAULT_BACKOFF_MULTIPLIER,
    logger: Optional[object] = None,
) -> str:
    """
    Translate text with retry and exponential backoff.

    - Defaults to unofficial Google endpoint (no key required)
    - When `use_official_api=True`, uses the official API (requires api_key)
    """
    if not isinstance(text, str):
        raise TypeError("text must be a string")

    attempt = 0
    delay = initial_backoff_seconds
    last_error: Optional[Exception] = None

    while attempt < max_attempts:
        attempt += 1
        try:
            if use_official_api:
                result = _translate_official(session, api_key or "", text, source_lang, target_lang)
            else:
                result = _translate_unofficial(session, text, source_lang, target_lang)
            if logger:
                try:
                    logger.info(
                        "translate_text success",
                        extra={
                            "source": source_lang,
                            "target": target_lang,
                            "official": use_official_api,
                            "attempt": attempt,
                        },
                    )
                except Exception:
                    pass
            return result
        except (requests.RequestException, ValueError) as exc:
            last_error = exc
            if logger:
                try:
                    logger.warning(
                        "translate_text retry",
                        extra={
                            "source": source_lang,
                            "target": target_lang,
                            "official": use_official_api,
                            "attempt": attempt,
                            "error": str(exc),
                        },
                    )
                except Exception:
                    pass
            if attempt >= max_attempts:
                break
            _sleep_with_jitter(delay)
            delay *= backoff_multiplier
        except Exception as exc:  # Unexpected error - do not retry blindly
            last_error = exc
            break

    if last_error:
        raise last_error
    return ""


