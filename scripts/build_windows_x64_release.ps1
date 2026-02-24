$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
Set-Location $repoRoot

$root = Join-Path $repoRoot "dist\release\windows-x64"
if (Test-Path $root) {
  Remove-Item $root -Recurse -Force
}
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
dotnet publish TranslationFiesta.WinUI/TranslationFiesta.WinUI.csproj `
  -c Release -r win-x64 --self-contained true `
  -p:Platform=x64 -p:RuntimeIdentifier=win-x64 `
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
Push-Location TranslationFiestaFlutter
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
$goExePath = "TranslationFiestaGo\build\bin\TranslationFiestaGo.exe"
$goNoExtPath = "TranslationFiestaGo\build\bin\TranslationFiestaGo"
if (Test-Path $goExePath) {
  Copy-Item $goExePath "$root\TranslationFiestaGo\TranslationFiestaGo.exe" -Force
} elseif (Test-Path $goNoExtPath) {
  Copy-Item $goNoExtPath "$root\TranslationFiestaGo\TranslationFiestaGo.exe" -Force
} else {
  throw "Go build output not found. Expected either '$goExePath' or '$goNoExtPath'."
}

# Python app
python -m pip install --upgrade pip
pip install -r TranslationFiestaPy/requirements.lock
pip install pyinstaller
Push-Location TranslationFiestaPy
pyinstaller --noconfirm --clean --windowed --onefile --name TranslationFiestaPy TranslationFiesta.py
Pop-Location
New-Item -ItemType Directory -Force -Path "$root\TranslationFiestaPy" | Out-Null
Copy-Item "TranslationFiestaPy\dist\TranslationFiestaPy.exe" "$root\TranslationFiestaPy\TranslationFiestaPy.exe" -Force


# Ruby self-contained runtime bundle (no system Ruby required)
Push-Location TranslationFiestaRuby
gem install rake --no-document
bundle install --deployment --path vendor/bundle --jobs 4 --retry 3
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

Write-Host ""
Write-Host "Done. Built Windows x64 apps (except Swift) under:"
Write-Host "  $root"
