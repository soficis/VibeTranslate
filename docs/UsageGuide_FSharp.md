# Beginner's Guide to TranslationFiestaFSharp (F#)

Welcome to TranslationFiestaFSharp! This guide introduces you to the functional programming implementation of the TranslationFiesta application, built with F# and .NET 9. It's designed for Windows and demonstrates how functional programming principles can create robust, maintainable software.

## 1. Installation and Setup

TranslationFiestaFSharp is a Windows-native application that leverages the power of functional programming with F# and the .NET ecosystem.

### Prerequisites
- **.NET 9 SDK or later**: Download from Microsoft's .NET site. Verify with `dotnet --version`
- **Windows**: The preferred platform for this Windows Forms application
- **Internet connection**: Required for Google Translate API access
- **Optional: Google Cloud Translation API key**: For official (paid) API, more reliable than unofficial

### Installing Dependencies
1. **Navigate to the TranslationFiestaFSharp folder**:
   ```
   cd TranslationFiestaFSharp
   ```

2. **Restore .NET packages**:
   ```
   dotnet restore
   ```
   This downloads all NuGet packages, including Windows Forms, JSON handling, HTTP clients, and other dependencies required for the application.

3. **Verify the setup**:
   ```
   dotnet build
   ```
   This compiles the F# code and ensures everything is ready.

### API Key Setup
The application supports both API types:
- **Unofficial API** (default): Free and immediate, no setup
- **Official Google Cloud API**: More robust, requires key

To use official API:
1. Obtain a Google Cloud Translation API key
2. Configure it in the application (explained below)
3. The key is stored securely using F#'s secure storage patterns

## 2. Step-by-Step Guide to Running the Application

### Development and Direct Run
1. **Build and run the application**:
   ```
   dotnet run
   ```

2. **Wait for compilation**: F# compiles to .NET IL, which is fast but may take a moment first time

3. **Windows Forms window appears**: A native Windows interface opens with the translation controls

### Running for the First Time
- **No additional setup needed** for basic functionality
- **Firewall**: Windows may prompt for network access - allow it
- **Administrator rights**: Not required, but may improve file access

### Alternative Execution Methods
If `dotnet run` doesn't work, try:
```
dotnet build -c Release
TranslationFiestaFSharp.exe  # Run the built executable
```

## 3. Basic Usage Examples

### Simple Translation
1. **Launch the app**: Use `dotnet run` or the executable
2. **Input text**: Type English text in the designated input field
3. **Select API mode**: Choose between Google Official (if key configured) or Unofficial
4. **Click "Translate"**: The back-translation process begins
5. **Review results**:
   - **Japanese translation**: Intermediate result
   - **Back-translated English**: Final output
   - **Any quality metrics**: If BLEU scoring is enabled
6. **Save results**: Use the menu options to export or save

### File Import and Processing
1. **Click "Load File"**: Opens Windows file dialog
2. **Select file type**: Supports .txt, .md, .html files
3. **Automatic processing**: Text content loads into the input area
4. **Translate**: Proceed with back-translation as normal

### Theme and UI Customization
- **Windows integration**: Follows Windows themes (dark/light)
- **Functional UI**: Clean, minimal interface designed for functionality
- **Windows Forms styling**: Traditional Windows look and feel

## 4. Basic Usage Examples for Key Advanced Features

### Batch Processing
Process multiple files efficiently:
1. Prepare a directory with text files (.txt, .md, .html)
2. Use batch processing from the menu
3. Monitor progress through status indicators
4. Results are processed and organized automatically

### BLEU Scoring
Evaluate translation quality using industry-standard metrics:
1. After translation, BLEU scores appear in the interface
2. Higher scores (closer to 1.0) indicate higher quality
3. Use scores to compare different translations or improve content

### Cost Tracking
Monitor API usage and manage expenses:
1. Access tracking features through the interface
2. View real-time cost calculations
3. Set monthly budgets to prevent overspending
4. Export detailed usage reports

### Advanced Exporting (Undocumented Feature!)
This F# version includes advanced exporting capabilities:
1. Export translations to PDF, DOCX, and HTML formats
2. Apply custom templates
3. Include BLEU scores and metadata in exports
4. Supports batch export for multiple files

(Note: This feature integrates with the BLEUScorer and may not be advertised in main documentation)

### Secure Storage
API keys are protected using .NET secure storage:
- Platform-specific secure storage mechanisms
- No manual configuration after initial setup
- Persists securely across application restarts

## 5. Troubleshooting Tips

### Common Issues

**Application won't start**
- **.NET version**: Ensure .NET 9 SDK is installed: `dotnet --version`
- **Project files**: Run `dotnet restore` again
- **Build errors**: Try `dotnet clean` then `dotnet build`

**Windows Forms not rendering**
- **Windows version**: Requires modern Windows
- **Framework versions**: Ensure .NET 9 compatibility
- **Display settings**: Check DPI scaling in Windows settings

**Translation fails**
- **Network**: Verify internet connection
- **API key**: For official API, check key configuration
- **Rate limits**: Switch between official/unofficial APIs if hitting limits
- **Permissions**: Firewall may block - allow network access

**File loading problems**
- **File types**: Only .txt, .md, .html are supported
- **Permissions**: Try running as administrator if files can't be accessed
- **File encoding**: Ensure files are UTF-8 encoded

**Features not available**
- **Note gaps**: Translation memory is missing compared to other implementations
- **Undocumented features**: Advanced exporting with BLEU integration may need enabling
- **Creative engines**: Ensure they are activated in settings

### Feature Gaps
This F# version has some known limitations:
- **Missing Translation Memory**: No LRU caching for translations (unlike Python, Go, C#)
- **No EPUB Support**: Cannot process .epub files
- **Limited Mobile/Web**: Windows-only, no cross-platform deployment

### Error Handling
The F# implementation emphasizes robust error handling:
- **Comprehensive exception management**
- **Functional error patterns** using Result/Option types
- **Immutability principles** prevent side-effect bugs

### Getting Help
- **Build logs**: Check output from `dotnet build`
- **F# documentation**: Microsoft F# documentation for language-specific issues
- **.NET troubleshooting**: Microsoft's .NET SDK documentation
- **Community**: F# forums and Stack Overflow for advanced issues

## 6. Screenshots

### Main Application Window
[Insert screenshot of the F# Windows Forms interface showing input fields and translate button in functional design]

### Advanced Exporting Interface
[Insert screenshot demonstrating the undocumented advanced exporting feature with template selection]

### BLEU Scoring Display
[Insert screenshot showing BLEU score calculation and display in the translation results]

### Batch Processing Progress
[Insert screenshot of batch file processing with progress indicators]

### Cost Tracking Dashboard
[Insert screenshot showing the cost tracking interface with usage statistics]

TranslationFiestaFSharp showcases how functional programming with F# creates clean, error-resistant code. While it has some feature gaps compared to other implementations, its strong error handling and undocumented advanced exporting make it valuable for specific use cases. The functional approach ensures immutability and reliable operation in production environments.