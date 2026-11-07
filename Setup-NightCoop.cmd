@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup-NightCoop.ps1" %*
if errorlevel 1 (
  echo Setup failed. Read the error above before retrying.
  pause
  exit /b 1
)
pause
