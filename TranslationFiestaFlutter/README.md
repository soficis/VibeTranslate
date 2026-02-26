# TranslationFiestaFlutter

**Repository**: [https://github.com/soficis/VibeTranslate](https://github.com/soficis/VibeTranslate)

A Flutter port of the TranslationFiestaFSharp application, implementing Clean Code principles and Clean Architecture. This application provides backtranslation functionality using the unofficial provider with a modern, responsive UI.

## Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable.
- Override data root with `TF_APP_HOME`.

## Overview

TranslationFiestaFlutter is a complete rewrite of the TranslationFiestaFSharp Windows Forms application in Flutter/Dart. It maintains all original functionality while following modern mobile/desktop development best practices and Clean Code principles.

## Features

### 🎯 Core Functionality
- **Backtranslation**: English → Japanese → English translation pipeline
- **Provider Support**:
  - Unofficial Google Translate (free, immediate setup)
- **Retry Logic**: Exponential backoff with configurable attempts
- **File Operations**: Import from .txt, .md, .html files with text extraction
- **Export Results**: Save backtranslation results to files
- **Clipboard Integration**: Copy results with one click

### 🎨 User Interface
- **Modern Material Design**: Clean, responsive interface
- **Dark/Light Theme**: Persistent theme preferences
- **Progress Indication**: Visual feedback during operations
- **Status Updates**: Real-time operation status
- **Responsive Layout**: Adapts to different screen sizes

### 📊 Logging & Monitoring
- **Comprehensive Logging**: All operations logged to file
- **Thread-safe**: Concurrent access protection
- **Multiple Levels**: DEBUG, INFO, WARN, ERROR
- **Performance Tracking**: Operation timing and metrics

## Architecture

### Clean Architecture Layers

```
lib/
├── core/                    # Core utilities and business rules
│   ├── constants/          # Application constants
│   ├── errors/            # Error handling (Either, Failure)
│   └── utils/             # Logger and utilities
├── data/                   # Data layer (repositories, services)
│   ├── repositories/      # Repository implementations
│   └── services/          # External service integrations
├── domain/                 # Domain layer (business logic)
│   ├── entities/          # Business objects
│   ├── repositories/      # Repository interfaces
│   └── usecases/          # Use cases
└── presentation/          # Presentation layer (UI)
    ├── pages/             # Main pages
    ├── widgets/           # UI components
    └── providers/         # State management
```

### Clean Code Principles Applied

#### 🎯 Single Responsibility
- Each class has one clear purpose
- Functions do one thing well
- Clear separation of concerns

#### 📝 Meaningful Names
- Descriptive class and function names
- Self-documenting code
- Clear variable naming

#### 🔄 No Side Effects
- Pure functions where possible
- Explicit state management
- Predictable behavior

#### 🧪 Error Handling
- Comprehensive error handling with Result types
- No silent failures - all errors logged
- Graceful degradation with retry mechanisms

## Installation & Setup

### Prerequisites
- **Flutter SDK**: 3.10.0 or newer
- **Dart SDK**: 3.0.0 or newer
- **Internet connection** for translation services

### Installation Steps

1. **Navigate to the project directory**:
   ```bash
   cd TranslationFiestaFlutter
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   flutter run
   ```

### Dependencies

#### Core Dependencies
- **flutter**: UI framework
- **http**: HTTP client for API calls
- **file-based settings**: Stored under portable data root (`./data/settings.json`)
- **provider**: State management

#### Development Dependencies
- **flutter_lints**: Code linting
- **flutter_test**: Unit testing framework

## Usage Guide

### Basic Operation

1. **Launch**: Run `flutter run` in the project directory
2. **Input Text**: Type or paste English text in the input area
3. **Configure Provider**: Use unofficial API (default, no setup)
4. **Translate**: Click "Backtranslate" button
5. **Monitor Progress**: Watch status updates and progress indicators
6. **Review Results**:
   - **Intermediate**: Japanese translation
   - **Final**: Back-translated English result

### Advanced Features

#### File Import
1. Click "Import" button
2. Select supported file (.txt, .md, .html)
3. Content loads automatically into input area
4. Proceed with translation

#### Theme Switching
- Click theme toggle button (moon/sun icon)
- Switches between dark/light modes
- Preference maintained across sessions

## Configuration

### Application Settings

```dart
// Located in lib/core/constants/app_constants.dart
class AppConstants {
  static const String defaultIntermediateLanguageCode = "ja";
  static const String defaultSourceLanguageCode = "en";
  static const int maxRetryAttempts = 4;
  static const int baseRetryDelayMs = 1000;
  // ... more configuration options
}
```

### Logging Configuration

```dart
// Located in lib/core/utils/logger.dart
class Logger {
  static const String _logFileName = 'TranslationFiestaFlutter.log';
  // Thread-safe logging with file output
}
```

### API Configuration

- **Unofficial Endpoint**: `https://translate.googleapis.com/translate_a/single`
- **Timeout**: 30 seconds per request
- **Retry Strategy**: Exponential backoff (1s, 2s, 4s, 8s)

## Development

### Project Structure

```
TranslationFiestaFlutter/
├── lib/
│   ├── core/
│   │   ├── constants/app_constants.dart
│   │   ├── errors/failure.dart
│   │   ├── errors/either.dart
│   │   └── utils/logger.dart
│   ├── data/
│   │   ├── repositories/
│   │   └── services/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   └── presentation/
│       ├── pages/main_page.dart
│       ├── widgets/
│       └── providers/
├── assets/
├── pubspec.yaml
└── README.md
```

### Clean Code Patterns

#### Function Composition
```dart
// Small functions combined for complex operations
Future<Result<T>> executeWithRetry(
  Future<Result<T>> Function() operation,
  ApiConfiguration config,
) async {
  // Implementation with clear, single-purpose functions
}
```

#### Result Types for Error Handling
```dart
// Explicit success/failure handling
Result<TranslationResult> result = await translateText(request, config);
result.fold(
  (failure) => handleError(failure),
  (success) => handleSuccess(success),
);
```

#### Async Workflows
```dart
// Non-blocking UI with async operations
Future<void> performBackTranslation() async {
  setLoading(true);
  try {
    final result = await translationUseCase.execute(text, config);
    // Handle result
  } finally {
    setLoading(false);
  }
}
```

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

## Performance

### Benchmarks
- **Startup Time**: < 3 seconds on modern devices
- **Translation Speed**: 2-8 seconds (network and API dependent)
- **Memory Usage**: ~100MB typical, ~200MB peak during translation
- **File Import**: Handles files up to 10MB efficiently

### Optimization Features
- **Async Operations**: Non-blocking UI during translation
- **Connection Reuse**: Single HTTP client instance
- **Efficient Logging**: Minimal performance overhead
- **Resource Cleanup**: Proper disposal of all resources

## Deployment

### Android APK
```bash
flutter build apk --release
```

### iOS IPA
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### Desktop
```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## Troubleshooting

### Common Issues

#### Build Failures
```
Error: Flutter SDK not found
Solution: Install Flutter SDK from flutter.dev
```

#### Translation Failures
```
Error: HTTP 429 (Rate Limited)
Solution: Wait and retry after the rate-limit window clears
```

#### File Import Issues
```
Error: Access denied
Solution: Check file permissions and ensure supported format
```

### Debug Information
- **Log File**: Check `TranslationFiestaFlutter.log` for detailed error information
- **Network Issues**: Verify internet connectivity
- **File Permissions**: Ensure read/write access to working directory

## Contributing

### Development Setup
1. **Install Flutter SDK**
2. **Clone repository**
3. **Run**: `flutter pub get && flutter run`
4. **Follow Clean Code principles**

### Code Standards
- **Meaningful Names**: Use descriptive identifiers
- **Single Responsibility**: One purpose per function
- **Error Handling**: Use Result types, no exceptions for flow control
- **Documentation**: Clear comments for complex logic
- **Testing**: Unit tests for core logic

### Pull Request Process
1. **Branch**: `git checkout -b feature/your-feature`
2. **Implement**: Follow existing patterns and principles
3. **Test**: Verify all scenarios work correctly
4. **Document**: Update relevant documentation
5. **PR**: Clear description of changes

## Architecture Decisions

### Why Flutter for This Project?
- **Cross-platform**: Single codebase for mobile, desktop, web
- **Modern UI**: Material Design with excellent theming
- **Dart Language**: Type-safe with excellent async support
- **Hot Reload**: Fast development cycle
- **Rich Ecosystem**: Extensive package ecosystem

### Clean Code Application
- **Small Functions**: Easier testing and maintenance
- **Meaningful Names**: Self-documenting code
- **Error Handling**: Explicit success/failure paths
- **No Side Effects**: Predictable, testable functions

### State Management Choice
- **Provider**: Simple, effective for this use case
- **ChangeNotifier**: Built-in Flutter support
- **Separation**: Clear separation of UI and business logic

## License

Educational and development purposes. Google Translate API usage subject to Google's terms of service.

## Related Documentation

- [Original TranslationFiestaFSharp](../TranslationFiestaFSharp/README.md)
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language](https://dart.dev/)
- [Clean Code by Robert C. Martin](../cleancode.md)
