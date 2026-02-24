#!/usr/bin/env python3
"""
Provider identifiers and labels for TranslationFiesta.
"""

from __future__ import annotations

from typing import Dict, Optional

PROVIDER_GOOGLE_UNOFFICIAL = "google_unofficial"

PROVIDER_LABELS: Dict[str, str] = {
    PROVIDER_GOOGLE_UNOFFICIAL: "Google Translate (Unofficial / Free)",
}


def normalize_provider_id(provider_id: Optional[str]) -> str:
    if provider_id in PROVIDER_LABELS:
        return provider_id  # type: ignore[return-value]
    return PROVIDER_GOOGLE_UNOFFICIAL

def get_provider_label(provider_id: str) -> str:
    return PROVIDER_LABELS.get(provider_id, PROVIDER_LABELS[PROVIDER_GOOGLE_UNOFFICIAL])
