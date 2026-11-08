# Puts back the appearance saved by apply.ps1.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'detect.ps1')
if (-not (Test-Path (Join-Path $BackupDir 'complete.txt'))) { throw "No backup found in $BackupDir" }

& (Join-Path $PSScriptRoot 'install-session.ps1') -Undo

# Animated layer first, otherwise the live wallpaper would keep covering the restored picture.
# The two programs stay installed, they just stop starting with Windows.
$lively = Find-ArasakaProgram 'Lively'
$rm = Find-ArasakaProgram 'Rainmeter'
if ($lively -and (Get-Process Lively -ErrorAction SilentlyContinue)) {
  $p = Start-Process $lively -ArgumentList @('closewp', '--monitor', '-1') -PassThru -WindowStyle Hidden
  $p.WaitForExit(10000) | Out-Null
  Start-Sleep 2
  $p = Start-Process $lively -ArgumentList @('--shutdown', 'true') -PassThru -WindowStyle Hidden
  $p.WaitForExit(10000) | Out-Null
  Start-Sleep 3
  Get-Process Lively, Lively.UI.WinUI -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
if ($rm -and (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
  & $rm '!Quit'
  Start-Sleep 2
  Get-Process Rainmeter -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
foreach ($n in 'Lively', 'Rainmeter') { Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $n -ErrorAction SilentlyContinue }
Remove-Item (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Rainmeter.lnk') -ErrorAction SilentlyContinue
if (Test-Path (Join-Path $BackupDir 'wallpaper-engine-config.json')) { & (Join-Path $PSScriptRoot 'apply-wallpaper-engine.ps1') -Undo }
Invoke-WindhawkSettings '-Off'
if (Test-Path (Join-Path $PSScriptRoot 'repair-shell-icons.ps1')) { Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File '+[char]34+(Join-Path $PSScriptRoot 'repair-shell-icons.ps1')+[char]34+' -Undo') }
& (Join-Path $PSScriptRoot 'apply-icons.ps1') -Undo

# Values that did not exist before must go away too, because a .reg import only adds and overwrites.
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -Name EnableWindowColorization -ErrorAction SilentlyContinue
# reg.exe reports success on stderr, which PowerShell would treat as a failure, so cmd handles its output.
foreach ($b in $RegBackups) {
  $file = Join-Path $BackupDir $b.File
  & cmd.exe /c "reg import `"$file`" >nul 2>&1"
  if ($LASTEXITCODE -ne 0) { Write-Host "Could not import $($b.File)" }
}

$desk = Get-Content (Join-Path $BackupDir 'desktop.json') -Raw | ConvertFrom-Json
Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle ([string]$desk.WallpaperStyle)
Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper ([string]$desk.TileWallpaper)
$wall = Join-Path $BackupDir 'wallpaper.jpg'
if (Test-Path $wall) { [CdNative]::SetWallpaper($wall) }

$lock = Join-Path $BackupDir 'lockscreen-original.img'
if (Test-Path $lock) {
  try {
    # The Windows API only accepts picture extensions, and the backup keeps a neutral one.
    $tmp = Join-Path $BackupDir 'lockscreen-original.jpg'
    Copy-Item $lock $tmp -Force
    Set-LockImage $tmp
    Write-Host 'Lock screen restored.'
  } catch { Write-Host "Lock screen not restored: $($_.Exception.Message). Pick it in Settings > Personalization > Lock screen." }
} else { Write-Host 'The previous lock screen had no saved picture: pick it in Settings > Personalization > Lock screen.' }

$wt = Get-TerminalSettings
$saved = Join-Path $BackupDir 'terminal-settings.json'
if ($wt -and (Test-Path $saved)) { Copy-Item $saved $wt -Force }

Refresh-Appearance
Write-Host 'Windows look restored.'
