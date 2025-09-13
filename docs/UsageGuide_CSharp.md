# Beginner's Guide to TranslationFiestaCSharp (C#)

Welcome to TranslationFiestaCSharp! This guide will help you get started with the C# Windows Forms implementation of the TranslationFiesta application. Built with .NET 9 and C# 12, it provides native Windows performance and integration for enterprise use.

## 1. Installation and Setup

TranslationFiestaCSharp is a .NET 9 application designed for Windows environments, offering optimal performance and native Windows integration.

### Prerequisites
- **.NET 9 SDK or later**: Download from Microsoft's .NET site. Verify with `dotnet --version`
- **Windows**: The target platform for this Windows Forms application
- **C# 12 support**: Comes with .NET 9 SDK
- **Internet connection**: Required for translation services
- **Optional: Google Cloud Translation API key**: For official (paid) API access, providing enhanced reliability over the unofficial API

### Installing Dependencies
1. **Navigate to the TranslationFiestaCSharp directory**:
   ```
   cd TranslationFiestaCSharp
   ```

2. **Restore .NET packages**:
   ```
   dotnet restore
   ```
   This downloads all NuGet packages from the project dependencies, including Windows Forms, HTTP clients, JSON processing, and other required libraries.

3. **Build the project**:
   ```
   dotnet build
   ```
   This compiles the C# 12 code and prepares the application for execution.

### API Key Setup
Choose from two API options:
- **Unofficial API** (default): Free, immediate access, no setup required
- **Official Google Cloud API**: Paid service, more reliable, requires configuration

To configure official API:
1. Acquire a Google Cloud Translation API key
2. Configure within the application (detailed below)
3. Keys are stored securely using the SecureStore implementation

## 2. Step-by-Step Guide to Running the Application

### Development and Direct Execution
1. **Run the application**:
   ```
   dotnet run
   ```

2. **Compilation completes**: .NET builds and starts the Windows Forms GUI

3. **Windows Forms window opens**: The native Windows interface is displayed with translation controls

### First-Time Setup
- **Network access**: Windows may prompt for firewall permissions - grant access
- **Windows version**: Optimized for modern Windows (10/11)
- **Administrator rights**: Not required for normal operations

### Running Built Executable
If using the built version:
```
dotnet build -c Release
.\bin\Release\net9.0-windows10.0.19041.0\win10-x64\TranslationFiestaCSharp.exe
```

## 3. Basic Usage Examples

### Basic Translation Workflow
1. **Start the application**: Use `dotnet run` to launch Windows Forms
2. **Enter content**: Type English text in the dedicated input field
3. **Configure API**: Toggle Official API on/off for key usage
4. **Execute translation**: Click the back-translation button
5. **Evaluate results**:
   - **Intermediate Japanese**: Displayed translation
   - **Final English**: Back-translated result
   - **Quality indicators**: Available if BLEU scoring is active

### File Integration
1. **Access file menu**: Click "Load File" in the Windows Forms interface
2. **Choose file format**: Select .txt, .md, or .html files
3. **Automatic loading**: Content imports directly into input area
4. **Proceed with translation**: Normal back-translation process

### User Interface Features
- **Windows Forms styling**: Native Windows appearance
- **Theme compatibility**: Respects Windows light/dark themes
- **Responsive design**: Adapts to different window sizes
- **Keyboard shortcuts**: Standard Windows application controls

## 4. Basic Usage Examples for Key Advanced Features

### Batch Processing
Handle multiple files simultaneously:
1. Organize text files in a dedicated directory
2. Enable batch processing through interface controls
3. Monitor processing through progress indicators
4. Automatically organize and present results

### BLEU Scoring
Assess translation quality with standard metrics:
1. After back-translation, BLEU calculations display automatically
2. Interpret scores: Closer to 1.0 indicates higher quality
3. Utilize for content comparison and improvement tracking

### Advanced Exporting
Generate formatted output in multiple formats:
1. Access export menu after translation
2. Choose PDF, DOCX, or HTML output
3. Select custom templates when available
4. Include metadata and quality scores

### Secure Storage
Protect API credentials:
- Utilizes .NET's SecureStore for credential protection
- Platform-specific encryption standards
- Automatic persistence across application sessions
- No manual configuration required after initial setup

### Translation Memory
Cache translations for efficiency:
1. Frequent translations are automatically cached
2. Reduces API costs by reusing previous translations
3. Fuzzy matching supports similar content
4. Performance improves with regular use

### Additional Features
- **Wordplay Engine**: Available for creative text variations
- **Randomization Engine**: Implements random text mutations for experimental purposes
- **Error Resilience**: Robust exception handling with retry mechanisms

## 5. Troubleshooting Tips

### Common Issues

**Application fails to launch**
- **.NET verification**: Confirm .NET 9 SDK installation with `dotnet --version`
- **Dependencies**: Re-run `dotnet restore` to ensure package availability
- **Compilation**: Attempt `dotnet clean` followed by `dotnet build`

**Windows Forms display problems**
- **Windows version**: Requires Windows 10/11 for optimal compatibility
- **Framework alignment**: Verify .NET 9 and Windows compatibility
- **Display scaling**: Check Windows DPI settings for interface scaling

**Translation failures**
- **Connectivity**: Ensure stable internet access
- **API configuration**: Verify official API key if enabled
- **Rate limitations**: Consider switching API modes or implementing delays
- **Permissions**: Windows Defender may require network access approval

**File operation errors**
- **Supported formats**: Limited to .txt, .md, .html files
- **Access rights**: Administrator permissions may be necessary for certain directories
- **File encoding**: UTF-8 encoding is recommended

**Feature limitations**
- **EPUB processing**: Disabled (EpubProcessor.cs.disabled file indicates planned but inactive functionality)
- **Missing translation memory**: Not available despite other C# implementations
- **Creative engines**: Dependent on proper activation

### Known Limitations
This C# implementation has specific constraints:
- **Disabled EPUB Support**: File indicates planned .epub processing (EpubProcessor.cs.disabled)
- **Object-Oriented Focus**: Strong emphasis on object-oriented programming patterns
- **Windows-Exclusive**: Designed specifically for Windows ecosystem

### Performance Optimization
- **Native Compilation**: Leverages .NET 9 performance capabilities
- **Efficient Resource Usage**: Optimized memory management and UI rendering
- **Background Processing**: Asynchronous operations prevent interface freezing

### Getting Help
- **Build logging**: Review output from `dotnet build`
- **C# documentation**: Reference Microsoft C# language and .NET documentation
- **Community resources**: .NET forums and Stack Overflow for issue resolution
- **Application logs**: Check Windows event logs for detailed error information

## 6. Screenshots

### Primary Application Window
[Insert screenshot of the C# Windows Forms interface showing input controls and translation results in native Windows styling]

### File Selection Interface
[Insert screenshot demonstrating the Windows file dialog for selecting translation source files]

### BLEU Scoring Integration
[Insert screenshot displaying BLEU score calculations within the translation results interface]

### Secure Storage Configuration
[Insert screenshot showing API key management interface with secure storage indicators]

### Advanced Exporting Options
[Insert screenshot of the export dialog showing available formats and template selection]

### Cost Tracking Dashboard
[Insert screenshot presenting the cost monitoring interface with usage statistics]

TranslationFiestaCSharp delivers enterprise-grade performance for Windows users, combining .NET 9's reliability with native Windows integration. While EPUB processing remains disabled and translation memory lacks implementation, the robust core translation functionality and advanced features provide a solid foundation for production translation workflows. The object-oriented design ensures maintainability and scalability for business applications.