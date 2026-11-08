@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "ARASAKA_EXIT=%ERRORLEVEL%"
echo.
if not "%ARASAKA_EXIT%"=="0" echo Installation needs attention. See the messages above and install.log.
pause
exit /b %ARASAKA_EXIT%
