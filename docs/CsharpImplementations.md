# C# Implementations - WinForms & WinUI 3

**Repository**: [https://github.com/soficis/VibeTranslate](https://github.com/soficis/VibeTranslate)

## Overview

The repository contains two C# implementations of the TranslationFiesta application:

### TranslationFiestaCSharp (WinForms)
**Traditional Desktop Edition** - A straightforward Windows Forms implementation targeting .NET Framework, designed for simplicity and ease of deployment.

### TranslationFiesta.WinUI (WinUI 3)
**Modern Desktop Edition** - A Windows App SDK/WinUI 3 implementation with advanced features, modern UI, and enhanced translation capabilities.

Both implementations maintain core functionality while showcasing different approaches to Windows desktop development.

## Architecture Overview

### Framework Comparison

| Aspect | WinForms | WinUI 3 |
|--------|----------|---------|
| **Framework Age** | Mature (2002) | Modern (2021) |
| **UI Paradigm** | Procedural | Declarative (XAML) |
| **Target Framework** | .NET Framework | .NET 6+ |
| **Packaging** | Traditional EXE | MSIX/Windows App SDK |
| **Performance** | Fast startup | Rich features with slight overhead |
| **Learning Curve** | Gentle | Moderate |
| **Deployment** | Simple | Modern packaging |

### WinForms Architecture

WinForms provides a mature, procedural approach to Windows desktop development with:
- **Simple UI Construction**: Procedural control placement and event handling
- **Fast Startup**: Lightweight framework with minimal overhead
- **Easy Deployment**: Self-contained executables
- **Familiar API**: Long-standing .NET Framework integration

### WinUI 3 Architecture

WinUI 3 represents the modern approach to Windows desktop development with:
- **Declarative UI**: XAML-based interface definition
- **Component-Based**: Modern control library with consistent styling
- **Async-Native**: Built-in support for modern async patterns
- **Cross-Platform Ready**: Foundation for future Windows/cross-platform development

## TranslationFiestaCSharp - WinForms Implementation

### Architecture

#### Core Components
- **Program.cs**: Main entry point and WinForms setup
- **TranslationClient.cs**: HTTP client for Google Translate APIs
- **Logger.cs**: Simple logging utility
- **Form Layout**: Procedural UI construction

#### Key Classes

##### TranslationClient
```csharp
public class TranslationClient
{
    private readonly HttpClient _httpClient;

    public async Task<string> TranslateUnofficialAsync(string text, string from, string to)
    public async Task<string> TranslateOfficialAsync(string text, string from, string to, string apiKey)
    public async Task<string> TranslateWithRetriesAsync(string text, string from, string to, string apiKey = null)
}
```

##### Main Form Structure
```csharp
public partial class MainForm : Form
{
    // UI Controls
    private TextBox txtInput;
    private TextBox txtIntermediate;
    private TextBox txtBackTranslated;
    private Button btnTranslate;
    private CheckBox chkOfficialApi;

    // Event Handlers
    private async void btnTranslate_Click(object sender, EventArgs e)
    private void btnLoadFile_Click(object sender, EventArgs e)
    private void chkOfficialApi_CheckedChanged(object sender, EventArgs e)
}
```

### Features

#### 🖥️ Windows Forms UI
- **Traditional Windows Styling**: Classic Windows appearance
- **High DPI Support**: System-aware scaling
- **Native Integration**: Seamless Windows integration
- **Simple Deployment**: Single executable

#### 🌐 Translation Engine
- **Dual API Support**: Unofficial and official Google Translate
- **Async Operations**: Modern async/await patterns
- **Error Handling**: Try-catch with user feedback
- **Retry Logic**: Exponential backoff for reliability

#### 📁 File Operations
- **Basic Import**: Load .txt files
- **Menu System**: Standard File menu with shortcuts
- **Save Results**: Export back-translation to file
- **Copy to Clipboard**: Quick result copying

#### ⚙️ Basic Features
- **Theme Toggle**: Simple dark/light mode
- **Progress Indication**: Status updates during translation
- **Input Validation**: Basic text validation
- **Keyboard Shortcuts**: Ctrl+O, Ctrl+S, Ctrl+C

## TranslationFiesta.WinUI - WinUI 3 Implementation

### Architecture

#### Core Components
- **MainWindow.xaml**: Declarative UI definition with modern controls
- **MainWindow.xaml.cs**: Code-behind with comprehensive event handling
- **TranslationClient.cs**: Advanced HTTP client with caching and quality assessment
- **BatchProcessor.cs**: Asynchronous batch file processing
- **BLEUScorer.cs**: Translation quality assessment with BLEU scoring
- **TranslationMemory.cs**: Intelligent caching and translation memory

#### Key Classes

##### TranslationClient
```csharp
public class TranslationClient
{
    private static readonly HttpClient _httpClient = new HttpClient();
    private readonly TranslationMemory _tm = new TranslationMemory();

    public async Task<BackTranslationResult> BackTranslateAsync(string text)
    public async Task<string> TranslateAsync(string text, string fromLang, string toLang)
    public async Task<TranslationResult> TranslateWithQualityAsync(string text, string from, string to)
}
```

##### BackTranslationResult
```csharp
public class BackTranslationResult
{
    public string? JapaneseTranslation { get; set; }
    public string? BackTranslation { get; set; }
    public QualityAssessment? QualityAssessment { get; set; }
    public double ProcessingTime { get; set; }
}
```

### Features

#### 🎨 Modern WinUI 3 UI
- **Fluent Design**: Microsoft's modern design language
- **Responsive Layout**: Adaptive UI with proper spacing and typography
- **Native Windows Integration**: Seamless Windows 11/10 integration
- **High DPI Support**: Automatic scaling for all display densities
- **Dark/Light Theme Support**: System-aware theming

#### 🌐 Advanced Translation Engine
- **Dual API Support**: Official Google Cloud Translation + unofficial Google Translate
- **Intelligent Caching**: TranslationMemory for performance optimization
- **Quality Assessment**: BLEU scoring for translation quality metrics
- **Backtranslation Workflow**: EN → JA → EN with separate result display
- **Batch Processing**: Directory-based file processing capabilities

#### 📁 Enhanced File Operations
- **Native File Picker**: Windows.Storage.Pickers integration
- **Multiple Format Support**: .txt, .html, .md files
- **Batch Directory Processing**: Process entire folders of documents
- **Smart Export**: Structured output with quality metrics
- **Real-time Progress**: Progress tracking during batch operations

#### ⚙️ Advanced Features
- **Async/Await Patterns**: Modern asynchronous programming throughout
- **Comprehensive Logging**: Detailed operation logging with Logger.cs
- **Error Recovery**: Robust exception handling and user feedback
- **Translation Memory**: Intelligent caching to reduce API calls
- **Quality Metrics**: BLEU scoring and confidence assessment

## Installation & Setup

### Prerequisites
- **.NET 8.0 SDK**: Required for WinUI 3 development
- **Windows App SDK 1.4+**: For WinUI 3 runtime components
- **Windows 10/11**: Target platform support
- **Internet connection**: For translation services

### TranslationFiestaCSharp Setup (WinForms)
1. **Navigate to directory**:
   ```powershell
   cd TranslationFiestaCSharp
   ```
2. **Build and run**:
   ```powershell
   dotnet build -c Release
   dotnet run --project TranslationFiestaCSharp.csproj
   ```

### TranslationFiesta.WinUI Setup (WinUI 3)
1. **Navigate to directory**:
   ```powershell
   cd TranslationFiesta.WinUI
   ```
2. **Restore packages**:
   ```powershell
   dotnet restore
   ```
3. **Build and run**:
   ```powershell
   dotnet build -c Release
   dotnet run --project TranslationFiesta.WinUI.csproj
   ```

### Dependencies

#### TranslationFiestaCSharp (WinForms)
- **System.Windows.Forms**: Core WinForms framework
- **System.Net.Http**: HTTP client for API calls
- **System.Text.Json**: JSON processing for API responses

#### TranslationFiesta.WinUI (WinUI 3)
- **Microsoft.WindowsAppSDK**: WinUI 3 framework and Windows App SDK
- **Microsoft.Windows.SDK.NET.Ref**: Windows SDK references
- **System.Net.Http**: HTTP client for API calls
- **System.Text.Json**: JSON processing for API responses
- **WinRT.Runtime**: Windows Runtime interop

## Usage Guide

### Basic Operation (Both)

1. **Launch**: Run respective dotnet run command
2. **Input Text**: Type or paste English text
3. **Translate**: Click "Backtranslate" or "Translate" button
4. **View Results**:
   - **Intermediate**: Japanese translation
   - **Final**: Back-translated English

### TranslationFiestaCSharp Features
- **API Selection**: Toggle between unofficial/official API
- **API Key Input**: Secure password field for Google Cloud key
- **Theme Toggle**: Switch between dark/light modes
- **File Menu**: Standard Windows menu operations

### TranslationFiesta.WinUI Features
- **Advanced Backtranslation**: Separate EN→JA and JA→EN display
- **Batch Processing**: Process entire directories of files
- **Quality Assessment**: BLEU scoring and confidence metrics
- **Translation Memory**: Intelligent caching for performance
- **Modern File Operations**: Native Windows file pickers
- **Async Processing**: Non-blocking operations with progress feedback

### Keyboard Shortcuts
- **Ctrl+O**: Import text file
- **Ctrl+S**: Save results
- **Ctrl+C**: Copy results to clipboard

## Development

### Project Structure Comparison

#### TranslationFiestaCSharp (WinForms)
```
TranslationFiestaCSharp/
├── Program.cs              # Entry point and form creation
├── TranslationClient.cs    # API client
├── Logger.cs               # Simple logging
├── TranslationFiestaCSharp.csproj
└── README.md
```

#### TranslationFiesta.WinUI (WinUI 3)
```
TranslationFiesta.WinUI/
├── MainWindow.xaml         # Declarative UI definition
├── MainWindow.xaml.cs      # Code-behind with event handlers
├── App.xaml                # Application definition
├── App.xaml.cs             # Application startup
├── TranslationClient.cs    # Advanced API client with caching
├── BatchProcessor.cs       # Batch file processing
├── BLEUScorer.cs          # Quality assessment
├── TranslationMemory.cs    # Intelligent caching
├── Logger.cs               # Comprehensive logging
├── SettingsService.cs      # User settings management
├── SecureStore.cs          # Secure data storage
├── TranslationFiesta.WinUI.csproj
├── app.manifest            # Application manifest
└── README.md
```


### Code Patterns

#### WinForms Pattern (TranslationFiestaCSharp)
```csharp
// Procedural UI creation
private void InitializeComponent()
{
    // Create controls programmatically
    var txtInput = new TextBox();
    txtInput.Location = new Point(10, 10);
    txtInput.Size = new Size(400, 200);
    Controls.Add(txtInput);

    // Configure properties
    txtInput.Multiline = true;
    txtInput.ScrollBars = ScrollBars.Vertical;
}
```

#### WinUI 3 Pattern (TranslationFiesta.WinUI)
```xml
<!-- Declarative XAML UI -->
<StackPanel Margin="20">
    <TextBlock Text="Translation Fiesta" FontSize="24" FontWeight="Bold" />
    <TextBox x:Name="TxtSource" Height="100" Margin="0,10,0,0"
             PlaceholderText="Enter text to translate..." />
    <Button x:Name="BtnTranslate" Content="Translate" Margin="0,10,0,0" />
    <TextBox x:Name="TxtResult" Height="100" Margin="0,10,0,0" />
</StackPanel>
```

```csharp
// Modern async event handling
private async void BtnTranslate_Click(object sender, RoutedEventArgs e)
{
    var result = await _translator.BackTranslateAsync(TxtSource.Text);
    TxtResult.Text = result.BackTranslation ?? "Translation failed";
}
```


### Building and Testing

#### Debug Build
```powershell
# WinForms
dotnet build TranslationFiestaCSharp.csproj

# WinUI 3
dotnet build TranslationFiesta.WinUI.csproj
```

#### Release Build
```powershell
# WinForms
dotnet build TranslationFiestaCSharp.csproj -c Release

# WinUI 3
dotnet build TranslationFiesta.WinUI.csproj -c Release
```

## Troubleshooting

### Common Issues

#### Build Failures
```
Error: .NET SDK not found
Solution: Install .NET 7+ SDK
```

#### Translation Failures
```
Error: HTTP request failed
Solution: Check internet connection and API endpoints
```

#### UI Issues
```
Error: Controls not displaying
Solution: Verify Windows Forms/WPF runtime is installed
```

### WinForms-Specific Issues
```
Error: High DPI scaling issues
Solution: Add app.manifest with DPI awareness settings
```

### WinUI 3-Specific Issues
```
Error: Windows App SDK not found
Solution: Install Windows App SDK 1.4+ from Microsoft Store or Visual Studio

Error: XAML compilation failed
Solution: Ensure Windows SDK version matches target framework

Error: WinRT interop issues
Solution: Check WinRT.Runtime package version compatibility
```

## Performance Comparison

### Benchmarks
- **Startup Time**:
  - WinForms: ~1 second
  - WinUI 3: ~2-3 seconds
- **Memory Usage**:
  - WinForms: ~40MB typical
  - WinUI 3: ~70MB typical
- **UI Responsiveness**:
  - WinForms: Fast, immediate
  - WinUI 3: Smooth, fluent animations

### Optimization Considerations
- **WinForms**: Best for simple, lightweight applications with fast startup
- **WinUI 3**: Best for modern applications requiring advanced UI features
- **Resource Usage**: WinForms generally lighter weight
- **Rendering**: WinUI 3 provides consistent, high-DPI rendering
- **Future-Proofing**: WinUI 3 aligns with Microsoft's modern development roadmap

## Deployment

### WinForms Deployment
```powershell
# Self-contained executable
dotnet publish -c Release -r win-x64 --self-contained true

# Framework-dependent
dotnet publish -c Release -r win-x64 --self-contained false
```

### WinUI 3 Deployment
```powershell
# MSIX Package (recommended)
dotnet build -c Release
# Creates MSIX package for Microsoft Store or sideloading

# Self-contained executable
dotnet publish -c Release -r win-x64 --self-contained true

# Framework-dependent
dotnet publish -c Release -r win-x64 --self-contained false
```

## Architecture Decisions

### Choosing the Right Implementation

#### When to Use TranslationFiestaCSharp (WinForms)
- **Simple Requirements**: Basic translation functionality without advanced features
- **Performance Priority**: Fast startup and minimal resource usage
- **Legacy Compatibility**: Support for older Windows versions
- **Development Speed**: Quick prototyping and implementation
- **Familiarity**: Developers experienced with traditional Windows development

#### When to Use TranslationFiesta.WinUI (WinUI 3)
- **Modern UI Requirements**: Fluent Design and contemporary user experience
- **Advanced Features**: Batch processing, quality assessment, translation memory
- **Future-Proofing**: Alignment with Microsoft's modern development roadmap
- **Rich Functionality**: Enhanced file operations and user feedback
- **Cross-Platform Potential**: Foundation for future Windows/cross-platform development

### Technology Comparison Benefits

#### WinForms Benefits
- **Procedural UI**: Familiar programming model for traditional developers
- **Lightweight**: Lower memory footprint and faster startup
- **Compatibility**: Broad Windows version support
- **Simplicity**: Easier learning curve and maintenance

#### WinUI 3 Benefits
- **Modern UI**: Fluent Design system and contemporary aesthetics
- **Advanced Features**: Rich controls, animations, and theming
- **Async-Native**: Built-in support for modern async patterns
- **Scalability**: Better suited for complex, feature-rich applications
- **Future-Ready**: Microsoft's recommended path for new Windows applications

## Contributing

### Development Guidelines
- **Consistent Patterns**: Follow existing code patterns in each project
- **Cross-Platform**: Consider compatibility across different Windows versions
- **Performance**: Optimize for both memory usage and responsiveness
- **Error Handling**: Implement comprehensive exception handling

### Feature Parity
- **Core Functionality**: Maintain same features across both implementations
- **UI Consistency**: Keep user experience similar where possible
- **API Support**: Ensure both support same translation APIs
- **Documentation**: Update both README files when making changes

## License

Educational and development purposes. Google Translate API usage subject to Google's terms of service.

## Related Documentation
- [Main Repository README](../README.md)
- [WinForms Documentation](https://docs.microsoft.com/en-us/dotnet/desktop/winforms/)
- [WinUI 3 Documentation](https://docs.microsoft.com/en-us/windows/apps/winui/winui3/)
- [Windows App SDK](https://docs.microsoft.com/en-us/windows/apps/windows-app-sdk/)
- [Google Cloud Translation API](https://cloud.google.com/translate/docs)
