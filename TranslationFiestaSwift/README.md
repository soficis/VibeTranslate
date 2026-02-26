# TranslationFiesta Swift

A comprehensive English ↔ Japanese translation application built with Swift and SwiftUI, featuring advanced translation capabilities and batch processing.

> ⚠️ Current status: the Swift version is presently untested.

## 📦 Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable.
- Override data root with `TF_APP_HOME`.

## 🌟 Features

### Core Translation
- **Bidirectional Translation**: English ↔ Japanese with unofficial provider support
- **Back-Translation Validation**: Automatically validate translations by translating back to source language
- **Provider Simplicity**: Unofficial provider only for a focused workflow

### Advanced Capabilities
- **Batch Processing**: Process multiple files simultaneously with progress tracking
- **Translation Memory**: LRU cache-based translation memory
- **Multiple Export Formats**: JSON, CSV, XML, and plain text export options
- **EPUB Processing**: Native support for EPUB file translation and processing

### User Experience
- **Native macOS Interface**: Built with SwiftUI for modern, responsive design
- **Dark/Light Theme Support**: Automatic theme switching based on system preferences
- **Real-time Progress**: Live progress tracking for all operations
- **Comprehensive Analytics**: Translation memory and usage statistics

## 🏗️ Architecture

This application follows **Clean Architecture** principles with clear separation of concerns:

```
┌─ Presentation Layer (SwiftUI Views & ViewModels)
│  ├─ MainViews.swift (Primary interface)
│  ├─ FeatureViews.swift (Advanced features)
│  └─ AdditionalViews.swift (Settings & utilities)
│
├─ Domain Layer (Business Logic)
│  ├─ Entities/ (Core business objects)
│  ├─ Repositories/ (Data access contracts)
│  └─ UseCases/ (Business use cases)
│
├─ Data Layer (External Dependencies)
│  └─ Services/ (API clients, storage, processing)
│
└─ Shared
   └─ AppContainer.swift (Dependency injection)
```

### Key Design Patterns
- **Clean Architecture**: Domain-driven design with dependency inversion
- **MVVM**: Model-View-ViewModel pattern for SwiftUI integration
- **Repository Pattern**: Abstracted data access layer
- **Dependency Injection**: Centralized dependency management
- **Async/Await**: Modern Swift concurrency for network operations

## 🚀 Getting Started

### Prerequisites
- **macOS 14.0+** (for macOS deployment)
- **Xcode 15.0+** with Swift 5.9+
- **Swift Package Manager** (included with Xcode)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd VibeTranslate/TranslationFiestaSwift
   ```

2. **Open in Xcode**:
   ```bash
   open Package.swift
   ```
   Or use Xcode: File → Open → Select `Package.swift`

3. **Build the project**:
   - In Xcode: `⌘ + B`
   - Or via command line: `swift build`

4. **Run the application**:
   - In Xcode: `⌘ + R`
   - Or via command line: `swift run TranslationFiestaSwift`

### Provider Configuration

1. **Open the application**
2. **Navigate to Settings** (gear icon in toolbar)
3. **Select a Provider**:
   - Use the unofficial Google Translate endpoint
   - No API key setup required

## 📱 Usage Guide

### Basic Translation

1. **Select Languages**: Choose source and target languages from the dropdown menus
2. **Enter Text**: Type or paste text in the source text field
3. **Translate**: Click the "Translate" button or use `⌘ + T`
4. **Review Results**: View translation and optional back-translation for validation

### Batch Processing

1. **Navigate to Batch Processing**: Click "Batch Process" in the toolbar
2. **Add Files**: 
   - Drag and drop files into the application
   - Or use "Add Files" button to browse
   - Supported formats: TXT, JSON, XML, EPUB
3. **Configure Settings**:
   - Set output directory
   - Choose export format
   - Enable/disable back-translation
4. **Start Processing**: Click "Start Batch" and monitor progress

### Translation Memory

1. **Access Memory**: Click "Translation Memory" in the toolbar
2. **View Statistics**: See cache hit rates and memory usage
3. **Search Entries**: Use the search bar to find specific translations
4. **Manage Cache**: Clear or optimize translation memory

### Export & Import

1. **Export Translations**:
   - Choose from JSON, CSV, XML, or TXT formats
   - Include metadata
   - Batch export multiple translation sessions

2. **Import Settings**:
   - Import translation memory from previous sessions

## 🔧 Advanced Features

### Back-Translation Validation

- **Round-Trip Validation**: Compare source → target → source translations
- **Human Review Focus**: Evaluate outputs directly instead of generated metrics

### Translation Memory

- **LRU Cache**: Efficient memory management with least-recently-used eviction
- **Persistent Storage**: Translation memory persists between application sessions
- **Import/Export**: Share translation memories between users or applications

### Reliability Features

- **Input Validation**: Defensive checks at service boundaries
- **Retry Logic**: Network retries for transient provider failures
- **Privacy Controls**: Configurable data retention and privacy settings
- **Secure Deletion**: Proper cleanup of temporary translation artifacts

## 🛠️ Development

### Project Structure

```
TranslationFiestaSwift/
├── Package.swift                    # Swift package definition
├── Sources/
│   └── TranslationFiestaSwift/
│       ├── Domain/                  # Business logic layer
│       │   ├── Entities/           # Core business objects
│       │   ├── Repositories/       # Data access contracts
│       │   └── UseCases/           # Business use cases
│       ├── Data/                   # Data access layer
│       │   └── Services/           # Concrete implementations
│       ├── Presentation/           # UI layer
│       │   └── Views/             # SwiftUI views and view models
│       ├── Shared/                 # Shared utilities
│       └── main.swift             # Application entry point
└── Tests/                          # Unit and integration tests
```

### Dependencies

- **Swift Collections**: Advanced data structures for translation memory
- **Swift Algorithms**: Efficient algorithms for text processing
- **Swift Log**: Structured logging throughout the application

### Building for Different Platforms

The application supports multiple Apple platforms:

```bash
# macOS (primary target)
swift build --configuration release

# iOS (if developing iOS companion)
swift build --configuration release --destination 'platform=iOS Simulator,name=iPhone 15'

# tvOS (for Apple TV interface)
swift build --configuration release --destination 'platform=tvOS Simulator,name=Apple TV'
```

### Testing

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter TranslationTests

# Generate test coverage
swift test --enable-code-coverage
```

## 📊 Performance Optimization

### Translation Memory
- **LRU Cache**: Configurable cache size with efficient eviction policy
- **Async Operations**: Non-blocking translation memory operations

### Batch Processing
- **Concurrent Processing**: Parallel file processing with configurable concurrency limits
- **Memory Management**: Efficient memory usage for large file processing
- **Progress Tracking**: Real-time progress updates without blocking UI

### Network Optimization
- **Request Batching**: Combine multiple translation requests when possible
- **Retry Logic**: Intelligent retry mechanisms for failed requests
- **Rate Limiting**: Automatic rate limiting to respect API constraints

## 🔐 Security Considerations

### Data Privacy
- Minimize retained data
- Configurable data retention policies
- Secure deletion of temporary files
- Optional network request logging

### Network Security
- TLS/SSL for all network communications
- Certificate pinning for enhanced security
- Request signing for authenticated APIs

## 🐛 Troubleshooting

### Common Issues

**Build Errors**:
- Ensure Xcode 15.0+ is installed with Command Line Tools: `xcode-select --install`
- Verify Swift 5.9+ compatibility: `swift --version`
- Check macOS 14.0+ target deployment in Xcode project settings
- Run `swift package resolve` to resolve and download dependencies
- Clear build cache if issues persist: `swift package clean`
- Check for conflicting package versions in Package.swift
- If build fails with exit code 1, examine error messages for specific compilation issues
- For exit code 143 (SIGTERM), the build may have been interrupted; retry the command
- Ensure you're in the correct directory: `cd /Users/nathan/VibeTranslate/TranslationFiestaSwift`

**Runtime Errors**:
- If `swift run` fails with exit code 127, verify the executable was built successfully
- Check for missing dynamic libraries or framework dependencies
- For exit code 130 (SIGINT), the process was interrupted; restart if needed
- Monitor system resources; insufficient memory may cause runtime failures

**API Connection Issues**:
- Check network connectivity and firewall settings
- Review API service status pages for outages
- Test API endpoints manually using curl or Postman
- Enable debug logging to inspect request/response details

**Performance Issues**:
- Adjust translation memory cache size in Settings (default: 1000 entries)
- Reduce batch processing concurrency limit (default: 4 parallel tasks)
- Monitor system memory usage with Activity Monitor
- Optimize file sizes for batch processing (large files may slow processing)
- Check disk space availability for temporary files and caches

### Debug Logging

Enable debug logging in Settings to get detailed information about:
- Translation API requests and responses (including headers and payloads)
- Translation memory operations (cache hits, misses, and evictions)
- File processing status (progress, errors, and completion times)
- Network connectivity issues and retry attempts

### Additional Support

- Check the [Contributing Guide](../docs/Contributing.md) for development setup tips
- Review Xcode console output for detailed error messages
- Use `swift build --verbose` for more detailed build information
- Join our community discussions for help with specific issues

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](../docs/Contributing.md) for details on:
- Code style and conventions
- Testing requirements
- Pull request process
- Issue reporting guidelines

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## 🙏 Acknowledgments

- **Swift Community**: For excellent documentation and Swift Package Manager
- **Apple**: For SwiftUI and comprehensive development tools
- **Translation Services**: For providing robust translation APIs
- **Open Source Libraries**: Swift Collections, Algorithms, and Logging

## 🔗 Related Projects

- [TranslationFiesta C#](../TranslationFiestaCSharp/) - C# implementation
- [TranslationFiesta Flutter](../TranslationFiestaFlutter/) - Cross-platform Flutter version
- [TranslationFiesta Python](../TranslationFiestaPy/) - Python implementation
- [TranslationFiesta Go](../TranslationFiestaGo/) - Go implementation
- [TranslationFiesta F#](../TranslationFiestaFSharp/) - F# implementation

---

**Version**: 1.0.0  
**Last Updated**: 2025
**Platform Compatibility**: macOS 14+, iOS 17+, tvOS 17+, watchOS 10+
