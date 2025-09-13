# Beginner's Guide to TranslationFiestaPy (Python)

Welcome to TranslationFiestaPy! This guide will help you get started with this Python-based back-translation application. It's designed for beginners, so we'll go step by step.

## 1. Installation and Setup

Before you can run the application, you need to prepare your system with the necessary software and tools.

### Prerequisites
- **Python 3.6 or higher**: Make sure you have Python installed on your computer. You can download it from python.org.
- **Internet connection**: The app uses Google's Translation API, so you need a stable internet connection.
- **Optional: Google Cloud Translation API key**: If you want to use the official (paid) API instead of the free unofficial one, you'll need a key from Google Cloud Console.

### Installing Dependencies
1. Open a terminal or command prompt.
2. Navigate to the TranslationFiestaPy folder (where you find this README).
3. Run this command to install all required libraries:
   ```
   pip install -r requirements.txt
   ```
   This installs essential packages like `requests` for API calls, `beautifulsoup4` for HTML processing, and others for advanced features.

### API Key Setup
The app supports two types of Google Translate APIs:

- **Unofficial (Free)**: No setup needed, it's the default mode
- **Official (Paid)**: More reliable but requires setup

For the official API:
1. Get an API key from Google Cloud Console
2. Set it securely using keyring (a package installed with requirements)
3. Or set an environment variable: `GOOGLE_TRANSLATE_API_KEY=your_key_here`

The app will prompt you to enter the key when you first try to use it.

## 2. Step-by-Step Guide to Running the Application

1. **Open your command prompt or terminal**
2. **Navigate to the TranslationFiestaPy directory**:
   ```
   cd path/to/TranslationFiestaPy
   ```
3. **Start the application**:
   ```
   python TranslationFiesta.py
   ```
4. **Wait for the window to open**: A Tkinter window should appear with the interface.

That's it! The application is now ready to use.

## 3. Basic Usage Examples

### Simple Translation
1. Type some English text in the input box (e.g., "Hello world")
2. Check the translation options:
   - Toggle "Use Official API" if you have a key
3. Click the "BackTranslate" button
4. Wait for the results to appear:
   - First you see the Japanese translation
   - Then the back-translated English
5. Copy or save the results as needed

### Using File Input
1. Click the "Load File" button
2. Choose a text file (.txt, .md, .html)
3. The content will be loaded into the input box
4. Proceed with translation as above

### Switching Themes
- Use the theme toggle button (moon/sun icon) to switch between dark and light modes

## 4. Basic Usage Examples for Key Advanced Features

### Batch Processing
Process entire directories of files:
1. Ensure you have a folder with multiple text files
2. The app will scan for .txt, .md, .html files
3. Results are saved automatically with naming patterns

### BLEU Scoring
Get quality scores for your translations:
1. After back-translation, look for BLEU score display
2. Higher scores (closer to 1.0) indicate better quality
3. Scores are useful for comparing different translations

### Cost Tracking
Monitor your API usage:
1. View cost information in the app's interface
2. Set monthly budgets to avoid overspending
3. Export usage reports when needed

### Secure Storage
Your API keys are stored securely using platform-specific features, so you don't need to set them repeatedly.

## 5. Troubleshooting Tips

### Common Issues

**The application won't start**
- Make sure Python is installed and in your PATH
- Try running `python --version` to verify
- Ensure all dependencies are installed: `pip install -r requirements.txt`

**GUI window doesn't appear**
- Tkinter should come with Python, but if not: install it (`apt install python3-tk` on Ubuntu, or search for your OS)
- Try running in different Python environments

**Translation errors**
- Check your internet connection
- If using official API: verify your API key is set correctly
- Try switching between unofficial and official API modes
- The app has retry logic, so slow connections should work eventually

**File loading issues**
- Supported formats: .txt, .md, .html only
- Ensure the file isn't corrupted or empty
- For HTML files, make sure they contain readable text content

**API quota exceeded**
- If using free unofficial API, wait a while before trying again
- Switch to official API with your Google Cloud key
- Check Google's terms of service and usage limits

### General Tips
- Always close the application properly before shutting down your computer
- Keep your Python and dependencies updated for best performance
- For large files, translation may take longer - be patient!

## 6. Screenshots

### Main Application Window (Light Theme)
[Insert GUI screenshot with main window showing input, buttons, and results here]

### File Loading Interface
[Insert screenshot showing file selection dialog here]

### Settings and Theme Toggle
[Insert screenshot showing theme options and settings here]

That's all you need to know to get started! TranslationFiestaPy is a powerful tool for content quality evaluation through back-translation. Explore the advanced features as you become more comfortable with the basics.