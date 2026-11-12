@echo off
setlocal
title Arasaka Emergency Rollback
fltmc >nul 2>&1
if errorlevel 1 (
 echo Run this file as Administrator, including in Safe Mode.
 pause
 exit /b 1
)
echo Disabling Windhawk appearance mods. No system files or boot settings will be changed.
for %%M in (windows-11-start-menu-styler windows-11-file-explorer-styler windows-11-taskbar-styler windows-11-notification-center-styler windows-11-settings-styler translucent-windows local@translucent-windows-fork arasaka-logon-styler local@arasaka-logon-styler arasaka-shutdown-styler local@arasaka-shutdown-styler lock-screen-clock-styler lockscreen-datetime-format icon-resource-redirect) do (
 reg query "HKLM\SOFTWARE\Windhawk\Engine\Mods\%%M" >nul 2>&1
 if not errorlevel 1 (
  reg add "HKLM\SOFTWARE\Windhawk\Engine\Mods\%%M" /v Disabled /t REG_DWORD /d 1 /f
 )
)
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Arasaka Session.lnk" move /y "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Arasaka Session.lnk" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Arasaka Session.lnk.disabled" >nul
echo.
echo Mods disabled for the next process start. Restart Windows normally when ready.
echo This file does not restart the PC automatically.
echo It does not repair EFI or undo firmware changes.
pause
