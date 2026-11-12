@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\apply-session-art.ps1" -Undo
if errorlevel 1 echo Boot artwork or status-policy restore failed. Review CyberDeck backup session-art-v2 apply.log.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\CyberDeck\apply-arasaka-cursors.ps1" -Undo
if errorlevel 1 echo Cursor restore failed.
pause
