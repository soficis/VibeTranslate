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

## Offline models (free, small, offline)

Default preset ships with ElanMT “tiny” models converted to CTranslate2 `int8`:

- One model per direction (each ≤ 20MB zipped).
- Install from any app’s “Local Model Manager” using **Install Default** (calls `POST /models/install`).

## Building and Testing

A unified root `Makefile` provides commands to evaluate the codebase across all languages:

- `make test-all`
- `make lint-all`
For specific targets, see the Makefile (e.g., `make test-python`).

## Build Instructions per App

### Python (Tkinter) `TranslationFiestaPy/`

```bash
cd TranslationFiestaPy
pip install -r requirements.txt
python TranslationFiesta.py
```

### C# WinForms `TranslationFiestaCSharp/`

```bash
cd TranslationFiestaCSharp
dotnet run
```

### F# WinForms `TranslationFiestaFSharp/`

```bash
cd TranslationFiestaFSharp
dotnet run
```

### C# WinUI 3 `TranslationFiesta.WinUI/`

Open `TranslationFiesta.WinUI.sln` in Visual Studio and deploy, or run:

```bash
cd TranslationFiesta.WinUI
dotnet build
```

### Go (Wails) `TranslationFiestaGo/`

Requires [Wails CLI](https://wails.io/).

```bash
cd TranslationFiestaGo
wails build # or wails dev for live reload
```

### Ruby (Sinatra) `TranslationFiestaRuby/`

```bash
cd TranslationFiestaRuby
bundle install
ruby lib/translation_fiesta/web/app.rb
# Service runs on http://localhost:4567
```

### Flutter `TranslationFiestaFlutter/`

```bash
cd TranslationFiestaFlutter
flutter pub get
flutter run -d macos # or windows/linux depending on your OS
```

### Swift (macOS) `TranslationFiestaSwift/`

```bash
cd TranslationFiestaSwift
swift run
```

### Electron `TranslationFiestaElectron/`

```bash
cd TranslationFiestaElectron
npm install
npm run dev
```
