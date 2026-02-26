param(
  [Parameter(Mandatory = $true)]
  [string]$Root
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$resolvedRoot = [System.IO.Path]::GetFullPath($Root)
if (!(Test-Path $resolvedRoot)) {
  throw "Windows release root does not exist: $resolvedRoot"
}

function Resolve-RelativePath([string]$from, [string]$to) {
  $fromUri = [System.Uri]::new(([System.IO.Path]::GetFullPath($from) + [System.IO.Path]::DirectorySeparatorChar))
  $toUri = [System.Uri]::new([System.IO.Path]::GetFullPath($to))
  $relativeUri = $fromUri.MakeRelativeUri($toUri)
  $relative = [System.Uri]::UnescapeDataString($relativeUri.ToString())
  return $relative.Replace('/', '\')
}

function Resolve-AppExecutableRelativePath([string]$appPath, [string]$appName) {
  $preferred = Join-Path $appPath "$appName.exe"
  if (Test-Path $preferred) {
    return "$appName.exe"
  }

  $candidates = @(Get-ChildItem -Path $appPath -Recurse -File -Filter *.exe | Where-Object {
    $_.Name -notmatch '^(?i:createdump|unins\d+)\.exe$' -and
    $_.FullName -notmatch '\\ruby-runtime\\'
  })

  if ($null -eq $candidates -or $candidates.Count -eq 0) {
    return $null
  }

  $nameMatches = @($candidates | Where-Object { $_.BaseName -ieq $appName })
  $selected = if ($null -ne $nameMatches -and $nameMatches.Count -gt 0) {
    $nameMatches | Sort-Object FullName | Select-Object -First 1
  } else {
    $candidates | Sort-Object FullName | Select-Object -First 1
  }

  return Resolve-RelativePath $appPath $selected.FullName
}

function Write-LauncherScripts([string]$appPath, [string]$relativeExecutablePath) {
  $cmdLauncherPath = Join-Path $appPath "run.cmd"
  $psLauncherPath = Join-Path $appPath "run.ps1"
  $exeRelativePath = $relativeExecutablePath.Replace('/', '\')

  $cmdContent = @(
    "@echo off"
    "setlocal"
    "cd /d ""%~dp0"""
    """%~dp0$exeRelativePath"" %*"
  ) -join [Environment]::NewLine

  $psContent = @(
    "Set-StrictMode -Version Latest"
    "`$ErrorActionPreference = 'Stop'"
    "Set-Location `$PSScriptRoot"
    "& (Join-Path `$PSScriptRoot '$exeRelativePath') @args"
  ) -join [Environment]::NewLine

  Set-Content -Path $cmdLauncherPath -Value $cmdContent -Encoding ASCII
  Set-Content -Path $psLauncherPath -Value $psContent -Encoding UTF8
}

function Get-AppDisplayName([string]$appFolderName) {
  switch ($appFolderName) {
    'TranslationFiestaCSharp' { return 'TranslationFiesta C#' }
    'TranslationFiestaFSharp' { return 'TranslationFiesta F#' }
    'TranslationFiesta.WinUI' { return 'TranslationFiesta C# WinUI' }
    'TranslationFiestaElectron' { return 'TranslationFiesta TypeScript' }
    'TranslationFiestaFlutter' { return 'TranslationFiesta Dart' }
    'TranslationFiestaGo' { return 'TranslationFiesta Go' }
    'TranslationFiestaPy' { return 'TranslationFiesta Python' }
    'TranslationFiestaRuby' { return 'TranslationFiesta Ruby' }
    'TranslationFiestaSwift' { return 'TranslationFiesta Swift' }
    default { return $appFolderName }
  }
}

$appDirectories = Get-ChildItem -Path $resolvedRoot -Directory | Sort-Object Name
$launchableApps = @()
$skippedApps = @{}
$knownWindowsApps = @(
  'TranslationFiestaCSharp',
  'TranslationFiestaFSharp',
  'TranslationFiesta.WinUI',
  'TranslationFiestaElectron',
  'TranslationFiestaFlutter',
  'TranslationFiestaGo',
  'TranslationFiestaPy',
  'TranslationFiestaRuby'
)

foreach ($directory in $appDirectories) {
  $appName = $directory.Name
  $appPath = $directory.FullName

  if ($appName -eq "TranslationFiestaRuby") {
    if (!(Test-Path (Join-Path $appPath "run.cmd"))) {
      throw "Ruby portable payload is missing run.cmd in $appPath"
    }
    if (!(Test-Path (Join-Path $appPath "run.ps1"))) {
      throw "Ruby portable payload is missing run.ps1 in $appPath"
    }
    $launchableApps += $appName
    continue
  }

  $relativeExecutablePath = Resolve-AppExecutableRelativePath $appPath $appName
  if ([string]::IsNullOrWhiteSpace($relativeExecutablePath)) {
    $skippedApps[$appName] = "No launchable .exe was found under '$appPath'."
    continue
  }

  Write-LauncherScripts $appPath $relativeExecutablePath
  $launchableApps += $appName
}

$launchableApps = @($launchableApps | Sort-Object -Unique)
foreach ($knownApp in $knownWindowsApps) {
  $knownAppPath = Join-Path $resolvedRoot $knownApp
  if (!(Test-Path $knownAppPath)) {
    continue
  }

  if ($launchableApps -notcontains $knownApp) {
    $reason = if ($skippedApps.ContainsKey($knownApp)) { $skippedApps[$knownApp] } else { "Launcher generation failed unexpectedly." }
    throw "Failed to generate launcher for required app '$knownApp'. $reason"
  }
}

if ($skippedApps.Count -gt 0) {
  foreach ($entry in $skippedApps.GetEnumerator() | Sort-Object Key) {
    Write-Warning "Skipped '$($entry.Key)': $($entry.Value)"
  }
}

if ($launchableApps.Count -eq 0) {
  throw "No launchable Windows apps found under $resolvedRoot"
}

$cmdMenuLines = @()
$psMenuLines = @()
$psDisplayMapEntries = @()
$cmdDisplayChoiceLines = @()
$selectionIndex = 1
foreach ($appName in $launchableApps) {
  $displayName = Get-AppDisplayName $appName
  $cmdMenuLines += "echo   [$selectionIndex] $displayName ($appName)"
  $psMenuLines += "  Write-Host '  [$selectionIndex] $displayName ($appName)'"
  $escapedCmdDisplayName = $displayName.Replace('"', '""')
  $cmdDisplayChoiceLines += "if /I ""%CHOICE%""==""$escapedCmdDisplayName"" set ""APP=$appName"" & goto launch"
  $escapedDisplayName = $displayName.Replace("'", "''")
  $psDisplayMapEntries += "  '$appName' = '$escapedDisplayName'"
  $selectionIndex += 1
}

$cmdMenuBlock = $cmdMenuLines -join [Environment]::NewLine
$cmdChoiceBlock = ($launchableApps | ForEach-Object -Begin { $i = 1 } -Process {
  $line = "if ""%CHOICE%""==""$i"" set ""APP=$_"" & goto launch"
  $i += 1
  $line
}) -join [Environment]::NewLine
$cmdDisplayChoiceBlock = $cmdDisplayChoiceLines -join [Environment]::NewLine
$psMenuBlock = $psMenuLines -join [Environment]::NewLine

$bundleCmdPath = Join-Path $resolvedRoot "launch.cmd"
$bundlePsPath = Join-Path $resolvedRoot "launch.ps1"

$bundleFolderName = Split-Path -Path $resolvedRoot -Leaf
$buildScriptRelativePath = $null
if ($bundleFolderName -match '^windows-(x64|arm64)$') {
  $candidateRelative = "..\..\..\scripts\build_windows_$($Matches[1])_release.ps1"
  $candidateAbsolute = Join-Path $resolvedRoot $candidateRelative
  if (Test-Path $candidateAbsolute) {
    $buildScriptRelativePath = $candidateRelative
  }
}

$cmdBuildScriptAssignment = if ([string]::IsNullOrWhiteSpace($buildScriptRelativePath)) {
  'set "BUILD_SCRIPT="'
} else {
  "set ""BUILD_SCRIPT=%~dp0$buildScriptRelativePath"""
}

$psBuildScriptAssignment = if ([string]::IsNullOrWhiteSpace($buildScriptRelativePath)) {
  "`$buildScript = ''"
} else {
  "`$buildScript = Join-Path `$PSScriptRoot '$buildScriptRelativePath'"
}

$bundleCmdContent = @"
@echo off
setlocal
$cmdBuildScriptAssignment

if not "%~1"=="" (
  set "APP=%~1"
  shift
  goto launch
)

:menu
echo TranslationFiesta portable launcher
echo.
echo Select an app to launch:
$cmdMenuBlock
if exist "%BUILD_SCRIPT%" echo   [B] Build/Rebuild current Windows bundle
echo   [Q] Quit
set "CHOICE="
set /p "CHOICE=Enter selection: "

if "%CHOICE%"=="" goto menu
if /I "%CHOICE%"=="Q" exit /b 0
if /I "%CHOICE%"=="B" goto build
$cmdChoiceBlock
$cmdDisplayChoiceBlock
set "APP=%CHOICE%"

:launch
set "TARGET=%~dp0%APP%\run.cmd"
if not exist "%TARGET%" (
  echo Unknown app folder "%APP%".
  goto menu
)
call "%TARGET%" %*
exit /b %ERRORLEVEL%

:build
if not exist "%BUILD_SCRIPT%" (
  echo Build script not found: "%BUILD_SCRIPT%"
  goto menu
)
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BUILD_SCRIPT%"
if errorlevel 1 (
  echo Build failed.
)
goto menu
"@

$bundlePsContent = @"
param(
  [Parameter(Position = 0)]
  [string]`$AppFolderName = '',
  [Parameter(ValueFromRemainingArguments = `$true)]
  [string[]]`$AppArgs
)

Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'

`$availableApps = @(
$(($launchableApps | ForEach-Object { "  '$_'" }) -join [Environment]::NewLine)
)

`$appDisplayNames = @{
$(($psDisplayMapEntries) -join [Environment]::NewLine)
}

$psBuildScriptAssignment

function Resolve-AppSelection {
  param([string]`$Choice)

  if ([string]::IsNullOrWhiteSpace(`$Choice)) {
    return `$null
  }

  `$trimmed = `$Choice.Trim()
  `$index = 0
  if ([int]::TryParse(`$trimmed, [ref]`$index)) {
    if (`$index -ge 1 -and `$index -le `$availableApps.Count) {
      return `$availableApps[`$index - 1]
    }
  }

  `$displayMatch = `$availableApps | Where-Object {
    `$display = if (`$appDisplayNames.ContainsKey(`$_)) { `$appDisplayNames[`$_] } else { `$_ }
    `$display -ieq `$trimmed
  } | Select-Object -First 1
  if (`$displayMatch) {
    return `$displayMatch
  }

  return (`$availableApps | Where-Object { `$_ -ieq `$trimmed } | Select-Object -First 1)
}

while ([string]::IsNullOrWhiteSpace(`$AppFolderName)) {
  Write-Host 'TranslationFiesta portable launcher'
  Write-Host ''
  Write-Host 'Select an app to launch:'
$psMenuBlock
  if (Test-Path `$buildScript) {
    Write-Host '  [B] Build/Rebuild current Windows bundle'
  }
  Write-Host '  [Q] Quit'

  `$choice = Read-Host 'Enter selection'
  if ([string]::IsNullOrWhiteSpace(`$choice)) {
    Write-Host ''
    continue
  }

  if (`$choice -match '^(?i:q)$') {
    exit 0
  }

  if (`$choice -match '^(?i:b)$') {
    if (!(Test-Path `$buildScript)) {
      Write-Host "Build script not found: `$buildScript"
      Write-Host ''
      continue
    }

    try {
      & `$buildScript
    } catch {
      Write-Host ("Build failed: " + `$_.Exception.Message)
    }
    Write-Host ''
    continue
  }

  `$AppFolderName = Resolve-AppSelection `$choice
  if ([string]::IsNullOrWhiteSpace(`$AppFolderName)) {
    Write-Host "Unknown app selection: '`$choice'"
    Write-Host ''
  }
}

`$target = Join-Path `$PSScriptRoot "`$AppFolderName\run.ps1"
if (!(Test-Path `$target)) {
  Write-Host "Unknown app folder '`$AppFolderName'."
  Write-Host 'Available apps:'
  `$availableApps | ForEach-Object { Write-Host ('  ' + `$_) }
  exit 1
}

& `$target @AppArgs
"@

Set-Content -Path $bundleCmdPath -Value $bundleCmdContent -Encoding ASCII
Set-Content -Path $bundlePsPath -Value $bundlePsContent -Encoding UTF8
