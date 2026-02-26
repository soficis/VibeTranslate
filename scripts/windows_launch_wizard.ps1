param(
  [Parameter(Position = 0)]
  [string]$AppFolderName = '',
  [ValidateSet('x64', 'arm64')]
  [string]$Arch = '',
  [switch]$Rebuild,
  [switch]$NoBuildPrompt,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AppArgs
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$releaseRoot = Join-Path $repoRoot "dist\release"
$launcherGenerator = Join-Path $repoRoot "scripts\create_windows_launchers.ps1"

function Get-WindowsBundleRoots {
  if (!(Test-Path $releaseRoot)) {
    return @()
  }

  return @(Get-ChildItem -Path $releaseRoot -Directory | Where-Object { $_.Name -match '^windows-(x64|arm64)$' } | Sort-Object Name)
}

function Get-BuildScriptForArch([string]$bundleArch) {
  $candidate = Join-Path $repoRoot "scripts\build_windows_${bundleArch}_release.ps1"
  if (Test-Path $candidate) {
    return $candidate
  }

  return $null
}

function Invoke-BundleBuild([string]$bundleArch) {
  $buildScript = Get-BuildScriptForArch $bundleArch
  if ([string]::IsNullOrWhiteSpace($buildScript)) {
    throw "No local build script is available for windows-$bundleArch."
  }

  & $buildScript
}

function Ensure-BundleLaunchers([string]$bundleRoot) {
  if (!(Test-Path $launcherGenerator)) {
    throw "Launcher generator script not found: $launcherGenerator"
  }
  if (!(Test-Path $bundleRoot)) {
    throw "Bundle root not found: $bundleRoot"
  }

  & $launcherGenerator -Root $bundleRoot
}

function Select-BundleRoot([string]$selectedArch, [bool]$allowPrompt) {
  $bundleDirs = @(Get-WindowsBundleRoots)

  if (![string]::IsNullOrWhiteSpace($selectedArch)) {
    $selected = $bundleDirs | Where-Object { $_.Name -eq "windows-$selectedArch" } | Select-Object -First 1
    if ($selected) {
      return $selected.FullName
    }
    return $null
  }

  if ($bundleDirs.Count -eq 1) {
    return $bundleDirs[0].FullName
  }

  if ($bundleDirs.Count -gt 1 -and $allowPrompt) {
    $index = 1
    Write-Host "Select Windows bundle architecture:"
    foreach ($directory in $bundleDirs) {
      Write-Host "  [$index] $($directory.Name)"
      $index += 1
    }

    while ($true) {
      $choice = Read-Host "Enter selection"
      $numericChoice = 0
      if ([int]::TryParse($choice, [ref]$numericChoice)) {
        if ($numericChoice -ge 1 -and $numericChoice -le $bundleDirs.Count) {
          return $bundleDirs[$numericChoice - 1].FullName
        }
      }

      $nameMatch = $bundleDirs | Where-Object { $_.Name -ieq $choice } | Select-Object -First 1
      if ($nameMatch) {
        return $nameMatch.FullName
      }

      if ($choice -match '^(?i:q)$') {
        return $null
      }

      Write-Host "Unknown selection: '$choice'. Enter 1-$($bundleDirs.Count), bundle name, or Q."
    }
  }

  return $null
}

$preferredArch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$selectedArch = if ([string]::IsNullOrWhiteSpace($Arch)) { '' } else { $Arch }
if ($Rebuild) {
  if ([string]::IsNullOrWhiteSpace($selectedArch)) {
    $selectedArch = $preferredArch
  }
  Invoke-BundleBuild $selectedArch
}

$bundleRoot = Select-BundleRoot -selectedArch $selectedArch -allowPrompt $true
if ([string]::IsNullOrWhiteSpace($bundleRoot)) {
  if ($NoBuildPrompt) {
    throw "No Windows portable bundle found under $releaseRoot."
  }

  $buildArch = if ([string]::IsNullOrWhiteSpace($selectedArch)) { $preferredArch } else { $selectedArch }
  $buildScript = Get-BuildScriptForArch $buildArch
  if ([string]::IsNullOrWhiteSpace($buildScript) -and [string]::IsNullOrWhiteSpace($selectedArch) -and $buildArch -ne 'x64') {
    $x64BuildScript = Get-BuildScriptForArch 'x64'
    if (![string]::IsNullOrWhiteSpace($x64BuildScript)) {
      $buildArch = 'x64'
      $buildScript = $x64BuildScript
    }
  }
  if ([string]::IsNullOrWhiteSpace($buildScript)) {
    throw "No Windows bundle found for windows-$buildArch and no local build script exists for that architecture."
  }

  $choice = Read-Host "Windows bundle windows-$buildArch not found. Build now? [Y/n]"
  if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '^(?i:y|yes)$') {
    Invoke-BundleBuild $buildArch
    $bundleRoot = Select-BundleRoot -selectedArch $buildArch -allowPrompt $false
  }
}

if ([string]::IsNullOrWhiteSpace($bundleRoot)) {
  throw "Launch cancelled."
}

Ensure-BundleLaunchers $bundleRoot

$bundleLauncher = Join-Path $bundleRoot "launch.ps1"
if (!(Test-Path $bundleLauncher)) {
  throw "Bundle launcher not found after build: $bundleLauncher"
}

if ([string]::IsNullOrWhiteSpace($AppFolderName)) {
  & $bundleLauncher
} else {
  & $bundleLauncher $AppFolderName @AppArgs
}
