@echo off
setlocal DisableDelayedExpansion
set "HOTD4_PERFORMANCE_LOG=1"
set "LINDBERGH_TIMING_FROM="
set "LINDBERGH_TIMING_TO="
set "LINDBERGH_TIMING_SAMPLES=120000"
call "%~dp0Play HOTD4.cmd" %*
set "HOTD4_LOG_EXIT=%ERRORLEVEL%"
if "%~1"=="" if exist "%~dp0Performance Logs\" start "" "%~dp0Performance Logs"
exit /b %HOTD4_LOG_EXIT%
