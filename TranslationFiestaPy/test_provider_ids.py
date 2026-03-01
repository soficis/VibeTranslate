#!/usr/bin/env python3

from provider_ids import (
    PROVIDER_GOOGLE_UNOFFICIAL,
    get_provider_label,
    normalize_provider_id,
)


def test_provider_aliases_normalize_to_google_unofficial():
    aliases = [
        "google_unofficial",
        "unofficial",
        "google_unofficial_free",
        "google_free",
        "googletranslate",
        "",
        "  unofficial  ",
        "GOOGLE_UNOFFICIAL",
        None,
        "unknown_provider",
        42,
        True,
        3.14,
    ]

    for alias in aliases:
        assert normalize_provider_id(alias) == PROVIDER_GOOGLE_UNOFFICIAL


def test_provider_label_uses_normalized_provider_id():
    assert get_provider_label("unofficial") == "Google Translate (Unofficial / Free)"
