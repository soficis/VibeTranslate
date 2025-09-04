# TranslationFiesta Go

A comprehensive back-translation application written in Go, combining all features from the existing TranslationFiesta implementations (Flutter, F#, C#, Python). This application performs back-translation using Google's translation APIs with support for both official and unofficial endpoints.

## Features

### Core Translation Features
- **Back-translation**: English → Japanese → English translation pipeline
- **Dual API Support**: Both official Google Cloud Translation API and unofficial translate.googleapis.com
- **Real-time Progress**: Visual progress indicators during translation
- **Error Handling**: Comprehensive error handling with retry logic
- **Cancellation Support**: Ability to cancel ongoing translations

### File Processing
- **Multiple File Types**: Support for .txt, .md, .html files
- **HTML Parsing**: Automatic text extraction from HTML content
- **File Loading**: Drag-and-drop or file dialog support
- **Result Export**: Save translation results to files

### User Interface
- **Modern GUI**: Built with Fyne for cross-platform support
- **Dark/Light Themes**: Complete theme switching support
- **Responsive Layout**: Adaptable UI for different screen sizes
- **Keyboard Shortcuts**: Full keyboard navigation support
- **Menu System**: Traditional menu bar with all functions

### Advanced Features
- **Clean Architecture**: Domain-driven design with clear separation of concerns
- **Logging**: Comprehensive logging with configurable levels
- **Settings Persistence**: Automatic saving of user preferences
- **Cross-platform**: Windows, macOS, Linux support
- **Async Operations**: Non-blocking translation operations

## Architecture

The application follows Clean Architecture principles:

```
├── internal/
│   ├── domain/           # Business logic layer
│   │   ├── entities/     # Core business entities
│   │   ├── repositories/ # Abstract data interfaces
│   │   └── usecases/     # Application use cases
│   ├── data/             # Data access layer
│   │   ├── repositories/ # Concrete repository implementations
│   │   └── services/     # External service integrations
│   ├── presentation/     # Presentation layer
│   └── gui/              # GUI implementation
└── utils/                # Shared utilities
```

## Installation

### Prerequisites
- Go 1.19 or later
- GCC (for CGO dependencies)

### Build from Source

1. Clone the repository:
```bash
git clone <repository-url>
cd TranslationFiestaGo
```

2. Install dependencies:
```bash
go mod download
```

3. Build the application:
```bash
go build -o translationfiestago main.go
```

4. Run the application:
```bash
./translationfiestago
```

## Usage

### Basic Translation

1. Launch the application
2. Enter English text in the input field
3. Click "Backtranslate" or press Enter
4. View the Japanese intermediate result and final English back-translation

### File Operations

- **Load File**: Click "Load File" or use Ctrl+O
- **Supported formats**: .txt, .md, .html
- **HTML processing**: Automatic text extraction from HTML content

### API Configuration

- **Unofficial API**: Default, no configuration required
- **Official API**: Click "Use Official API" and enter your Google Cloud API key

### Theme Switching

- Click the theme toggle button to switch between light and dark modes
- Theme preference is automatically saved

### Keyboard Shortcuts

- `Ctrl+O`: Load file
- `Ctrl+S`: Save result
- `Ctrl+C`: Copy result
- `Ctrl+Q`: Quit application

## Configuration

The application stores settings in:
- **Windows**: `%APPDATA%\TranslationFiestaGo\settings.json`
- **macOS**: `~/Library/Application Support/TranslationFiestaGo/settings.json`
- **Linux**: `~/.config/TranslationFiestaGo/settings.json`

Settings include:
- Theme preference
- API configuration
- Window size and position
- Language preferences

## API Keys

### Official Google Cloud Translation API

1. Create a Google Cloud Project
2. Enable the Cloud Translation API
3. Create an API key
4. Enter the key in the application

### Unofficial API

No configuration required. Uses `translate.googleapis.com` endpoint.

## Development

### Project Structure

- `main.go`: Application entry point
- `internal/domain/`: Business logic and entities
- `internal/data/`: Data access implementations
- `internal/gui/`: User interface components
- `internal/utils/`: Shared utilities

### Adding New Features

1. Define entities in `internal/domain/entities/`
2. Create repository interfaces in `internal/domain/repositories/`
3. Implement repositories in `internal/data/repositories/`
4. Add use cases in `internal/domain/usecases/`
5. Update GUI in `internal/gui/`

### Testing

```bash
go test ./...
```

### Building for Distribution

```bash
# Windows
GOOS=windows GOARCH=amd64 go build -o translationfiestago.exe main.go

# macOS
GOOS=darwin GOARCH=amd64 go build -o translationfiestago main.go

# Linux
GOOS=linux GOARCH=amd64 go build -o translationfiestago main.go
```

## Feature Comparison

| Feature | Original F# | Flutter | C# WinUI | Python | Go Port |
|---------|-------------|---------|----------|--------|---------|
| Back-translation | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unofficial API | ✅ | ✅ | ✅ | ✅ | ✅ |
| Official API | ✅ | ✅ | ✅ | ✅ | ✅ |
| HTML Parsing | ✅ | ❌ | ❌ | ❌ | ✅ |
| Dark Theme | ✅ | ✅ | ❌ | ✅ | ✅ |
| File Loading | ✅ | ❌ | ❌ | ✅ | ✅ |
| Settings Persistence | ❌ | ✅ | ❌ | ❌ | ✅ |
| Cross-platform | ❌ | ✅ | ❌ | ✅ | ✅ |
| Clean Architecture | ❌ | ✅ | ❌ | ❌ | ✅ |
| Logging | ✅ | ✅ | ❌ | ✅ | ✅ |
| Progress Indicators | ✅ | ❌ | ❌ | ✅ | ✅ |
| Keyboard Shortcuts | ✅ | ❌ | ✅ | ❌ | ✅ |

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Original TranslationFiesta concept and implementations
- Google Translate APIs
- Fyne GUI framework
- Go community for excellent libraries

## Troubleshooting

### Common Issues

1. **Build fails with CGO errors**
   - Install GCC: `sudo apt-get install gcc` (Linux) or `choco install mingw` (Windows)

2. **Theme doesn't apply immediately**
   - Restart the application after theme changes

3. **API requests fail**
   - Check internet connection
   - Verify API key for official API
   - Check firewall settings

4. **File loading fails**
   - Ensure file is not locked by another application
   - Check file permissions
   - Verify supported file format

### Logs

Logs are stored in:
- **Windows**: `%APPDATA%\TranslationFiestaGo\translationfiestago.log`
- **macOS**: `~/Library/Application Support/TranslationFiestaGo/translationfiestago.log`
- **Linux**: `~/.config/TranslationFiestaGo/translationfiestago.log`

## Version History

- **v1.0.0**: Initial Go port with all features from existing implementations
  - Complete back-translation pipeline
  - Dual API support
  - Cross-platform GUI
  - Settings persistence
  - File processing
  - Theme support
