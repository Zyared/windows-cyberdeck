# Turns on the animated layer: the live wallpaper in Lively and the HUD in Rainmeter. Run after apply.ps1.
param([ValidateSet('Lively', 'WallpaperEngine')][string]$Wallpaper = 'Lively')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$root = Join-Path $env:USERPROFILE 'CyberDeck'
& (Join-Path $root 'make-icons.ps1') -OutDir (Join-Path $root 'icons')
& (Join-Path $root 'apply-icons.ps1')
Invoke-WindhawkSettings ''
$lively = 'C:\Program Files\Lively Wallpaper\Lively.exe'
$rm = 'C:\Program Files\Rainmeter\Rainmeter.exe'
foreach ($p in $(if ($Wallpaper -eq 'Lively') { $lively }), $rm) { if ($p -and -not (Test-Path $p)) { throw "Not installed: $p" } }
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

if ($Wallpaper -eq 'WallpaperEngine') {
  & (Join-Path $root 'apply-wallpaper-engine.ps1')
} else {
  # --- Lively ---
  $lib = Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\Library\wallpapers\cyberdeck'
  New-Item -ItemType Directory -Force -Path $lib | Out-Null
  Copy-Item (Join-Path $root 'live\*') $lib -Recurse -Force   # Lively ignores a folder outside its library, without any error
  Set-ItemProperty $run 'Lively' "`"$lively`""
  if (-not (Get-Process Lively -ErrorAction SilentlyContinue)) { Start-Process $lively; Start-Sleep 8 }
  $p = Start-Process $lively -ArgumentList @('setwp', '--file', "`"$lib`"") -PassThru -WindowStyle Hidden
  $p.WaitForExit(15000) | Out-Null
  Start-Sleep 5
  $layout = Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\WallpaperLayout.json'
  if ((Get-Content $layout -Raw) -notmatch 'cyberdeck') { throw 'Lively did not accept the wallpaper.' }
  Write-Host 'Live wallpaper on.'
}

# --- Rainmeter: the skin goes where Rainmeter looks for it, the old sample skins stay off ---
$skin = Join-Path $env:USERPROFILE 'Documents\Rainmeter\Skins\CyberDeck\HUD'
New-Item -ItemType Directory -Force -Path $skin | Out-Null
Copy-Item (Join-Path $root 'rainmeter\HUD.ini') $skin -Force
if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { Start-Process $rm; Start-Sleep 6 }
& $rm '!RefreshApp'
Start-Sleep 3
foreach ($c in 'illustro\Clock', 'illustro\Disk', 'illustro\Google', 'illustro\Network', 'illustro\Recycle Bin', 'illustro\System', 'illustro\Welcome') { & $rm '!DeactivateConfig' $c; Start-Sleep -Milliseconds 200 }
& $rm '!ActivateConfig' 'CyberDeck\HUD' 'HUD.ini'
Start-Sleep 2
$scr = Add-Type -AssemblyName System.Windows.Forms -PassThru | Out-Null
$b = [Windows.Forms.Screen]::PrimaryScreen.Bounds
& $rm '!Move' ([string]($b.Width - 470)) ([string][int]($b.Height * 0.44)) 'CyberDeck\HUD'
& $rm '!Draggable' '0' 'CyberDeck\HUD'
& $rm '!ZPos' '-2' 'CyberDeck\HUD'
& $rm '!WriteKeyValue' 'Rainmeter' 'Update' '1000' (Join-Path $skin 'HUD.ini')
Set-ItemProperty $run 'Rainmeter' "`"$rm`""
Write-Host 'HUD on.'
"Rainmeter running: " + [bool](Get-Process Rainmeter -ErrorAction SilentlyContinue)
"Lively running: " + [bool](Get-Process Lively -ErrorAction SilentlyContinue)
Refresh-Appearance
# Explorer resets the Recycle Bin icon while it starts, so the icons are written once more after that.
Start-Sleep 4
& (Join-Path $root 'apply-icons.ps1')
# The wallpaper keeps playing without Lively's library window, which opens on its own at every launch.
Get-Process 'Lively.UI.WinUI' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
