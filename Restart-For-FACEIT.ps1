param([ValidateSet('Reboot','TestRoundTrip','Cancel')][string]$Action='TestRoundTrip')
$ErrorActionPreference='Stop'
if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Action '+$Action) -Wait -PassThru
 exit $child.ExitCode
}
$folder=Join-Path $env:USERPROFILE 'CyberDeck\backup\faceit-next-boot'
New-Item -ItemType Directory -Force $folder | Out-Null
function Read-Firmware{
 $lines=& bcdedit.exe /enum '{fwbootmgr}'
 if($LASTEXITCODE){throw 'Cannot read firmware boot manager'}
 $text=$lines -join "`n"
 $next=[regex]::Match($text,'(?m)^bootsequence\s+((?:\{[^}]+\}\s*)+)').Groups[1].Value.Trim()
 $order=[regex]::Match($text,'(?m)^displayorder\s+((?:\{[^}]+\}\s*)+)').Groups[1].Value.Trim()
 if(!$order){throw 'Cannot read persistent boot order'}
 [pscustomobject]@{Next=$next;Order=$order;Text=$text}
}
function Clear-OurNext{
 $current=Read-Firmware
 if(!$current.Next){return}
 if($current.Next -ne '{bootmgr}'){throw 'Another one-time boot target exists; not changing it'}
 & bcdedit.exe /deletevalue '{fwbootmgr}' bootsequence | Out-Null
 if($LASTEXITCODE -or (Read-Firmware).Next){throw 'One-time boot reset failed'}
}
$set=$false
try{
 $before=Read-Firmware
 if($Action -eq 'Cancel'){
  if(!(Test-Path (Join-Path $folder 'pending.json'))){throw 'No pending request created by this script'}
  Clear-OurNext
  Remove-Item -LiteralPath (Join-Path $folder 'pending.json')
  'Pending FACEIT boot cancelled; persistent order unchanged.' | Set-Content (Join-Path $folder 'result.txt')
  return
 }
 if($before.Next){throw 'A one-time firmware boot is already pending. It has not been overwritten.'}
 $manager=& bcdedit.exe /enum '{bootmgr}'
 if($LASTEXITCODE -or ($manager -join "`n") -notmatch '(?im)^path\s+\\EFI\\Microsoft\\Boot\\bootmgfw\.efi\s*$'){throw 'Windows Boot Manager path is not standard'}
 $before.Text | Set-Content (Join-Path $folder 'before.txt') -Encoding UTF8
 & bcdedit.exe /set '{fwbootmgr}' bootsequence '{bootmgr}' | Out-Null
 if($LASTEXITCODE){throw 'Firmware rejected the one-time boot request'}
 $set=$true
 $after=Read-Firmware
 if($after.Next -ne '{bootmgr}' -or $after.Order -ne $before.Order){throw 'One-time boot readback failed'}
 if($Action -eq 'TestRoundTrip'){
  Clear-OurNext
  if((Read-Firmware).Order -ne $before.Order){throw 'Persistent boot order changed'}
  $set=$false
  'PASS: BootNext set to Windows Boot Manager and cleared; persistent order unchanged; no shutdown command executed.' | Set-Content (Join-Path $folder 'test.txt')
  return
 }
 @{Created=(Get-Date -Format o);Target='{bootmgr}'} | ConvertTo-Json | Set-Content (Join-Path $folder 'pending.json')
 'Next boot: Windows Boot Manager. Requesting restart without force-closing applications.' | Set-Content (Join-Path $folder 'result.txt')
 # /t > 0 implies /f. Use zero and no /f so unsaved applications can block restart.
 & shutdown.exe /r /t 0
 if($LASTEXITCODE){throw 'Restart request failed'}
 $set=$false
}catch{
 $failure=$_
 if($set){try{Clear-OurNext}catch{$_ | Out-String | Set-Content (Join-Path $folder 'reset-error.txt')}}
 $failure | Out-String | Set-Content (Join-Path $folder 'error.txt')
 throw $failure
}
