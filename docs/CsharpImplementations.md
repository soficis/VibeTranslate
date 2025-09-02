# C# Implementations - WinForms & WPF

## Overview

The repository contains two C# implementations of the TranslationFiesta application:

### CsharpTranslationFiesta (WinForms)
**Console Application Edition** - A straightforward Windows Forms implementation targeting .NET 9, designed for simplicity and ease of deployment.

### FreeTranslateWin (WPF)
**Modern Desktop Edition** - A Windows Presentation Foundation implementation with rich UI controls, data binding, and MVVM-ready architecture.

Both implementations maintain the same core functionality while showcasing different approaches to Windows desktop development.

## Architecture Comparison

### WinForms vs WPF

| Aspect | WinForms | WPF |
|--------|----------|-----|
| **Framework Age** | Mature (2002) | Modern (2006) |
| **UI Paradigm** | Procedural | Declarative (XAML) |
| **Styling** | Limited | Extensive |
| **Data Binding** | Basic | Advanced |
| **Performance** | Fast startup | Rich features |
| **Learning Curve** | Gentle | Steeper |
| **Deployment** | Simple | Feature-rich |

## CsharpTranslationFiesta - WinForms Implementation

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

## FreeTranslateWin - WPF Implementation

### Architecture

#### Core Components
- **MainWindow.xaml**: Declarative UI definition
- **MainWindow.xaml.cs**: Code-behind with event handling
- **App.xaml**: Application resources and startup
- **Translation Logic**: Integrated API client

#### XAML Structure
```xml
<Window x:Class="FreeTranslateWin.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Free Google Translate WinForms" Height="600" Width="800">

    <Grid>
        <!-- Menu -->
        <Menu Grid.Row="0">
            <MenuItem Header="File">
                <MenuItem Header="Import .txt" Click="ImportTxtMenuItem_Click" />
                <MenuItem Header="Save Back" Click="SaveBackMenuItem_Click" />
            </MenuItem>
        </Menu>

        <!-- Main Content -->
        <Grid Grid.Row="1">
            <!-- Input Section -->
            <TextBox x:Name="inputTextBox" Grid.Row="0" />

            <!-- Output Section -->
            <TextBox x:Name="intermediateTextBox" Grid.Row="1" />
            <TextBox x:Name="backTranslatedTextBox" Grid.Row="2" />

            <!-- Controls -->
            <Button x:Name="translateButton" Grid.Row="3" Click="TranslateButton_Click" />
        </Grid>
    </Grid>
</Window>
```

#### Code-Behind Organization
```csharp
public partial class MainWindow : Window
{
    // Fields
    private readonly HttpClient _httpClient = new();

    // Constructor
    public MainWindow()
    {
        InitializeComponent();
    }

    // Event Handlers
    private async void TranslateButton_Click(object sender, RoutedEventArgs e)
    private void ImportTxtMenuItem_Click(object sender, Object e)
    private void SaveBackMenuItem_Click(object sender, Object e)
}
```

### Features

#### 🎨 WPF UI
- **Rich Controls**: Advanced text boxes, buttons, and layout panels
- **Data Binding**: Basic data binding capabilities
- **Styling**: XAML-based styling and theming
- **Modern Appearance**: More polished UI than WinForms

#### 🌐 Translation Engine
- **Unofficial API Only**: Uses free Google Translate endpoint
- **Async Processing**: Modern async/await implementation
- **Error Handling**: Comprehensive exception management
- **Network Resilience**: Timeout and retry logic

#### 📁 File Operations
- **Import Support**: Load .txt files with file dialog
- **Export Results**: Save back-translation to file
- **Menu Integration**: Standard Windows menu system
- **Keyboard Shortcuts**: Standard shortcuts support

#### ⚙️ UI Features
- **Window Management**: Resizable, minimizable window
- **Status Updates**: Progress feedback during operations
- **Input Areas**: Separate text boxes for different content
- **Control Layout**: Grid-based responsive layout

## Installation & Setup

### Prerequisites (Both Implementations)
- **.NET 7+ SDK** (.NET 9 recommended)
- **Windows OS** (WinForms/WPF dependency)
- **Internet connection** for translation services

### CsharpTranslationFiesta Setup
1. **Navigate to directory**:
   ```powershell
   cd CsharpTranslationFiesta
   ```
2. **Build and run**:
   ```powershell
   dotnet build -c Release
   dotnet run --project CsharpTranslationFiesta.csproj
   ```

### FreeTranslateWin Setup
1. **Navigate to directory**:
   ```powershell
   cd FreeTranslateWin
   ```
2. **Build and run**:
   ```powershell
   dotnet build "FreeTranslateWin.csproj"
   dotnet run --project "FreeTranslateWin.csproj"
   ```

### Dependencies

#### Shared Dependencies
- **System.Windows.Forms** (WinForms only)
- **PresentationFramework** (WPF only)
- **System.Net.Http**: HTTP client for API calls
- **System.Text.Json**: JSON processing

## Usage Guide

### Basic Operation (Both)

1. **Launch**: Run respective dotnet run command
2. **Input Text**: Type or paste English text
3. **Translate**: Click "Backtranslate" or "Translate" button
4. **View Results**:
   - **Intermediate**: Japanese translation
   - **Final**: Back-translated English

### CsharpTranslationFiesta Features
- **API Selection**: Toggle between unofficial/official API
- **API Key Input**: Secure password field for Google Cloud key
- **Theme Toggle**: Switch between dark/light modes
- **File Menu**: Standard Windows menu operations

### FreeTranslateWin Features
- **Simplified UI**: Focused on core translation functionality
- **Menu System**: File operations via menu bar
- **Status Updates**: Progress feedback in UI
- **Window Management**: Standard Windows window controls

### Keyboard Shortcuts (Both)
- **Ctrl+O**: Import text file
- **Ctrl+S**: Save results
- **Ctrl+C**: Copy results to clipboard

## Development

### Project Structure Comparison

#### CsharpTranslationFiesta
```
CsharpTranslationFiesta/
├── Program.cs              # Entry point and form creation
├── TranslationClient.cs    # API client
├── Logger.cs               # Simple logging
├── CsharpTranslationFiesta.csproj
└── README.md
```

#### FreeTranslateWin
```
FreeTranslateWin/
├── App.xaml                # Application definition
├── App.xaml.cs             # Application code
├── MainWindow.xaml         # Window XAML
├── MainWindow.xaml.cs      # Window code-behind
├── FreeTranslateWin.csproj
├── app.manifest            # Application manifest
└── README.md
```

### Code Patterns

#### WinForms Pattern (CsharpTranslationFiesta)
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

#### WPF Pattern (FreeTranslateWin)
```xml
<!-- Declarative UI in XAML -->
<TextBox x:Name="inputTextBox"
         Grid.Row="0"
         Margin="10"
         AcceptsReturn="True"
         TextWrapping="Wrap"
         VerticalScrollBarVisibility="Auto" />
```

```csharp
// Code-behind for event handling
private async void TranslateButton_Click(object sender, RoutedEventArgs e)
{
    // Access controls by name
    string inputText = inputTextBox.Text;
    // Process translation
}
```

### Building and Testing

#### Debug Build
```powershell
# WinForms
dotnet build CsharpTranslationFiesta.csproj

# WPF
dotnet build FreeTranslateWin.csproj
```

#### Release Build
```powershell
# WinForms
dotnet build CsharpTranslationFiesta.csproj -c Release

# WPF
dotnet build FreeTranslateWin.csproj -c Release
```

## Troubleshooting

### Common Issues (Both)

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

### WPF-Specific Issues
```
Error: XAML parsing errors
Solution: Check XAML syntax and namespace declarations
```

## Performance Comparison

### Benchmarks
- **Startup Time**:
  - WinForms: ~1 second
  - WPF: ~2 seconds
- **Memory Usage**:
  - WinForms: ~40MB typical
  - WPF: ~60MB typical
- **UI Responsiveness**:
  - WinForms: Fast, immediate
  - WPF: Smooth, hardware-accelerated

### Optimization Considerations
- **WinForms**: Better for simple, fast applications
- **WPF**: Better for complex, feature-rich applications
- **Resource Usage**: WinForms generally lighter
- **Rendering**: WPF more consistent across different DPIs

## Deployment

### WinForms Deployment
```powershell
# Self-contained executable
dotnet publish -c Release -r win-x64 --self-contained true

# Framework-dependent
dotnet publish -c Release -r win-x64 --self-contained false
```

### WPF Deployment
```powershell
# Self-contained executable
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

# Framework-dependent
dotnet publish -c Release -r win-x64 --self-contained false
```

## Architecture Decisions

### Why Two C# Implementations?

#### CsharpTranslationFiesta (WinForms)
- **Simplicity**: Easier for beginners to understand
- **Performance**: Faster startup and lower resource usage
- **Deployment**: Simpler distribution
- **Maintenance**: Less complex codebase

#### FreeTranslateWin (WPF)
- **Modern UI**: Better visual appearance
- **Scalability**: Easier to extend and enhance
- **Data Binding**: Better separation of UI and logic
- **Future-Proof**: More aligned with modern .NET development

### Technology Choice Guidelines
- **Choose WinForms** for:
  - Simple applications
  - Fast development
  - Low resource requirements
  - Familiar procedural programming

- **Choose WPF** for:
  - Complex user interfaces
  - Rich data visualization
  - MVVM architecture
  - Modern Windows integration

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
- [WPF Documentation](https://docs.microsoft.com/en-us/dotnet/desktop/wpf/)
- [Google Cloud Translation API](https://cloud.google.com/translate/docs)
