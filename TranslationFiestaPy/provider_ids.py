#!/usr/bin/env python3
"""
Provider identifiers and labels for TranslationFiesta.
"""

from __future__ import annotations

from typing import Dict, Optional

PROVIDER_GOOGLE_UNOFFICIAL = "google_unofficial"

_PROVIDER_ALIASES = {
    "google_unofficial": PROVIDER_GOOGLE_UNOFFICIAL,
    "unofficial": PROVIDER_GOOGLE_UNOFFICIAL,
    "google_unofficial_free": PROVIDER_GOOGLE_UNOFFICIAL,
    "google_free": PROVIDER_GOOGLE_UNOFFICIAL,
    "googletranslate": PROVIDER_GOOGLE_UNOFFICIAL,
    "": PROVIDER_GOOGLE_UNOFFICIAL,
}

PROVIDER_LABELS: Dict[str, str] = {
    PROVIDER_GOOGLE_UNOFFICIAL: "Google Translate (Unofficial / Free)",
}


def normalize_provider_id(provider_id: Optional[str]) -> str:
    if provider_id is None:
        return PROVIDER_GOOGLE_UNOFFICIAL

    normalized = provider_id.strip().lower()
    return _PROVIDER_ALIASES.get(normalized, PROVIDER_GOOGLE_UNOFFICIAL)

def get_provider_label(provider_id: str) -> str:
    normalized = normalize_provider_id(provider_id)
    return PROVIDER_LABELS.get(normalized, PROVIDER_LABELS[PROVIDER_GOOGLE_UNOFFICIAL])
