Translation Fiesta — WinUI 3 edition

This is a WinUI 3 (Windows App SDK) version of Translation Fiesta. It uses WinUI controls and Fluent styles for a Windows 11 look, provides dark mode, and persistent user settings.

## Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable.
- Override data root with `TF_APP_HOME`.

Requirements
- Windows 10 (19041+) or Windows 11
- .NET SDK 10.0.100+ (`dotnet --version`)
- Visual Studio 2022 (17.10+) with **Windows application development** support
- Windows 10 SDK 10.0.19041.0+ (installed via Visual Studio Installer)

## Building and Running

### Method 1: Command Line Build (Recommended)
```powershell
# Clean stale outputs
if (Test-Path bin) { Remove-Item bin -Recurse -Force }
if (Test-Path obj) { Remove-Item obj -Recurse -Force }

# Restore + publish portable WinUI build
dotnet restore TranslationFiesta.WinUI.csproj -r win-x64 -p:Platform=x64
dotnet publish TranslationFiesta.WinUI.csproj -c Release -r win-x64 --no-restore --self-contained true `
  -p:Platform=x64 -p:RuntimeIdentifier=win-x64 `
  -p:UseXamlCompilerExecutable=true `
  -p:WindowsAppSDKSelfContained=true `
  -p:WindowsPackageType=None -p:AppxPackage=false -p:GenerateAppxPackageOnBuild=false `
  -o ..\dist\release\windows-x64\TranslationFiesta.WinUI

# Run the application
..\dist\release\windows-x64\TranslationFiesta.WinUI\TranslationFiesta.WinUI.exe
```

### Method 2: Using the Batch Script
```powershell
# Build all Windows x64 portable apps (includes WinUI)
pwsh -File ..\scripts\build_windows_x64_release.ps1

# Then run WinUI directly
..\dist\release\windows-x64\TranslationFiesta.WinUI\run.cmd
```

### Method 3: Visual Studio
- Open the solution in Visual Studio 2022/2023 with the "Windows App SDK" workload
- Build and run the WinUI project

**Important**: Always build with an explicit runtime (`win-x64` or `win-arm64`) and platform (`x64` or `arm64`).

## Common build failure fix (XAML compiler)

If you hit `MarkupCompilePass1` / `XamlCompiler.exe exited with code 1`:

```powershell
dotnet nuget locals all --clear
if (Test-Path bin) { Remove-Item bin -Recurse -Force }
if (Test-Path obj) { Remove-Item obj -Recurse -Force }
dotnet restore TranslationFiesta.WinUI.csproj -r win-x64 -p:Platform=x64
```

Then rebuild with the publish command above.
Avoid `-p:UseXamlCompilerExecutable=false`; that mode can throw `WMC9999` on current WinUI toolchains.

Distribution
- Portable release artifacts are produced by repo release workflows.
- No MSIX/installer packaging is maintained in this project.

Notes
- Theme resources (LightTheme.xaml, DarkTheme.xaml, Controls.xaml) are under `Themes/` and can be extended.
- The preview panel is a native read-only text pane (no WebView2 dependency at startup).
- For full Fluent visuals, further customization of ResourceDictionaries and use of WinUI brushes is recommended.
