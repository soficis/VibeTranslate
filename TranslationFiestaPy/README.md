# TranslationFiesta Python Application

This folder contains the Python version of TranslationFiesta - a desktop application for back-translation using Google's translation API.

## Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable.
- Override data root with `TF_APP_HOME`.
- Startup failures are logged to `./data/logs/startup_error.log` and shown in a dialog for windowed builds.

## Files

- `TranslationFiesta.py` - Main application file
- `requirements.txt` - Python dependencies
- `test_sample.html` - Sample HTML file for testing
- `test_sample.txt` - Sample text file for testing

## Quick Start

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Run the application:
   ```bash
   python TranslationFiesta.py
   ```

For PyInstaller builds, run the executable from the **dist output** folder (portable payload), not from the temporary `build/` work folder.

## Features

- 🌙 Dark/Light mode toggle
- 📁 File loading (.txt, .md, .html)
- 🏗️ Smart HTML text extraction
- 🎯 English ↔ Japanese back-translation
- ⚡ Asynchronous processing
- 🔌 Provider support: Unofficial Google Translate (default)
- 🔁 Retry with exponential backoff
- 📊 Conditional progress bar during translation
- 💾 Save results and 📋 copy back-translation (Ctrl+S / Ctrl+C)

## Requirements

- Python 3.6+
- Internet connection for translation API
- Dependencies: requests, beautifulsoup4

### Architecture

- Main class: `TranslationFiesta` (GUI and orchestration)
- Translation: `translation_services.translate_text` with retry/backoff
- File IO: `file_utils.load_text_from_path` and HTML extraction
- Logging: `app_logger.create_logger` with rotating file handler

For detailed usage instructions, see the main [USAGE.md](../USAGE.md) file.
