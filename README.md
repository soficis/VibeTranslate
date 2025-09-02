# VibeTranslate 🎉t

A collection of translation applications built in different languages and frameworks, all implementing the same core functionality: **English ↔ Japanese back-translation** for content quality evaluation and linguistic analysis.

## 🌟 Overview

VibeTranslate is a polyglot project showcasing how the same application can be implemented across multiple programming languages and UI frameworks. Each implementation maintains the same core features while leveraging language-specific strengths and platform capabilities.

### 🎯 Core Functionality
- **Back-translation**: English → Japanese → English using Google Translate APIs
- **File Import**: Load text from .txt, .md, and .html files
- **Dual API Support**: Unofficial (free) and Official Google Cloud Translation API
- **Modern UI**: Dark/Light themes, responsive design, progress indicators
- **Export Features**: Save results, copy to clipboard, file operations

## 📱 Applications

### 🐍 TranslationFiestaPy (Python)
**Original Implementation** - The foundation for all other ports
- **Framework**: Tkinter GUI
- **Language**: Python 3.6+
- **Key Features**: Async processing, smart HTML extraction, comprehensive logging
- **Dependencies**: `requests`, `beautifulsoup4`
- **Best For**: Cross-platform compatibility, easy customization

### 🔷 CsharpTranslationFiesta (C#)
**WinForms Edition** - .NET 9 console application
- **Framework**: Windows Forms (.NET 9)
- **Language**: C# 12
- **Key Features**: Native Windows integration, high DPI support
- **Build**: `dotnet build -c Release`
- **Best For**: Windows-native performance, enterprise deployment

### ⚡ FSharpTranslate (F#)
**Functional Edition** - Most feature-complete implementation
- **Framework**: Windows Forms (.NET 9)
- **Language**: F# 8
- **Key Features**: Clean Code principles, comprehensive error handling, dual API support, enterprise logging
- **Build**: `dotnet build && dotnet run`
- **Best For**: Production use, educational examples, clean architecture patterns

### 🎭 TranslationFiesta.WinUI (C#)
**Modern Windows Edition** - Windows 11 native app *(Untested Code)*
- **Framework**: WinUI 3 (Windows App SDK)
- **Language**: C# 12
- **Key Features**: Fluent Design, MSIX packaging, secure DPAPI storage, persistent settings
- **Requirements**: Windows 10 19041+ or Windows 11, Windows App SDK workload installed
- **Best For**: Modern Windows experiences, app store distribution
- **⚠️ Note**: This implementation is currently untested and may require additional setup

## 🚀 Quick Start

### Prerequisites
- **Python 3.6+** (for Python version)
- **.NET 9 SDK** (for .NET versions)
- **Windows 10+** (all Windows versions)
- **Windows App SDK workload** (required for WinUI implementation - install via Visual Studio Installer)
- **Internet connection** (for translation APIs)

> **Note**: The TranslationFiesta.WinUI implementation is currently untested and may require additional setup beyond the standard .NET SDK installation.

### Running Your First Translation

#### Python Version (Cross-platform)
```bash
cd TranslationFiestaPy
pip install -r requirements.txt
python TranslationFiesta.py
```

#### .NET Versions (Windows)
```powershell
# Choose your preferred implementation
cd FSharpTranslate          # Most feature-complete
# OR
cd TranslationFiesta.WinUI  # Most modern UI
# OR
cd CsharpTranslationFiesta  # Simplest

dotnet run
```

## 📊 Feature Comparison

| Feature | Python | C# WinForms | F# | WinUI 3 |
|---------|--------|-------------|----|---------|
| **UI Framework** | Tkinter | Windows Forms | Windows Forms | WinUI 3 |
| **Dark/Light Theme** | ✅ | ✅ | ✅ | ✅ |
| **File Import** | ✅ (.txt, .md, .html) | ✅ (.txt) | ✅ (.txt, .md, .html) | ✅ |
| **Unofficial API** | ✅ | ✅ | ✅ | ✅ |
| **Official API** | ✅ | ✅ | ✅ | ✅ |
| **Progress Bar** | ✅ | ✅ | ✅ | ✅ |
| **Async Processing** | ✅ (threading) | ✅ | ✅ | ✅ |
| **Error Handling** | Basic | Basic | Comprehensive | Basic |
| **Logging** | ✅ | Basic | Comprehensive | Basic |
| **Retry Logic** | ✅ | ✅ | ✅ | ✅ |
| **Copy/Save Results** | ✅ | ✅ | ✅ | ✅ |
| **Secure Storage** | ❌ | ❌ | ❌ | ✅ (DPAPI) |
| **MSIX Packaging** | ❌ | ❌ | ❌ | ✅ |
| **Clean Code** | Good | Basic | ✅ (Applied) | Basic |

## 🛠️ Development

### Building All Projects

#### Python
```bash
cd TranslationFiestaPy
pip install -r requirements.txt
python TranslationFiesta.py
```

#### .NET Projects
```powershell
# Build all .NET projects
foreach ($project in @("CsharpTranslationFiesta", "FSharpTranslate", "TranslationFiesta.WinUI")) {
    cd $project
    dotnet build -c Release
    cd ..
}
```

#### Publishing for Distribution
```powershell
# F# version (recommended for production)
cd FSharpTranslate
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

# WinUI version (for Microsoft Store)
cd TranslationFiesta.WinUI
.\tools\package-winui-msix.ps1 -AppExecutablePath "bin\Release\net9.0-windows10.0.19041.0\win10-x64\TranslationFiesta.WinUI.exe" -OutputMsix "TranslationFiesta.msix"
```

## 🎨 UI Screenshots

*Coming soon - screenshots of each application's interface showing the consistent yet distinct approaches to the same functionality.*

## 📋 API Usage Notes

### Unofficial Google Translate API
- **Endpoint**: `https://translate.googleapis.com/translate_a/single`
- **Rate Limits**: Subject to Google's discretion
- **Usage**: Free, no API key required
- **Reliability**: May change without notice
- **Best For**: Development, testing, personal use

### Official Google Cloud Translation API
- **Service**: Google Cloud Translation API v2
- **Pricing**: Pay-per-use ($20/1M characters)
- **Setup**: Requires Google Cloud account and API key
- **Reliability**: Enterprise-grade SLA
- **Best For**: Production applications, high-volume usage

## 🤝 Contributing

### Development Setup
1. **Choose your language/framework** of interest
2. **Fork the repository**
3. **Clone locally**: `git clone your-fork-url`
4. **Install prerequisites** for your chosen implementation
5. **Build and test**: Follow the quick start guides above

### Code Standards
- **Python**: PEP 8, type hints, comprehensive docstrings
- **C#**: .NET coding conventions, async/await patterns
- **F#**: Clean Code principles, meaningful names, single responsibility
- **Cross-platform**: Consistent feature parity across implementations

### Adding New Features
1. **Implement in one language first** (preferably F# for complex features)
2. **Document the feature** and its API requirements
3. **Port to other languages** maintaining consistent behavior
4. **Update this README** with new feature comparisons
5. **Test across all platforms**

## 📈 Project Goals

### 🎯 Technical Objectives
- **Polyglot Implementation**: Same app in multiple languages/frameworks
- **Best Practices**: Each implementation follows its language's conventions
- **Feature Parity**: Core functionality consistent across versions
- **Educational Value**: Learning resource for different technologies

### 🚀 Future Enhancements
- **More Languages**: Rust, Go, Swift implementations
- **Web Version**: React/TypeScript and Blazor WebAssembly
- **Mobile Apps**: React Native, .NET MAUI, Flutter
- **Additional APIs**: DeepL, Microsoft Translator, Yandex
- **Batch Processing**: Handle multiple files/directories
- **Plugin Architecture**: Extensible translation providers

## 🔧 Troubleshooting

### Common Issues

#### Translation Failures
```
Error: HTTP 429 (Rate Limited)
Solution: Wait and retry, or switch to official API with key
```

#### Build Issues
```powershell
# Clear NuGet cache and rebuild
dotnet clean
dotnet restore
dotnet build
```

#### File Import Problems
```
Error: Access denied or encoding issues
Solution: Check file permissions, ensure UTF-8 encoding
```

### Getting Help
- **Check logs**: Each app creates log files for debugging
- **Network connectivity**: Ensure stable internet for API calls
- **API keys**: Verify Google Cloud credentials for official API
- **GitHub Issues**: Report bugs and request features

## 📄 License

This project is provided for educational and development purposes. Usage of translation APIs should comply with respective terms of service:

- **Unofficial Google Translate**: Personal, non-commercial use
- **Google Cloud Translation API**: Per your Google Cloud agreement

## 🙏 Acknowledgments

- **Google Translate**: For providing both official and unofficial API access
- **.NET Foundation**: For the excellent .NET platform and tooling
- **Python Community**: For the robust ecosystem and libraries
- **F# Community**: For functional programming inspiration

## 📞 Support

### FAQ

**Q: Why only English ↔ Japanese?**
A: Japanese provides good linguistic distance from English for effective back-translation quality evaluation.

**Q: Can I add more languages?**
A: Yes! Modify the `intermediateLanguageCode` (typically "ja") in each implementation.

**Q: Which version should I use?**
A: **FSharpTranslate** for production use, **TranslationFiestaPy** for cross-platform, **TranslationFiesta.WinUI** for modern Windows UI.

**Q: Are these production-ready?**
A: Yes, especially FSharpTranslate and TranslationFiesta.WinUI. For high-volume translation workflows, use the official Google Cloud Translation API.

---

**Built with ❤️ across multiple languages and frameworks | Educational Project | Translation Quality Evaluation Tools**
