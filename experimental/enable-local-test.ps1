param([switch]$Disable)
$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run as administrator.' }
$key = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\arasaka-logon-styler'
$engine = 'HKLM:\SOFTWARE\Windhawk\Engine\Settings'
$target = '%systemroot%\system32\logonui.exe'
$include = [string](Get-ItemProperty $engine).Include
if ($Disable) {
    if (Test-Path $key) { Set-ItemProperty $key Disabled 1 }
    $shutdownKey = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\arasaka-shutdown-styler'
    if (Test-Path $shutdownKey) { Set-ItemProperty $shutdownKey Disabled 1 }
    $remaining = @($include -split '\|' | Where-Object { $_ -and $_ -ine $target })
    Set-ItemProperty $engine Include ($remaining -join '|')
    Write-Output 'LogonUI mod disabled; explicit injection inclusion removed. Restart Windows manually if needed.'
    exit
}
$dll = Join-Path $PSScriptRoot 'build\arasaka-logon-styler.dll'
if (!(Test-Path $dll)) { throw 'Build with -VmResearchOnly first.' }
if (Test-Path $key) { throw 'Mod already registered; disable/review before replacing.' }
$backup = Join-Path $env:USERPROFILE 'CyberDeck\backup\logon-local-test'
New-Item -ItemType Directory -Force $backup | Out-Null
@{ Include = $include; Time = (Get-Date -Format o); DllHash = (Get-FileHash $dll).Hash } |
    ConvertTo-Json | Set-Content (Join-Path $backup 'before.json') -Encoding UTF8
$name = 'arasaka-logon-styler_0.1.1_localtest.dll'
Copy-Item $dll (Join-Path $env:ProgramData "Windhawk\Engine\Mods\64\$name")
New-Item $key -Force | Out-Null
New-ItemProperty $key Disabled -Value 1 -PropertyType DWord -Force | Out-Null
@{ LibraryFileName=$name; Include='LogonUI.exe'; Exclude=''; Architecture='x86-64'; Version='0.1.1' }.GetEnumerator() | ForEach-Object {
    New-ItemProperty $key $_.Key -Value $_.Value -PropertyType String -Force | Out-Null
}
New-ItemProperty $key LoggingEnabled -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty $key SettingsChangeTime -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -PropertyType DWord -Force | Out-Null
New-Item "$key\Settings" -Force | Out-Null
New-ItemProperty "$key\Settings" enableStyling -Value 1 -PropertyType DWord -Force | Out-Null
if ($target -notin ($include -split '\|')) {
    Set-ItemProperty $engine Include ((@($include -split '\|' | Where-Object { $_ }) + $target) -join '|')
}
Set-ItemProperty $key Disabled 0
Write-Output 'Registered and enabled for LogonUI only; styling=1. No lock or restart performed.'
Get-FileHash (Join-Path $env:ProgramData "Windhawk\Engine\Mods\64\$name")
