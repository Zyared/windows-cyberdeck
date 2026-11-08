# Entry point: run unelevated so all per-user settings belong to the desktop user.
param(
  [ValidateSet('Auto', 'Lively', 'WallpaperEngine', 'Static')][string]$Wallpaper = 'Auto',
  [switch]$CheckOnly,
  [switch]$SkipHud,
  [switch]$SkipWindhawk
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'detect.ps1')

function Invoke-SetupStep([string]$File, [string[]]$StepArguments = @()) {
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $File) @StepArguments
  if ($LASTEXITCODE -ne 0) { throw "$File failed (exit $LASTEXITCODE). Installation is incomplete." }
}

$version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
if ([int]$version.CurrentBuildNumber -lt 22000) { throw 'Arasaka requires Windows 11.' }
if (-not [Environment]::Is64BitProcess) { throw 'Run Install-Arasaka.cmd with 64-bit Windows PowerShell.' }
$lively = Find-ArasakaProgram 'Lively'
$we = Get-WallpaperEngineDir
$rainmeter = Find-ArasakaProgram 'Rainmeter'
$mods = @(Get-ArasakaMods)
$missing = @($mods | Where-Object { -not $_.Installed })
if ($Wallpaper -eq 'Auto') {
  $Wallpaper = if ($lively) { 'Lively' } elseif ($we) { 'WallpaperEngine' } else { 'Static' }
}
Write-Host "ARASAKA / Windows $($version.DisplayVersion) / $env:USERNAME"
Write-Host "Wallpaper: $Wallpaper; Rainmeter available: $([bool]$rainmeter)"
foreach ($mod in $mods) { Write-Host ($mod.Id + ': ' + $(if ($mod.Installed) { $mod.Version } else { 'MISSING' })) }
if ($missing.Count) { Write-Warning 'Install the missing Windhawk mods manually, then rerun this installer. The other theme components can be installed now.' }
if ($CheckOnly) { return }
if ($Wallpaper -eq 'Lively' -and -not $lively) { throw 'Desktop Lively Wallpaper was not found. Install it from livelywallpaper.net, or use -Wallpaper Static.' }
if ($Wallpaper -eq 'WallpaperEngine' -and -not $we) { throw 'Wallpaper Engine was not found in the Steam libraries.' }

$log = Join-Path $PSScriptRoot 'install.log'
Start-Transcript -Path $log -Force | Out-Null
try {
  Write-Host 'Applying the theme. Explorer folder windows will close; no reboot or shutdown is performed.'
  Invoke-SetupStep 'apply.ps1'
  $liveArguments = @('-Wallpaper', $Wallpaper, '-SkipWindhawk', '-NoRefresh')
  if ($SkipHud) { $liveArguments += '-SkipHud' }
  Invoke-SetupStep 'apply-live.ps1' $liveArguments
  if (-not $SkipWindhawk -and @($mods | Where-Object Installed).Count) {
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $env:USERPROFILE 'CyberDeck\windhawk-settings.ps1') + '" -WithTranslucent -LogPath "' + (Join-Path $PSScriptRoot 'windhawk-install.log') + '"'
    $process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Windhawk settings failed (exit $($process.ExitCode))." }
  }
  $registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
  try {
    if (-not $SkipWindhawk) {
      foreach ($mod in $mods | Where-Object Installed) {
        $key = $registry.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\' + $mod.Id + '\Settings')
        try {
          $rules = @($key.GetValueNames() | Where-Object { $_ -match '^controlStyles\[\d+\]\.target$' -and $key.GetValue($_) })
          if ($rules.Count -lt 2) { throw "No theme rules found for $($mod.Id)." }
          Write-Host "$($mod.Id): $($rules.Count) rules verified."
        } finally { if ($key) { $key.Close() } }
      }
    }
  } finally { $registry.Close() }
  Write-Host "Theme files: $env:USERPROFILE\CyberDeck"
  Write-Host "Undo: $env:USERPROFILE\CyberDeck\Restore-Windows-Look.bat"
  if ($missing.Count -and -not $SkipWindhawk) {
    Write-Warning ('Window styling is incomplete. Missing mods: ' + (($missing | ForEach-Object Id) -join ', '))
    Write-Host 'Install them in Windhawk and run Install-Arasaka.cmd again.'
    exit 2
  }
  Write-Host 'Installation completed. Close and reopen Settings / Quick Settings to see their styles.'
} catch {
  Write-Host ($_ | Out-String) -ForegroundColor Red
  Write-Host "Installation is incomplete. Log: $log"
  exit 1
} finally { Stop-Transcript | Out-Null }
