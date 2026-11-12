# Build a new local package; this script does not install it or touch firmware.
param(
 [Parameter(Mandatory=$true)][string]$Snapshot,
 [Parameter(Mandatory=$true)][string]$LoaderBuild,
 [Parameter(Mandatory=$true)][string]$HackBGRT,
 [Parameter(Mandatory=$true)][string]$Artwork,
 [Parameter(Mandatory=$true)][string]$Splash,
 [Parameter(Mandatory=$true)][string]$Output
)
$ErrorActionPreference='Stop'
$Output=[IO.Path]::GetFullPath($Output)
if(Test-Path -LiteralPath $Output){throw 'Use a new package directory'}
$targets=Get-Content -LiteralPath (Join-Path $LoaderBuild 'targets.json') -Raw | ConvertFrom-Json
if(@($targets | Where-Object {$_.component -eq 'winload' -and $_.sha256 -eq 'cd736797b74b87714cd53d78e5724de3bc7263c3db91e4f9eeb66969ad795443'}).Count -ne 1){throw 'Not the reviewed host build'}
New-Item -ItemType Directory -Path $Output | Out-Null
foreach($dir in @('efi','efi-fonts','windows-fonts')){New-Item -ItemType Directory -Path (Join-Path $Output $dir) | Out-Null}
$files=@()
function Record([string]$Source,[string]$Destination){
 [pscustomobject]@{Source=$Source;Destination=$Destination;SHA256=(Get-FileHash -LiteralPath (Join-Path $Output $Source)).Hash}
}
$copies=@(
 @((Join-Path $LoaderBuild 'arasaka-font-lab.efi'),'grubx64.efi'),
 @((Join-Path $HackBGRT 'efi-signed\bootx64.efi'),'hackbgrt.efi'),
 @((Join-Path $HackBGRT 'shim-signed\shimx64.efi'),'loader.efi'),
 @((Join-Path $HackBGRT 'shim-signed\mmx64.efi'),'mmx64.efi'),
 @($Splash,'splash.bmp')
)
foreach($pair in $copies){
 Copy-Item -LiteralPath $pair[0] -Destination (Join-Path $Output ('efi\'+$pair[1]))
 $files+=Record ('efi\'+$pair[1]) ('ESP:EFI\ArasakaAnim\'+$pair[1])
}
@('boot=\EFI\Microsoft\Boot\bootmgfw.efi','image=path=splash.bmp','resolution=0x0','debug=0','log=0') |
 Set-Content -LiteralPath (Join-Path $Output 'efi\config.txt') -Encoding ascii
$files+=Record 'efi\config.txt' 'ESP:EFI\ArasakaAnim\config.txt'
foreach($kind in @('efi','windows')){
 foreach($name in @('segoe_slboot.ttf','segoen_slboot.ttf')){
  $src=Join-Path $Snapshot ($kind+'-'+$name)
  $relative=$kind+'-fonts\'+$name
  & python (Join-Path $PSScriptRoot 'experimental\make-lab-font.py') $src $Artwork (Join-Path $Output $relative)
  if($LASTEXITCODE){throw 'Font generation failed'}
  $destination='ESP:EFI\Microsoft\aras\fonts\'+$name
  if($kind -eq 'windows'){$destination='Windows:aras\fonts\'+$name}
  $files+=Record $relative $destination
 }
}
$stock=@(Get-Content -LiteralPath (Join-Path $Snapshot 'manifest.json') -Raw | ConvertFrom-Json | ForEach-Object {
 [pscustomobject]@{Path=$_.Source.Replace('C:\Windows','%WINDIR%');SHA256=$_.SHA256}
})
$stock+=@(
 [pscustomobject]@{Path='S:\EFI\HackBGRT\grubx64.efi';SHA256=(Get-FileHash -LiteralPath (Join-Path $HackBGRT 'efi-signed\bootx64.efi')).Hash},
 [pscustomobject]@{Path='S:\EFI\HackBGRT\loader.efi';SHA256=(Get-FileHash -LiteralPath (Join-Path $HackBGRT 'shim-signed\shimx64.efi')).Hash}
)
[pscustomobject]@{Version=1;Created=(Get-Date -Format o);Files=$files;Stock=$stock;Targets=$targets;PhysicalBootTested=$false} |
 ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $Output 'manifest.json') -Encoding UTF8
Write-Output ('Prepared package: '+$Output)
