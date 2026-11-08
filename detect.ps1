# Read-only dependency detection shared by setup and the live layer.
function Find-ArasakaProgram([string]$Name) {
  $processName = if ($Name -eq 'Rainmeter') { 'Rainmeter' } else { 'Lively' }
  $candidates = @()
  foreach ($process in @(Get-Process $processName -ErrorAction SilentlyContinue)) {
    try { if ($process.Path) { $candidates += $process.Path } } catch {}
  }
  foreach ($base in @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
    if ($base) {
      $relative = if ($Name -eq 'Rainmeter') { 'Rainmeter\Rainmeter.exe' } else { 'Lively Wallpaper\Lively.exe' }
      $candidates += Join-Path $base $relative
    }
  }
  foreach ($file in $candidates | Select-Object -Unique) {
    if ((Test-Path -LiteralPath $file -PathType Leaf) -and $file -notmatch '\\WindowsApps\\') { return $file }
  }
  return $null
}

function Get-WallpaperEngineDir {
  $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
  if (-not $steam) { return $null }
  $libraries = @($steam)
  $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
  if (Test-Path -LiteralPath $vdf) {
    $libraries += [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' }
  }
  foreach ($library in $libraries | Select-Object -Unique) {
    $folder = Join-Path $library 'steamapps\common\wallpaper_engine'
    if (Test-Path -LiteralPath (Join-Path $folder 'wallpaper64.exe')) { return $folder }
  }
  return $null
}

function Get-ArasakaMods {
  $ids = 'windows-11-start-menu-styler', 'windows-11-file-explorer-styler', 'windows-11-taskbar-styler', 'windows-11-notification-center-styler', 'windows-11-settings-styler'
  $registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
  try {
    foreach ($id in $ids) {
      $key = $registry.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\' + $id)
      try { [pscustomobject]@{ Id = $id; Installed = ($null -ne $key); Version = if ($key) { $key.GetValue('Version') } else { $null } } }
      finally { if ($key) { $key.Close() } }
    }
  } finally { $registry.Close() }
}
