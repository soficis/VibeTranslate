# TranslationFiesta.WinUI - WinUI 3 Implementation

## Overview

**TranslationFiesta.WinUI** is a modern Windows 11 native implementation of the TranslationFiesta application, built with WinUI 3 (Windows App SDK). This version provides a Fluent Design experience with secure storage, persistent settings, and MSIX packaging capabilities.

## Architecture

### WinUI 3 Framework

WinUI 3 is Microsoft's modern UI framework for Windows applications, providing:

#### 🎨 Fluent Design System
- **Consistent Styling**: Follows Windows 11 design language
- **Dark/Light Themes**: System-aware theme switching
- **Responsive Layout**: Adapts to different screen sizes and orientations
- **Accessibility**: Built-in accessibility features

#### 🔧 Windows App SDK
- **Modern APIs**: Latest Windows platform features
- **Better Performance**: Improved rendering and resource management
- **Future-Proof**: Regular updates and long-term support
- **Deployment**: MSIX packaging for Microsoft Store distribution

### Core Components

#### Main Window (`MainWindow.xaml.cs`)
- **XAML Layout**: Declarative UI definition
- **Code-Behind**: Event handling and business logic
- **Data Binding**: MVVM-ready architecture
- **Lifecycle Management**: Proper resource cleanup

#### Application (`App.xaml.cs`)
- **Entry Point**: Application startup and initialization
- **Resource Management**: Global styles and resources
- **Theme Handling**: System theme integration
- **Exception Handling**: Global error management

#### Services
- **TranslationClient**: Advanced API client with translation memory and quality assessment.
- **BatchProcessor**: Handles batch processing of directories.
- **BLEUScorer**: Calculates BLEU scores for translation quality assessment.
- **CostTracker**: Tracks API usage costs.
- **ExportManager**: Exports translations to PDF, DOCX, and HTML.
- **SecureStore**: DPAPI-based credential storage.
- **SettingsService**: Persistent application settings.
- **ThemeService**: Theme management and switching.
- **TemplateManager**: Manages custom templates for exporting.
- **AnalyticsManager**: Provides analytics and dashboarding features.
- **TranslationMemoryManager**: Manages the translation memory.

## Features

### 🎨 Modern UI Experience
- **Fluent Design**: Windows 11 native appearance
- **Responsive Layout**: Grid-based adaptive design
- **Theme Integration**: Automatic dark/light mode switching
- **Progress Indicators**: WinUI ProgressBar and ProgressRing controls

### 🔐 Security & Storage
- **Secure API Storage**: Windows DPAPI (Data Protection API)
- **Persistent Settings**: User preferences maintained across sessions
- **Credential Protection**: Encrypted storage for API keys
- **Per-User Encryption**: Keys encrypted with user-specific data

### 📦 Deployment & Distribution
- **MSIX Packaging**: Modern Windows app packaging format
- **Microsoft Store Ready**: Compatible with Windows Store requirements
- **Self-Contained**: No external dependencies required
- **Auto-Updates**: Framework for update mechanisms

### 🌐 Translation Engine
- **Dual API Support**:
  - **Unofficial Google Translate**: Free, immediate setup
  - **Official Google Cloud Translation API**: Enterprise-grade with secure key storage
- **Async Operations**: Modern async/await patterns
- **Error Handling**: Comprehensive exception management
- **Retry Logic**: Intelligent retry with exponential backoff

### ⚙️ Advanced Features
- **Batch Processing**: Process entire directories of text files.
- **Quality Metrics (BLEU)**: Assess translation quality with BLEU scores.
- **Cost Tracking**: Track API usage costs and set monthly budgets.
- **Advanced Exporting**: Export to PDF, DOCX, and HTML with custom templates.
- **Secure Storage**: Securely store API keys using DPAPI.
- **Translation Memory**: Cache translations to improve performance and reduce costs.
- **Analytics Dashboard**: View detailed analytics on translation usage.
- **Template Editor**: Create and manage custom export templates.

## Installation & Setup

### Prerequisites
- **Windows 10 version 1903 (19H1)** or later, or **Windows 11**
- **Windows App SDK** installed
- **.NET 9 SDK** or newer
- **Internet connection** for translation services

### Installation Steps

#### Development Setup
1. **Clone or download** the TranslationFiesta.WinUI folder
2. **Navigate to the directory**:
   ```powershell
   cd TranslationFiesta.WinUI
   ```
3. **Restore dependencies**:
   ```powershell
   dotnet restore
   ```
4. **Build the project**:
   ```powershell
   dotnet build
   ```
5. **Run the application**:
   ```powershell
   dotnet run
   ```

#### MSIX Packaging
1. **Build Release version**:
   ```powershell
   dotnet build -c Release
   ```
2. **Package as MSIX**:
   ```powershell
   .\tools\package-winui-msix.ps1 -AppExecutablePath "bin\Release\net9.0-windows10.0.19041.0\win10-x64\TranslationFiesta.WinUI.exe" -OutputMsix "TranslationFiesta.msix"
   ```
3. **Sign the package** (optional but recommended):
   ```powershell
   # Requires Windows SDK and code signing certificate
   SignTool sign /fd SHA256 /a /f cert.pfx /p password TranslationFiesta.msix
   ```

### Dependencies

#### Core Dependencies
- **Microsoft.WindowsAppSDK**: WinUI 3 framework
- **Microsoft.Windows.SDK.BuildTools**: Windows SDK build tools
- **System.Net.Http**: HTTP client for API calls
- **System.Text.Json**: JSON serialization

#### Development Dependencies
- **Microsoft.NET.Sdk**: .NET SDK
- **WinUI tools**: XAML designer and debugging tools

## Usage Guide

### Basic Operation

1. **Launch**: Run `dotnet run` or install the MSIX package
2. **Input Text**: Type or paste English text in the input area
3. **Configure API**:
   - Use unofficial API (default)
   - Or enable official API and enter Google Cloud API key
4. **Translate**: Click "Backtranslate" button
5. **Review Results**:
   - **Intermediate**: Japanese translation
   - **Final**: Back-translated English result

### Advanced Features

#### Secure API Key Storage
1. Check "Use Official API"
2. Enter your Google Cloud API key
3. Key is automatically encrypted and stored securely
4. Key persists across application sessions

#### Theme Management
- **Automatic**: Follows Windows system theme
- **Manual Override**: Toggle dark/light mode
- **Persistent**: Theme preference saved between sessions

#### File Operations
1. **Import**: Click "Load File" or Ctrl+O
2. **Supported Formats**: .txt, .md, .html
3. **Export**: Save results with Ctrl+S
4. **Copy**: Copy results to clipboard with Ctrl+C

#### Settings Persistence
- **Window Size/Position**: Restored on next launch
- **Theme Preference**: Maintains dark/light mode choice
- **API Selection**: Remembers unofficial/official choice
- **API Key**: Securely stored (if provided)

### Keyboard Shortcuts
- **Ctrl+O**: Open file
- **Ctrl+S**: Save results
- **Ctrl+C**: Copy results to clipboard
- **F11**: Toggle fullscreen (if supported)

## Configuration

### Application Settings
Settings are automatically saved to `%APPDATA%\TranslationFiesta.WinUI\settings.json`:

```json
{
  "Theme": "System",
  "WindowWidth": 1200,
  "WindowHeight": 800,
  "UseOfficialApi": false,
  "LastUsedDirectory": "C:\\Users\\User\\Documents"
}
```

### Secure Storage
API keys are encrypted using Windows DPAPI:
- **Location**: `%APPDATA%\TranslationFiesta.WinUI\secure.dat`
- **Encryption**: User-specific, machine-specific encryption
- **Access**: Only accessible by the same user on the same machine

### Theme Configuration
Themes defined in `Themes/` directory:
- **`LightTheme.xaml`**: Light mode resources
- **`DarkTheme.xaml`**: Dark mode resources
- **`Controls.xaml`**: Custom control styles

## Development

### Project Structure
```
TranslationFiesta.WinUI/
├── App.xaml                    # Application definition
├── App.xaml.cs                 # Application code-behind
├── MainWindow.xaml             # Main window XAML
├── MainWindow.xaml.cs          # Main window code-behind
├── TranslationFiesta.WinUI.csproj
├── Package.appxmanifest        # MSIX manifest
├── Themes/
│   ├── LightTheme.xaml         # Light theme resources
│   ├── DarkTheme.xaml          # Dark theme resources
│   └── Controls.xaml           # Custom controls
├── Logger.cs                   # Logging utility
├── SecureStore.cs              # DPAPI storage service
├── SettingsService.cs          # Settings management
├── ThemeService.cs             # Theme management
└── tools/
    └── package-winui-msix.ps1  # MSIX packaging script
```

### XAML Architecture

#### MainWindow.xaml Structure
```xml
<Window x:Class="TranslationFiesta.WinUI.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        mc:Ignorable="d">

    <Grid>
        <!-- Menu -->
        <MenuBar... />

        <!-- Main Content -->
        <Grid...>
            <!-- Input Section -->
            <!-- Output Section -->
            <!-- Controls -->
        </Grid>

        <!-- Status Bar -->
        <InfoBar... />
    </Grid>
</Window>
```

#### Code-Behind Organization
```csharp
public sealed partial class MainWindow : Window
{
    // Fields
    private SettingsService _settings;
    private SecureStore _secureStore;
    private ThemeService _themeService;

    // Constructor
    public MainWindow()
    {
        InitializeComponent();
        InitializeServices();
        LoadSettings();
    }

    // Event Handlers
    private void BacktranslateButton_Click(object sender, RoutedEventArgs e)
    private async void LoadFileButton_Click(object sender, RoutedEventArgs e)

    // Helper Methods
    private async Task TranslateTextAsync(string text)
    private void UpdateTheme(Theme theme)
    private void SaveSettings()
}
```

### Building and Debugging

#### Debug Build
```powershell
dotnet build
```

#### Release Build
```powershell
dotnet build -c Release
```

#### Debugging WinUI Apps
- **Visual Studio**: Full debugging support with XAML hot reload
- **Debug Console**: Live Visual Tree inspection
- **Performance**: UI thread analysis and optimization

#### Hot Reload
WinUI supports XAML hot reload during debugging:
1. Make XAML changes
2. Save file
3. Changes appear immediately without restart

## Security

### DPAPI Implementation
```csharp
public class SecureStore
{
    public void SaveApiKey(string apiKey)
    {
        // Encrypt with ProtectedData.Protect
        // Store in user-specific location
    }

    public string LoadApiKey()
    {
        // Decrypt with ProtectedData.Unprotect
        // Return decrypted API key
    }
}
```

### Best Practices
- **Never log API keys**: Even in debug mode
- **Encrypt sensitive data**: All credentials encrypted at rest
- **Per-user encryption**: Keys tied to specific user account
- **Secure deletion**: Overwrite memory containing keys

## Deployment

### MSIX Packaging
```powershell
# Using the included script
.\tools\package-winui-msix.ps1 `
    -AppExecutablePath "bin\Release\net9.0-windows10.0.19041.0\win10-x64\TranslationFiesta.WinUI.exe" `
    -OutputMsix "C:\output\TranslationFiesta.msix"
```

### MSIX Manifest Configuration
Key settings in `Package.appxmanifest`:
```xml
<Package>
  <Identity Name="TranslationFiesta.WinUI" Version="1.0.0.0" />
  <Properties>
    <DisplayName>TranslationFiesta</DisplayName>
    <Description>Modern back-translation tool for Windows</Description>
  </Properties>
  <Applications>
    <Application Id="App" Executable="TranslationFiesta.WinUI.exe">
      <VisualElements DisplayName="TranslationFiesta" Description="Back-translation tool" />
    </Application>
  </Applications>
</Package>
```

### Distribution Options
- **Sideloading**: Install MSIX directly on target machines
- **Microsoft Store**: Submit for Windows Store distribution
- **Enterprise**: Deploy via Microsoft Intune or SCCM
- **Development**: Share MSIX packages for testing

## Troubleshooting

### Common Issues

#### Build Failures
```
Error: Windows App SDK not found
Solution: Install Windows App SDK from Visual Studio Installer
```

#### Runtime Errors
```
Error: The application cannot be installed
Solution: Enable Developer Mode in Windows Settings
```

#### Theme Issues
```
Error: Theme not applying
Solution: Check system theme settings and app permissions
```

#### API Key Issues
```
Error: Failed to decrypt API key
Solution: Clear secure storage and re-enter API key
```

### Debug Information
- **Event Viewer**: Windows Logs → Application
- **Debug Output**: Visual Studio Output window
- **MSIX Logs**: `%LOCALAPPDATA%\Packages\...\AC\Temp\*.log`
- **Settings Location**: `%APPDATA%\TranslationFiesta.WinUI\`

## Performance

### Benchmarks
- **Startup Time**: < 3 seconds on modern hardware
- **Translation Speed**: 2-6 seconds (network dependent)
- **Memory Usage**: ~60MB typical, ~120MB peak during translation
- **UI Responsiveness**: 60 FPS smooth animations

### Optimization Features
- **Async Operations**: Non-blocking UI with async/await
- **Compiled Bindings**: Fast XAML data binding
- **Resource Management**: Proper disposal and cleanup
- **Efficient Rendering**: Hardware-accelerated graphics

## Contributing

### Development Setup
1. **Install Windows App SDK**
2. **Install .NET 9 SDK**
3. **Clone repository**
4. **Build and run**: `dotnet build && dotnet run`

### Code Standards
- **MVVM Pattern**: Separation of concerns
- **Async/Await**: Modern async programming
- **Exception Handling**: Try-catch with appropriate handling
- **Resource Cleanup**: IDisposable pattern
- **Security**: Never log sensitive data

### UI/UX Guidelines
- **Fluent Design**: Follow Windows 11 design principles
- **Accessibility**: Support screen readers and keyboard navigation
- **Responsive**: Work on different screen sizes
- **Performance**: Smooth animations and interactions

## Architecture Decisions

### Why WinUI 3?
- **Modern Framework**: Latest Windows development platform
- **Better Performance**: Improved rendering and resource usage
- **Future-Proof**: Long-term Microsoft support
- **Native Integration**: Best Windows 11 experience

### Security-First Design
- **DPAPI Integration**: Enterprise-grade credential protection
- **Persistent Settings**: Better user experience
- **MSIX Packaging**: Secure deployment model
- **Per-User Storage**: Isolated user data

### Fluent Design Implementation
- **System Theme Integration**: Automatic theme switching
- **Consistent Styling**: Windows 11 design language
- **Accessibility Support**: Built-in accessibility features
- **Responsive Layout**: Adapts to different form factors

## License

Educational and development purposes. Google Translate API usage subject to Google's terms of service.

## Related Documentation
- [Main Repository README](../README.md)
- [WinUI 3 Documentation](https://docs.microsoft.com/en-us/windows/winui/winui3/)
- [Windows App SDK](https://docs.microsoft.com/en-us/windows/apps/windows-app-sdk/)
- [Google Cloud Translation API](https://cloud.google.com/translate/docs)
- [MSIX Packaging](https://docs.microsoft.com/en-us/windows/msix/)
