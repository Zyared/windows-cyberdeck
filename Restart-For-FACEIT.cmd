@echo off
echo Restarting through Windows Boot Manager for the next boot only.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\Restart-For-FACEIT.ps1" -Action Reboot
if errorlevel 1 (
 echo Failed. See CyberDeck\backup\faceit-next-boot\error.txt
 pause
 exit /b 1
)
