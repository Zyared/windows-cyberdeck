@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\Restore-Optimization.ps1"
if errorlevel 1 echo Restore failed. Keep the backup files and review the error above.
pause
