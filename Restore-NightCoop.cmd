@echo off
echo This restores mod files recorded by this kit. Your saves are kept.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Restore-NightCoop.ps1" -Confirm
if errorlevel 1 (
  pause
  exit /b 1
)
pause
