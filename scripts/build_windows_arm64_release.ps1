<#
.SYNOPSIS
  Builds the VibeTranslate portable release bundle for Windows ARM64.

.DESCRIPTION
  Builds every port that supports native ARM64 by default:
    C#, F#, WinUI, Electron, Flutter, Go/Wails

  With -IncludeX64Emulated, also builds ports whose native-extension
  dependencies lack ARM64 wheels (Python, Ruby) as x64 binaries that
  run under Windows' built-in x64 emulation layer.

.PARAMETER IncludeX64Emulated
  Also build Python and Ruby ports as x64 binaries for emulation on ARM64.

.PARAMETER PythonX64Path
  Explicit path to an x64 Python interpreter (e.g. C:\Python312\python.exe).
  Only used when -IncludeX64Emulated is set.  Falls back to auto-detection.

.PARAMETER RubyX64Prefix
  Explicit path to the x64 Ruby installation prefix (e.g. C:\Ruby34-x64).
  Only used when -IncludeX64Emulated is set.  Falls back to auto-detection.
#>
param(
  [switch]$IncludeX64Emulated,
  [string]$PythonX64Path = '',
  [string]$RubyX64Prefix = ''
)

$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
Set-Location $repoRoot

$root = Join-Path $repoRoot "dist\release\windows-arm64"

# ---------------------------------------------------------------------------
# Helpers (shared with x64 build script)
# ---------------------------------------------------------------------------

function Stop-ProcessesRunningFromPath([string]$pathPrefix) {
  $fullPrefix = [System.IO.Path]::GetFullPath($pathPrefix).TrimEnd('\')
  $candidates = @()
  foreach ($process in (Get-Process -ErrorAction SilentlyContinue)) {
    try {
      if ($process.Path -and $process.Path.StartsWith($fullPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $candidates += $process
      }
    } catch {
      # Ignore processes that do not expose a readable Path.
    }
  }

  foreach ($process in $candidates) {
    try {
      Write-Host "Stopping process locking release folder: $($process.ProcessName) (PID $($process.Id))"
      Stop-Process -Id $process.Id -Force -ErrorAction Stop
    } catch {
      Write-Warning "Could not stop process PID $($process.Id): $($_.Exception.Message)"
    }
  }
}

function Remove-DirectoryWithRetries([string]$targetPath, [int]$maxAttempts = 3) {
  if (!(Test-Path $targetPath)) {
    return
  }

  for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
      Get-ChildItem -LiteralPath $targetPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.IsReadOnly = $false } catch {}
      }

      Remove-Item -LiteralPath $targetPath -Recurse -Force -ErrorAction Stop
      return
    } catch {
      if ($attempt -eq 1) {
        Stop-ProcessesRunningFromPath $targetPath
      }

      if ($attempt -lt $maxAttempts) {
        Write-Warning "Failed to delete '$targetPath' (attempt $attempt/$maxAttempts): $($_.Exception.Message). Retrying..."
        Start-Sleep -Seconds 1
        continue
      }

      throw "Failed to clean release directory '$targetPath'. Close any running binaries from that folder and retry."
    }
  }
}

# ---------------------------------------------------------------------------
# x64 tool-chain resolution helpers (used by -IncludeX64Emulated)
# ---------------------------------------------------------------------------

function Find-PythonX64 {
  # Honour explicit parameter / environment variable.
  if (![string]::IsNullOrWhiteSpace($PythonX64Path)) {
    if (Test-Path $PythonX64Path) { return $PythonX64Path }
    throw "Specified PythonX64Path not found: $PythonX64Path"
  }
  if (![string]::IsNullOrWhiteSpace($env:PYTHON_X64)) {
    if (Test-Path $env:PYTHON_X64) { return $env:PYTHON_X64 }
    throw "PYTHON_X64 env var path not found: $env:PYTHON_X64"
  }

  # Auto-detect common x64 install locations.
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
    "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe"
    "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
    "C:\Python312\python.exe"
    "C:\Python313\python.exe"
    "C:\Python314\python.exe"
    "C:\Python312-x64\python.exe"
    "C:\Python313-x64\python.exe"
  )

  foreach ($path in $candidates) {
    if (Test-Path $path) {
      # Verify it is actually x64 (not ARM64).
      $peHeader = [System.IO.File]::ReadAllBytes($path)
      $peOffset = [System.BitConverter]::ToInt32($peHeader, 0x3C)
      $machine  = [System.BitConverter]::ToUInt16($peHeader, $peOffset + 4)
      if ($machine -eq 0x8664) {  # IMAGE_FILE_MACHINE_AMD64
        return $path
      }
    }
  }

  return $null
}

function Find-RubyX64Prefix {
  if (![string]::IsNullOrWhiteSpace($RubyX64Prefix)) {
    if (Test-Path $RubyX64Prefix) { return $RubyX64Prefix }
    throw "Specified RubyX64Prefix not found: $RubyX64Prefix"
  }
  if (![string]::IsNullOrWhiteSpace($env:RUBY_X64_PREFIX)) {
    if (Test-Path $env:RUBY_X64_PREFIX) { return $env:RUBY_X64_PREFIX }
    throw "RUBY_X64_PREFIX env var path not found: $env:RUBY_X64_PREFIX"
  }

  # Common RubyInstaller x64 paths.
  $candidates = @(
    "C:\Ruby34-x64"
    "C:\Ruby33-x64"
    "C:\Ruby32-x64"
  )

  foreach ($path in $candidates) {
    $rubyExe = Join-Path $path "bin\ruby.exe"
    if (Test-Path $rubyExe) {
      return $path
    }
  }

  return $null
}

# ---------------------------------------------------------------------------
# Clean & prepare output directory
# ---------------------------------------------------------------------------

Remove-DirectoryWithRetries $root
New-Item -ItemType Directory -Force -Path $root | Out-Null

Write-Host "Building TranslationFiesta Windows ARM64 release bundle from: $repoRoot"
Write-Host "Output: $root"

# ---------------------------------------------------------------------------
# SDK version checks
# ---------------------------------------------------------------------------

# Try to find dotnet if not in PATH (common after fresh install)
if (!(Get-Command dotnet -ErrorAction SilentlyContinue)) {
    $commonDotnetPath = "C:\Program Files\dotnet"
    if (Test-Path (Join-Path $commonDotnetPath "dotnet.exe")) {
        $env:PATH = "$commonDotnetPath;$env:PATH"
    }
}

try {
    $dotnetVersion = (& dotnet --version).Trim()
    if (-not $dotnetVersion.StartsWith("10.")) {
        throw "This build requires .NET SDK 10.x. Current SDK: $dotnetVersion"
    }
} catch {
    throw "The 'dotnet' command was not found. Please run scripts\install_windows_arm64_sdks.ps1 first and ensure you have restarted your terminal."
}

# ===================================================================
#  ARM64 NATIVE PORTS
# ===================================================================

# --- C# ---
Write-Host "`n=== Building TranslationFiestaCSharp (ARM64) ===`n"
dotnet publish TranslationFiestaCSharp/TranslationFiestaCSharp.csproj `
  -c Release -r win-arm64 --self-contained true `
  -o "$root\TranslationFiestaCSharp"

# --- F# ---
Write-Host "`n=== Building TranslationFiestaFSharp (ARM64) ===`n"
dotnet publish TranslationFiestaFSharp/TranslationFiestaFSharp.fsproj `
  -c Release -r win-arm64 --self-contained true `
  -o "$root\TranslationFiestaFSharp"

# --- WinUI ---
Write-Host "`n=== Building TranslationFiesta.WinUI (ARM64) ===`n"
Remove-DirectoryWithRetries (Join-Path $repoRoot "TranslationFiesta.WinUI\obj")
Remove-DirectoryWithRetries (Join-Path $repoRoot "TranslationFiesta.WinUI\bin")
dotnet restore TranslationFiesta.WinUI/TranslationFiesta.WinUI.csproj -r win-arm64 -p:Platform=arm64
dotnet publish TranslationFiesta.WinUI/TranslationFiesta.WinUI.csproj `
  -c Release -r win-arm64 --no-restore --self-contained true `
  -p:Platform=arm64 -p:RuntimeIdentifier=win-arm64 `
  -p:UseXamlCompilerExecutable=true `
  -p:WindowsAppSDKSelfContained=true `
  -p:WindowsPackageType=None -p:AppxPackage=false -p:GenerateAppxPackageOnBuild=false `
  -o "$root\TranslationFiesta.WinUI"

# --- Electron ---
Write-Host "`n=== Building TranslationFiestaElectron (ARM64) ===`n"
Push-Location TranslationFiestaElectron
npm ci
npm run build
npx electron-packager . TranslationFiestaElectron --platform=win32 --arch=arm64 --out "$root\TranslationFiestaElectron" --overwrite --prune=true
Pop-Location

# --- Flutter ---
Write-Host "`n=== Building TranslationFiestaFlutter (ARM64) ===`n"
flutter config --enable-windows-desktop
Remove-DirectoryWithRetries (Join-Path $repoRoot "TranslationFiestaFlutter\build\windows")
Push-Location TranslationFiestaFlutter
flutter clean
flutter pub get
flutter build windows --release
Pop-Location

$flutterBuildDir = Join-Path $repoRoot "TranslationFiestaFlutter\build\windows\arm64\runner\Release"
if (!(Test-Path $flutterBuildDir)) {
  # Fallback: some Flutter versions omit the arch sub-directory on the native host.
  $flutterBuildDir = Join-Path $repoRoot "TranslationFiestaFlutter\build\windows\runner\Release"
}
if (!(Test-Path $flutterBuildDir)) {
  throw "Flutter build output not found.  Ensure this script is running on an ARM64 host with the ARM64 Flutter SDK."
}

New-Item -ItemType Directory -Force -Path "$root\TranslationFiestaFlutter" | Out-Null
Copy-Item "$flutterBuildDir\*" "$root\TranslationFiestaFlutter" -Recurse -Force

# --- Go (Wails) ---
Write-Host "`n=== Building TranslationFiestaGo (ARM64) ===`n"
Push-Location TranslationFiestaGo
go run github.com/wailsapp/wails/v2/cmd/wails@v2.11.0 build -platform windows/arm64 -clean -o TranslationFiestaGo
Pop-Location

New-Item -ItemType Directory -Force -Path "$root\TranslationFiestaGo" | Out-Null
$goBuildRoot = Join-Path $repoRoot "TranslationFiestaGo\build\bin"
if (!(Test-Path $goBuildRoot)) {
  throw "Go build output directory not found: $goBuildRoot"
}

Copy-Item (Join-Path $goBuildRoot "*") "$root\TranslationFiestaGo" -Recurse -Force

$goExePath = Join-Path "$root\TranslationFiestaGo" "TranslationFiestaGo.exe"
if (!(Test-Path $goExePath)) {
  $goNoExtPath = Join-Path "$root\TranslationFiestaGo" "TranslationFiestaGo"
  if (Test-Path $goNoExtPath) {
    Copy-Item $goNoExtPath $goExePath -Force
  } else {
    throw "Go build output not found. Expected TranslationFiestaGo(.exe) in $goBuildRoot."
  }
}

# ===================================================================
#  X64 EMULATED PORTS (opt-in via -IncludeX64Emulated)
# ===================================================================

if ($IncludeX64Emulated) {
  Write-Host "`n=== Building x64-emulated ports (Python, Ruby) ===`n"

  # ---------------------------------------------------------------
  # Python (x64 emulated)
  # ---------------------------------------------------------------
  Write-Host "`n--- TranslationFiestaPy (x64 emulated) ---`n"
  $pythonExe = Find-PythonX64
  if ([string]::IsNullOrWhiteSpace($pythonExe)) {
    throw @"
x64 Python interpreter not found.  Install x64 Python 3.12+ or set one of:
  -PythonX64Path <path>    (parameter)
  `$env:PYTHON_X64          (environment variable)
Run scripts\install_windows_arm64_sdks.ps1 -IncludeX64Runtimes to install it.
"@
  }

  Write-Host "Using x64 Python: $pythonExe"

  & $pythonExe -m pip install --upgrade pip
  & $pythonExe -m pip install -r TranslationFiestaPy/requirements.lock
  & $pythonExe -m pip install pyinstaller

  $pythonOutRoot = Join-Path $repoRoot "TranslationFiestaPy\out"
  Remove-DirectoryWithRetries $pythonOutRoot
  New-Item -ItemType Directory -Force -Path $pythonOutRoot | Out-Null

  Push-Location TranslationFiestaPy
  & $pythonExe -m PyInstaller --noconfirm --clean --windowed --onedir `
    --name TranslationFiestaPy `
    --collect-submodules tkinterweb --collect-data tkinterweb `
    --collect-submodules tkinterweb_tkhtml --collect-data tkinterweb_tkhtml `
    --distpath "$pythonOutRoot\dist" --workpath "$pythonOutRoot\build" --specpath "$pythonOutRoot\spec" `
    TranslationFiesta.py
  Pop-Location

  New-Item -ItemType Directory -Force -Path "$root\TranslationFiestaPy" | Out-Null
  Copy-Item "$pythonOutRoot\dist\TranslationFiestaPy\*" "$root\TranslationFiestaPy" -Recurse -Force

  # ---------------------------------------------------------------
  # Ruby (x64 emulated)
  # ---------------------------------------------------------------
  Write-Host "`n--- TranslationFiestaRuby (x64 emulated) ---`n"
  $rubyPrefix = Find-RubyX64Prefix
  if ([string]::IsNullOrWhiteSpace($rubyPrefix)) {
    throw @"
x64 Ruby installation not found.  Install RubyInstaller x64 3.4+ or set one of:
  -RubyX64Prefix <path>    (parameter)
  `$env:RUBY_X64_PREFIX      (environment variable)
Run scripts\install_windows_arm64_sdks.ps1 -IncludeX64Runtimes to install it.
"@
  }

  $rubyBin = Join-Path $rubyPrefix "bin"
  $rubyExe = Join-Path $rubyBin "ruby.exe"
  $gemExe  = Join-Path $rubyBin "gem.bat"
  $bundleExe = Join-Path $rubyBin "bundle.bat"

  if (!(Test-Path $rubyExe)) {
    throw "x64 Ruby executable not found at: $rubyExe"
  }

  Write-Host "Using x64 Ruby prefix: $rubyPrefix"

  # Temporarily prepend x64 Ruby to PATH for gem/bundle commands.
  $savedPath = $env:PATH
  $env:PATH = "$rubyBin;$env:PATH"

  try {
    Push-Location TranslationFiestaRuby
    & $gemExe install rake --no-document
    $env:BUNDLE_PATH = "vendor/bundle"
    $env:BUNDLE_DEPLOYMENT = "false"
    $env:BUNDLE_FROZEN = "false"
    & $bundleExe install --jobs 4 --retry 3
    Remove-Item Env:BUNDLE_PATH, Env:BUNDLE_DEPLOYMENT, Env:BUNDLE_FROZEN -ErrorAction SilentlyContinue
    Pop-Location
  } finally {
    $env:PATH = $savedPath
  }

  $rubyTarget = "$root\TranslationFiestaRuby"
  New-Item -ItemType Directory -Force -Path $rubyTarget | Out-Null

  $pathsToCopy = @('Gemfile', 'Gemfile.lock', 'translation_fiesta.gemspec', 'bin', 'lib', 'config', 'vendor')
  foreach ($path in $pathsToCopy) {
    Copy-Item (Join-Path $repoRoot "TranslationFiestaRuby\$path") (Join-Path $rubyTarget $path) -Recurse -Force
  }

  $rubyPrefixPath = $rubyPrefix -replace '/', '\'
  if (!(Test-Path $rubyPrefixPath)) {
    throw "Ruby runtime path not found: $rubyPrefixPath"
  }

  $rubyRuntimeTarget = Join-Path $rubyTarget 'ruby-runtime'
  New-Item -ItemType Directory -Force -Path $rubyRuntimeTarget | Out-Null
  Copy-Item (Join-Path $rubyPrefixPath '*') $rubyRuntimeTarget -Recurse -Force

  $bundleBat = Join-Path $rubyRuntimeTarget 'bin\bundle.bat'
  if (!(Test-Path $bundleBat)) {
    throw "Bundled Ruby runtime is missing bundle.bat at $bundleBat"
  }

  $libGmp = Get-ChildItem -Path $rubyRuntimeTarget -Recurse -File -Filter 'libgmp*.dll' | Select-Object -First 1
  if (-not $libGmp) {
    throw "Bundled Ruby runtime is missing libgmp*.dll."
  }

  $runPs1 = @(
    "Set-StrictMode -Version Latest"
    "`$ErrorActionPreference = 'Stop'"
    "Set-Location `$PSScriptRoot"
    "`$runtimeBin = Join-Path `$PSScriptRoot 'ruby-runtime\bin'"
    "`$env:PATH = ""`$runtimeBin;`$env:PATH"""
    "`$env:BUNDLE_GEMFILE = Join-Path `$PSScriptRoot 'Gemfile'"
    "`$env:BUNDLE_PATH = Join-Path `$PSScriptRoot 'vendor\bundle'"
    "& (Join-Path `$runtimeBin 'bundle.bat') exec ruby bin/translation_fiesta"
  ) -join [Environment]::NewLine
  Set-Content -Path "$rubyTarget\run.ps1" -Value $runPs1

  $runCmd = @(
    "@echo off"
    "setlocal"
    "cd /d ""%~dp0"""
    "set ""RUNTIME_BIN=%~dp0ruby-runtime\bin"""
    "set ""PATH=%RUNTIME_BIN%;%PATH%"""
    "set ""BUNDLE_GEMFILE=%~dp0Gemfile"""
    "set ""BUNDLE_PATH=%~dp0vendor\bundle"""
    "call ""%RUNTIME_BIN%\bundle.bat"" exec ruby bin\translation_fiesta"
  ) -join [Environment]::NewLine
  Set-Content -Path "$rubyTarget\run.cmd" -Value $runCmd

} else {
  Write-Host ""
  Write-Host "Skipping Python and Ruby ports (no native ARM64 support for all dependencies)."
  Write-Host "Re-run with -IncludeX64Emulated to build them as x64 binaries for emulation."
}

# ===================================================================
#  Generate launcher scripts
# ===================================================================

$launcherScript = Join-Path $repoRoot "scripts\create_windows_launchers.ps1"
& $launcherScript -Root $root

Write-Host ""
Write-Host "Done. Built Windows ARM64 apps under:"
Write-Host "  $root"
if ($IncludeX64Emulated) {
  Write-Host "  (includes x64-emulated Python and Ruby ports)"
}
Write-Host "From repo root, run '.\launch_portable.cmd' for the interactive launcher wizard."
