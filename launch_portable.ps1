$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptPath = Join-Path $PSScriptRoot "scripts\windows_launch_wizard.ps1"
if (!(Test-Path $scriptPath)) {
  throw "Missing launcher script: $scriptPath"
}

$windowsPowerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (!(Test-Path $windowsPowerShell)) {
  $windowsPowerShell = "powershell"
}

& $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath @args
exit $LASTEXITCODE
