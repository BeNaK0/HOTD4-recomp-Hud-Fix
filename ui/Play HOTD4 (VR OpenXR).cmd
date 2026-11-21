@echo off
setlocal DisableDelayedExpansion
if not exist "%~dp0HOTD4_Recomp\hotd4-vr.exe" (
    echo The OpenXR version is missing. Run Setup and select OpenXR.
    exit /b 1
)
pushd "%~dp0game\disk0\elf" || exit /b 1
set "PATH=%~dp0HOTD4_Recomp;%PATH%"
for %%D in ("..") do set "TEA_DIR=%%~fD"
set "LINDBERGH_NVRAM=%~dp0HOTD4_Recomp\vr-nvram.bin"
set "HOTD4_VR_LOG_DIR=%~dp0HOTD4_Recomp\VR Logs"
if not exist "%HOTD4_VR_LOG_DIR%" mkdir "%HOTD4_VR_LOG_DIR%"
if not exist "%HOTD4_VR_LOG_DIR%" (
    echo Cannot create the VR Logs folder. Check write permissions for this installation.
    popd
    exit /b 1
)
set "HOTD4_VR_LOG=%HOTD4_VR_LOG_DIR%\OpenXR-%RANDOM%-%RANDOM%.log"
echo Start your PC VR runtime and connect your headset before playing.
echo Diagnostic log: "%HOTD4_VR_LOG%"
>"%HOTD4_VR_LOG%" echo HOTD4 OpenXR session: %DATE% %TIME%
"%~dp0HOTD4_Recomp\hotd4-vr.exe" hod4M.elf >>"%HOTD4_VR_LOG%" 2>&1
set "HOTD4_EXIT=%ERRORLEVEL%"
popd
if not "%HOTD4_EXIT%"=="0" (
    echo HOTD4 VR exited with code %HOTD4_EXIT%.
    echo Please include this log with your report: "%HOTD4_VR_LOG%"
    pause
)
exit /b %HOTD4_EXIT%
