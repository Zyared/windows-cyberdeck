# Configures the selected wallpaper backend and optional HUD. Run after apply.ps1.
param(
  [ValidateSet('Lively', 'WallpaperEngine', 'Static')][string]$Wallpaper = 'Lively',
  [switch]$SkipHud, [switch]$SkipWindhawk, [switch]$NoRefresh
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'detect.ps1')
$root = Join-Path $env:USERPROFILE 'CyberDeck'
if (-not $SkipWindhawk) { Invoke-WindhawkSettings '' }
$lively = Find-ArasakaProgram 'Lively'
$rm = Find-ArasakaProgram 'Rainmeter'
if ($Wallpaper -eq 'Lively' -and -not $lively) { throw 'Lively Wallpaper is not installed.' }
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

if ($Wallpaper -eq 'WallpaperEngine') {
  & (Join-Path $root 'apply-wallpaper-engine.ps1')
} elseif ($Wallpaper -eq 'Lively') {
  # --- Lively ---
  $lib = Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\Library\wallpapers\cyberdeck'
  New-Item -ItemType Directory -Force -Path $lib | Out-Null
  # Reload even when this wallpaper was already active, so updated HTML is picked up.
  if (Get-Process Lively -ErrorAction SilentlyContinue) {
    $close = Start-Process $lively -ArgumentList @('closewp', '--monitor', '-1') -PassThru -WindowStyle Hidden
    $close.WaitForExit(15000) | Out-Null
    Start-Sleep 2
  }
  Copy-Item (Join-Path $root 'live\*') $lib -Recurse -Force
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
if (-not $SkipHud -and $rm) {
$skinRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
$configFile = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if (Test-Path -LiteralPath $configFile) {
  $skinMatch = [regex]::Match((Get-Content -LiteralPath $configFile -Raw), '(?mi)^SkinPath=(.+)$')
  if ($skinMatch.Success) { $skinRoot = [Environment]::ExpandEnvironmentVariables($skinMatch.Groups[1].Value.Trim()) }
}
$skin = Join-Path $skinRoot 'CyberDeck\HUD'
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
} elseif (-not $SkipHud) { Write-Host 'Rainmeter not installed: optional HUD skipped. The live wallpaper includes its own clock.' }
if (-not $NoRefresh) { Refresh-Appearance }
# Explorer resets the Recycle Bin icon while it starts, so the icons are written once more after that.
Start-Sleep 4
if (-not $NoRefresh) { & (Join-Path $root 'apply-icons.ps1') }
# Keep any open Lively library window intact.
