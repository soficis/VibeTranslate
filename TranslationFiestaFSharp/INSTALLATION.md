# Installation Guide - F# TranslationFiesta

## Quick Start (Recommended)

### Option 1: Download Pre-built Executable
1. **Download** the latest `TranslationFiestaFSharp.exe` from the [Releases](../../releases) page
2. **Run** the executable directly - no installation required!
3. **First run** will create a log file (`fsharptranslate.log`) in the same directory

### Option 2: Build from Source
```powershell
# Clone the repository
git clone https://github.com/soficis/VibeTranslate.git
cd Vibes/TranslationFiestaFSharp

# Build and run
dotnet build
dotnet run
```

## System Requirements

### Minimum Requirements
- **Operating System**: Windows 10 (1809) or later
- **Architecture**: x64 (64-bit)
- **Memory**: 512 MB RAM
- **Storage**: 50 MB free space
- **Network**: Internet connection for translation services

### Recommended Requirements
- **Operating System**: Windows 11
- **Memory**: 2 GB RAM
- **Storage**: 200 MB free space (for logs and temporary files)
- **Network**: Stable broadband connection

## Installation Methods

### Method 1: Portable Executable (Recommended)
The provided `TranslationFiestaFSharp.exe` is a **self-contained executable** that includes all dependencies.

**Advantages:**
- ✅ No .NET installation required
- ✅ Single file deployment
- ✅ Works on any compatible Windows machine
- ✅ Easy to distribute and backup

**Installation Steps:**
1. Download `TranslationFiestaFSharp.exe`
2. Place it in your preferred directory (e.g., `C:\Tools\TranslationFiestaFSharp\`)
3. Double-click to run
4. Optional: Create desktop shortcut for easy access

### Method 2: Framework-Dependent (Smaller Size)
If you have .NET 9 runtime installed, you can use the smaller framework-dependent version.

**Prerequisites:**
- [.NET 9 Runtime](https://dotnet.microsoft.com/download/dotnet/9.0) (Windows Desktop Apps)

**Build Command:**
```powershell
dotnet publish -c Release -r win-x64 --self-contained false -o publish-framework
```

## Deployment Options

### Single User Installation
```
C:\Users\[Username]\AppData\Local\TranslationFiestaFSharp\
├── TranslationFiestaFSharp.exe
└── fsharptranslate.log (created on first run)
```

### System-wide Installation
```
C:\Program Files\TranslationFiestaFSharp\
├── TranslationFiestaFSharp.exe
└── fsharptranslate.log (created on first run)
```

### Portable Installation
```
[Any Directory]\TranslationFiestaFSharp\
├── TranslationFiestaFSharp.exe
├── fsharptranslate.log (created on first run)
└── README.md (optional)
```

## Configuration

### Default Settings
- **Translation API**: Unofficial Google Translate (free)
- **Language Path**: English → Japanese → English
- **Theme**: Light mode
- **Log Level**: All operations logged

### Optional: Google Cloud Translation API
1. **Get API Key**: Visit [Google Cloud Console](https://console.cloud.google.com/)
2. **Enable API**: Cloud Translation API
3. **Create Credentials**: API Key with Translation API access
4. **Configure in App**: Check "Use Official API" and enter your key

## Troubleshooting Installation

### Common Issues

#### "Windows protected your PC" Warning
**Cause**: Windows SmartScreen protecting against unsigned executables
**Solution**: 
1. Click "More info"
2. Click "Run anyway"
3. Alternative: Right-click → Properties → Unblock

#### Missing Visual C++ Redistributables
**Cause**: Some Windows installations lack required C++ runtime
**Solution**: Download [Microsoft Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)

#### Application Won't Start
**Diagnostics:**
1. Check Windows Event Viewer for error details
2. Ensure Windows 10 version 1809 or later
3. Verify x64 architecture compatibility
4. Try running as Administrator

#### Network Connection Issues
**Symptoms**: Translation failures, timeout errors
**Solutions:**
1. Check firewall settings
2. Verify internet connectivity
3. Try official Google Cloud API if unofficial API is blocked
4. Check corporate proxy settings

### Log File Analysis
The application creates `fsharptranslate.log` with detailed information:

```
[2024-01-15T10:30:45.123Z] INFO: F# TranslationFiesta started
[2024-01-15T10:30:50.456Z] DEBUG: UI enabled
[2024-01-15T10:31:00.789Z] INFO: Status: Translating to ja...
[2024-01-15T10:31:05.012Z] INFO: Official translation successful: 25 chars
```

## Uninstallation

### Portable Version
1. Delete `TranslationFiestaFSharp.exe`
2. Delete `fsharptranslate.log` (if desired)
3. Remove any shortcuts created

### Complete Cleanup
```powershell
# Remove all traces (optional)
Remove-Item -Path "C:\Users\$env:USERNAME\AppData\Local\TranslationFiestaFSharp" -Recurse -Force -ErrorAction SilentlyContinue
```

## Security Considerations

### Executable Safety
- **Source**: Built from open-source F# code
- **Dependencies**: Self-contained .NET 9 runtime
- **Network**: Only connects to Google Translate APIs
- **Data**: No personal data stored or transmitted beyond translation text

### API Key Security
- **Storage**: API keys are not persisted between sessions
- **Transmission**: Sent securely over HTTPS to Google Cloud
- **Recommendation**: Use API keys with restricted scope and IP limitations

## Performance Optimization

### Startup Performance
- **Cold Start**: ~2-3 seconds (first run)
- **Warm Start**: ~1-2 seconds (subsequent runs)
- **Optimization**: Place executable on SSD for faster loading

### Memory Usage
- **Idle**: ~30-50 MB
- **Active Translation**: ~80-120 MB
- **Peak**: ~150 MB during large text processing

### Network Optimization
- **Unofficial API**: Rate limited, may have delays
- **Official API**: Faster, more reliable, requires payment
- **Retry Logic**: Automatic retry with exponential backoff

## Advanced Configuration

### Command Line Options
The application currently runs as a GUI-only application. Future versions may support:
```powershell
# Planned features
TranslationFiestaFSharp.exe --theme=dark --api=official --key=your-api-key
```

### Environment Variables
```powershell
# Future configuration options
$env:FSHARP_TRANSLATE_THEME = "dark"
$env:FSHARP_TRANSLATE_API_KEY = "your-google-cloud-key"
```

## Support and Updates

### Getting Help
1. **Check Logs**: Review `fsharptranslate.log` for error details
2. **GitHub Issues**: Report bugs and request features
3. **Documentation**: Refer to README.md for usage instructions

### Update Process
1. **Download** new version from Releases page
2. **Replace** existing `TranslationFiestaFSharp.exe`
3. **Restart** application to use new version
4. **Backup** your API key if using official API

---

**Installation Complete!** 🎉

You're now ready to use F# TranslationFiesta for backtranslation testing. See [README.md](README.md) for usage instructions and features overview.
