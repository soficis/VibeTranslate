# TranslationFiestaGo (Go Implementation)

## Overview

TranslationFiestaGo is a modern Go implementation of the TranslationFiesta application, featuring Clean Architecture principles and comprehensive domain modeling. It provides both CLI and GUI interfaces for cross-platform back-translation functionality.

## Architecture

### Clean Architecture Implementation

The Go implementation follows Clean Architecture principles with clear separation of concerns:

```
internal/
├── domain/           # Business logic layer
│   ├── entities/     # Core business entities
│   ├── repositories/ # Abstract data interfaces
│   └── usecases/     # Application use cases
├── data/             # Data access layer
│   ├── repositories/ # Concrete repository implementations
│   └── services/     # External service integrations
├── presentation/     # Presentation layer
└── gui/              # GUI implementation (Fyne)
```

### Key Components

#### Domain Layer
- **Entities**: `Translation`, `Language`, `FileInfo`, `BackTranslation`
- **Repositories**: Abstract interfaces for data access
- **Use Cases**: Application business logic

#### Data Layer
- **Translation Service**: Handles Google Translate API calls
- **File Repository**: Manages file I/O with HTML parsing
- **Settings Repository**: JSON-based configuration management

#### Presentation Layer
- **CLI Interface**: Command-line interface with interactive commands
- **GUI Interface**: Fyne-based desktop application

## Features

### Core Functionality
- ✅ **Back-translation**: English → Japanese → English
- ✅ **Dual API Support**: Official and unofficial Google Translate APIs
- ✅ **File Processing**: .txt, .md, .html with HTML text extraction
- ✅ **Settings Persistence**: JSON-based configuration
- ✅ **Cross-platform**: Windows, macOS, Linux support
- ✅ **Clean Architecture**: Domain-driven design implementation

### Advanced Features
- **Batch Processing**: Process entire directories of text files.
- **Quality Metrics (BLEU)**: Assess translation quality with BLEU scores.
- **Cost Tracking**: Track API usage costs and set monthly budgets.
- **Advanced Exporting**: Export to PDF, DOCX, and HTML with custom templates.
- **Secure Storage**: Securely store API keys using platform-specific features.
- **EPUB Processing**: Extract and translate text from `.epub` files.
- **Translation Memory**: Cache translations to improve performance and reduce costs.

### CLI Features
- Interactive command-line interface
- File import/export functionality
- API key management
- Real-time translation status

### GUI Features (⚠️ Build Issues)
- Modern desktop interface with Fyne
- Dark/light theme support
- Progress indicators
- File picker integration
- Keyboard shortcuts

## Installation & Setup

### Prerequisites
- Go 1.21 or later
- GCC (for CGO dependencies, optional for CLI-only)

### Build Instructions

#### CLI Version (Recommended)
```bash
cd TranslationFiestaGo
go mod tidy
go build -o translationfiestago-cli cmd/cli/main.go
```

#### GUI Version (May have build issues on Windows)
```bash
cd TranslationFiestaGo
go mod tidy
go build -tags=software -o translationfiestago main.go  # May fail on Windows
```

## Usage

### CLI Interface

```bash
# Start the CLI
./translationfiestago-cli

# Available commands
> translate <text>    - Translate text
> file <path>        - Load and translate file
> set-api <key>      - Set official API key
> toggle-api         - Toggle between official/unofficial API
> status            - Show current configuration
> quit              - Exit
```

### Example Usage

```bash
# Translate text
> translate Hello world, this is a test.

# Load file
> file document.txt

# Set API key for official API
> set-api YOUR_GOOGLE_CLOUD_API_KEY

# Check status
> status
```

## API Integration

### Unofficial Google Translate API
- **Endpoint**: `https://translate.googleapis.com/translate_a/single`
- **Usage**: Free, no API key required
- **Limitations**: Subject to Google's discretion

### Official Google Cloud Translation API
- **Service**: Google Cloud Translation API v2
- **Setup**: Requires Google Cloud project and API key
- **Pricing**: Pay-per-use ($20/1M characters)
- **Benefits**: Enterprise-grade reliability

## Configuration

Settings are stored in platform-specific locations:

### Windows
- Settings: `%APPDATA%\TranslationFiestaGo\settings.json`
- Logs: `%APPDATA%\TranslationFiestaGo\translationfiestago.log`

### macOS
- Settings: `~/Library/Application Support/TranslationFiestaGo/settings.json`
- Logs: `~/Library/Application Support/TranslationFiestaGo/translationfiestago.log`

### Linux
- Settings: `~/.config/TranslationFiestaGo/settings.json`
- Logs: `~/.config/TranslationFiestaGo/translationfiestago.log`

## File Processing

### Supported Formats
- **.txt**: Plain text files
- **.md**: Markdown files
- **.html**: HTML files with automatic text extraction

### HTML Processing
The implementation includes sophisticated HTML parsing that:
- Removes script, style, and code blocks
- Strips HTML tags while preserving text content
- Normalizes whitespace
- Handles encoding properly

## Error Handling & Logging

### Comprehensive Error Handling
- Network error recovery
- API rate limiting handling
- File I/O error management
- Graceful degradation

### Logging
- Structured logging with configurable levels
- Debug, Info, Warn, Error levels
- Automatic log rotation
- Platform-specific log file locations

## Development

### Project Structure
```
TranslationFiestaGo/
├── cmd/cli/main.go          # CLI application entry point
├── main.go                  # GUI application entry point
├── internal/
│   ├── domain/             # Business logic
│   ├── data/               # Data access implementations
│   ├── gui/                # GUI components
│   └── utils/              # Shared utilities
├── go.mod
├── go.sum
└── README.md
```

### Adding New Features

1. **Define entities** in `internal/domain/entities/`
2. **Create repository interfaces** in `internal/domain/repositories/`
3. **Implement use cases** in `internal/domain/usecases/`
4. **Add concrete implementations** in `internal/data/`
5. **Update presentation layer** (CLI/GUI)

### Testing
```bash
go test ./...
```

## Build Issues & Solutions

### GUI Build Issues on Windows

**Problem**: Fyne GUI has OpenGL dependency conflicts on Windows
```
build constraints exclude all Go files in OpenGL libraries
```

**Solutions**:
1. **Use CLI version** (recommended): `go build cmd/cli/main.go`
2. **Try build tags**: `go build -tags=software main.go`
3. **Disable CGO**: `CGO_ENABLED=0 go build main.go`
4. **Use Linux/macOS**: GUI builds successfully on Unix systems

### Dependencies

- **fyne.io/fyne/v2**: GUI framework (optional)
- **github.com/go-resty/resty/v2**: HTTP client
- **golang.org/x/net/html**: HTML parsing

## Performance

### Benchmarks
- CLI version: ~500-800ms per translation
- Memory usage: ~20MB baseline
- Concurrent processing support

### Optimization Features
- HTTP connection reuse
- Response caching
- Efficient HTML parsing
- Minimal memory footprint

## Contributing

### Code Standards
- Follow Go idioms and conventions
- Comprehensive error handling
- Clean Architecture principles
- Unit tests for new functionality

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Add tests
4. Ensure CLI builds successfully
5. Submit PR with detailed description

## Troubleshooting

### Common Issues

#### CLI Won't Start
```bash
# Check Go installation
go version

# Rebuild dependencies
go mod tidy
go build cmd/cli/main.go
```

#### Translation Failures
```
Error: HTTP 429 (Rate Limited)
Solution: Wait and retry, or use official API
```

#### File Loading Issues
```
Error: Access denied
Solution: Check file permissions, run as administrator if needed
```

### Getting Help
- Check logs in platform-specific locations
- Verify internet connectivity
- Test with simple text first
- Use CLI version for reliable operation

## Future Enhancements

- Web API server mode
- Batch file processing
- Additional language support
- Plugin architecture for translation providers
- Advanced HTML processing
- Mobile app support via Flutter integration

---

**TranslationFiestaGo**: Clean Architecture implementation with reliable CLI and experimental GUI interfaces.
