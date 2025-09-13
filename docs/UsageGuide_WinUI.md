# Beginner's Guide to TranslationFiesta.WinUI (C#)

Welcome to TranslationFiesta.WinUI! This guide will help you get started with the modern Windows 11 native implementation of the TranslationFiesta application. Built with WinUI 3 (Windows App SDK), it provides a beautiful Fluent Design experience with secure storage and MSIX packaging.

## 1. Installation and Setup

The WinUI version is designed specifically for Windows 11 and requires modern Windows development tools. Ensure your system meets the requirements before proceeding.

### Prerequisites
- **Windows 10 version 1903 (19H1) or later, or Windows 11**: For the best experience, use Windows 11
- **Windows App SDK**: Download and install from Microsoft's developer site or Visual Studio Installer
- **.NET 9 SDK**: Install from Microsoft's .NET downloads page. Verify with `dotnet --version`
- **Internet connection**: Required for Google Translate API access
- **Optional: Google Cloud Translation API key**: For official (paid) API usage

### Installing Dependencies
1. **Navigate to the TranslationFiesta.WinUI folder**:
   ```
   cd TranslationFiesta.WinUI
   ```

2. **Restore project dependencies**:
   ```
   dotnet restore
   ```
   This downloads and sets up all required NuGet packages, including Windows App SDK and other dependencies.

3. **Build the project**:
   ```
   dotnet build
   ```
   This compiles the application and ensures everything is ready to run.

### API Key Setup
Choose between two API options:
- **Unofficial API** (default): Free, no setup required
- **Official Google Cloud API**: More reliable but requires key

For official API:
1. Get an API key from Google Cloud Console
2. Start the app and configure it (explained below)
3. The key will be securely stored using Windows DPAPI (Data Protection API)

## 2. Step-by-Step Guide to Running the Application

### Development/Direct Run
1. **Build and run in one step**:
   ```
   dotnet run
   ```

2. **Wait for the application window to appear**: A modern WinUI window should open with Fluent Design styling.

3. **The application is ready to use!**

### MSIX Packaging and Installation (Optional)
For a more professional deployment, you can create an MSIX package:

1. **Build release version**:
   ```
   dotnet build -c Release
   ```

2. **Use the packaging script** (included in the tools folder):
   ```
   .\tools\package-winui-msix.ps1 -AppExecutablePath "bin\Release\net9.0-windows10.0.19041.0\win10-x64\TranslationFiesta.WinUI.exe" -OutputMsix "TranslationFiesta.msix"
   ```

3. **Install the MSIX package**:
   - Double-click the .msix file, or
   - Use PowerShell: `Add-AppxPackage -Path TranslationFiesta.msix`

If installation fails:
- Enable "Developer Mode" in Windows Settings → Update & Security → For developers
- Try sideloading or use the development run instead

## 3. Basic Usage Examples

### Simple Translation
1. **Launch the application**: Either through `dotnet run` or MSIX installation
2. **Enter text**: Type or paste English text in the input area
3. **Configure API**:
   - Default: Unofficial API (no setup needed)
   - Optional: Check "Use Official API" and enter your Google Cloud key
4. **Click "Backtranslate"**: Watch the progress bar as translation begins
5. **View results**:
   - **Intermediate**: See the Japanese translation
   - **Final**: Review the back-translated English result
6. **Save or copy**: Use keyboard shortcuts or menu options to save results

### File Operations
1. **Load a file**: Click "Load File" button (or Ctrl+O)
2. **Select format**: Choose .txt, .md, or .html files
3. **Auto-import**: Text content is loaded into the input area
4. **Translate**: Proceed with back-translation as usual

### Theme Switching
- **Automatic**: App follows your Windows system theme by default
- **Manual toggle**: Use the theme button to switch between dark/light modes
- **Persistent**: Your preference is saved between app sessions

### Keyboard Shortcuts
- **Ctrl+S**: Save translation results to file
- **Ctrl+C**: Copy results to clipboard
- **Ctrl+O**: Open file for translation
- **F11**: Toggle fullscreen mode

## 4. Basic Usage Examples for Key Advanced Features

### Batch Processing
Process entire folders of text files:
1. Set up a directory with multiple .txt, .md, or .html files
2. Use the batch processing feature through the menu
3. Monitor progress with built-in indicators
4. Results are automatically organized and saved

### BLEU Scoring
Evaluate translation quality:
1. After back-translation, BLEU scores appear automatically
2. Higher scores (closer to 1.0) indicate better translation quality
3. Use scores to compare different texts or API results

### Cost Tracking
Monitor your API usage:
1. Access the cost dashboard from the menu
2. View real-time cost calculation based on API usage
3. Set monthly budgets to prevent overspending
4. Export detailed cost reports

### Advanced Exporting
Save results in various formats:
1. Choose "Export" from the menu or use Ctrl+E
2. Select format: PDF, DOCX, or HTML
3. Use custom templates for professional output
4. Include metadata like translation quality scores

### Secure Storage
Your Google Cloud API key is automatically protected:
- Uses Windows DPAPI for user-specific encryption
- Only accessible by you, on your machine
- No manual configuration after initial setup
- Persists securely across app restarts

### Translation Memory
Cache translations for efficiency:
1. Frequent translations are automatically cached
2. Reduces API costs for repeated content
3. Performance improves with repeated use
4. Fuzzy matching for similar texts

### Analytics Dashboard
View detailed usage analytics:
1. Access analytics through the menu
2. See translation statistics and trends
3. Monitor API usage patterns
4. Track performance metrics

## 5. Troubleshooting Tips

### Common Issues

**"Windows App SDK not found" or build failures**
- **Solution**: Install Windows App SDK from Visual Studio Installer under "Individual components" → ".NET Framework and Windows App SDK"
- **Alternative**: Use the latest Visual Studio version with WinUI support

**MSIX installation blocked**
- **Enable Developer Mode**: Settings → Update & Security → For developers → Developer Mode
- **Or**: Use the development `dotnet run` method instead

**API key decryption errors**
- **Clear storage**: Delete `%APPDATA%\TranslationFiesta.WinUI\secure.dat`
- **Re-enter key**: The app will prompt for the API key again
- **User context**: Make sure you're running as the same user who originally stored the key

**Theme not applying**
- **Check system settings**: Windows Settings → Personalization → Colors
- **App permissions**: Some theme features may require specific Windows permissions
- **Restart app**: Theme changes should apply immediately, but try restarting if needed

**Translation timeouts**
- **Check internet**: Ensure stable internet connection
- **API limits**: Switch between official/unofficial APIs
- **Retry**: Use the built-in retry logic or try again later

**File loading errors**
- **Supported formats**: Only .txt, .md, .html are supported
- **Permissions**: Make sure you have read access to the file
- **Large files**: Very large files may need more processing time

**Memory or performance issues**
- **Dotnet version**: Make sure you're using .NET 9
- **Graphics drivers**: Update Windows and graphics drivers for best performance
- **System resources**: Close other applications if running slowly

### Getting Help
- **Log files**: Check `%APPDATA%\TranslationFiesta.WinUI\logs\` for detailed error information
- **Event Viewer**: Windows Logs → Application for system-level events
- **Debug mode**: During development, use F5 debugging in Visual Studio
- **Community**: Check if others have similar issues with WinUI apps

### Performance Optimization
- **Startup time**: Should be under 3 seconds on modern hardware
- **Translation speed**: Typically 2-6 seconds (network dependent)
- **Memory usage**: About 60MB normally, may peak at 120MB during large translations
- **UI smoothness**: 60 FPS animations on modern systems

## 6. Screenshots

### Main Application Window (Light Theme)
[Insert screenshot showing main WinUI window with input fields, translate button, and progress indicators in Fluent Design style]

### Main Application Window (Dark Theme)
[Insert screenshot of the same window in dark theme showing perfect Fluent Design implementation]

### File Selection Dialog
[Insert screenshot of the WinUI file picker dialog for selecting text files]

### Analytics Dashboard
[Insert screenshot of the analytics dashboard showing translation statistics and performance metrics]

### Settings Panel
[Insert screenshot of settings window with theme options and API configuration]

### Cost Tracking View
[Insert screenshot showing cost dashboard with usage charts and budget settings]

### Template Editor
[Insert screenshot of export template customization interface]

This application leverages Windows 11's native capabilities for the best possible experience. If you encounter issues with MSIX installation, the development build will work perfectly for daily use. Enjoy modern Windows app development with TranslationFiesta.WinUI!