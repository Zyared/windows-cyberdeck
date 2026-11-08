@echo off
bcdedit /set {fwbootmgr} displayorder {bootmgr} /addfirst
if errorlevel 1 (
 echo Run this file as Administrator. Boot order was not restored.
 pause
 exit /b 1
)
"C:\Users\Zyared\CyberDeck\HackBGRT\setup.exe" batch disable-bcdedit
pause