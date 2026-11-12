param([Parameter(Mandatory=$true)][string]$Edk2,[Parameter(Mandatory=$true)][string]$Output,[switch]$Control,[switch]$HackBGRT,[switch]$HostBuild,
 [string]$Compiler='C:\Program Files\Windhawk\Compiler\bin')
$ErrorActionPreference='Stop'
if(!(Test-Path -LiteralPath (Join-Path $Output 'font-lab-targets.h'))){throw 'Generate exact lab targets first'}
$header=Get-Content -LiteralPath (Join-Path $Output 'font-lab-targets.h') -Raw
if($HostBuild -and $header -notmatch '#define TARGET_HOST 1'){throw 'Host binary requires the reviewed host fingerprints'}
$object=Join-Path $Output 'loader.obj'
$binary=Join-Path $Output 'arasaka-font-lab.efi'
$mode='-DLAB_PATCH_ENABLED=1'
if($Control){$mode='-DLAB_PATCH_ENABLED=0';$binary=Join-Path $Output 'arasaka-font-control.efi'}
$defines=@($mode,('-DARASAKA_HACKBGRT_CHAIN='+[int]$HackBGRT.IsPresent),('-DARASAKA_HOST_BUILD='+[int]$HostBuild.IsPresent))
if($HostBuild -and !$HackBGRT){throw 'Host build requires the reviewed HackBGRT chain'}
& (Join-Path $Compiler 'clang++.exe') -x c --target=x86_64-w64-windows-gnu -ffreestanding -fno-stack-protector -mno-red-zone -fshort-wchar -O1 -Wall -Wextra -Werror @defines ('-I'+(Join-Path $Edk2 'MdePkg\Include')) ('-I'+(Join-Path $Edk2 'MdePkg\Include\X64')) ('-I'+$Output) -c (Join-Path $PSScriptRoot 'arasaka-font-lab.c') -o $object
if($LASTEXITCODE){throw 'Compile failed'}
& (Join-Path $Compiler 'ld.lld.exe') -flavor link /subsystem:efi_application /entry:EfiMain /nodefaultlib /machine:x64 /dynamicbase /include:arasaka_sbat ('/out:'+$binary) $object
if($LASTEXITCODE){throw 'Link failed'}
Get-FileHash -LiteralPath $binary
