# One-shot per-user logon repair; no background loop, elevation or boot changes.
param([switch]$AtLogon)
$ErrorActionPreference='Stop'
if($AtLogon){Start-Sleep -Seconds 15}
$root=Join-Path $env:USERPROFILE 'CyberDeck'
$log=Join-Path $root 'backup\theme-session-last.txt'
try {
 & (Join-Path $root 'apply-arasaka-cursors.ps1')
 . (Join-Path $root 'common.ps1')
 $path=Join-Path $env:ProgramData 'CyberDeck\lockscreen.png'
 if(!(Test-Path $path)){$path=Join-Path $root 'lockscreen.png'}
 $null=[Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]
 $current=[Windows.System.UserProfile.LockScreen]::OriginalImageFile.LocalPath
 if($current -ne $path){Set-LockImage $path}
 @(
  ('Time='+(Get-Date -Format o))
  'Cursors=Arasaka'
  ('LockImage='+[Windows.System.UserProfile.LockScreen]::OriginalImageFile.LocalPath)
 ) | Set-Content $log -Encoding UTF8
}catch{$_ | Out-String | Set-Content $log -Encoding UTF8;throw}
