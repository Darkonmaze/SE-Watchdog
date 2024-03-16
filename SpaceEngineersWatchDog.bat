@echo off
setlocal

REM Get the directory where the batch file is located
set "batchDir=%~dp0"

REM Set the search pattern
set "searchPattern=*WatchDog*.ps1"

REM Search for .ps1 files containing "WatchDog" in the filename in the batch file's directory
for /r "%batchDir%" %%f in (%searchPattern%) do (
    echo Found PowerShell script: %%f
    echo Starting the PowerShell script...
    powershell -ExecutionPolicy Bypass -File "%%f"
    goto :EOF
)

echo No PowerShell script (.ps1) files containing "WatchDog" found in directory "%batchDir%".
pause
