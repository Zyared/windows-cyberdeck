param([switch]$Undo)
$ErrorActionPreference='Stop'
$run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$backup=Join-Path $env:USERPROFILE 'CyberDeck\backup\startup-optimization.json'
New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null
if($Undo){
 $saved=Get-Content $backup -Raw | ConvertFrom-Json
 foreach($item in $saved){New-ItemProperty $run $item.Name -Value $item.Value -PropertyType String -Force | Out-Null}
 return
}
if(Test-Path $backup){throw 'Backup already exists; review before applying again'}
$entries=(Get-Item $run).GetValueNames() | Where-Object {$_ -in @('Spotify','EADM','electron.app.LM Studio','RobloxPlayerBeta') -or $_ -like 'MicrosoftEdgeAutoLaunch_*' -or $_ -like 'YandexBrowserAutoLaunch_*'}
$saved=@($entries | ForEach-Object {[pscustomobject]@{Name=$_;Value=(Get-ItemPropertyValue $run $_)}})
ConvertTo-Json -InputObject $saved | Set-Content $backup -Encoding UTF8
foreach($entry in $entries){Remove-ItemProperty $run $entry}
$saved | Select-Object Name
