# Builds an isolated Windows RE boot directory. Never edits the system BCD/ESP.
param(
 [Parameter(Mandatory=$true)][string]$LabRoot,
 [Parameter(Mandatory=$true)][string]$WinrePath,
 [Parameter(Mandatory=$true)][string]$BootManagerPath
)
$ErrorActionPreference='Stop'
if(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 throw 'Run elevated: BCDEdit requires administrator rights even for a separate store.'
}
$LabRoot=[IO.Path]::GetFullPath($LabRoot)
$allowed=[IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'Documents\Codex'))+'\'
if(!$LabRoot.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){
 throw 'Lab must be inside the Codex workspace, never an EFI or Windows directory.'
}
if(Test-Path -LiteralPath $LabRoot){throw 'Choose a new empty lab directory; existing labs are not overwritten.'}
foreach($path in @($WinrePath,$BootManagerPath)){
 if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw "Source missing: $path"}
}
New-Item -ItemType Directory -Path $LabRoot | Out-Null
$log=Join-Path $LabRoot 'prepare.log'
Start-Transcript -Path $log | Out-Null
try {
 $boot=Join-Path $LabRoot 'EFI\Microsoft\Boot'
 foreach($relative in @('EFI\Boot','EFI\Microsoft\Boot','Boot','sources')){
  New-Item -ItemType Directory -Path (Join-Path $LabRoot $relative) -Force | Out-Null
 }
 Copy-Item -LiteralPath $WinrePath -Destination (Join-Path $LabRoot 'sources\boot.wim')
 Copy-Item -LiteralPath $BootManagerPath -Destination (Join-Path $LabRoot 'EFI\Boot\bootx64.efi')
 Copy-Item -LiteralPath $BootManagerPath -Destination (Join-Path $boot 'bootmgfw.efi')
 Copy-Item -LiteralPath "$env:windir\Boot\DVD\EFI\boot.sdi" -Destination (Join-Path $LabRoot 'Boot\boot.sdi')
 Copy-Item -LiteralPath "$env:windir\Boot\EFI\bootmgr.efi" -Destination (Join-Path $LabRoot 'bootmgr.efi')
 Copy-Item -LiteralPath "$env:windir\Boot\DVD\EFI\en-US\efisys_noprompt.bin" -Destination (Join-Path $LabRoot 'efisys.bin')
 Copy-Item -LiteralPath "$env:windir\Boot\Fonts" -Destination (Join-Path $boot 'Fonts') -Recurse
 Copy-Item -LiteralPath "$env:windir\Boot\Resources" -Destination (Join-Path $boot 'Resources') -Recurse
 # Secure Boot requires the signed boot policies as well as the EFI binaries.
 foreach($name in @('boot.stl','boot.pnd.stl','winsipolicy.p7b','SecureBootRecovery.efi')){
  Copy-Item -LiteralPath (Join-Path "$env:windir\Boot\EFI" $name) -Destination (Join-Path $boot $name)
 }
 Copy-Item -LiteralPath "$env:windir\Boot\EFI\CIPolicies" -Destination (Join-Path $boot 'CIPolicies') -Recurse
 foreach($locale in @('en-US','ru-RU')){
  $mui=Join-Path "$env:windir\Boot\EFI" $locale
  if(Test-Path -LiteralPath $mui){Copy-Item -LiteralPath $mui -Destination (Join-Path $boot $locale) -Recurse}
 }
 $store=Join-Path $boot 'BCD'
 & bcdedit.exe /createstore $store
 if($LASTEXITCODE){throw 'Could not create the lab BCD store'}
 function LabBcd([string[]]$BcdArguments){
  & bcdedit.exe /store $store @BcdArguments
  if($LASTEXITCODE){throw "Lab BCDEdit failed: $($BcdArguments -join ' ')"}
 }
 $loader='{'+[guid]::NewGuid().ToString()+'}'
 LabBcd @('/create','{bootmgr}','/d','Isolated Windows RE boot lab')
 LabBcd @('/set','{bootmgr}','device','boot')
 LabBcd @('/create','{ramdiskoptions}','/d','Lab RAM disk')
 LabBcd @('/set','{ramdiskoptions}','ramdisksdidevice','boot')
 LabBcd @('/set','{ramdiskoptions}','ramdisksdipath','\Boot\boot.sdi')
 LabBcd @('/create',$loader,'/d','Windows RE baseline (lab only)','/application','osloader')
 foreach($name in @('device','osdevice')){
  LabBcd @('/set',$loader,$name,'ramdisk=[boot]\sources\boot.wim,{ramdiskoptions}')
 }
 LabBcd @('/set',$loader,'path','\Windows\System32\Boot\winload.efi')
 LabBcd @('/set',$loader,'systemroot','\Windows')
 LabBcd @('/set',$loader,'winpe','yes')
 LabBcd @('/set',$loader,'detecthal','yes')
 LabBcd @('/set',$loader,'bootmenupolicy','standard')
 LabBcd @('/set','{bootmgr}','default',$loader)
 LabBcd @('/set','{bootmgr}','displayorder',$loader)
 LabBcd @('/set','{bootmgr}','timeout','0')
 LabBcd @('/enum','all')
 Copy-Item -LiteralPath $store -Destination (Join-Path $LabRoot 'Boot\BCD')
 $originalHash=(Get-FileHash -LiteralPath $WinrePath).Hash
 if((Get-FileHash -LiteralPath (Join-Path $LabRoot 'sources\boot.wim')).Hash -ne $originalHash){throw 'WinRE copy hash mismatch'}
 $bootHash=(Get-FileHash -LiteralPath $BootManagerPath).Hash
 if((Get-FileHash -LiteralPath (Join-Path $LabRoot 'EFI\Boot\bootx64.efi')).Hash -ne $bootHash){throw 'Boot Manager copy hash mismatch'}
 [pscustomobject]@{WinreSource=$WinrePath;WinreHash=$originalHash;BootManagerSource=$BootManagerPath;BootManagerHash=$bootHash;Loader=$loader;SystemBootChanged=$false} |
  ConvertTo-Json | Set-Content -LiteralPath (Join-Path $LabRoot 'manifest.json') -Encoding UTF8
} finally {Stop-Transcript | Out-Null}
