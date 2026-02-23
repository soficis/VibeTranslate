import pytest

import secure_storage
from exceptions import SecureStorageError


def _build_unavailable_storage(monkeypatch):
    monkeypatch.setattr(secure_storage, "KEYRING_AVAILABLE", False)
    storage = secure_storage.SecureStorage("TranslationFiestaTest")
    monkeypatch.setattr(secure_storage, "_secure_storage", storage)
    return storage


def test_store_api_key_fails_when_keyring_unavailable(monkeypatch):
    _build_unavailable_storage(monkeypatch)

    with pytest.raises(SecureStorageError):
        secure_storage.store_api_key("google_translate", "sk-test")


def test_get_api_key_fails_when_keyring_unavailable(monkeypatch):
    _build_unavailable_storage(monkeypatch)

    with pytest.raises(SecureStorageError):
        secure_storage.get_api_key("google_translate")


def test_delete_api_key_fails_when_keyring_unavailable(monkeypatch):
    _build_unavailable_storage(monkeypatch)

    with pytest.raises(SecureStorageError):
        secure_storage.delete_api_key("google_translate")
