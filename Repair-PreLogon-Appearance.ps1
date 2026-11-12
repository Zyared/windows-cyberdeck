# Machine-level image and cursors for the desktop before the first user sign-in.
# Clock Styler still belongs to LockApp; this does not promise an early custom clock.
param([switch]$Undo)
$ErrorActionPreference='Stop'
if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'"'
 if($Undo){$arguments+=' -Undo'}
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
 exit $child.ExitCode
}
$root=Join-Path $env:USERPROFILE 'CyberDeck'
$shared=Join-Path $env:ProgramData 'CyberDeck'
$backup=Join-Path $root 'backup\prelogon-appearance.json'
function Open-Key([string]$Hive,[string]$Name){
 if($Hive -eq 'Users'){return [Microsoft.Win32.Registry]::Users.CreateSubKey($Name)}
 if($Hive -eq 'LocalMachine'){return [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($Name)}
 throw 'Unexpected hive'
}
if($Undo){
 foreach($v in (Get-Content $backup -Raw | ConvertFrom-Json)){
  $k=Open-Key $v.Hive $v.Key
  try{if($v.Exists){$k.SetValue($v.Name,$v.Value,[Microsoft.Win32.RegistryValueKind]::$($v.Kind))}else{$k.DeleteValue($v.Name,$false)}}finally{$k.Dispose()}
 }
 Write-Output 'Previous pre-logon settings restored.';return
}
New-Item -ItemType Directory -Path (Join-Path $shared 'cursors-v2') -Force | Out-Null
$changes=@()
$roles='Arrow','Help','AppStarting','Wait','Crosshair','IBeam','NWPen','No','SizeNS','SizeWE','SizeNWSE','SizeNESW','SizeAll','UpArrow','Hand','Pin','Person'
foreach($role in $roles){
 $ext=if($role -in 'Wait','AppStarting'){'ani'}else{'cur'}
 $src=Join-Path $root ("cursors-v2\$role.$ext")
 $dst=Join-Path $shared ("cursors-v2\$role.$ext")
 Copy-Item -LiteralPath $src -Destination $dst -Force
 if((Get-FileHash $src).Hash -ne (Get-FileHash $dst).Hash){throw 'Shared cursor copy mismatch'}
 $changes+=@{Hive='Users';Key='.DEFAULT\Control Panel\Cursors';Name=$role;Value=$dst;Kind='ExpandString'}
}
$image=Join-Path $shared 'lockscreen.png'
Copy-Item -LiteralPath (Join-Path $root 'lockscreen.png') -Destination $image -Force
if((Get-FileHash $image).Hash -ne (Get-FileHash (Join-Path $root 'lockscreen.png')).Hash){throw 'Image hash mismatch'}
$changes+=@{Hive='Users';Key='.DEFAULT\Control Panel\Cursors';Name='';Value='Arasaka';Kind='String'}
# These device settings are experimental on ordinary Windows Pro: Microsoft
# officially limits Personalization CSP there to specific Shared PC modes.
foreach($name in @('LockScreenImagePath','LockScreenImageUrl')){
 $changes+=@{Hive='LocalMachine';Key='SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP';Name=$name;Value=$image;Kind='String'}
}
$changes+=@{Hive='LocalMachine';Key='SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP';Name='LockScreenImageStatus';Value=1;Kind='DWord'}
$changes+=@{Hive='LocalMachine';Key='SOFTWARE\Policies\Microsoft\Windows\Personalization';Name='LockScreenImage';Value=$image;Kind='String'}
if(!(Test-Path $backup)){
 $saved=@(foreach($change in $changes){
  $k=Open-Key $change.Hive $change.Key
  try{$exists=$k.GetValueNames() -contains $change.Name;[pscustomobject]@{Hive=$change.Hive;Key=$change.Key;Name=$change.Name;Exists=$exists;Value=$k.GetValue($change.Name,$null,'DoNotExpandEnvironmentNames');Kind=$(if($exists){$k.GetValueKind($change.Name).ToString()}else{$change.Kind})}}finally{$k.Dispose()}
 })
 ConvertTo-Json -InputObject $saved | Set-Content $backup -Encoding UTF8
}
foreach($change in $changes){
 $k=Open-Key $change.Hive $change.Key
 try{$k.SetValue($change.Name,$change.Value,[Microsoft.Win32.RegistryValueKind]::$($change.Kind));if($k.GetValue($change.Name) -ne $change.Value){throw 'Registry readback failed'}}finally{$k.Dispose()}
}
Write-Output 'Pre-logon image/cursor settings written and verified. Visual confirmation needs next manual boot.'
