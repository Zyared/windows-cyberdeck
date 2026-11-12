# Change only HackBGRT's BMP and the documented status-message policy.
param([switch]$Undo)
$ErrorActionPreference='Stop'
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(!$admin){
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'"'
 if($Undo){$arguments+=' -Undo'}
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
 exit $child.ExitCode
}
$root=Join-Path $env:USERPROFILE 'CyberDeck'
$backup=Join-Path $root 'backup\session-art-v2'
New-Item -ItemType Directory -Force $backup | Out-Null
Start-Transcript -Path (Join-Path $backup 'apply.log') -Force | Out-Null
try {
 if(Test-Path 'S:\'){throw 'S: is occupied; refusing to mount the EFI partition'}
 & mountvol.exe S: /S
 if($LASTEXITCODE){throw 'EFI mount failed'}
 try {
  $target='S:\EFI\HackBGRT\splash.bmp'
  $config='S:\EFI\HackBGRT\config.txt'
  if(!(Test-Path $target) -or !(Test-Path $config)){throw 'Installed HackBGRT artwork was not found'}
  $cfg=Get-Content $config -Raw
  $images=@($cfg -split '\r?\n' | Where-Object {$_ -match '^\s*image='})
  if($images.Count -ne 1 -or $images[0] -notmatch '(?i)path=(?:\\EFI\\HackBGRT\\)?splash\.bmp\s*$'){throw 'Unexpected image configuration; no boot files changed'}
  $loaderBefore=(Get-FileHash 'S:\EFI\Microsoft\Boot\bootmgfw.efi').Hash
  $local=Join-Path $root 'HackBGRT\splash.bmp'
  $source=if($Undo){Join-Path $backup 'efi-splash.bmp'}else{Join-Path $root 'boot-v2-splash.bmp'}
  $data=[IO.File]::ReadAllBytes($source)
  if($data.Length -lt 54 -or $data[0] -ne 66 -or $data[1] -ne 77 -or [BitConverter]::ToUInt16($data,28) -ne 24){throw 'Expected 24-bit BMP'}
  if(!$Undo -and !(Test-Path (Join-Path $backup 'efi-splash.bmp'))){
   Copy-Item $target (Join-Path $backup 'efi-splash.bmp')
   Copy-Item $local (Join-Path $backup 'local-splash.bmp')
   Copy-Item $config (Join-Path $backup 'efi-config.txt')
  }
  Copy-Item $source $target -Force
  if((Get-FileHash $source).Hash -ne (Get-FileHash $target).Hash){throw 'EFI artwork verification failed'}
  Copy-Item $(if($Undo){Join-Path $backup 'local-splash.bmp'}else{$source}) $local -Force
  if($loaderBefore -ne (Get-FileHash 'S:\EFI\Microsoft\Boot\bootmgfw.efi').Hash){throw 'Windows loader hash unexpectedly changed'}
  Write-Output "Artwork verified; Windows loader unchanged: $loaderBefore"
 } finally {& mountvol.exe S: /D}
 $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System',$true)
 try {
  $saved=Join-Path $backup 'status-policy.json'
  if($Undo){
   $old=Get-Content $saved -Raw | ConvertFrom-Json
   if($old.Exists){$key.SetValue('DisableStatusMessages',$old.Value,[Microsoft.Win32.RegistryValueKind]::$($old.Kind))}else{$key.DeleteValue('DisableStatusMessages',$false)}
  } else {
   if(!(Test-Path $saved)){
    $exists=$key.GetValueNames() -contains 'DisableStatusMessages'
    [pscustomobject]@{Exists=$exists;Value=$key.GetValue('DisableStatusMessages');Kind=$(if($exists){$key.GetValueKind('DisableStatusMessages').ToString()}else{'DWord'})} | ConvertTo-Json | Set-Content $saved -Encoding UTF8
   }
   $key.SetValue('DisableStatusMessages',1,'DWord')
  }
  Write-Output "DisableStatusMessages=$($key.GetValue('DisableStatusMessages','absent'))"
 }finally{$key.Dispose()}
 Write-Output "SecureBoot=$(Confirm-SecureBootUEFI)"
 & bcdedit /enum '{current}'
 if($LASTEXITCODE){throw 'BCD readback failed'}
}finally{Stop-Transcript | Out-Null}
