$ErrorActionPreference='Stop'
& (Join-Path $env:USERPROFILE 'CyberDeck\Optimize-Startup.ps1') -Undo
$file=Join-Path $env:USERPROFILE 'CyberDeck\backup\power-before-optimization.txt'
$guid=[regex]::Match((Get-Content $file -Raw),'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}').Value
if(!$guid){throw 'Previous power scheme GUID is missing'}
& powercfg /setactive $guid
if($LASTEXITCODE){throw 'Power scheme restore failed'}
Write-Output 'Startup entries and the original power scheme restored.'
