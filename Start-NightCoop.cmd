@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Start-NightCoop.ps1"
if errorlevel 1 pause
