#!/usr/bin/env python3
"""
translation_services.py

Clean, testable translation utilities with comprehensive error handling.

Implements both the unofficial Google endpoint (default) and the official
Google Cloud Translation API (via API key) with robust error handling,
retry mechanisms, and structured logging.
"""

from __future__ import annotations

import json
import time
import urllib.parse
from typing import Optional, Callable
from dataclasses import dataclass

import requests

from exceptions import (
    TranslationFiestaError,
    HttpError,
    InvalidTranslationResponseError,
    NoTranslationFoundError,
    ApiKeyRequiredError,
    NetworkError,
    TimeoutError,
    ConnectionError,
    SSLError,
    get_user_friendly_message,
)
from result import Result, Success, Failure, TranslationResult
from enhanced_logger import get_logger
from rate_limiter import RateLimiter

from collections import OrderedDict
import json
from datetime import datetime
from rapidfuzz import fuzz
from cost_tracker import get_cost_tracker, track_translation_cost


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
    """Translation Memory with LRU, fuzzy matching, persistence, and metrics"""

    def __init__(self, cache_size: int = 1000, persistence_path: str = "tm_cache.json", similarity_threshold: float = 0.8):
        self.cache_size = cache_size
        self.persistence_path = persistence_path
        self.similarity_threshold = similarity_threshold
        self.cache = OrderedDict()  # key: f"{source}:{target_lang}"
        self.metrics = {
            'hits': 0,
            'misses': 0,
            'fuzzy_hits': 0,
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

    def fuzzy_lookup(self, source: str, target_lang: str) -> Optional[tuple[str, float]]:
        start_time = time.time()
        best_match = None
        best_score = 0.0
        for k, entry in self.cache.items():
            if entry['target_lang'] == target_lang:
                cached_source = k.split(':')[0]
                score = fuzz.ratio(source, cached_source) / 100.0
                if score > best_score and score >= self.similarity_threshold:
                    best_score = score
                    best_match = entry['translation']
        if best_match:
            self.metrics['fuzzy_hits'] += 1
            self.metrics['total_lookups'] += 1
            self.metrics['total_time'] += (time.time() - start_time)
            return best_match, best_score
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
        stats['hit_rate'] = (stats['hits'] + stats['fuzzy_hits']) / max(1, stats['total_lookups'])
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
                'threshold': self.similarity_threshold
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
                self.similarity_threshold = data['config'].get('threshold', 0.8)
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

    def __init__(self):
        self.logger = get_logger()
        self.rate_limiter = RateLimiter()
        self.tm = TranslationMemory(cache_size=1000, persistence_path="tm_cache.json")

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

            response = session.get(url, timeout=10)
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
                error_msg = f"HTTP {response.status_code}"
                if response.text:
                    error_msg += f": {response.text[:200]}"
                return Failure(HttpError(response.status_code, error_msg, response.text, response.headers))

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

    def _translate_official(
        self,
        session: requests.Session,
        api_key: str,
        request: TranslationRequest
    ) -> Result[str, TranslationFiestaError]:
        """Translate using official Google Cloud Translation API"""
        if not api_key:
            return Failure(ApiKeyRequiredError())

        if not request.text or request.text.isspace():
            return Success("")

        try:
            start_time = time.time()

            # Google Translation API v2 endpoint
            url = "https://translation.googleapis.com/language/translate/v2"
            params = {
                "key": api_key,
                "q": request.text,
                "source": request.source_language,
                "target": request.target_language,
                "format": "text",
            }

            response = session.post(url, params=params, timeout=15)
            duration = time.time() - start_time

            # Log API call
            self.logger.log_api_call(
                endpoint="translation.googleapis.com/language/translate/v2",
                method="POST",
                status_code=response.status_code,
                duration_ms=duration * 1000,
                success=response.status_code < 400
            )

            if response.status_code >= 400:
                error_msg = f"HTTP {response.status_code}"
                if response.text:
                    error_msg += f": {response.text[:200]}"
                return Failure(HttpError(response.status_code, error_msg, response.text, response.headers))

            try:
                payload = response.json()
            except json.JSONDecodeError as e:
                return Failure(InvalidTranslationResponseError(f"Failed to parse JSON response: {e}"))

            # Parse official API response
            if not isinstance(payload, dict):
                return Failure(InvalidTranslationResponseError("Response is not a valid object"))

            data = payload.get("data")
            if not isinstance(data, dict):
                return Failure(InvalidTranslationResponseError("Missing data field in response"))

            translations = data.get("translations")
            if not isinstance(translations, list) or not translations:
                return Failure(NoTranslationFoundError())

            first_translation = translations[0]
            if not isinstance(first_translation, dict):
                return Failure(InvalidTranslationResponseError("Invalid translation format"))

            translated_text = first_translation.get("translatedText", "")
            if not isinstance(translated_text, str):
                return Failure(InvalidTranslationResponseError("Translated text is not a string"))

            if not translated_text:
                return Failure(NoTranslationFoundError())

            # Track cost for successful official API translation
            try:
                track_translation_cost(
                    characters=len(translated_text),
                    source_lang=request.source_language,
                    target_lang=request.target_language,
                    implementation="python",
                    api_version="v2"
                )
            except Exception as e:
                self.logger.warning(f"Failed to track translation cost: {e}")

            return Success(translated_text)

        except requests.exceptions.Timeout:
            return Failure(TimeoutError("Official API request timed out"))
        except requests.exceptions.ConnectionError:
            return Failure(ConnectionError("Failed to connect to official API"))
        except requests.exceptions.SSLError as e:
            return Failure(SSLError(f"SSL certificate error: {e}"))
        except requests.RequestException as e:
            return Failure(NetworkError(f"Official API network error: {e}"))
        except Exception as e:
            return Failure(TranslationFiestaError(f"Unexpected error in official translation: {e}"))

    def translate_text(
        self,
        session: requests.Session,
        text: str,
        source_lang: str,
        target_lang: str,
        *,
        use_official_api: bool = False,
        api_key: Optional[str] = None,
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

        # Check cache before API call
        cache_result = self.tm.lookup(text, target_lang)
        if cache_result is not None:
            self.logger.info(f"Cache hit for {text[:50]}...")
            return Success(cache_result)
    
        # Check fuzzy cache
        fuzzy_result = self.tm.fuzzy_lookup(text, target_lang)
        if fuzzy_result is not None:
            translation, score = fuzzy_result
            self.logger.info(f"Fuzzy cache hit (score: {score:.2f}) for {text[:50]}...")
            return Success(translation)
    
        # Execute with retry if cache miss
        retry_result = None
        for attempt in range(max_attempts):
            if use_official_api:
                retry_result = self._translate_official(session, api_key or "", request)
            else:
                retry_result = self._translate_unofficial(session, request)
    
            if retry_result.is_success():
                self.rate_limiter.success()
                break
    
            if isinstance(retry_result.error, HttpError) and retry_result.error.status_code == 429:
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
                use_official=use_official_api,
                attempt=max_attempts,  # Final attempt
                success=False,
                error=str(error)
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
            use_official=use_official_api,
            attempt=1,  # Assume success on first attempt for logging
            success=True
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

        use_official = api_config.get("use_official_api", False)
        api_key = api_config.get("api_key")

        # First translation: source -> intermediate
        first_result = self.translate_text(
            session=session,
            text=text,
            source_lang="en",
            target_lang=intermediate_language,
            use_official_api=use_official,
            api_key=api_key,
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
            use_official_api=use_official,
            api_key=api_key,
            status_callback=status_callback
        )

        if second_result.is_failure():
            return Failure(second_result.error)  # type: ignore

        final_text = second_result.value  # type: ignore

        # Track costs for backtranslation (two API calls)
        if use_official and api_key:
            try:
                # Track cost for first translation (source -> intermediate)
                track_translation_cost(
                    characters=len(intermediate_text),
                    source_lang="en",
                    target_lang=intermediate_language,
                    implementation="python",
                    api_version="v2"
                )
                # Track cost for second translation (intermediate -> source)
                track_translation_cost(
                    characters=len(final_text),
                    source_lang=intermediate_language,
                    target_lang="en",
                    implementation="python",
                    api_version="v2"
                )
            except Exception as e:
                self.logger.warning(f"Failed to track backtranslation costs: {e}")

        # Log successful backtranslation
        self.logger.log_backtranslation_completed(
            original_length=len(text),
            intermediate_length=len(intermediate_text),
            final_length=len(final_text),
            duration_seconds=0.0,  # Could be enhanced to track actual duration
            total_attempts=1  # Could be enhanced to track actual attempts
        )

        return Success((intermediate_text, final_text))


# Legacy function for backward compatibility
def translate_text(
    session: requests.Session,
    text: str,
    source_lang: str,
    target_lang: str,
    *,
    use_official_api: bool = False,
    api_key: Optional[str] = None,
    max_attempts: int = 4,
    initial_backoff_seconds: float = 0.5,
    backoff_multiplier: float = 2.0,
    logger: Optional[object] = None,
) -> str:
    """
    Legacy function for backward compatibility.
    Use TranslationService for new code with comprehensive error handling.
    """
    service = TranslationService()
    result = service.translate_text(
        session=session,
        text=text,
        source_lang=source_lang,
        target_lang=target_lang,
        use_official_api=use_official_api,
        api_key=api_key,
        max_attempts=max_attempts
    )

    if result.is_success():
        return result.value  # type: ignore
    else:
        # For backward compatibility, raise the exception
        raise result.error  # type: ignore


