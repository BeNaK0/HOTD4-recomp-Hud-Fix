@echo off
setlocal
if exist "%~dp0Model Viewer.exe" (
    start "" "%~dp0Model Viewer.exe"
    exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0HOTD4_Recomp\hotd4-model-viewer.ps1"
if errorlevel 1 pause
