# Beginner's Guide to TranslationFiestaFlutter (Dart)

Welcome to TranslationFiestaFlutter! This guide will help you get started with the modern, cross-platform implementation of the TranslationFiesta application. Built with Flutter and Dart, it provides beautiful Material Design interfaces across desktop and mobile platforms.

## 1. Installation and Setup

Before running FlutterTranslate, ensure you have the Flutter development environment properly configured. This is the most modern and cross-platform version of the application.

### Prerequisites
- **Flutter 3.0 or later**: Download and install Flutter SDK from flutter.dev. Verify with `flutter --version`
- **Dart 3.0 or later**: Usually comes with Flutter, verify with `dart --version`
- **Platform-specific requirements**:
  - **Windows**: Visual Studio 2019/2022 with C++ build tools OR Visual Studio Build Tools
  - **macOS**: Xcode 13 or later (for iOS/mobile development)
  - **Linux**: GCC compiler and required libraries
- **Internet connection**: For Google Translate APIs and package downloads
- **Optional: Google Cloud Translation API key**: For official (paid) API usage

### Installing Dependencies
1. **Navigate to the TranslationFiestaFlutter directory**:
   ```
   cd TranslationFiestaFlutter
   ```

2. **Get Flutter packages**:
   ```
   flutter pub get
   ```
   This downloads all dependencies from pub.dev, including core Flutter packages, HTTP client, EPUB processing libraries, and secure storage plugins.

3. **Verify setup**:
   ```
   flutter doctor
   ```
   This checks your Flutter installation and reports any issues.

### API Key Setup
Choose your translation API:
- **Unofficial API** (default): Free, no setup needed
- **Official Google Cloud API**: More reliable, requires setup

For official API:
1. Get a key from Google Cloud Console
2. Start the app (explained below)
3. Configure the API key in the app settings
4. The key is securely stored using platform-specific secure storage (flutter_secure_storage)

## 2. Step-by-Step Guide to Running the Application

### Development Mode (Recommended for First Time)
1. **Run in development mode**:
   ```
   flutter run
   ```

2. **Select platform** (if prompted): Choose from:
   - Android emulator/device
   - iOS simulator
   - Windows desktop
   - macOS desktop
   - Linux desktop
   - Web browser
   
   For first-time desktop users, you can specify directly:
   ```
   flutter run -d windows  # For Windows
   flutter run -d linux   # For Linux
   ```

3. **Wait for compilation**: Flutter builds native code, which may take 1-2 minutes first time
4. **Hot reload**: Make code changes while running - they'll appear instantly!

### Building for Distribution
For production use, build standalone executables:

**Desktop builds:**
```
flutter build windows --release    # Windows executable
flutter build linux --release      # Linux binary
flutter build macos --release      # macOS app
```

**Mobile builds:**
```
flutter build apk --release        # Android APK
flutter build ios --release        # iOS app (requires Xcode)
```

**Web build:**
```
flutter build web --release        # Web deployment
```

Run the built executable directly for desktop platforms.

## 3. Basic Usage Examples

### Simple Translation
1. **Launch the app**: Use `flutter run` or the built executable
2. **Enter text**: Type English text in the large input area
3. **Select API**: Toggle between unofficial/official API in settings
4. **Translate**: Tap the "Translate" button
5. **View results**:
   - **Japanese intermediate**: See the translation
   - **English back-translation**: Final result
   - **Character count**: Visual badges showing text lengths
6. **Save or share**: Use built-in export options

### File Processing
1. **Load from device**: Tap "Choose File" button
2. **Select file type**: Supports .txt, .md, .html
3. **Auto-preview**: Content loads into the input area
4. **Translate**: Proceed as usual

### Theme Switching ("Surrealist" Mode)
- Unique to this Flutter version: Try the "Surrealist" theme!
- **Normal Theme**: Material Design 3 with dark/light modes
- **Surrealist Theme**: Artistic, unique UI with custom styling
- Automatic: Follows system themes on most platforms

### Mobile Experience
On mobile devices:
- **Touch-friendly**: Large buttons and input areas
- **Swipe gestures**: Navigate between sections
- **Orientation support**: Works in portrait/landscape
- **Platform conventions**: Feels native on iOS/Android

## 4. Basic Usage Examples for Key Advanced Features

### EPUB Processing
Handle eBook files directly:
1. Tap "Choose File" and select a .epub file
2. Preview chapters in the EPUB panel
3. Select specific chapters for translation
4. Translate chapter by chapter or choose multiple
5. Extract text content automatically from EPUB format

### BLEU Scoring
Evaluate translation quality:
1. After back-translation, BLEU score appears
2. Higher scores (closer to 1.0) indicate better quality
3. Use to compare translations or track improvement

### Cost Tracking
Monitor API usage (basic implementation):
1. View cost information in the app interface
2. Track usage patterns and estimates
3. Set simple budget alerts

### Secure Storage
Your API keys are protected:
- Uses flutter_secure_storage for platform-specific encryption
- Automatic secure storage across sessions
- Works consistently across Windows, macOS, Linux, Android, iOS

### Cross-Platform Consistency
The app provides identical functionality across:
- **Desktop**: Native file dialogs, window management, system integration
- **Mobile**: Touch-optimized controls, platform-specific features
- **Web**: Same features in browser environment

## 5. Troubleshooting Tips

### Common Issues

**"flutter doctor" shows issues**
- **Solution**: Follow the specific recommendations from `flutter doctor`
- **Common fixes**: Install missing Android Studio/SDK, Xcode, or desktop dependencies

**Build fails on mobile**
- **Android**: Ensure Android SDK is installed and `ANDROID_HOME` is set
- **iOS**: Requires macOS and Xcode; check developer provisioning
- **USB debugging**: Enable on device for physical Android testing

**App won't start**
- **Clear cache**: `flutter clean` then `flutter run`
- **Dependencies**: `flutter pub get` again
- **Platform sync**: `flutter config` to reconfigure platforms

**Translation errors**
- **Network**: Check internet connection
- **API limits**: Try switching API modes or wait if rate-limited
- **Key issues**: For official API, verify your Google Cloud key

**File loading problems**
- **Permissions**: Grant storage/file access permissions
- **Formats**: Ensure .txt, .md, .html, .epub files
- **Size limits**: Very large files may need special handling

**Theme/surrealist mode issues**
- **Platform**: Some features may vary by platform
- **Reset**: Try normal theme to troubleshoot
- **Updates**: Occasionally restart for theme changes

**Performance slow**
- **Development mode**: Use `--release` builds for best performance
- **Device**: Older devices may need simpler themes
- **Background**: Close other apps during translation operations

### Platform-Specific Help

**Windows Desktop:**
- Ensure Visual C++ Build Tools are installed
- Try running as administrator if file access issues

**Linux Desktop:**
- Install GTK development packages
- Check for necessary graphics libraries

**macOS Desktop:**
- Xcode command-line tools must be installed
- May require additional permissions for file access

**Mobile Platforms:**
- **Android**: Enable "Install unknown apps" and developer options
- **iOS**: Requires Apple Developer Program for physical device testing

### Getting Help
- **Flutter doctor**: Run regularly to identify issues
- **Logs**: Check console output and device logs
- **Community**: Search Flutter/Dart communities for similar issues
- **Documentation**: Flutter.dev has extensive troubleshooting guides

## 6. Screenshots

### Main Application Interface (Material Design 3)
[Insert screenshot showing the main screen with input field, translate button, and results display in Material Design]

### Surrealist Theme Display
[Insert screenshot demonstrating the unique "surrealist" UI theme with artistic styling and custom widgets]

### EPUB Chapter Selection
[Insert screenshot of the EPUB processing interface showing chapter list and preview pane]

### Mobile Interface (Android)
[Insert screenshot showing the touch-optimized mobile layout with appropriate styling]

### Platform Comparison
[Insert comparison screenshots showing the app running on Windows desktop, Android mobile, and web browser]

### File Selection and Processing
[Insert screenshot of the file picker dialog and processing screen]

### Settings Panel
[Insert screenshot showing settings for API configuration, theme selection, and preferences]

This Flutter implementation showcases modern cross-platform development with beautiful UI and robust architecture. It demonstrates how Flutter can deliver native-quality experiences on multiple platforms from a single codebase. Whether you're on Windows, Linux, macOS, Android, iOS, or web, TranslationFiestaFlutter provides a consistent, polished experience!