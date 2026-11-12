param()
$ErrorActionPreference='Stop'
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(!$admin){
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'"') -Wait -PassThru
 exit $child.ExitCode
}
$out=Join-Path $env:USERPROFILE ('CyberDeck\backup\boot-indicator-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $out | Out-Null
$mounted=$false
try {
 if(Test-Path 'S:\'){throw 'S: is occupied; nothing mounted'}
 & mountvol.exe S: /S
 if($LASTEXITCODE){throw 'Cannot mount system ESP'}
 $mounted=$true
 $manifest=@()
 foreach($pair in @(
  @('S:\EFI\Microsoft\Boot\bootmgfw.efi','efi-bootmgfw.efi'),
  @('S:\EFI\Microsoft\Boot\Fonts\segoe_slboot.ttf','efi-segoe_slboot.ttf'),
  @('S:\EFI\Microsoft\Boot\Fonts\segoen_slboot.ttf','efi-segoen_slboot.ttf'),
  @('C:\Windows\System32\winload.efi','windows-winload.efi'),
  @('C:\Windows\System32\bootvid.dll','windows-bootvid.dll'),
  @('C:\Windows\Boot\Fonts\segoe_slboot.ttf','windows-segoe_slboot.ttf'),
  @('C:\Windows\Boot\Fonts\segoen_slboot.ttf','windows-segoen_slboot.ttf')
 )){
  $source=$pair[0];$dest=Join-Path $out $pair[1]
  Copy-Item -LiteralPath $source -Destination $dest
  $hash=(Get-FileHash -LiteralPath $source).Hash
  if($hash -ne (Get-FileHash -LiteralPath $dest).Hash){throw 'Backup hash mismatch'}
  $sig=Get-AuthenticodeSignature -LiteralPath $source
  $manifest+= [pscustomobject]@{Source=$source;Backup=$pair[1];SHA256=$hash;SignatureStatus=[string]$sig.Status;Version=(Get-Item -LiteralPath $source).VersionInfo.FileVersion}
 }
 $manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $out 'manifest.json') -Encoding UTF8
 & bcdedit.exe /enum all | Out-File (Join-Path $out 'bcd-readonly.txt') -Encoding utf8
 if($LASTEXITCODE){throw 'BCD read failed'}
 & bcdedit.exe /export (Join-Path $out 'BCD-export')
 if($LASTEXITCODE){throw 'BCD backup failed'}
 "SecureBoot=$(Confirm-SecureBootUEFI)" | Set-Content (Join-Path $out 'state.txt')
 Set-Content (Join-Path $env:USERPROFILE 'CyberDeck\backup\boot-indicator-latest.txt') $out
}catch{$_ | Out-String | Set-Content (Join-Path $out 'error.txt');throw}
finally{if($mounted){ & mountvol.exe S: /D; if($LASTEXITCODE){Write-Warning 'ESP unmount failed'}}}
