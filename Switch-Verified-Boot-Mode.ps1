param([ValidateSet('FACEIT','Arasaka','Restore')][string]$Mode='FACEIT',[switch]$CheckOnly)
$ErrorActionPreference='Stop'
if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 $argsList='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Mode '+$Mode
 if($CheckOnly){$argsList+=' -CheckOnly'}
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $argsList -Wait -PassThru
 exit $child.ExitCode
}
$folder=Join-Path $env:USERPROFILE 'CyberDeck\backup\boot-switch'
New-Item -ItemType Directory -Force $folder | Out-Null
$snapshot=Join-Path $folder 'verified-baseline-v2.json'
function Read-Firmware {
 $text=& bcdedit.exe /enum firmware
 if($LASTEXITCODE){throw 'Cannot read firmware entries'}
 $blocks=($text -join "`n") -split '(?:\r?\n){2,}'
 $fw=@($blocks | Where-Object {$_ -match '\{fwbootmgr\}'})
 if($fw.Count -ne 1){throw 'Firmware manager not uniquely identified'}
 $match=[regex]::Match($fw[0],'(?m)^displayorder\s+((?:\{[^}]+\}\s*)+)')
 if(!$match.Success){throw 'Cannot parse firmware display order'}
 $order=@([regex]::Matches($match.Groups[1].Value,'\{[^}]+\}') | ForEach-Object {$_.Value})
 [pscustomobject]@{Text=$text;Blocks=$blocks;Order=$order}
}
function Write-Order([string[]]$Order){
 $arguments=@('/set','{fwbootmgr}','displayorder')+$Order
 & bcdedit.exe @arguments | Out-Null
 if($LASTEXITCODE){throw 'Firmware order write failed'}
 if(((Read-Firmware).Order -join ',') -ne ($Order -join ',')){throw 'Firmware order readback mismatch'}
}
$mounted=$false;$before=$null;$changed=$false
try {
 $before=Read-Firmware
 if(!(Confirm-SecureBootUEFI)){throw 'Secure Boot is off; verified mode cannot be reported'}
 $manager=& bcdedit.exe /enum '{bootmgr}'
 if($LASTEXITCODE -or ($manager -join "`n") -notmatch '(?im)^path\s+\\EFI\\Microsoft\\Boot\\bootmgfw\.efi\s*$'){throw 'Nonstandard Windows Boot Manager path'}
 $loader=& bcdedit.exe /enum '{current}'
 if($LASTEXITCODE -or ($loader -join "`n") -notmatch '(?im)^path\s+\\WINDOWS\\system32\\winload\.efi\s*$'){throw 'Nonstandard current Windows loader path'}
 $all=& bcdedit.exe /enum all
 if($LASTEXITCODE){throw 'Cannot inspect BCD policy'}
 if(($all -join "`n") -match '(?im)^(testsigning|nointegritychecks|debug|bootdebug)\s+(Yes|True|1|\u0414\u0430)\s*$'){throw 'Enabled BCD test/debug/integrity-bypass flags found'}
 if(Test-Path 'S:\'){throw 'S: is occupied'}
 & mountvol.exe S: /S
 if($LASTEXITCODE){throw 'Cannot mount system ESP for read-only verification'}
 $mounted=$true
 $paths=@('S:\EFI\Microsoft\Boot\bootmgfw.efi',"$env:windir\System32\winload.efi", "$env:windir\System32\ntoskrnl.exe", "$env:windir\Boot\Fonts\segoe_slboot.ttf", "$env:windir\Boot\Fonts\segoen_slboot.ttf",'S:\EFI\Microsoft\Boot\Fonts\segoe_slboot.ttf','S:\EFI\Microsoft\Boot\Fonts\segoen_slboot.ttf')
 $files=@()
 for($i=0;$i -lt $paths.Count;$i++){
  $path=$paths[$i];$signature=Get-AuthenticodeSignature -LiteralPath $path
  if($i -lt 5 -and $signature.Status -ne 'Valid'){throw "Signature verification failed: $path"}
  $files+= [pscustomobject]@{Path=$path;SHA256=(Get-FileHash -LiteralPath $path).Hash;Signature=[string]$signature.Status}
 }
 if(Test-Path $snapshot){
  $baseline=Get-Content -LiteralPath $snapshot -Raw | ConvertFrom-Json
  if($baseline.Version -ne 2 -or $baseline.Files.Count -ne $files.Count){throw 'Unsupported baseline'}
  foreach($file in $files){
   $old=@($baseline.Files | Where-Object {$_.Path -eq $file.Path})
   if($old.Count -ne 1 -or $old[0].SHA256 -ne $file.SHA256){throw "Boot file changed since baseline: $($file.Path). Review updates/modifications; baseline not overwritten."}
  }
 }else{
  if($Mode -eq 'Restore'){throw 'No verified firmware-order snapshot exists'}
  $baseline=[pscustomobject]@{Version=2;Created=(Get-Date -Format o);Order=$before.Order;Files=$files}
  $baseline | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $snapshot -Encoding UTF8
 }
 $target='{bootmgr}'
 if($Mode -eq 'Arasaka'){
  $hack=@($before.Blocks | Where-Object {$_ -match '\\EFI\\HackBGRT\\loader\.efi'})
  if($hack.Count -ne 1){throw 'Expected exactly one HackBGRT entry'}
  $target=[regex]::Match($hack[0],'\{[0-9a-fA-F-]{36}\}').Value
  if(!$target){throw 'HackBGRT identifier missing'}
 }
 if($Mode -eq 'Restore'){
  $desired=@($baseline.Order)
  foreach($id in $desired){if(($before.Text -join "`n") -notmatch [regex]::Escape($id)){throw "Saved entry no longer exists: $id"}}
 }else{$desired=@($target)+@($before.Order | Where-Object {$_ -ne $target})}
 if(!$CheckOnly){$changed=$true;Write-Order $desired}
 $after=Read-Firmware
 @("Mode=$Mode","CheckOnly=$CheckOnly","SecureBoot=True","VerifiedFiles=$($files.Count)","ExpectedOrder=$($desired -join ',')",$after.Text,'FACEIT itself has not been tested. Restart manually to activate the selected boot path.') | Set-Content (Join-Path $folder 'result.txt') -Encoding UTF8
 Copy-Item (Join-Path $folder 'result.txt') (Join-Path $folder ("last-$Mode-$CheckOnly.txt")) -Force
}catch{
 $failure=$_
 if($changed -and $before){try{Write-Order $before.Order}catch{$_ | Out-String | Set-Content (Join-Path $folder 'rollback-error.txt')}}
 $failure | Out-String | Set-Content (Join-Path $folder 'error.txt')
 throw $failure
}finally{if($mounted){& mountvol.exe S: /D;if($LASTEXITCODE){Write-Warning 'Unmount failed'}}}
