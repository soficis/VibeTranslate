# Beginner's Guide to TranslationFiestaGo (Go)

Welcome to TranslationFiestaGo! This guide will help you get started with the Go implementation of the TranslationFiesta application. It's designed for beginners and covers both CLI and GUI interfaces, with a focus on reliable operation.

## 1. Installation and Setup

Before running the application, ensure your system has the necessary tools and dependencies installed.

### Prerequisites
- **Go 1.21 or later**: Download and install Go from golang.org. Verify with `go version`
- **GCC compiler** (optional, but needed for GUI version): Required for building the GUI components
- **Internet connection**: For Google Translate API access
- **Optional**: Google Cloud Translation API key for official API usage

### Installing Dependencies
1. **Navigate to the TranslationFiestaGo directory**:
   ```
   cd TranslationFiestaGo
   ```

2. **Download and organize Go modules**:
   ```
   go mod tidy
   ```
   This command automatically downloads and sets up all required dependencies from the `go.mod` file.

### API Key Setup
You can use either:
- **Unofficial API** (default): Free, no setup required
- **Official Google Cloud API**: More reliable but paid

To use the official API:
1. Get an API key from Google Cloud Console
2. Set it using the CLI (explained below) for secure storage

The application securely stores your API key using keyring (with AES encrypted file fallback).

## 2. Step-by-Step Guide to Running the Application

TranslationFiestaGo offers both CLI and GUI interfaces. The CLI version is recommended for reliable operation, especially on Windows.

### Building and Running the CLI Version (Recommended)

1. **Build the CLI application**:
   ```
   go build -o translationfiestago-cli cmd/cli/main.go
   ```

2. **Start the CLI**:
   ```
   ./translationfiestago-cli
   ```

3. **You'll see the interactive prompt**:
   ```
   TranslationFiestaGo CLI
   >
   ```

### Building and Running the GUI Version (Experimental)

⚠️ **Note**: The GUI version may have build issues on Windows due to OpenGL dependency conflicts. If you experience problems, use the CLI version instead.

1. **Build the GUI application**:
   ```
   go build -tags=software -o translationfiestago-gui main.go
   ```
   If this fails, try adding `CGO_ENABLED=0`:
   ```
   CGO_ENABLED=0 go build main.go
   ```

2. **Run the GUI**:
   ```
   ./translationfiestago-gui
   ```

3. **Wait for the Fyne window to open**: A modern desktop interface should appear.

### Alternative: Development Mode with Wails

For development and testing GUI features:
1. Ensure Wails is installed (if you want to use it)
2. Run: `wails dev`

## 3. Basic Usage Examples

### CLI Interface

The CLI provides an interactive command-line experience:

1. **Start with simple translation**:
   ```
   > translate Hello world, this is a test.
   ```

2. **Load and translate a file**:
   ```
   > file document.txt
   ```

3. **Set up official API** (if you have a key):
   ```
   > set-api YOUR_GOOGLE_CLOUD_API_KEY
   ```

4. **Toggle between API types**:
   ```
   > toggle-api
   ```

5. **Check current settings**:
   ```
   > status
   ```

### GUI Interface

1. **Enter text**: Type or paste English text in the input field
2. **Select API**: Choose between official and unofficial API
3. **Click Translate**: Press the back-translation button
4. **View results**: See Japanese intermediate and back-translated English
5. **Load files**: Use file picker to import .txt, .md, .html files
6. **Monitor progress**: Watch progress bars during translation

## 4. Basic Usage Examples for Key Advanced Features

### Batch Processing
Process entire directories of multiple files:
1. Set up a folder with .txt, .md, or .html files
2. Use CLI: `file folder_path/` (process entire directory)
3. View progress indicators as files are processed
4. Results are automatically organized and saved

### BLEU Scoring
Evaluate translation quality using BLEU scores:
1. After back-translation, the BLEU score appears automatically
2. Higher scores (closer to 1.0) indicate better quality
3. Useful for comparing different translation approaches

### Cost Tracking
Monitor API usage and set spending limits:
1. View dashboard if building with GUI enabled
2. CLI shows cost information per translation
3. Set monthly budgets to prevent overspending
4. Export cost reports to track usage over time

### Secure Storage
API keys are stored securely using:
- Preferred: Platform-specific keyring
- Fallback: AES encrypted local files
- No manual configuration needed after initial setup

### EPUB Processing
Handle eBooks directly:
1. Load .epub files
2. Select specific chapters for translation
3. Preview chapter contents before translation
4. Extract and translate text content automatically

## 5. Troubleshooting Tips

### Common Issues

**Build fails on Windows**
- **CLI builds always**: `go build cmd/cli/main.go`
- **GUI issues**: Try `CGO_ENABLED=0 go build main.go` or use different build tags
- **Recommendation**: Use CLI version for Windows

**GUI doesn't appear**
- Ensure GCC is installed for CGO dependencies
- Try running on Linux/macOS for better GUI support
- Fall back to CLI which works reliably across platforms

**Translation errors**
- **HTTP errors**: Check internet connection
- **Rate limiting**: Wait a few minutes, then retry
- **API failures**: Switch between official/unofficial APIs
- **Official API**: Verify your API key is set correctly (`> set-api`)

**File processing issues**
- **Supported formats**: Only .txt, .md, .html files
- **Permissions**: Run as administrator if files are not accessible
- **Large files**: Translation may take longer - be patient

**Dependency problems**
- Run `go mod tidy` again to refresh modules
- Check Go version: `go version`
- Ensure PATH includes Go binaries

### Getting Help
- **Check logs**: Located in platform-specific directories
- **Test with simple text**: Verify basic functionality first
- **CLI is always reliable**: Use CLI version if GUI fails
- **Official documentation**: Refer to Google Cloud docs for API keys

## 6. Screenshots

The application has both CLI and GUI interfaces. For CLI, you'll interact through command prompts. Here are the GUI components:

### Main GUI Window
[Insert main application window screenshot showing input field, translate button, and results display here]

### File Selection Dialog
[Insert file picker dialog screenshot here]

### Settings and Configuration Panel
[Insert settings window showing API options and preferences here]

### Cost Tracking Dashboard
[Insert cost tracking interface if GUI supports it, or note CLI equivalent here]

### EPUB Chapter Selector
[Insert EPUB preview pane showing chapter selection here]

### CLI Interface Example
Since CLI is text-based, here's what the interactive session looks like:

```
TranslationFiestaGo CLI
> translate Hello world
Translating...
Japanese: こんにちは世界
Back-translation: Hello world
BLEU Score: 1.000
>
```

TranslationFiestaGo is a powerful, cross-platform application with clean architecture principles. If you encounter GUI issues on Windows, the CLI version provides full functionality reliably. Happy translating!