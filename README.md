# VibeTranslate / TranslationFiesta

Polyglot monorepo of TranslationFiesta ports with a shared feature set: **EN↔JA back-translation**, file import/export, batch processing, and a standardized provider UX across apps.

## Apps
- `TranslationFiestaPy/` (Python + Tkinter)
- `TranslationFiestaCSharp/` (C# WinForms)
- `TranslationFiestaFSharp/` (F# WinForms)
- `TranslationFiesta.WinUI/` (C# WinUI 3)
- `TranslationFiestaGo/` (Go + Wails/Svelte UI)
- `TranslationFiestaRuby/` (Ruby CLI + Sinatra web UI)
- `TranslationFiestaFlutter/` (Flutter)
- `TranslationFiestaSwift/` (Swift/SwiftUI package; macOS)
- `TranslationFiestaElectron/` (TypeScript/Electron)

## Providers (standardized across ports)
Every app exposes the same provider IDs:
- **Local (Offline)**: `TranslationFiestaLocal/` service (HTTP) using quantized JA↔EN models.
- **Google Translate (Unofficial / Free)**: must exist in every app; network calls are mocked in tests.
- **Google Cloud Translate (Official)**: API key required; optional cost tracking.

## Offline models (free, small, offline)
Default preset ships with ElanMT “tiny” models converted to CTranslate2 `int8`:
- One model per direction (each ≤ 20MB zipped).
- Install from any app’s “Local Model Manager” using **Install Default** (calls `POST /models/install`).

Details: `docs/OfflineModels.md`

## Cost tracking (opt-in)
- Disabled by default and hidden in UI unless enabled.
- Applies only to the official provider.
- Enable via Settings (where available) or set `TF_COST_TRACKING_ENABLED=1`.

Details: `docs/CostTracking.md`, `docs/COST_TRACKING_README.md`

## Docs
- Feature parity: `docs/FeatureComparison.md`
- Unofficial provider contract: `docs/UnofficialGoogleProvider.md`
- Translation contract: `docs/translation_contract.md`
- Build/setup: `docs/SetupAndBuild.md`
