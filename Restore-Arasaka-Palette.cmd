@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\Apply-Arasaka-Palette.ps1" -Undo
if errorlevel 1 (echo Restore failed. See CyberDeck\backup\palette-v3\error.txt) else (echo Restored. Sign out and back in to reload the theme.)
pause