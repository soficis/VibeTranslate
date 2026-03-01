#!/usr/bin/env python3
"""
Translation provider orchestration (unofficial Google),
including retry/backoff, error mapping, and structured logging.
"""

from __future__ import annotations

import json
import os
import time
import urllib.parse
from collections import OrderedDict
from dataclasses import dataclass
from datetime import datetime
from typing import Callable, Optional

import requests

from app_paths import get_tm_cache_file
from enhanced_logger import get_logger
from exceptions import (
    BlockedError,
    ConnectionError,
    HttpError,
    InvalidTranslationResponseError,
    NetworkError,
    NoTranslationFoundError,
    RateLimitedError,
    SSLError,
    TimeoutError,
    TranslationFiestaError,
)
from provider_ids import (
    normalize_provider_id,
)
from rate_limiter import RateLimiter
from result import Failure, Result, Success, TranslationResult


@dataclass
class TranslationRequest:
    """Data class for translation requests"""
    text: str
    source_language: str
    target_language: str

    def __post_init__(self):
        if not isinstance(self.text, str):
            raise TypeError("text must be a string")
        if not isinstance(self.source_language, str):
            raise ValueError("source_language must be a string")
        if not isinstance(self.target_language, str):
            raise ValueError("target_language must be a string")


@dataclass
class TranslationResponse:
    """Data class for translation responses"""
    translated_text: str
    original_text: str
    source_language: str
    target_language: str
    character_count: int
    timestamp: float

    def __post_init__(self):
        self.character_count = len(self.translated_text)


class TranslationMemory:
    """Translation Memory with LRU, persistence, and metrics."""

    def __init__(self, cache_size: int = 1000, persistence_path: str | None = None):
        self.cache_size = cache_size
        self.persistence_path = persistence_path or str(get_tm_cache_file())
        self.cache = OrderedDict()  # key: f"{source}:{target_lang}"
        self.metrics = {
            'hits': 0,
            'misses': 0,
            'total_lookups': 0,
            'total_time': 0.0
        }
        self.load_cache()

    def _get_key(self, source: str, target_lang: str) -> str:
        return f"{source}:{target_lang}"

    def lookup(self, source: str, target_lang: str) -> Optional[str]:
        key = self._get_key(source, target_lang)
        start_time = time.time()
        if key in self.cache:
            self.cache.move_to_end(key)
            self.metrics['hits'] += 1
            self.metrics['total_lookups'] += 1
            self.metrics['total_time'] += (time.time() - start_time)
            return self.cache[key]['translation']
        self.metrics['misses'] += 1
        self.metrics['total_lookups'] += 1
        self.metrics['total_time'] += (time.time() - start_time)
        return None

    def store(self, source: str, target_lang: str, translation: str):
        key = self._get_key(source, target_lang)
        now = datetime.now().isoformat()
        self.cache[key] = {
            'source': source,
            'translation': translation,
            'target_lang': target_lang,
            'access_time': now
        }
        self.cache.move_to_end(key)
        if len(self.cache) > self.cache_size:
            self.cache.popitem(last=False)  # Remove LRU
        self.persist()

    def get_stats(self) -> dict:
        stats = self.metrics.copy()
        stats['hit_rate'] = stats['hits'] / max(1, stats['total_lookups'])
        stats['avg_lookup_time'] = stats['total_time'] / max(1, stats['total_lookups'])
        stats['cache_size'] = len(self.cache)
        stats['max_size'] = self.cache_size
        return stats

    def clear_cache(self):
        self.cache.clear()
        self.metrics = {k: 0 if k != 'total_time' else v for k, v in self.metrics.items()}
        self.metrics['total_time'] = 0.0
        self.persist()

    def persist(self):
        data = {
            'config': {
                'max_size': self.cache_size,
            },
            'cache': [
                {
                    'source': v['source'],
                    'translation': v['translation'],
                    'target_lang': v['target_lang'],
                    'access_time': v['access_time']
                } for v in self.cache.values()
            ],
            'metrics': self.metrics
        }
        try:
            with open(self.persistence_path, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"Failed to persist cache: {e}")

    def load_cache(self):
        try:
            with open(self.persistence_path, 'r') as f:
                data = json.load(f)
                self.cache_size = data['config'].get('max_size', 1000)
                for entry in data['cache']:
                    key = self._get_key(entry['source'], entry['target_lang'])
                    self.cache[key] = entry
                self.metrics.update(data['metrics'])
                # Reorder by access_time (approximate LRU)
                sorted_items = sorted(self.cache.items(), key=lambda x: x[1]['access_time'], reverse=True)
                self.cache = OrderedDict(sorted_items)
        except FileNotFoundError:
            pass
        except Exception as e:
            print(f"Failed to load cache: {e}")


class TranslationService:
    """Enhanced translation service with comprehensive error handling"""

    def __init__(
        self,
        session: Optional[requests.Session] = None,
    ) -> None:
        self.logger = get_logger()
        self.rate_limiter = RateLimiter()
        self.session = session or requests.Session()
        self.tm = TranslationMemory(cache_size=1000)

    def _extract_text_from_unofficial_response(self, data: object) -> Result[str, TranslationFiestaError]:
        """Extract translated text from unofficial Google Translate API response"""
        try:
            if not isinstance(data, list) or not data:
                return Failure(InvalidTranslationResponseError("Response is not a valid array"))

            if not isinstance(data[0], list):
                return Failure(InvalidTranslationResponseError("Response structure is invalid"))

            translated_parts = []
            for sentence in data[0]:
                if isinstance(sentence, list) and sentence:
                    part = sentence[0]
                    if isinstance(part, str) and part:
                        translated_parts.append(part)

            if not translated_parts:
                return Failure(NoTranslationFoundError())

            return Success("".join(translated_parts))

        except Exception as e:
            return Failure(InvalidTranslationResponseError(f"Failed to parse response: {e}"))

    def _translate_unofficial(
        self,
        session: requests.Session,
        request: TranslationRequest
    ) -> Result[str, TranslationFiestaError]:
        """Translate using unofficial Google Translate API"""
        if not request.text or request.text.isspace():
            return Success("")

        try:
            start_time = time.time()
            encoded_text = urllib.parse.quote(request.text)
            url = (
                "https://translate.googleapis.com/translate_a/single"
                f"?client=gtx&sl={request.source_language}&tl={request.target_language}&dt=t&q={encoded_text}"
            )

            headers = {
                "Accept": "application/json,text/plain,*/*",
            }
            user_agent = os.getenv("TF_UNOFFICIAL_USER_AGENT")
            if user_agent:
                headers["User-Agent"] = user_agent

            proxy_url = os.getenv("TF_UNOFFICIAL_PROXY_URL", "").strip()
            proxies = None
            if proxy_url:
                proxies = {"http": proxy_url, "https": proxy_url}

            timeout_seconds = float(os.getenv("TF_UNOFFICIAL_TIMEOUT_SECONDS", "10"))
            response = session.get(url, timeout=timeout_seconds, headers=headers, proxies=proxies)
            duration = time.time() - start_time

            # Log API call
            self.logger.log_api_call(
                endpoint="translate.googleapis.com/translate_a/single",
                method="GET",
                status_code=response.status_code,
                duration_ms=duration * 1000,
                success=response.status_code < 400
            )

            if response.status_code >= 400:
                body_preview = (response.text or "")[:200]
                if response.status_code == 429:
                    retry_after = response.headers.get("Retry-After")
                    retry_delay = None
                    if retry_after:
                        try:
                            retry_delay = int(retry_after)
                        except ValueError:
                            retry_delay = None
                    return Failure(RateLimitedError(retry_after=retry_delay, details=body_preview))
                if response.status_code == 403:
                    return Failure(BlockedError(details=body_preview))
                error_msg = f"HTTP {response.status_code}"
                if response.text:
                    error_msg += f": {body_preview}"
                return Failure(HttpError(response.status_code, error_msg, response.text, response.headers))

            body_lower = (response.text or "").lower()
            if not response.text:
                return Failure(InvalidTranslationResponseError("Empty response body"))
            if "<html" in body_lower or "captcha" in body_lower:
                return Failure(BlockedError(details=body_lower[:200]))

            try:
                data = response.json()
            except json.JSONDecodeError as e:
                return Failure(InvalidTranslationResponseError(f"Failed to parse JSON response: {e}"))

            return self._extract_text_from_unofficial_response(data)

        except requests.exceptions.Timeout:
            return Failure(TimeoutError("Request timed out"))
        except requests.exceptions.ConnectionError:
            return Failure(ConnectionError("Failed to connect to translation service"))
        except requests.exceptions.SSLError as e:
            return Failure(SSLError(f"SSL certificate error: {e}"))
        except requests.RequestException as e:
            return Failure(NetworkError(f"Network error: {e}"))
        except Exception as e:
            return Failure(TranslationFiestaError(f"Unexpected error in unofficial translation: {e}"))

    def translate_text(
        self,
        session: Optional[requests.Session],
        text: str,
        source_lang: str,
        target_lang: str,
        *,
        provider_id: Optional[str] = None,
        max_attempts: int = 4,
        status_callback: Optional[Callable[[str], None]] = None,
    ) -> TranslationResult:
        """
        Translate text with comprehensive error handling and retry logic.

        Returns:
            Result containing translated text or detailed error information
        """
        try:
            request = TranslationRequest(text, source_lang, target_lang)
        except (TypeError, ValueError) as e:
            return Failure(TranslationFiestaError(f"Invalid request parameters: {e}"))

        session = session or self.session
        resolved_provider_id = normalize_provider_id(provider_id)

        # Check cache before API call
        cache_result = self.tm.lookup(text, target_lang)
        if cache_result is not None:
            self.logger.info(f"Cache hit for {text[:50]}...")
            return Success(cache_result)

        # Execute with retry if cache miss
        retry_result = None
        for attempt in range(max_attempts):
            retry_result = self._translate_unofficial(session, request)

            if retry_result.is_success():
                self.rate_limiter.success()
                break

            if isinstance(retry_result.error, RateLimitedError):
                retry_after = retry_result.error.retry_after
                self.rate_limiter.failure(retry_after=retry_after)
                if not self.rate_limiter.should_retry():
                    break
                self.rate_limiter.wait()
            elif isinstance(retry_result.error, HttpError) and retry_result.error.status_code == 429:
                retry_after = retry_result.error.headers.get("Retry-After")
                if retry_after:
                    try:
                        retry_after = int(retry_after)
                    except ValueError:
                        retry_after = None
                self.rate_limiter.failure(retry_after=retry_after)
                if not self.rate_limiter.should_retry():
                    break
                self.rate_limiter.wait()
            else:
                break

        if retry_result.is_failure():
            error = retry_result.error  # type: ignore
            # Log translation failure
            self.logger.log_translation_attempt(
                source_lang=source_lang,
                target_lang=target_lang,
                text_length=len(text),
                attempt=max_attempts,  # Final attempt
                success=False,
                error=str(error),
                provider_id=resolved_provider_id,
            )
            return Failure(error)

        translated_text = retry_result.value  # type: ignore

        # Store in cache
        self.tm.store(text, target_lang, translated_text)

        # Log successful translation
        self.logger.log_translation_attempt(
            source_lang=source_lang,
            target_lang=target_lang,
            text_length=len(text),
            attempt=1,  # Assume success on first attempt for logging
            success=True,
            provider_id=resolved_provider_id,
        )

        return Success(translated_text)

    def perform_backtranslation(
        self,
        session: requests.Session,
        text: str,
        api_config: dict,
        *,
        intermediate_language: str = "ja",
        status_callback: Optional[Callable[[str], None]] = None,
    ) -> Result[tuple[str, str], TranslationFiestaError]:
        """
        Perform backtranslation (English -> Intermediate -> English) with comprehensive error handling.

        Returns:
            Result containing (intermediate_translation, final_translation) or error
        """
        if not text or text.isspace():
            return Success(("", ""))

        provider_id = normalize_provider_id(
            api_config.get("provider_id"),
        )

        # First translation: source -> intermediate
        first_result = self.translate_text(
            session=session,
            text=text,
            source_lang="en",
            target_lang=intermediate_language,
            provider_id=provider_id,
            status_callback=status_callback
        )

        if first_result.is_failure():
            return Failure(first_result.error)  # type: ignore

        intermediate_text = first_result.value  # type: ignore

        # Second translation: intermediate -> source
        second_result = self.translate_text(
            session=session,
            text=intermediate_text,
            source_lang=intermediate_language,
            target_lang="en",
            provider_id=provider_id,
            status_callback=status_callback
        )

        if second_result.is_failure():
            return Failure(second_result.error)  # type: ignore

        final_text = second_result.value  # type: ignore

        # Log successful backtranslation
        self.logger.log_backtranslation_completed(
            original_length=len(text),
            intermediate_length=len(intermediate_text),
            final_length=len(final_text),
            duration_seconds=0.0,  # Could be enhanced to track actual duration
            total_attempts=1  # Could be enhanced to track actual attempts
        )

        return Success((intermediate_text, final_text))

