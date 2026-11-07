# Runs the live wallpaper in Wallpaper Engine instead of Lively. Run after apply.ps1, or through apply-live.ps1 -Wallpaper WallpaperEngine.
# -Undo puts back the Wallpaper Engine settings saved on the first run.
param([switch]$Undo)
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:USERPROFILE 'CyberDeck'
$bak = Join-Path $root 'backup\wallpaper-engine-config.json'

# Wallpaper Engine lives in whichever Steam library it was installed to.
function Get-WallpaperEngineDir {
  $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
  if (-not $steam) { return $null }
  $libraries = @($steam)
  $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
  if (Test-Path $vdf) { $libraries += [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' } }
  foreach ($l in $libraries) {
    $dir = Join-Path $l 'steamapps\common\wallpaper_engine'
    if (Test-Path (Join-Path $dir 'wallpaper64.exe')) { return $dir }
  }
  return $null
}

$we = Get-WallpaperEngineDir
if (-not $we) { throw 'Wallpaper Engine not found in the Steam libraries.' }
$exe = Join-Path $we 'wallpaper64.exe'
$cfg = Join-Path $we 'config.json'

if ($Undo) {
  if (-not (Test-Path $bak)) { throw "No backup found: $bak" }
  Get-Process wallpaper32, wallpaper64 -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep 2
  Copy-Item $bak $cfg -Force
  Start-Process $exe
  Write-Host 'Wallpaper Engine settings restored.'
  return
}

# Backup once, so a repeated run cannot overwrite the original selection.
if (-not (Test-Path $bak)) { Copy-Item $cfg $bak -Force; Write-Host 'Wallpaper Engine settings saved.' }

# make-art.ps1 and apply.ps1 leave the page, picture and data in CyberDeck\live.
$project = Join-Path $we 'projects\myprojects\cyberdeck'
New-Item -ItemType Directory -Force -Path $project | Out-Null
foreach ($f in 'index.html', 'base.png', 'data.js', 'thumbnail.jpg') { Copy-Item (Join-Path $root "live\$f") $project -Force }
$manifest = [ordered]@{ file = 'index.html'; preview = 'thumbnail.jpg'; title = 'ARASAKA / Corporate Terminal'; type = 'web'; visibility = 'private' }
[IO.File]::WriteAllText((Join-Path $project 'project.json'), ($manifest | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))

if (-not (Get-Process wallpaper64, wallpaper32 -ErrorAction SilentlyContinue)) { Start-Process $exe; Start-Sleep 8 }
Add-Type -AssemblyName System.Windows.Forms
$file = Join-Path $project 'project.json'
for ($m = 0; $m -lt [Windows.Forms.Screen]::AllScreens.Count; $m++) {
  & $exe -control openWallpaper -file $file -monitor $m
  Start-Sleep 3
}
Write-Host 'Live wallpaper on.'
