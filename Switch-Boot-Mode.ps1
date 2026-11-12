param([ValidateSet('FACEIT','Arasaka')][string]$Mode='FACEIT',[switch]$CheckOnly)
$ErrorActionPreference='Stop'
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(!$admin){
 $argsList='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Mode '+$Mode
 if($CheckOnly){$argsList+=' -CheckOnly'}
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $argsList -Wait -PassThru
 exit $child.ExitCode
}
$folder=Join-Path $env:USERPROFILE 'CyberDeck\backup\boot-switch'
New-Item -ItemType Directory -Force $folder | Out-Null
$firmware=& bcdedit /enum firmware
if($LASTEXITCODE){throw 'Cannot read firmware boot entries'}
$firmware | Set-Content (Join-Path $folder 'latest-before.txt') -Encoding UTF8
if(!(Test-Path (Join-Path $folder 'original.txt'))){$firmware | Set-Content (Join-Path $folder 'original.txt') -Encoding UTF8}
$blocks=($firmware -join "`n") -split '(?:\r?\n){2,}'
$hack=@($blocks | Where-Object {$_ -match '\\EFI\\HackBGRT\\loader\.efi'})
$target='{bootmgr}'
if($Mode -eq 'Arasaka'){
 if($hack.Count -ne 1){throw 'Expected exactly one HackBGRT entry'}
 $target=[regex]::Match($hack[0],'\{[0-9a-fA-F-]{36}\}').Value
 if(!$target){throw 'HackBGRT identifier missing'}
}
if(!$CheckOnly){
 & bcdedit /set '{fwbootmgr}' displayorder $target /addfirst
 if($LASTEXITCODE){throw 'Boot order update failed'}
}
$after=& bcdedit /enum firmware
if($LASTEXITCODE){throw 'Cannot verify firmware boot entries'}
if(!$CheckOnly){
 $fwBlock=@(($after -join "`n") -split '(?:\r?\n){2,}' | Where-Object {$_ -match '\{fwbootmgr\}'})
 if($fwBlock.Count -ne 1 -or $fwBlock[0] -notmatch ('displayorder\s+'+[regex]::Escape($target))){throw 'Boot order verification failed'}
}
@("Mode=$Mode","Target=$target","CheckOnly=$CheckOnly",$after,"SecureBoot=$(Confirm-SecureBootUEFI)") | Set-Content (Join-Path $folder 'result.txt') -Encoding UTF8
