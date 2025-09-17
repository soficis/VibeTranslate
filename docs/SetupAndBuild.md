# Setup and Build Guide

**Repository**: [https://github.com/soficis/VibeTranslate](https://github.com/soficis/VibeTranslate) - VibeTranslate

This guide provides comprehensive instructions for setting up, building, and running all TranslationFiesta applications in the repository.

## Prerequisites

### System Requirements

| Component | Requirement | Download Link |
|-----------|-------------|---------------|
| **Operating System** | Windows 10 1903+, Windows 11, macOS, Linux | N/A |
| **.NET SDK** | .NET 9 (recommended) or .NET 7+ | [Download .NET](https://dotnet.microsoft.com/download) |
| **Python** | Python 3.6+ (for Python version only) | [Download Python](https://python.org) |
| **Go** | Go 1.21+ (for Go version only) | [Download Go](https://golang.org/dl/) |
| **Flutter SDK** | Flutter 3.10+ (for Flutter version only) | [Install Flutter](https://flutter.dev/docs/get-started/install) |
| **Git** | Latest version | [Download Git](https://git-scm.com) |
| **Visual Studio** | 2022+ (optional, for WinUI development) | [Download VS](https://visualstudio.microsoft.com) |

### Development Tools Setup

#### 1. Install .NET 9 SDK
```powershell
# Download and install .NET 9 SDK
winget install Microsoft.DotNet.SDK.9
# OR download from: https://dotnet.microsoft.com/download/dotnet/9.0
```

#### 2. Verify .NET Installation
```powershell
# Check installed SDKs
dotnet --list-sdks

# Check installed runtimes
dotnet --list-runtimes

# Verify .NET 9
dotnet --version
```

#### 3. Install Python (for Python version)
```powershell
# Install Python 3.9+ via winget
winget install Python.Python.3.11

# Verify installation
python --version
pip --version
```

#### 4. Install Go (for Go version)
```powershell
# Download and install Go 1.21+ from:
# https://golang.org/dl/

# OR install via winget
winget install GoLang.Go

# Verify installation
go version

# Set GOPROXY for faster module downloads (optional)
go env -w GOPROXY=https://goproxy.cn,direct
```

#### 5. Install Flutter (for Flutter version)
```powershell
# Download and install Flutter SDK from:
# https://flutter.dev/docs/get-started/install/windows

# Verify installation
flutter doctor

# Enable Windows desktop development
flutter config --enable-windows-desktop
```

#### 6. Install Windows App SDK (for WinUI)
```powershell
# Install via winget
winget install Microsoft.WindowsAppSDK

# OR download from Visual Studio Installer
# Search for "Windows App SDK" workload
```

## Quick Start - All Applications

### Clone Repository
```powershell
git clone https://github.com/soficis/VibeTranslate.git
cd VibeTranslate
```

### Build All Projects
```powershell
# Build all .NET projects
foreach ($project in @("TranslationFiestaCSharp", "FSharpTranslationFiesta", "TranslationFiesta.WinUI")) {
    Write-Host "Building $project..."
    cd $project
    dotnet build -c Release
    cd ..
}

# Python setup
cd TranslationFiestaPy
pip install -r requirements.txt
```

### Run Applications
```powershell
# C# WinForms
cd TranslationFiestaCSharp
dotnet run

# F# (most feature-complete)
cd ..\FSharpTranslationFiesta
dotnet run

# WinUI (most modern)
cd ..\TranslationFiesta.WinUI
dotnet run

# Python
cd ..\TranslationFiestaPy
python TranslationFiesta.py
```

## Detailed Setup - By Application

## 🐍 TranslationFiestaPy (Python)

### Environment Setup
```bash
# Create virtual environment (recommended)
python -m venv venv
venv\Scripts\activate  # Windows
# OR
source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt
```

### Dependencies Explained
- **`tkinter`**: GUI framework (usually pre-installed)
- **`requests`**: HTTP client for Google Translate API
- **`beautifulsoup4`**: HTML parsing for file import

### Running
```bash
python TranslationFiesta.py
```

### Troubleshooting Python Issues
```bash
# Update pip
python -m pip install --upgrade pip

# Install missing tkinter (if needed)
# Windows: Usually pre-installed with Python
# Linux: sudo apt-get install python3-tk

# Clear pip cache
pip cache purge
```

## 🔷 TranslationFiestaCSharp (.NET WinForms)

### Build Configuration
```powershell
cd TranslationFiestaCSharp

# Debug build
dotnet build

# Release build
dotnet build -c Release

# Run
dotnet run
```

### Project Structure
```
TranslationFiestaCSharp/
├── Program.cs              # Main application
├── TranslationClient.cs    # API client
├── Logger.cs               # Logging utility
└── TranslationFiestaCSharp.csproj
```

### Dependencies
- **System.Windows.Forms**: Windows Forms UI
- **System.Net.Http**: HTTP client
- **System.Text.Json**: JSON processing

## ⚡ FSharpTranslationFiesta (F#)

### Build Configuration
```powershell
cd FSharpTranslationFiesta

# Restore dependencies
dotnet restore

# Build
dotnet build

# Run
dotnet run
```

### Project Structure
```
FSharpTranslationFiesta/
├── Program.fs              # Main application
├── Logger.fs               # Logging module
└── FSharpTranslationFiesta.fsproj
```

### Dependencies
- **FSharp.Core**: F# core library
- **System.Windows.Forms**: UI framework
- **System.Net.Http**: HTTP client

## 🎭 TranslationFiesta.WinUI (WinUI 3) *(Untested Implementation)*

> **⚠️ Important Note**: This WinUI implementation is currently untested and may require additional setup. The Windows App SDK workload must be properly installed through Visual Studio Installer for the project to build successfully.

### Prerequisites Check
```powershell
# Verify Windows App SDK
Get-AppxPackage | Where-Object {$_.Name -like "*WindowsAppSDK*"}

# Check Windows version
winver  # Must be Windows 10 1903+ or Windows 11
```

### Build Configuration
```powershell
cd TranslationFiesta.WinUI

# Restore packages
dotnet restore

# Build
dotnet build

# Run
dotnet run
```

### MSIX Packaging
```powershell
# Build Release version
dotnet build -c Release

# Package as MSIX
.\tools\package-winui-msix.ps1 `
    -AppExecutablePath "bin\Release\net9.0-windows10.0.19041.0\win10-x64\TranslationFiesta.WinUI.exe" `
    -OutputMsix "TranslationFiesta.msix"
```

### Project Structure
```
TranslationFiesta.WinUI/
├── App.xaml
├── MainWindow.xaml
├── Themes/                 # Theme resources
├── SecureStore.cs          # DPAPI storage
├── SettingsService.cs      # Persistent settings
└── ThemeService.cs         # Theme management
```

## Advanced Build Options

### Publishing for Distribution

#### Self-Contained Executables
```powershell
# Python (using PyInstaller)
cd TranslationFiestaPy
pip install pyinstaller
pyinstaller --onefile --windowed TranslationFiesta.py

# .NET (all projects)
cd [ProjectName]
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

#### Framework-Dependent Publishing
```powershell
# Smaller size, requires .NET runtime on target machine
dotnet publish -c Release -r win-x64 --self-contained false
```

### Build Optimization

#### Release Configuration
```xml
<!-- Add to .csproj files for optimization -->
<PropertyGroup Condition="'$(Configuration)'=='Release'">
  <Optimize>true</Optimize>
  <DebugType>none</DebugType>
  <DebugSymbols>false</DebugSymbols>
</PropertyGroup>
```

#### IL Trimming (.NET 6+)
```xml
<!-- Reduces executable size -->
<PropertyGroup>
  <PublishTrimmed>true</PublishTrimmed>
  <TrimMode>link</TrimMode>
</PropertyGroup>
```

## Development Environment Setup

### Visual Studio Code
```json
// .vscode/settings.json
{
    "dotnet.defaultSolution": "TranslationFiesta.WinUI.sln",
    "csharp.format.enable": true,
    "fsharp.suggestGitignore": true,
    "python.pythonPath": "venv\\Scripts\\python.exe"
}
```

### Visual Studio 2022
- Install workloads:
  - **.NET desktop development**
  - **Windows App SDK**
  - **F# language support**
- Open solution files:
  - `TranslationFiesta.WinUI.sln`

### Environment Variables
```powershell
# Set .NET environment
$env:DOTNET_CLI_TELEMETRY_OPTOUT=1
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

# Python environment
$env:PYTHONPATH="$env:PYTHONPATH;[YourProjectPath]"
```

## Testing Setup

### Unit Testing
```powershell
# .NET projects
dotnet test

# Python
pip install pytest
pytest
```

### Integration Testing
```powershell
# Test all builds
foreach ($project in @("TranslationFiestaCSharp", "FSharpTranslationFiesta", "TranslationFiesta.WinUI")) {
    cd $project
    dotnet build -c Release
    Write-Host "$project build: SUCCESS"
    cd ..
}
```

## Deployment Strategies

### Portable Applications
```powershell
# Create portable .NET apps
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishTrimmed=true
```

### MSIX Packages (WinUI)
```powershell
# Automated packaging
.\tools\package-winui-msix.ps1 -AppExecutablePath "path\to\exe" -OutputMsix "output.msix"
```

### CI/CD Pipeline Example
```yaml
# .github/workflows/build.yml
name: Build All Projects
on: [push, pull_request]

jobs:
  build:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: '9.0.x'
    - name: Build .NET Projects
      run: |
        foreach ($project in @("TranslationFiestaCSharp", "FSharpTranslationFiesta", "TranslationFiesta.WinUI")) {
          cd $project
          dotnet build -c Release
          cd ..
        }
```

## 🦀 TranslationFiestaGo (Go)

### Build Configuration
```powershell
cd TranslationFiestaGo

# Download dependencies
go mod tidy

# Build CLI version (recommended)
go build -o translationfiestago-cli.exe cmd/cli/main.go

# Build GUI version (may have OpenGL issues on Windows)
go build -tags=software -o translationfiestago.exe main.go

# Run CLI version
.\translationfiestago-cli.exe
```

### Project Structure
```
TranslationFiestaGo/
├── cmd/cli/main.go          # CLI application
├── main.go                  # GUI application
├── internal/
│   ├── domain/             # Business logic
│   ├── data/               # Data implementations
│   ├── gui/                # GUI components
│   └── utils/              # Shared utilities
├── go.mod
├── go.sum
└── README.md
```

### Dependencies
- **fyne.io/fyne/v2**: GUI framework (optional)
- **github.com/go-resty/resty/v2**: HTTP client
- **golang.org/x/net/html**: HTML parsing

### Go-Specific Issues
```bash
# If GUI build fails on Windows
CGO_ENABLED=0 go build cmd/cli/main.go

# Update dependencies
go get -u all
go mod tidy

# Clean module cache
go clean -modcache
```

## 💎 TranslationFiestaRuby (Ruby) *(Experimental Implementation)*

> **⚠️ Important Note**: This Ruby implementation is currently experimental and untested. It provides feature parity with other ports but may require additional setup for native gem compilation on Windows.

### Prerequisites

#### Ruby Installation (Windows)
```powershell
# Option 1: RubyInstaller with DevKit (Recommended)
# Download from: https://rubyinstaller.org/
# Choose Ruby+Devkit version (e.g., Ruby 3.4.x with DevKit)

# After installation, run:
ridk install  # Install MSYS2 and MINGW toolchains
ridk enable   # Enable toolchains for gem compilation

# Option 2: MSYS2 (Advanced)
# Download from: https://www.msys2.org/
# Install and update:
pacman -Syu
pacman -S mingw-w64-x86_64-ruby
pacman -S mingw-w64-x86_64-gcc  # For native compilation
```

#### Verify Ruby Installation
```powershell
# Check Ruby version
ruby -v

# Check Gem version
gem -v

# Check Bundler
bundle -v

# Verify DevKit (RubyInstaller)
gcc --version  # Should show MinGW GCC
make --version # Should show GNU Make
```

### Build Configuration
```powershell
cd TranslationFiestaRuby

# Install dependencies
bundle install

# Setup database
rake setup_db

# Run web UI (recommended)
rake web

# Run CLI
rake cli translate "Hello world"

# Run in mock mode (no API keys needed)
TF_USE_MOCK=1 rake web
```

### Project Structure
```
TranslationFiestaRuby/
├── lib/translation_fiesta/
│   ├── domain/             # Business logic
│   ├── use_cases/         # Application orchestration
│   ├── data/              # Data implementations
│   ├── features/          # Feature modules
│   ├── infrastructure/    # Cross-cutting concerns
│   ├── web/               # Sinatra web UI
│   └── gui/               # Legacy Tk GUI (deprecated)
├── bin/translation_fiesta # Executable
├── spec/                  # RSpec tests
├── Rakefile               # Build tasks
├── Gemfile                # Dependencies
└── README.md
```

### Dependencies
- **sinatra**: Web framework (replaces Tk GUI)
- **nokogiri**: HTML/XML parsing (requires native compilation)
- **sqlite3**: Database (requires native compilation)
- **prawn**: PDF generation
- **google-cloud-translate-v2**: Official Google Translate API
- **easy_translate**: Unofficial Google Translate API

### Windows-Specific Setup

#### Native Gem Compilation Issues
```powershell
# If bundle install fails with native gems:
# 1. Ensure DevKit is properly installed
ridk install
ridk enable

# 2. Set environment variables for compilation
$env:MAKE = "make"
$env:CC = "gcc"
$env:CXX = "g++"

# 3. Install problematic gems individually
gem install nokogiri --platform=ruby
gem install sqlite3 --platform=ruby

# 4. Alternative: Use precompiled binaries
# Edit Gemfile to pin specific versions:
# gem 'nokogiri', '1.18.10-x64-mingw-ucrt'
# gem 'sqlite3', '1.7.3-x64-mingw-ucrt'

# 5. Clean and retry
bundle clean --force
bundle install
```

#### MSYS2 Toolchain Setup
```bash
# If using MSYS2, ensure proper PATH
# Add to PATH: C:\msys64\mingw64\bin
# Add to PATH: C:\msys64\usr\bin

# Update MSYS2 packages
pacman -Syu
pacman -S mingw-w64-x86_64-gcc
pacman -S mingw-w64-x86_64-make
pacman -S mingw-w64-x86_64-sqlite3
pacman -S mingw-w64-x86_64-libxml2  # For nokogiri
```

#### Troubleshooting Ruby Issues
```powershell
# Check Ruby environment
ruby -e "puts RUBY_PLATFORM"

# Verify gem installation
gem list nokogiri
gem list sqlite3

# Clear gem cache
gem cleanup

# Reinstall bundler
gem uninstall bundler
gem install bundler

# Check for conflicting installations
where.exe ruby
where.exe gem
where.exe bundle
```

### Environment Variables
```powershell
# Web server configuration
$env:TF_WEB_BIND = "127.0.0.1"
$env:TF_WEB_PORT = "4567"

# Mock mode (no API keys required)
$env:TF_USE_MOCK = "1"

# API token for web UI (optional)
$env:TF_API_TOKEN = "your-secret-token"

# Rate limiting (requests per minute)
$env:TF_RATE_LIMIT = "60"

# Export directory
$env:TF_EXPORT_DIR = "exports"
```

### Running Applications
```powershell
# Web UI (Sinatra)
rake web

# Web UI with browser launch
rake web:open

# CLI mode
rake cli translate "Hello world"

# Setup database
rake setup_db

# Run tests
rake spec
```

### Ruby-Specific Issues
```bash
# If Sinatra fails to start
gem install sinatra
gem install rack

# If database issues
rake setup_db

# If mock mode not working
TF_USE_MOCK=1 rake web

# Clear all caches
bundle clean --force
gem cleanup
```

## Troubleshooting

### Common Build Issues

#### .NET SDK Issues
```powershell
# Clear NuGet cache
dotnet nuget locals all --clear

# Restore packages
dotnet restore --force

# Clean and rebuild
dotnet clean
dotnet build
```

#### Python Issues
```bash
# Virtual environment issues
rm -rf venv
python -m venv venv
source venv/Scripts/activate
pip install -r requirements.txt
```

#### WinUI Issues
```powershell
# Repair Windows App SDK
winget repair Microsoft.WindowsAppSDK

# Check Windows version compatibility
winver
```

#### Go Issues
```bash
# Check Go installation
go version

# Check module status
go mod verify

# Clear Go cache
go clean -cache
go clean -testcache

# GUI build issues on Windows
go env -w CGO_ENABLED=0
```

### Performance Optimization

#### Build Performance
```powershell
# Use incremental builds
dotnet build --no-restore

# Parallel builds
dotnet build -m:4  # Use 4 cores
```

#### Runtime Optimization
```xml
<!-- Add to project files -->
<PropertyGroup>
  <TieredCompilation>true</TieredCompilation>
  <ReadyToRun>true</ReadyToRun>
</PropertyGroup>
```

## Getting Help

### Debug Information
```powershell
# .NET version info
dotnet --info

# Python version info
python --version
pip list

# Go version info
go version
go env

# Windows version
winver
systeminfo | findstr /B /C:"OS"
```

### Log Files
- **.NET Apps**: Check application directory for `.log` files
- **Python App**: `translationfiesta.log`
- **Go App**: `translationfiestago.log` (platform-specific location)
- **WinUI App**: `%LOCALAPPDATA%\Packages\[AppId]\Temp\`

### Community Support
- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share experiences
- **Documentation**: Check individual app README files

## Next Steps

After setup, you can:
1. **Run applications** and test basic functionality
2. **Explore the code** to understand different implementations
3. **Contribute features** by following the contributing guidelines
4. **Customize applications** for your specific needs
5. **Deploy applications** using the publishing instructions above

For detailed usage instructions, see the individual application documentation in the `docs/` folder.
