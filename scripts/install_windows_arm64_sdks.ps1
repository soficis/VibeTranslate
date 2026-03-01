<#
.SYNOPSIS
  Installs the necessary SDKs and runtimes for VibeTranslate on Windows ARM64.

.DESCRIPTION
  This script automates the installation of:
    - Visual Studio 2022 Build Tools (ARM64 specific)
    - .NET 10 SDK (ARM64)
    - Node.js LTS (ARM64)
    - Go 1.26 (ARM64)
    - Flutter (ARM64 stable)
    - Python 3.12 (ARM64)
    - Ruby 3.4 (ARM64)

  With -IncludeX64Runtimes, also installs:
    - x64 Python (for emulated PyInstaller builds)
    - x64 Ruby (for emulated RubyInstaller runtime)

.PARAMETER IncludeX64Runtimes
  Install x64 versions of Python and Ruby for x64-emulated build support.
#>
param(
  [switch]$IncludeX64Runtimes
)

$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Warning "This script requires Administrator privileges for winget installations.  Please restart PowerShell as Administrator."
  exit 1
}

# ---------------------------------------------------------------------------
# Winget Installation Helper
# ---------------------------------------------------------------------------
function Install-App([string]$id, [string]$name, [string]$version = "", [string]$architecture = "") {
  Write-Host "Checking for $name ($id)..." -ForegroundColor Cyan
  
  # Use --source winget to prevent localized hangs or database locks.
  # Run detect in a background job with a 20-second timeout to avoid indefinite hangs
  # (e.g. VS Build Tools triggers a full installer infrastructure phone-home).
  $isInstalled = $false
  try {
    $job = Start-Job -ScriptBlock {
      param($pkgId)
      $out = winget list --id $pkgId --exact -e --source winget --accept-source-agreements 2>$null
      if ($out -match [regex]::Escape($pkgId)) { return $true }
      return $false
    } -ArgumentList $id

    $completed = Wait-Job $job -Timeout 20
    if ($completed) {
      $isInstalled = Receive-Job $job
    } else {
      Write-Warning "  Timed out checking if $name is installed (winget list slow). Will attempt install anyway."
      Stop-Job $job -ErrorAction SilentlyContinue
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
  } catch {
    Write-Warning "  Warning: Error checking status for $id. Proceeding with installation attempt."
  }

  if ($isInstalled) {
    Write-Host "  $name is already installed." -ForegroundColor Green
    return
  }

  Write-Host "  Installing $name..." -ForegroundColor Yellow
  $cmd = "winget install --id $id --exact -e --accept-package-agreements --accept-source-agreements --silent --scope machine --force"
  if ($version) { $cmd += " --version $version" }
  if ($architecture) { $cmd += " --architecture $architecture" }
  
  Invoke-Expression $cmd | Out-Null
  Write-Host "  Done." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# VS Build Tools (detected separately via vswhere - avoids slow winget list)
# ---------------------------------------------------------------------------
function Install-VSBuildTools {
  Write-Host "Checking for VS 2022 Build Tools..." -ForegroundColor Cyan

  # Use vswhere.exe for a fast, offline check instead of winget list which triggers
  # the VS installer's network channel-update and can hang for minutes.
  $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path $vswhere) {
    $instances = & $vswhere -products 'Microsoft.VisualStudio.Product.BuildTools' -version '[17.0,)' -format json 2>$null | ConvertFrom-Json
    if ($instances -and $instances.Count -gt 0) {
      Write-Host "  VS 2022 Build Tools is already installed at: $($instances[0].installationPath)" -ForegroundColor Green
      return
    }
  }

  # Also check Program Files directly as a fallback.
  $buildToolsPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"
  if (Test-Path $buildToolsPath) {
    Write-Host "  VS 2022 Build Tools found at: $buildToolsPath" -ForegroundColor Green
    return
  }

  Write-Host "  Installing VS 2022 Build Tools..." -ForegroundColor Yellow
  winget install --id Microsoft.VisualStudio.2022.BuildTools --exact -e `
    --accept-package-agreements --accept-source-agreements --silent --scope machine --force | Out-Null
  Write-Host "  Done." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Core ARM64 SDKs
# ---------------------------------------------------------------------------

Write-Host "`n=== Installing Windows ARM64 Core SDKs ===`n" -ForegroundColor Magenta

# Visual Studio 2022 Build Tools containing ARM64 components.
Install-VSBuildTools

# .NET 10 (Preview/Final) - Adjusting ID for the latest available.
Install-App "Microsoft.DotNet.SDK.10" ".NET 10 SDK" --architecture arm64

# Add .NET to the current session's PATH immediately
$dotnetPath = "C:\Program Files\dotnet"
if (Test-Path $dotnetPath) {
    if ($env:PATH -notlike "*$dotnetPath*") {
        $env:PATH = "$dotnetPath;$env:PATH"
        Write-Host "  Added $dotnetPath to current session PATH." -ForegroundColor Gray
    }
}

# Node.js 22 LTS (ARM64)
Install-App "OpenJS.NodeJS.LTS" "Node.js LTS" --architecture arm64

# Go 1.26 (ARM64) - Winget usually tracks latest.
Install-App "GoLang.Go" "Go Language" --architecture arm64

# Flutter (ARM64 stable)
Install-App "Google.Flutter" "Flutter SDK" --architecture arm64

# Python 3.12 (ARM64)
Install-App "Python.Python.3.12" "Python 3.12 (ARM64)" --architecture arm64

# Ruby 3.4 (ARM64)
Install-App "RubyInstallerTeam.RubyWithDevKit.3.4" "Ruby 3.4 (ARM64)" --architecture arm64

# ---------------------------------------------------------------------------
# x64 Runtimes (for emulation / build support)
# ---------------------------------------------------------------------------

if ($IncludeX64Runtimes) {
  Write-Host "`n=== Installing x64 Runtimes for Emulation Support ===`n" -ForegroundColor Magenta

  # Explicitly targeting x64 for these specific installs.
  Install-App "Python.Python.3.12" "Python 3.12 (x64)" --architecture x64
  Install-App "RubyInstallerTeam.RubyWithDevKit.3.4" "Ruby 3.4 (x64)" --architecture x64

  Write-Host "`nNote: Python and Ruby x64 are installed to run under emulation."
  Write-Host "      Ensure they are correctly added to your PATH or set PYTHON_X64 / RUBY_X64_PREFIX."
}

# ---------------------------------------------------------------------------
# Final Environment Setup
# ---------------------------------------------------------------------------

Write-Host "`n=== Finalizing Environment ===`n" -ForegroundColor Magenta

# Trigger Flutter ARM64 desktop support if possible.
try {
  Write-Host "Enabling Flutter Windows ARM64 desktop support..."
  & flutter config --enable-windows-desktop
  & flutter doctor
} catch {
  Write-Warning "Could not run flutter config/doctor. Ensure Flutter bin is in your PATH."
}

# Check for .NET arm64
try {
  $info = & dotnet --info
  if ($info -match "Architecture:.*arm64") {
    Write-Host "Verified .NET is running as native ARM64." -ForegroundColor Green
  } else {
    Write-Warning "Detected .NET running as x64/x86. Ensure the ARM64 SDK is first in your PATH."
  }
} catch {
  # dotnet not in path yet.
}

Write-Host "`nPrerequisites installation complete. Restart your terminal to refresh PATH." -ForegroundColor Green
