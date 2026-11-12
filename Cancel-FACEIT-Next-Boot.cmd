@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\Restart-For-FACEIT.ps1" -Action Cancel
if errorlevel 1 (echo Failed. See CyberDeck\backup\faceit-next-boot\error.txt) else (echo One-time boot request cleared.)
pause
