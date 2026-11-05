# Applies the CYBER//DECK look to Windows. Per-user settings only: no administrator rights, no system files touched.
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
. (Join-Path $src 'common.ps1')

# 1. Backup, once: a second run must not overwrite the original settings with themed ones.
New-Item -ItemType Directory -Force -Path $Home2 | Out-Null
if (-not (Test-Path (Join-Path $BackupDir 'complete.txt'))) {
  New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
  foreach ($b in $RegBackups) { & reg.exe export $b.Key (Join-Path $BackupDir $b.File) /y | Out-Null }
  $desk = Get-ItemProperty 'HKCU:\Control Panel\Desktop'
  @{ WallpaperStyle = $desk.WallpaperStyle; TileWallpaper = $desk.TileWallpaper; Wallpaper = $desk.Wallpaper } | ConvertTo-Json | Set-Content (Join-Path $BackupDir 'desktop.json') -Encoding UTF8
  $cur = Join-Path $env:APPDATA 'Microsoft\Windows\Themes\TranscodedWallpaper'
  if (Test-Path $cur) { Copy-Item $cur (Join-Path $BackupDir 'wallpaper.jpg') -Force }
  try {
    $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
    $uri = [Windows.System.UserProfile.LockScreen]::OriginalImageFile
    if ($uri -and $uri.IsFile -and (Test-Path $uri.LocalPath)) { Copy-Item $uri.LocalPath (Join-Path $BackupDir 'lockscreen-original.img') -Force }
  } catch { Write-Host "Lock screen image not copied: $($_.Exception.Message)" }
  $wt = Get-TerminalSettings
  if ($wt) { Copy-Item $wt (Join-Path $BackupDir 'terminal-settings.json') -Force }
  Set-Content (Join-Path $BackupDir 'complete.txt') (Get-Date -Format s)
  Write-Host 'Backup saved.'
} else { Write-Host 'Backup already exists, keeping the original one.' }
# Keys added in later versions join an existing backup without touching what is already saved.
foreach ($b in $RegBackups) {
  $file = Join-Path $BackupDir $b.File
  if (-not (Test-Path $file)) { & reg.exe export $b.Key $file /y | Out-Null }
}

# 2. Keep everything needed later outside the session folder.
foreach ($f in 'common.ps1', 'restore.ps1', 'apply.ps1', 'apply-live.ps1', 'apply-wallpaper-engine.ps1', 'apply-icons.ps1', 'make-art.ps1', 'make-icons.ps1', 'windhawk-settings.ps1', 'live', 'rainmeter') { if ($src -ne $Home2) { Copy-Item (Join-Path $src $f) $Home2 -Recurse -Force } }
$bat = '@echo off' + "`r`n" + 'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1"' + "`r`n" + 'pause' + "`r`n"
[IO.File]::WriteAllText((Join-Path $Home2 'Restore-Windows-Look.bat'), $bat)

# 3. Artwork.
& (Join-Path $src 'make-art.ps1') -OutDir $Home2
$wall = Join-Path $Home2 'wallpaper.png'

# 4. Colours. Registry colours are stored as ABGR.
function Abgr([byte]$r, [byte]$g, [byte]$b) { [BitConverter]::ToInt32([byte[]]@($r, $g, $b, 255), 0) }
$accent = Abgr 252 238 10
$p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-ItemProperty $p AppsUseLightTheme 0 -Type DWord
Set-ItemProperty $p SystemUsesLightTheme 0 -Type DWord
Set-ItemProperty $p EnableTransparency 1 -Type DWord
Set-ItemProperty $p ColorPrevalence 1 -Type DWord   # accent on Start and the taskbar, using the dark shades of the palette below
$a = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
if (-not (Test-Path $a)) { New-Item $a -Force | Out-Null }
# The last three shades colour Start and the taskbar, so they are near-black with a yellow cast.
[byte[]]$palette = 0xFF,0xFA,0xA8,0xFF, 0xFE,0xF5,0x6A,0xFF, 0xFD,0xF1,0x35,0xFF, 0xFC,0xEE,0x0A,0xFF, 0x4A,0x46,0x06,0xFF, 0x26,0x24,0x05,0xFF, 0x17,0x16,0x05,0xFF, 0xFF,0x00,0x3C,0xFF
Set-ItemProperty $a AccentPalette $palette -Type Binary
Set-ItemProperty $a AccentColorMenu $accent -Type DWord
Set-ItemProperty $a StartColorMenu (Abgr 23 22 5) -Type DWord
$d = 'HKCU:\Software\Microsoft\Windows\DWM'
Set-ItemProperty $d AccentColor $accent -Type DWord
Set-ItemProperty $d ColorizationColor ([BitConverter]::ToInt32([byte[]]@(10, 238, 252, 196), 0)) -Type DWord
Set-ItemProperty $d ColorizationAfterglow ([BitConverter]::ToInt32([byte[]]@(10, 238, 252, 196), 0)) -Type DWord
Set-ItemProperty $d ColorPrevalence 1 -Type DWord   # yellow title bars and window borders
Set-ItemProperty $d EnableWindowColorization 1 -Type DWord

# 5. Cursors: only three roles change, the rest keep the Windows defaults.
$c = 'HKCU:\Control Panel\Cursors'
Set-ItemProperty $c '(default)' 'CyberDeck'
Set-ItemProperty $c Arrow (Join-Path $Home2 'arrow.cur')
Set-ItemProperty $c Hand (Join-Path $Home2 'link.cur')
Set-ItemProperty $c IBeam (Join-Path $Home2 'beam.cur')

# 6. Wallpaper (Fill) and lock screen.
Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
$wk = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
if (-not (Test-Path $wk)) { New-Item $wk -Force | Out-Null }
Set-ItemProperty $wk BackgroundType 0 -Type DWord   # picture mode: slideshow or solid colour would ignore the new image
[CdNative]::SetWallpaper($wall)
try {
  Set-LockImage (Join-Path $Home2 'lockscreen.png')
  Write-Host 'Lock screen set.'
} catch { Write-Host "Lock screen not changed: $($_.Exception.InnerException.Message)$($_.Exception.Message)" }

# 7. Windows Terminal.
$wt = Get-TerminalSettings
if ($wt) {
  try {
    $raw = [IO.File]::ReadAllText($wt)
    $clean = ($raw -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
    $clean = $clean -replace ',(\s*[\]}])', '$1'
    $j = $clean | ConvertFrom-Json
    $scheme = [pscustomobject]@{
      name = 'CyberDeck'; background = '#08080A'; foreground = '#E8E5D0'; cursorColor = '#FCEE0A'; selectionBackground = '#FCEE0A'
      black = '#08080A'; red = '#FF003C'; green = '#FCEE0A'; yellow = '#FCEE0A'; blue = '#00F0FF'; purple = '#FF003C'; cyan = '#00F0FF'; white = '#E8E5D0'
      brightBlack = '#918E74'; brightRed = '#FF4D73'; brightGreen = '#FFF95C'; brightYellow = '#FFF95C'; brightBlue = '#7DF7FF'; brightPurple = '#FF4D73'; brightCyan = '#7DF7FF'; brightWhite = '#FFFFFF'
    }
    $schemes = @(@($j.schemes) | Where-Object { $_ -and $_.name -ne 'CyberDeck' }) + $scheme
    if ($j.PSObject.Properties['schemes']) { $j.schemes = $schemes } else { $j | Add-Member schemes $schemes }
    $defaults = $j.profiles.defaults
    if (-not $defaults) { $defaults = [pscustomobject]@{}; $j.profiles | Add-Member defaults $defaults -Force }
    foreach ($kv in @{ colorScheme = 'CyberDeck'; cursorShape = 'filledBox'; opacity = 94; useAcrylic = $true }.GetEnumerator()) {
      $defaults | Add-Member $kv.Key $kv.Value -Force
    }
    $defaults | Add-Member font ([pscustomobject]@{ face = 'Cascadia Mono' }) -Force
    $json = $j | ConvertTo-Json -Depth 40
    $null = $json | ConvertFrom-Json
    [IO.File]::WriteAllText($wt, $json, (New-Object Text.UTF8Encoding $false))
    Write-Host 'Terminal themed.'
  } catch { Write-Host "Terminal left unchanged: $($_.Exception.Message)" }
}

Refresh-Appearance
Write-Host "Done. To undo: $Home2\Restore-Windows-Look.bat"
