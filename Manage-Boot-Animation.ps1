# Exact-build experimental animation. Stock boot files are never overwritten.
param(
 [ValidateSet('Install','Check','TestRoundTrip','ArmTest','CancelTest','Restore')][string]$Action='Check',
 [switch]$Reboot
)
$ErrorActionPreference='Stop'
if($Reboot -and $Action -ne 'ArmTest'){throw '-Reboot is only valid with ArmTest'}
if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Action '+$Action
 if($Reboot){$arguments+=' -Reboot'}
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
 exit $child.ExitCode
}
$base=Join-Path $env:USERPROFILE 'CyberDeck'
$bundle=Join-Path $base 'boot-animation-v1'
$backup=Join-Path $base 'backup\boot-animation-v1'
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$statePath=Join-Path $backup 'state.json'
$state=$null;$mounted=$false;$installing=$false
function Bcd([string[]]$Arguments){
 $lines=@(& bcdedit.exe @Arguments)
 if($LASTEXITCODE){throw "BCDEdit failed: $($Arguments -join ' '): $($lines -join ' ')"}
 return ($lines -join "`n")
}
function Firmware {
 $text=Bcd @('/enum','{fwbootmgr}')
 $match=[regex]::Match($text,'(?m)^displayorder\s+((?:\{[^}]+\}\s*)+)')
 if(!$match.Success){throw 'Cannot parse firmware order'}
 $next=[regex]::Match($text,'(?m)^bootsequence\s+((?:\{[^}]+\}\s*)+)').Groups[1].Value.Trim()
 [pscustomobject]@{Order=@([regex]::Matches($match.Groups[1].Value,'\{[^}]+\}') | ForEach-Object {$_.Value});Next=$next}
}
function Save-State {
 $temp=$statePath+'.tmp'
 $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
 Move-Item -LiteralPath $temp -Destination $statePath -Force
}
function Destination([string]$Relative){
 $roots=@{ESP='S:\';Windows=($env:windir+'\')}
 $parts=$Relative -split ':',2
 if($parts.Count -ne 2 -or !$roots.ContainsKey($parts[0])){throw 'Invalid destination root'}
 $root=$roots[$parts[0]]
 $full=[IO.Path]::GetFullPath((Join-Path $root $parts[1]))
 $allowed=@('S:\EFI\ArasakaAnim\','S:\EFI\Microsoft\aras\fonts\',($env:windir+'\aras\fonts\'))
 if(!@($allowed | Where-Object {$full.StartsWith($_,[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Destination outside animation folders'}
 return $full
}
function Ui-Value {
 $text=Bcd @('/enum',$state.OsId)
 return [regex]::Match($text,'(?m)^bootuxdisabled\s+(\S+)').Groups[1].Value
}
function Restore-Ui {
 if(!$state.UiArmed){return}
 $now=Ui-Value
 if($now -and $now -notmatch '^(No|False|0|Нет)$' -and $now -ne $state.BootUx){throw 'Boot UI was changed elsewhere; not overwriting it'}
 if($state.BootUx){Bcd @('/set',$state.OsId,'bootuxdisabled',$state.BootUx) | Out-Null}
 elseif($now){Bcd @('/deletevalue',$state.OsId,'bootuxdisabled') | Out-Null}
 if((Ui-Value) -ne $state.BootUx){throw 'Boot UI rollback readback failed'}
 $state.UiArmed=$false;Save-State
}
function Clear-OurNext {
 $fw=Firmware
 if($fw.Next -eq $state.Entry){Bcd @('/deletevalue','{fwbootmgr}','bootsequence') | Out-Null}
 elseif($fw.Next){throw 'Another BootNext request exists; it was not overwritten'}
}
function Check-Stock {
 if(!(Confirm-SecureBootUEFI)){throw 'Secure Boot is disabled'}
 foreach($file in $state.Stock){
  $path=$file.Path.Replace('%WINDIR%',$env:windir)
  if((Get-FileHash -LiteralPath $path).Hash -ne $file.SHA256){throw "Stock boot component changed: $path. Review Windows updates first."}
 }
 $text=Bcd @('/enum','{bootmgr}')
 if($text -notmatch '(?im)^path\s+\\EFI\\Microsoft\\Boot\\bootmgfw\.efi\s*$'){throw 'Windows Boot Manager path changed'}
 $text=Bcd @('/enum',$state.OsId)
 if($text -notmatch '(?im)^path\s+\\WINDOWS\\system32\\winload\.efi\s*$'){throw 'Windows loader path changed'}
 $text=Bcd @('/enum','all')
 if($text -match '(?im)^(testsigning|nointegritychecks|debug|bootdebug)\s+(Yes|True|1|Да)\s*$'){throw 'Unexpected boot integrity/debug settings'}
}
function Check-Installed {
 if(!$state -or !$state.Installed){throw 'Animation is not installed'}
 Check-Stock
 foreach($file in $state.Files){
  $path=Destination $file.Destination
  if((Get-FileHash -LiteralPath $path).Hash -ne $file.SHA256){throw "Installed file mismatch: $path"}
 }
 $entry=Bcd @('/enum',$state.Entry)
 if($entry -notmatch '(?im)^path\s+\\EFI\\ArasakaAnim\\loader\.efi\s*$'){throw 'Animation entry path mismatch'}
}
function Remove-Installed {
 if(!$state){throw 'No installation journal'}
 # Stop selecting the experiment before touching any of its files.
 $fw=Firmware
 if($fw.Next -eq $state.Entry){Clear-OurNext}
 if($state.Entry){
  $entries=Bcd @('/enum','firmware')
  if($entries -match [regex]::Escape($state.Entry)){
   $entry=Bcd @('/enum',$state.Entry)
   if($entry -notmatch '(?im)^path\s+\\EFI\\ArasakaAnim\\loader\.efi\s*$' -and $state.Installed){throw 'Entry changed elsewhere; refusing deletion'}
   Bcd @('/delete',$state.Entry) | Out-Null
  }
 }
 Restore-Ui
 $changed=@()
 foreach($file in $state.Files){
  $path=Destination $file.Destination
  if(Test-Path -LiteralPath $path){
   if((Get-FileHash -LiteralPath $path).Hash -ne $file.SHA256){$changed+=$path;continue}
   Remove-Item -LiteralPath $path
  }
 }
 if($changed.Count){throw ('Changed files retained for manual review: '+($changed -join ', '))}
 # Remove only empty, exact directories owned by this installation. No recursion.
 foreach($dir in @('S:\EFI\ArasakaAnim','S:\EFI\Microsoft\aras\fonts','S:\EFI\Microsoft\aras',($env:windir+'\aras\fonts'),($env:windir+'\aras'))){
  if((Test-Path -LiteralPath $dir) -and !(Get-ChildItem -LiteralPath $dir -Force)){Remove-Item -LiteralPath $dir}
 }
 $state.Installed=$false;$state.Restored=(Get-Date -Format o);Save-State
}
Start-Transcript -Path (Join-Path $backup ($Action+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')) | Out-Null
try {
 if(Test-Path -LiteralPath $statePath){$state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json}
 if(Test-Path S:\){throw 'S: is occupied; no EFI volume mounted'}
 & mountvol.exe S: /S
 if($LASTEXITCODE){throw 'ESP mount failed'}
 $mounted=$true
 if($Action -eq 'Restore'){Remove-Installed;Write-Output 'PASS: removed experimental boot entry and owned files; restored boot UI.';return}
 if($Action -eq 'Install'){
  if($state -and $state.Installed){throw 'Already installed; use Check or Restore'}
  $fw=Firmware
  if($fw.Next){throw 'Existing BootNext request; installation deferred'}
  if((Get-CimInstance Win32_ComputerSystem).Model -notlike '*FA507XI*'){throw 'This package is reviewed for this ASUS FA507XI only'}
  $bitlocker=Get-BitLockerVolume -MountPoint $env:SystemDrive
  if([string]$bitlocker.ProtectionStatus -ne 'Off'){throw 'BitLocker protection is active; installation did not alter it'}
  $manifest=Get-Content -LiteralPath (Join-Path $bundle 'manifest.json') -Raw | ConvertFrom-Json
  if($manifest.Version -ne 1){throw 'Unsupported bundle'}
  foreach($file in $manifest.Files){
   $src=[IO.Path]::GetFullPath((Join-Path $bundle $file.Source))
   if(!$src.StartsWith($bundle+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Source outside bundle'}
   if((Get-FileHash -LiteralPath $src).Hash -ne $file.SHA256){throw 'Bundle hash mismatch'}
   if(Test-Path -LiteralPath (Destination $file.Destination)){throw 'Destination already exists; not replacing it'}
  }
  $osText=Bcd @('/enum','{current}','/v')
  $osId=[regex]::Match($osText,'\{[0-9a-fA-F-]{36}\}').Value
  if(!$osId){throw 'Cannot determine OS entry'}
  $ui=[regex]::Match($osText,'(?m)^bootuxdisabled\s+(\S+)').Groups[1].Value
  $state=[pscustomobject]@{Version=1;Created=(Get-Date -Format o);Installed=$false;Entry='';OsId=$osId;BootUx=$ui;UiArmed=$false;OriginalOrder=$fw.Order;Files=$manifest.Files;Stock=$manifest.Stock;Restored=$null}
  Check-Stock
  Bcd @('/export',(Join-Path $backup ('BCD-before-'+(Get-Date -Format 'yyyyMMdd-HHmmss')))) | Out-Null
  Save-State;$installing=$true
  foreach($file in $state.Files){
   $dest=Destination $file.Destination
   New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
   Copy-Item -LiteralPath (Join-Path $bundle $file.Source) -Destination $dest
   if((Get-FileHash -LiteralPath $dest).Hash -ne $file.SHA256){throw 'Copy verification failed'}
  }
  $created=Bcd @('/copy','{bootmgr}','/d','Arasaka Animation (experimental)')
  $state.Entry=[regex]::Match($created,'\{[0-9a-fA-F-]{36}\}').Value
  if(!$state.Entry){throw 'Cannot identify new firmware entry'}
  Save-State
  Bcd @('/set',$state.Entry,'device','partition=S:') | Out-Null
  Bcd @('/set',$state.Entry,'path','\EFI\ArasakaAnim\loader.efi') | Out-Null
  Bcd (@('/set','{fwbootmgr}','displayorder')+@($fw.Order)) | Out-Null
  if(((Firmware).Order -join ',') -ne ($fw.Order -join ',')){throw 'Persistent boot order readback mismatch'}
  $state.Installed=$true;Save-State
  Check-Installed
  $installing=$false
  Write-Output 'PASS: installed separate animation entry and resources. Default order and BootNext unchanged. No reboot.'
  return
 }
 if($Action -eq 'CancelTest'){
  if(!$state){throw 'No journal'}
  Clear-OurNext;Restore-Ui
  Write-Output 'PASS: pending animation boot cancelled; previous boot UI restored.';return
 }
 Check-Installed
 if($Action -eq 'Check'){Write-Output 'PASS: originals and installed hashes verified; Secure Boot enabled. FACEIT itself has not been tested.';return}
 $before=Firmware
 if($before.Next){throw 'BootNext is already set; it was not overwritten'}
 if($Action -eq 'TestRoundTrip' -and $state.UiArmed){throw 'A real test is already armed; cancel it before round-trip testing'}
 try {
  $state.UiArmed=$true;Save-State
  Bcd @('/set',$state.OsId,'bootuxdisabled','No') | Out-Null
  Bcd @('/set','{fwbootmgr}','bootsequence',$state.Entry) | Out-Null
  $after=Firmware
  if($after.Next -ne $state.Entry -or ($after.Order -join ',') -ne ($before.Order -join ',')){throw 'One-time boot readback mismatch'}
  if((Ui-Value) -notmatch '^(No|False|0|Нет)$'){throw 'Boot UI was not enabled'}
  if($Action -eq 'TestRoundTrip'){
   Clear-OurNext;Restore-Ui
   Write-Output 'PASS: animation BootNext set and cleared; boot UI restored; no restart.';return
  }
  Write-Output 'Animation armed for one restart. MOK hash enrollment may require two separate test starts.'
  if($Reboot){& shutdown.exe /r /t 0;if($LASTEXITCODE){throw 'Restart request failed'}}
 } catch {Clear-OurNext;Restore-Ui;throw}
} catch {
 $failure=$_
 if($installing -and $state){try{Remove-Installed}catch{Write-Warning ('Partial rollback: '+$_)}}
 $failure | Out-String | Set-Content -LiteralPath (Join-Path $backup 'last-error.txt') -Encoding UTF8
 throw $failure
} finally {
 if($mounted){& mountvol.exe S: /D}
 Stop-Transcript | Out-Null
}
