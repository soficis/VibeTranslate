# Feature Comparison (Parity Matrix)

This document tracks cross-port feature parity. Provider behavior is standardized by `docs/translation_contract.md` and `docs/UnofficialGoogleProvider.md`.

## Ports
| App | Language | UI framework |
|-----|----------|--------------|
| TranslationFiestaPy | Python | Tkinter |
| TranslationFiestaCSharp | C# | WinForms |
| TranslationFiestaFSharp | F# | WinForms |
| TranslationFiesta.WinUI | C# | WinUI 3 |
| TranslationFiestaGo | Go | Wails + Svelte |
| TranslationFiestaRuby | Ruby | Sinatra (web UI) |
| TranslationFiestaFlutter | Dart | Flutter |
| TranslationFiestaSwift | Swift | SwiftUI |
| TranslationFiestaElectron | TypeScript | Electron + React |

## Provider parity
| App | Local (Offline) | Google Translate (Unofficial / Free) | Google Cloud Translate (Official) |
|-----|------------------|---------------------------------------|-----------------------------------|
| TranslationFiestaPy | Yes | Yes | Yes |
| TranslationFiestaCSharp | Yes | Yes | Yes |
| TranslationFiestaFSharp | Yes | Yes | Yes |
| TranslationFiesta.WinUI | Yes | Yes | Yes |
| TranslationFiestaGo | Yes | Yes | Yes |
| TranslationFiestaRuby | Yes | Yes | Yes |
| TranslationFiestaFlutter | Yes | Yes | Yes |
| TranslationFiestaSwift | Yes | Yes | Yes |
| TranslationFiestaElectron | Yes | Yes | Yes |

Notes:
- Local (Offline) uses `TranslationFiestaLocal/` over HTTP and supports backtranslation via `POST /backtranslate`.
- Unofficial provider tests are mocked (no live network).

## UI parity (core workflow)
| Capability | Py | C# | F# | WinUI | Go | Ruby | Flutter | Swift | Electron |
|-----------|----|----|----|-------|----|------|---------|-------|----------|
| Provider selector | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| API key input (official) | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Local model manager (status/verify/remove/install) | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| EN↔JA backtranslation | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Import `.txt/.md/.html` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Export/copy results | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Batch processing | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| Translation memory | Varies | Varies | Varies | Varies | Varies | Varies | Varies | Varies | Varies |

## Cost tracking parity
- Cost tracking is **opt-in** and hidden unless enabled: `TF_COST_TRACKING_ENABLED=1`.
- Applies only to the official provider.
- Implemented in: Py, Go, C# WinForms, F#, WinUI, Ruby, Swift.
- Not implemented (yet): Flutter, Electron.
