@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\Switch-Boot-Mode.ps1" -Mode FACEIT
if errorlevel 1 (
 echo ERROR: Boot mode was not confirmed. Check CyberDeck backup boot-switch logs.
 pause
 exit /b 1
)
echo Boot order updated. Restart Windows manually to use the selected mode.
pause
