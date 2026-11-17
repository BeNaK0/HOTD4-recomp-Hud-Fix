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
echo Start your PC VR runtime and connect your headset before playing.
"%~dp0HOTD4_Recomp\hotd4-vr.exe" hod4M.elf
set "HOTD4_EXIT=%ERRORLEVEL%"
popd
if not "%HOTD4_EXIT%"=="0" (
    echo HOTD4 VR exited with code %HOTD4_EXIT%.
    pause
)
exit /b %HOTD4_EXIT%
