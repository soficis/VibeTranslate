#!/usr/bin/env python3
"""
Client for the TranslationFiestaLocal offline service.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Optional

import requests

from enhanced_logger import get_logger
from exceptions import ConnectionError, NetworkError, TimeoutError, TranslationFiestaError
from result import Failure, Result, Success

DEFAULT_LOCAL_URL = "http://127.0.0.1:5055"
SUPPORTED_LOCAL_PAIRS = {("en", "ja"), ("ja", "en")}


@dataclass(frozen=True)
class LocalServiceConfig:
    base_url: str = DEFAULT_LOCAL_URL
    timeout_seconds: int = 5
    startup_timeout_seconds: int = 8
    auto_start: bool = True
    model_dir: Optional[str] = None


class LocalServiceClient:
    def __init__(self, session: Optional[requests.Session] = None, config: Optional[LocalServiceConfig] = None) -> None:
        self._logger = get_logger()
        self._session = session or requests.Session()
        env_url = os.getenv("TF_LOCAL_URL")
        env_autostart = os.getenv("TF_LOCAL_AUTOSTART")
        env_timeout = os.getenv("TF_LOCAL_TIMEOUT_SECONDS")
        env_model_dir = os.getenv("TF_LOCAL_MODEL_DIR")
        base_config = config or LocalServiceConfig()
        auto_start = base_config.auto_start
        if env_autostart is not None:
            auto_start = env_autostart.strip() not in {"0", "false", "False"}
        timeout_seconds = base_config.timeout_seconds
        if env_timeout and env_timeout.isdigit():
            timeout_seconds = int(env_timeout)
        model_dir = env_model_dir or base_config.model_dir
        self._config = LocalServiceConfig(
            base_url=env_url or base_config.base_url,
            timeout_seconds=timeout_seconds,
            startup_timeout_seconds=base_config.startup_timeout_seconds,
            auto_start=auto_start,
            model_dir=model_dir,
        )
        self._process: Optional[subprocess.Popen] = None

    def translate(self, text: str, source_lang: str, target_lang: str) -> Result[str, TranslationFiestaError]:
        if not text or text.isspace():
            return Success("")
        if (source_lang, target_lang) not in SUPPORTED_LOCAL_PAIRS:
            return Failure(TranslationFiestaError("Local provider supports only en<->ja."))

        ensure = self._ensure_running()
        if ensure.is_failure():
            return Failure(ensure.error)  # type: ignore[arg-type]

        payload = {
            "text": text,
            "source_lang": source_lang,
            "target_lang": target_lang,
        }
        try:
            response = self._session.post(
                f"{self._config.base_url}/translate",
                headers={"Content-Type": "application/json"},
                data=json.dumps(payload),
                timeout=self._config.timeout_seconds,
            )
            return self._parse_translate_response(response)
        except requests.exceptions.Timeout:
            return Failure(TimeoutError("Local provider request timed out"))
        except requests.exceptions.ConnectionError:
            return Failure(ConnectionError("Failed to connect to local provider"))
        except requests.RequestException as exc:
            return Failure(NetworkError(f"Local provider network error: {exc}"))
        except Exception as exc:
            return Failure(TranslationFiestaError(f"Local provider error: {exc}"))

    def models_status(self) -> Result[dict, TranslationFiestaError]:
        ensure = self._ensure_running()
        if ensure.is_failure():
            return Failure(ensure.error)  # type: ignore[arg-type]
        return self._get_json("/models")

    def models_verify(self) -> Result[dict, TranslationFiestaError]:
        ensure = self._ensure_running()
        if ensure.is_failure():
            return Failure(ensure.error)  # type: ignore[arg-type]
        return self._post_json("/models/verify", {})

    def models_remove(self) -> Result[dict, TranslationFiestaError]:
        ensure = self._ensure_running()
        if ensure.is_failure():
            return Failure(ensure.error)  # type: ignore[arg-type]
        return self._post_json("/models/remove", {})

    def models_install(
        self,
        en_ja_url: str,
        ja_en_url: str,
        *,
        en_ja_sha256: Optional[str] = None,
        ja_en_sha256: Optional[str] = None,
    ) -> Result[dict, TranslationFiestaError]:
        ensure = self._ensure_running()
        if ensure.is_failure():
            return Failure(ensure.error)  # type: ignore[arg-type]
        payload = {
            "en_ja_url": en_ja_url,
            "ja_en_url": ja_en_url,
            "en_ja_sha256": en_ja_sha256,
            "ja_en_sha256": ja_en_sha256,
        }
        return self._post_json("/models/install", payload)

    def models_install_default(self) -> Result[dict, TranslationFiestaError]:
        ensure = self._ensure_running()
        if ensure.is_failure():
            return Failure(ensure.error)  # type: ignore[arg-type]
        return self._post_json("/models/install", {})

    def _parse_translate_response(self, response: requests.Response) -> Result[str, TranslationFiestaError]:
        if response.status_code >= 400:
            message = self._extract_error_message(response)
            return Failure(TranslationFiestaError(message))
        try:
            payload = response.json()
        except json.JSONDecodeError:
            return Failure(TranslationFiestaError("Invalid JSON from local provider"))
        translated = payload.get("translated_text", "")
        if not isinstance(translated, str):
            return Failure(TranslationFiestaError("Invalid local translation response"))
        return Success(translated)

    def _extract_error_message(self, response: requests.Response) -> str:
        try:
            payload = response.json()
            error = payload.get("error", {})
            message = error.get("message")
            code = error.get("code")
            if message:
                return f"Local provider error ({code}): {message}"
        except Exception:
            pass
        return f"Local provider error: HTTP {response.status_code}"

    def _get_json(self, path: str) -> Result[dict, TranslationFiestaError]:
        try:
            response = self._session.get(
                f"{self._config.base_url}{path}",
                timeout=self._config.timeout_seconds,
            )
            return self._parse_json_response(response)
        except requests.exceptions.Timeout:
            return Failure(TimeoutError("Local provider request timed out"))
        except requests.exceptions.ConnectionError:
            return Failure(ConnectionError("Failed to connect to local provider"))
        except requests.RequestException as exc:
            return Failure(NetworkError(f"Local provider network error: {exc}"))
        except Exception as exc:
            return Failure(TranslationFiestaError(f"Local provider error: {exc}"))

    def _post_json(self, path: str, payload: dict) -> Result[dict, TranslationFiestaError]:
        try:
            response = self._session.post(
                f"{self._config.base_url}{path}",
                headers={"Content-Type": "application/json"},
                data=json.dumps(payload),
                timeout=self._config.timeout_seconds,
            )
            return self._parse_json_response(response)
        except requests.exceptions.Timeout:
            return Failure(TimeoutError("Local provider request timed out"))
        except requests.exceptions.ConnectionError:
            return Failure(ConnectionError("Failed to connect to local provider"))
        except requests.RequestException as exc:
            return Failure(NetworkError(f"Local provider network error: {exc}"))
        except Exception as exc:
            return Failure(TranslationFiestaError(f"Local provider error: {exc}"))

    def _parse_json_response(self, response: requests.Response) -> Result[dict, TranslationFiestaError]:
        if response.status_code >= 400:
            message = self._extract_error_message(response)
            return Failure(TranslationFiestaError(message))
        try:
            payload = response.json()
        except json.JSONDecodeError:
            return Failure(TranslationFiestaError("Invalid JSON from local provider"))
        if not isinstance(payload, dict):
            return Failure(TranslationFiestaError("Invalid local provider response"))
        return Success(payload)

    def _ensure_running(self) -> Result[bool, TranslationFiestaError]:
        if self._is_healthy():
            return Success(True)
        if not self._config.auto_start:
            return Failure(TranslationFiestaError("Local provider is not running."))
        self._start_process()
        deadline = time.time() + self._config.startup_timeout_seconds
        while time.time() < deadline:
            if self._is_healthy():
                return Success(True)
            time.sleep(0.2)
        return Failure(TranslationFiestaError("Local provider failed to start."))

    def _is_healthy(self) -> bool:
        try:
            response = self._session.get(
                f"{self._config.base_url}/health",
                timeout=self._config.timeout_seconds,
            )
            return response.status_code == 200
        except requests.RequestException:
            return False

    def _start_process(self) -> None:
        if self._process and self._process.poll() is None:
            return
        service_path = os.path.join(os.path.dirname(__file__), "..", "TranslationFiestaLocal", "local_service.py")
        service_path = os.path.abspath(service_path)
        if not os.path.exists(service_path):
            self._logger.warning("Local service script not found", extra={"path": service_path})
            return
        try:
            env = os.environ.copy()
            env.setdefault("PYTHONUNBUFFERED", "1")
            if self._config.model_dir:
                env["TF_LOCAL_MODEL_DIR"] = self._config.model_dir
            self._process = subprocess.Popen(
                [sys.executable, service_path, "serve"],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                cwd=os.path.dirname(service_path),
            )
            self._logger.info("Local provider started", extra={"path": service_path})
        except Exception as exc:
            self._logger.error("Failed to start local provider", extra={"error": str(exc)})
