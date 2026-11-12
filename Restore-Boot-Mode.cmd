@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\Switch-Verified-Boot-Mode.ps1" -Mode Restore
if errorlevel 1 (
 echo ERROR: Restore failed. See CyberDeck\backup\boot-switch\error.txt
 pause
 exit /b 1
)
echo Saved firmware boot order restored and verified. No restart performed.
pause
