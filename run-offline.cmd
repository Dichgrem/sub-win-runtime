@echo off
rem ============================================================
rem  Windows Runtimes Offline - double-click launcher
rem  Self-elevates and runs install-offline.ps1 (no network needed)
rem ============================================================
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel%==0 goto :run

echo Requesting administrator privileges...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%~dp0run-offline.cmd' -Verb RunAs"
exit /b

:run
echo.
echo === Windows Runtimes Offline ===
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-offline.ps1" %*
echo.
echo Finished. Log: install.log
pause
