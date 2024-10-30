@echo off
echo Initializing setup for Space Engineers configuration...

:: Run the PowerShell script to detect directories and generate config.json
powershell -ExecutionPolicy Bypass -File "%~dp0find_directories.ps1"
