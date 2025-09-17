# TranslationFiesta Ruby

IMPORTANT: This Ruby port is experimental and currently untested. It was added to provide feature parity with other ports, but automated tests and full QA are still pending. Use the mock mode for local exploration without API credentials.

A comprehensive Ruby implementation of the TranslationFiesta application for English ↔ Japanese back-translation with quality assessment and cost tracking.

## 🌟 Features

### Core Translation Features
- **Back-translation**: English → Japanese → English using Google Translate APIs
- **Dual API Support**: Both unofficial (free) and official Google Cloud Translation API
- **Quality Assessment**: BLEU score calculation for translation quality metrics
- **Translation Memory**: Intelligent caching system to reduce API calls and costs

### Advanced Features
- **Batch Processing**: Process entire directories of files with multi-threading support
- **Cost Tracking**: Comprehensive cost monitoring with monthly budgets and warnings
- **Advanced Export**: Export results to PDF, DOCX, HTML, and text formats
- **Secure Storage**: Platform-specific secure storage for API keys using keyring
- **File Support**: Process .txt, .md, .html, and .epub files
- **GUI Interface**: Modern Tk-based graphical user interface
- **CLI Interface**: Full command-line interface for automation and scripting

## 🏗️ Architecture

This application follows Clean Architecture principles with clear separation of concerns:

```
lib/translation_fiesta/
├── domain/                    # Business logic and entities
│   ├── entities/             # Core business objects
│   ├── repositories/         # Abstract interfaces
│   └── services/            # Business logic services
├── use_cases/               # Application orchestration
├── data/                    # Data access implementations
│   └── repositories/        # Concrete repository implementations
├── features/                # Feature-specific modules
├── infrastructure/          # Cross-cutting concerns
└── gui/                     # User interface components
```

## 🚀 Installation

1. **Prerequisites**:
   - Ruby 3.2+
   - Bundler gem

2. **Install Dependencies**:
   ```bash
   cd TranslationFiestaRuby
   # Recommended: use a gemset or bundler environment. Be aware some native gems (nokogiri) may require platform-specific build tools.
   bundle install
   ```

   #### Windows-Specific Setup
   If `bundle install` fails on Windows due to native gem compilation:

   **Option 1: RubyInstaller with DevKit (Recommended)**
   ```powershell
   # Download Ruby+Devkit from: https://rubyinstaller.org/
   # After installation:
   ridk install  # Install MSYS2 toolchains
   ridk enable   # Enable for gem compilation
   bundle install
   ```

   **Option 2: MSYS2 Toolchain**
   ```bash
   # Install MSYS2 from: https://www.msys2.org/
   pacman -Syu
   pacman -S mingw-w64-x86_64-ruby
   pacman -S mingw-w64-x86_64-gcc
   bundle install
   ```

   **Troubleshooting Native Gems**
   ```powershell
   # Install problematic gems individually
   gem install nokogiri --platform=ruby
   gem install sqlite3 --platform=ruby

   # Or pin precompiled versions in Gemfile
   # gem 'nokogiri', '1.18.10-x64-mingw-ucrt'
   # gem 'sqlite3', '1.7.3-x64-mingw-ucrt'
   ```

3. **Setup Database**:
   ```bash
   rake setup_db
   ```

## 💻 Usage

### Web UI (Sinatra)
The legacy Tk GUI has been replaced by a cross-platform web interface.

Start server (defaults to http://127.0.0.1:4567):
```bash
ruby bin/translation_fiesta
```

Mock / offline mode (no external API calls):
```bash
TF_USE_MOCK=1 ruby bin/translation_fiesta
```

Environment variables:
| Variable | Default | Purpose |
|----------|---------|---------|
| TF_WEB_BIND | 127.0.0.1 | Bind address |
| TF_WEB_PORT | 4567 | Port |
| TF_USE_MOCK | (unset) | Enable mock translation when set to 1 |
| TF_EXPORT_DIR | exports | Export output directory |

Key endpoints:
| Method | Path | Description |
|--------|------|-------------|
| POST | /api/translate | Translate text (JSON: { text, api_type }) |
| GET | /api/result/:id | Fetch stored result |
| POST | /api/export/:id | Export result (JSON: { format }) |
| GET | /health | Health check |

Example translate request:
```bash
curl -X POST http://127.0.0.1:4567/api/translate \
   -H 'Content-Type: application/json' \
   -d '{"text":"Hello world","api_type":"unofficial"}'
```

Supported export formats: txt, md, pdf, html, docx* (*requires docx gem installed)

### Command Line Interface

**Translate text directly**:
```bash
rake cli translate "Hello, world!"
```

**Process a single file**:
```bash
rake cli file sample.txt --api official --output result.pdf
```

**Batch process directory**:
```bash
rake cli batch ./documents --threads 8 --format pdf
```

**View cost summary**:
```bash
rake cli cost
```

### CLI Options
- `--api [unofficial|official]`: Choose API type (default: unofficial)
- `--output FILE`: Specify output file for results
- `--format [txt|pdf|docx|html]`: Export format
- `--threads COUNT`: Number of threads for batch processing
- `--verbose`: Enable verbose output

## 🔧 Configuration

Edit `config/config.yml` to customize:
- Default API settings
- Cost tracking budgets
- Batch processing options
- Export preferences
- UI themes

## 🔐 API Keys

For official Google Translate API:
1. Get API key from Google Cloud Console
2. Use the Settings dialog in GUI or store securely using the CLI
3. Keys are stored using platform-specific secure storage (keyring)

## 📊 Cost Tracking

- **Monthly Budgets**: Set spending limits
- **Real-time Monitoring**: Track costs as you translate
- **Budget Warnings**: Alerts at 80% of budget
- **Detailed Reports**: Cost breakdown by API type and time period

## 🧪 Testing

```bash
# Note: The Ruby port is currently untested. Tests are being added; use the mock mode to exercise the web UI and CLI locally.
# Run the available request specs (mock mode):
TF_USE_MOCK=1 rspec spec/requests/web_app_spec.rb

# Run all tests (may be incomplete)
rake spec

# Run specific test file
rspec spec/domain/services/bleu_scorer_spec.rb

# Run with coverage
rake spec

# Lint code
rake rubocop
```

## 📁 File Support

| Format | Read | Export | Notes |
|--------|------|--------|-------|
| TXT    | ✅   | ✅     | Plain text files |
| MD     | ✅   | ✅     | Markdown files |
| HTML   | ✅   | ✅     | HTML content extraction |
| EPUB   | ✅   | ❌     | E-book text extraction |
| PDF    | ❌   | ✅     | Export only |
| DOCX   | ❌   | ✅     | Export only |

## 🎯 Quality Metrics

BLEU scores are calculated and interpreted as:
- **0.9-1.0**: Excellent translation quality
- **0.7-0.9**: Very good quality
- **0.5-0.7**: Good quality
- **0.3-0.5**: Fair quality
- **0.0-0.3**: Poor quality

## 🔄 Translation Memory

- Automatic caching of translation pairs
- 30-day TTL for cached entries
- Reduces API costs and improves performance
- SQLite-based storage for persistence

## 🚀 Development

### Project Structure
- **Domain Layer**: Core business logic, entities, and repository interfaces
- **Use Cases**: Application-specific business rules
- **Data Layer**: Database and external API implementations
- **Features**: High-level application features
- **Infrastructure**: Cross-cutting concerns like dependency injection
- **GUI**: User interface components

### Adding New Features
1. Start with domain entities and repositories
2. Implement use cases for business logic
3. Add data layer implementations
4. Create feature modules
5. Update GUI and CLI interfaces
6. Add comprehensive tests

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Follow Ruby style guidelines (RuboCop)
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is part of the VibeTranslate collection. See the main repository for license information.

## 🔗 Related Projects

- **TranslationFiestaPy**: Original Python implementation
- **TranslationFiestaGo**: Go implementation
- **TranslationFiesta.WinUI**: Windows WinUI implementation
- **TranslationFiestaFlutter**: Cross-platform Flutter implementation
- **TranslationFiestaFSharp**: F# functional implementation

---