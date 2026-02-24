# TranslationFiesta Ruby

A professional Ruby implementation featuring a modern Sinatra web UI with dark mode (default), comprehensive file import/export, batch processing, and full feature parity with other TranslationFiesta implementations.

A comprehensive Ruby implementation of the TranslationFiesta application for English ↔ Japanese back-translation.

## 🌟 Features

### Core Translation Features
- **Back-translation**: English → Japanese → English using the unofficial provider
- **Provider Support**: Google Translate (unofficial/free)
- **Translation Memory**: Intelligent caching system to reduce repeated API calls

### Advanced Features
- **Batch Processing**: Process entire directories of files with multi-threading support
- **Advanced Export**: Export results to PDF, DOCX, HTML, and text formats
- **File Support**: Process .txt, .md, .html, and .epub files
- **Web Interface**: Modern Sinatra interface for desktop and mobile browsers
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
└── web/                     # Sinatra UI components
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
A modern, professional web interface with dark mode (default) and comprehensive features including file import, export, batch processing, and analytics dashboard.

**🚀 Quick Start:**
```bash
ruby bin/translation_fiesta
```
Open http://127.0.0.1:4567 in your browser to access the full-featured web UI.

**Mock / offline mode** (no external API calls):
```bash
TF_USE_MOCK=1 ruby bin/translation_fiesta
```

**Features:**
- 🌙 **Dark Mode (Default)**: Modern dark theme with light mode toggle
- 📁 **File Import**: Drag & drop or click to upload TXT, MD, HTML, EPUB files
- 💾 **Export Options**: Export to PDF, DOCX, HTML, TXT formats
- 🔄 **Batch Processing**: Process multiple files simultaneously with progress tracking
- 📈 **Analytics Dashboard**: Translation memory and activity stats
- 🎛️ **Settings**: Configurable provider preferences
- 📱 **Responsive Design**: Works on desktop and mobile devices

**Environment Variables:**
| Variable | Default | Purpose |
|----------|---------|---------|
| TF_WEB_BIND | 127.0.0.1 | Bind address |
| TF_WEB_PORT | 4567 | Port |
| TF_USE_MOCK | (unset) | Enable mock translation when set to 1 |
| TF_EXPORT_DIR | exports | Export output directory |
| TF_API_TOKEN | (unset) | API token for authentication |
| TF_RATE_LIMIT | 60 | Requests per minute per IP |

**API Endpoints:**
| Method | Path | Description |
|--------|------|-------------|
| GET | / | Modern web UI |
| POST | /api/translate | Translate text (JSON: { text, api_type }) |
| GET | /api/result/:id | Fetch stored result |
| POST | /api/export/:id | Export result (JSON: { format }) |
| POST | /api/batch | Batch process files (JSON: { files, api_type, threads }) |
| GET | /api/analytics | Get analytics data |
| GET | /health | Health check |

**Example API Usage:**
```bash
# Translate text
curl -X POST http://127.0.0.1:4567/api/translate \
   -H 'Content-Type: application/json' \
   -d '{"text":"Hello world","api_type":"unofficial"}'

# Get analytics
curl http://127.0.0.1:4567/api/analytics

# Batch process (simplified for web UI)
curl -X POST http://127.0.0.1:4567/api/batch \
   -H 'Content-Type: application/json' \
   -d '{"files":[{"filename":"test.txt","content":"Hello"}],"api_type":"unofficial"}'
```

**Supported Export Formats:**
- **TXT/MD**: Plain text and Markdown export (always available)
- **PDF**: Formatted PDF documents (always available)
- **HTML**: Web-ready HTML documents (always available)
- **DOCX**: Microsoft Word documents (⚠️ **untested/broken**)

**DOCX Export:**
⚠️ **DOCX export functionality is currently untested and may not work properly.**

**Known Issues:**
- Compatibility problems with the docx gem
- Version conflicts between different docx gem versions
- Limited testing of the export functionality

**If you encounter issues:**
```bash
# Try installing the specific version
gem uninstall docx
gem install docx -v 0.6.2
```

**Status:** ⚠️ **DOCX export is untested and may not work**

**Recommended Alternatives (always available):**
1. **PDF Export**: Fully supported with professional formatting
2. **HTML Export**: Web-ready documents with complete styling
3. **TXT/MD Export**: Plain text formats that work reliably

### Command Line Interface

**Translate text directly**:
```bash
rake cli translate "Hello, world!"
```

**Process a single file**:
```bash
rake cli file sample.txt --api unofficial --output result.pdf
```

**Batch process directory**:
```bash
rake cli batch ./documents --threads 8 --format pdf
```

### CLI Options
- `--api [unofficial]`: Choose API type (default: unofficial)
- `--output FILE`: Specify output file for results
- `--format [txt|pdf|docx|html]`: Export format
- `--threads COUNT`: Number of threads for batch processing
- `--verbose`: Enable verbose output

## 🔧 Configuration

Edit `config/config.yml` to customize:
- Default API settings
- Batch processing options
- Export preferences
- UI themes

## 🧪 Testing

```bash
# Note: The Ruby port is currently untested. Tests are being added; use the mock mode to exercise the web UI and CLI locally.
# Run the available request specs (mock mode):
TF_USE_MOCK=1 rspec spec/requests/web_app_spec.rb

# Run all tests (may be incomplete)
rake spec

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

## 🔄 Translation Memory

- Automatic caching of translation pairs
- 30-day TTL for cached entries
- Reduces repeated translation requests and improves performance
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
