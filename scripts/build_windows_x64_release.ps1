$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
Set-Location $repoRoot

$root = Join-Path $repoRoot "dist\release\windows-x64"

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
      # Clear read-only attributes that can block deletion.
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

Remove-DirectoryWithRetries $root
New-Item -ItemType Directory -Force -Path $root | Out-Null

Write-Host "Building TranslationFiesta Windows x64 release bundle from: $repoRoot"
Write-Host "Output: $root"

$dotnetVersion = (& dotnet --version).Trim()
if (-not $dotnetVersion.StartsWith("10.")) {
  throw "This build requires .NET SDK 10.x. Current SDK: $dotnetVersion"
}

# C#
dotnet publish TranslationFiestaCSharp/TranslationFiestaCSharp.csproj `
  -c Release -r win-x64 --self-contained true `
  -o "$root\TranslationFiestaCSharp"

# F#
dotnet publish TranslationFiestaFSharp/TranslationFiestaFSharp.fsproj `
  -c Release -r win-x64 --self-contained true `
  -o "$root\TranslationFiestaFSharp"

# WinUI
Remove-DirectoryWithRetries (Join-Path $repoRoot "TranslationFiesta.WinUI\obj")
Remove-DirectoryWithRetries (Join-Path $repoRoot "TranslationFiesta.WinUI\bin")
dotnet restore TranslationFiesta.WinUI/TranslationFiesta.WinUI.csproj -r win-x64 -p:Platform=x64
dotnet publish TranslationFiesta.WinUI/TranslationFiesta.WinUI.csproj `
  -c Release -r win-x64 --no-restore --self-contained true `
  -p:Platform=x64 -p:RuntimeIdentifier=win-x64 `
  -p:UseXamlCompilerExecutable=true `
  -p:WindowsAppSDKSelfContained=true `
  -p:WindowsPackageType=None -p:AppxPackage=false -p:GenerateAppxPackageOnBuild=false `
  -o "$root\TranslationFiesta.WinUI"

# Electron
Push-Location TranslationFiestaElectron
npm ci
npm run build
npx electron-packager . TranslationFiestaElectron --platform=win32 --arch=x64 --out "$root\TranslationFiestaElectron" --overwrite --prune=true
Pop-Location

# Flutter
flutter config --enable-windows-desktop
Remove-DirectoryWithRetries (Join-Path $repoRoot "TranslationFiestaFlutter\build\windows")
Push-Location TranslationFiestaFlutter
flutter clean
flutter pub get
flutter build windows --release
Pop-Location
New-Item -ItemType Directory -Force -Path "$root\TranslationFiestaFlutter" | Out-Null
Copy-Item "TranslationFiestaFlutter\build\windows\x64\runner\Release\*" "$root\TranslationFiestaFlutter" -Recurse -Force

# Go (Wails)
Push-Location TranslationFiestaGo
go run github.com/wailsapp/wails/v2/cmd/wails@v2.11.0 build -platform windows/amd64 -clean -o TranslationFiestaGo
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

# Python app
python -m pip install --upgrade pip
pip install -r TranslationFiestaPy/requirements.lock
pip install pyinstaller
$pythonOutRoot = Join-Path $repoRoot "TranslationFiestaPy\out"
Remove-DirectoryWithRetries $pythonOutRoot
New-Item -ItemType Directory -Force -Path $pythonOutRoot | Out-Null
Push-Location TranslationFiestaPy
pyinstaller --noconfirm --clean --windowed --onedir --name TranslationFiestaPy --collect-submodules tkinterweb --collect-data tkinterweb --collect-submodules tkinterweb_tkhtml --collect-data tkinterweb_tkhtml --distpath "$pythonOutRoot\dist" --workpath "$pythonOutRoot\build" --specpath "$pythonOutRoot\spec" TranslationFiesta.py
Pop-Location
New-Item -ItemType Directory -Force -Path "$root\TranslationFiestaPy" | Out-Null
Copy-Item "$pythonOutRoot\dist\TranslationFiestaPy\*" "$root\TranslationFiestaPy" -Recurse -Force


# Ruby self-contained runtime bundle (no system Ruby required)
Push-Location TranslationFiestaRuby
gem install rake --no-document
$env:BUNDLE_PATH = "vendor/bundle"
$env:BUNDLE_DEPLOYMENT = "false"
$env:BUNDLE_FROZEN = "false"
bundle install --jobs 4 --retry 3
Remove-Item Env:BUNDLE_PATH, Env:BUNDLE_DEPLOYMENT, Env:BUNDLE_FROZEN -ErrorAction SilentlyContinue
$rubyPrefix = (& ruby -e "require 'rbconfig'; print RbConfig::CONFIG['prefix']").Trim()
Pop-Location

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

$libGmp = Get-ChildItem -Path $rubyRuntimeTarget -Recurse -Filter 'libgmp-10.dll' | Select-Object -First 1
if (-not $libGmp) {
  throw "Bundled Ruby runtime is missing libgmp-10.dll."
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

$launcherScript = Join-Path $repoRoot "scripts\create_windows_launchers.ps1"
& $launcherScript -Root $root

Write-Host ""
Write-Host "Done. Built Windows x64 apps (except Swift) under:"
Write-Host "  $root"
Write-Host "From repo root, run '.\\launch_portable.cmd' for the interactive launcher wizard."
