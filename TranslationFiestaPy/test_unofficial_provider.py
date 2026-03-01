#!/usr/bin/env python3

import json

from exceptions import BlockedError, InvalidTranslationResponseError, RateLimitedError
from translation_services import TranslationRequest, TranslationService


class DummyResponse:
    def __init__(self, status_code=200, text="", json_payload=None, headers=None):
        self.status_code = status_code
        self.text = text
        self._json_payload = json_payload
        self.headers = headers or {}

    def json(self):
        if self._json_payload is None:
            raise json.JSONDecodeError("invalid", "", 0)
        return self._json_payload


class DummySession:
    def __init__(self, response):
        self._response = response
        self.last_url = None

    def get(self, url, timeout=None, headers=None, proxies=None):
        self.last_url = url
        return self._response


def test_unofficial_parses_translation():
    payload = [[["Hello", "こんにちは", None, None]]]
    session = DummySession(DummyResponse(text=json.dumps(payload), json_payload=payload))
    service = TranslationService(session=session)
    request = TranslationRequest("こんにちは", "ja", "en")

    result = service._translate_unofficial(session, request)

    assert result.is_success()
    assert result.value == "Hello"
    assert "client=gtx" in session.last_url
    assert "dt=t" in session.last_url


def test_unofficial_rate_limited_maps_error():
    response = DummyResponse(status_code=429, text="too many", headers={"Retry-After": "5"})
    session = DummySession(response)
    service = TranslationService(session=session)
    request = TranslationRequest("hello", "en", "ja")

    result = service._translate_unofficial(session, request)

    assert result.is_failure()
    assert isinstance(result.error, RateLimitedError)
    assert result.error.code == "rate_limited"


def test_unofficial_blocked_maps_error():
    response = DummyResponse(status_code=403, text="<html>captcha</html>")
    session = DummySession(response)
    service = TranslationService(session=session)
    request = TranslationRequest("hello", "en", "ja")

    result = service._translate_unofficial(session, request)

    assert result.is_failure()
    assert isinstance(result.error, BlockedError)
    assert result.error.code == "blocked"


def test_unofficial_invalid_response_maps_error():
    response = DummyResponse(status_code=200, text="not json", json_payload=None)
    session = DummySession(response)
    service = TranslationService(session=session)
    request = TranslationRequest("hello", "en", "ja")

    result = service._translate_unofficial(session, request)

    assert result.is_failure()
    assert isinstance(result.error, InvalidTranslationResponseError)
