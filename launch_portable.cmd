@echo off
setlocal
set "SCRIPT_PATH=%~dp0scripts\windows_launch_wizard.ps1"

if not exist "%SCRIPT_PATH%" (
  echo Missing launcher script: "%SCRIPT_PATH%"
  exit /b 1
)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %*
exit /b %ERRORLEVEL%
