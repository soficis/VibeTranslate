#!/usr/bin/env python3
"""
Provider identifiers and labels for TranslationFiesta.
"""

from __future__ import annotations

from typing import Dict, Optional

PROVIDER_LOCAL = "local"
PROVIDER_GOOGLE_UNOFFICIAL = "google_unofficial"
PROVIDER_GOOGLE_OFFICIAL = "google_official"

PROVIDER_LABELS: Dict[str, str] = {
    PROVIDER_LOCAL: "Local (Offline)",
    PROVIDER_GOOGLE_UNOFFICIAL: "Google Translate (Unofficial / Free)",
    PROVIDER_GOOGLE_OFFICIAL: "Google Cloud Translate (Official)",
}


def normalize_provider_id(provider_id: Optional[str], use_official_api: Optional[bool] = None) -> str:
    if provider_id in PROVIDER_LABELS:
        return provider_id  # type: ignore[return-value]
    if use_official_api:
        return PROVIDER_GOOGLE_OFFICIAL
    return PROVIDER_GOOGLE_UNOFFICIAL


def is_official_provider(provider_id: str) -> bool:
    return provider_id == PROVIDER_GOOGLE_OFFICIAL


def get_provider_label(provider_id: str) -> str:
    return PROVIDER_LABELS.get(provider_id, PROVIDER_LABELS[PROVIDER_GOOGLE_UNOFFICIAL])
