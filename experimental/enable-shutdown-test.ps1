$ErrorActionPreference='Stop'
$principal=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as administrator' }
$key='HKLM:\SOFTWARE\Windhawk\Engine\Mods\arasaka-shutdown-styler'
if (Test-Path $key) { throw 'Already installed; review before replacing a loaded module' }
$source=Join-Path $PSScriptRoot 'build\arasaka-shutdown-styler.dll'
$file='arasaka-shutdown-styler_0.1.0_localtest.dll'
Copy-Item $source "$env:ProgramData\Windhawk\Engine\Mods\64\$file"
New-Item $key -Force | Out-Null
New-ItemProperty $key Disabled -PropertyType DWord -Value 1 -Force | Out-Null
@{LibraryFileName=$file;Include='LogonUI.exe';Exclude='';Architecture='x86-64';Version='0.1.0'}.GetEnumerator() | ForEach-Object {
    New-ItemProperty $key $_.Key -PropertyType String -Value $_.Value -Force | Out-Null
}
New-ItemProperty $key LoggingEnabled -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty $key SettingsChangeTime -PropertyType DWord -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Force | Out-Null
$engine='HKLM:\SOFTWARE\Windhawk\Engine\Settings'
$entry='%systemroot%\system32\logonui.exe'
$include=[string](Get-ItemProperty $engine).Include
if ($entry -notin ($include -split '\|')) {
    Set-ItemProperty $engine Include ((@($include -split '\|' | Where-Object {$_})+$entry) -join '|')
}
Set-ItemProperty $key Disabled 0
Get-FileHash "$env:ProgramData\Windhawk\Engine\Mods\64\$file"
Write-Output 'Shutdown test registered and enabled. No shutdown or restart initiated.'
