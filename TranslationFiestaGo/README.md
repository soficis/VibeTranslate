# TranslationFiestaGo

A comprehensive back-translation application written in Go, combining all features from the existing TranslationFiesta implementations (Flutter, F#, C#, Python). This application performs back-translation using the Google Translate unofficial endpoint.

## Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable.
- WebView2 user data path (Windows): `./data/webview2`.
- Override data root with `TF_APP_HOME`.
- Optional bundled WebView2 fixed runtime folder names: `webview2-runtime/` or `WebView2Runtime/` beside the executable.

## Features

### Core Translation Features
- **Back-translation**: English → Japanese → English translation pipeline
- **Provider Support**: Unofficial translate.googleapis.com
- **Real-time Progress**: Visual progress indicators during translation
- **Error Handling**: Comprehensive error handling with retry logic
- **Cancellation Support**: Ability to cancel ongoing translations

### User Interface
- **Modern GUI**: A modern, cross-platform GUI built with Wails.
- **Clean Interface**: Intuitive and user-friendly interface for translation operations.
- **Cross-platform**: Windows, macOS, Linux support

## Usage

1. Run the application: `wails dev`
2. Enter English text in the input field.
3. Click the "Backtranslate" button.
4. View the Japanese intermediate result and final English back-translation.

## Building

To build a redistributable, production mode package, use `wails build`.
