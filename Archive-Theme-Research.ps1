# Curated, reproducible research artifacts and installers only. No live theme,
# original recovery backup, app installation, personal document or phone backup.
param([string]$ArchiveRoot='E:\Archives\Arasaka-2026-11-13')
$ErrorActionPreference='Stop'
$work=[IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'Documents\Codex\2026-11-07\c\work'))
$ArchiveRoot=[IO.Path]::GetFullPath($ArchiveRoot)
if(!$ArchiveRoot.StartsWith('E:\Archives\',[StringComparison]::OrdinalIgnoreCase)){throw 'Archive must be below E:\Archives'}
if(Test-Path -LiteralPath $ArchiveRoot){throw 'Use a new archive directory'}
if(Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue){throw 'A lab VM is running'}
$items=@()
foreach($name in @('boot-lab','boot-research-tools','edk2-headers','efiguard-review','shim-source-review','hackbgrt-source-review','HackBGRT-2.6.0','animeboot-review','edge-render','edge-render-v2','boot-v2')){
 $items+=@{Source=(Join-Path $work $name);Relative=('research\'+$name)}
}
$items+=@{Source='D:\Setups\Noita build 12082024 by FreeTP';Relative='installers\Noita build 12082024 by FreeTP'}
foreach($name in @('open_server_panel_5_4_3_setup(1).exe','ghidra_12.2_PUBLIC_20261016.zip','BsgLauncher.15.1.0.4653.exe','YChromeSetup.exe','incy-windows-setup (1).exe','incy-windows-setup.exe','SirusLauncher-2.0.8.exe','msys2-x86_64-20260611.exe','lghub_installer.exe','denwer-master.zip','volatility3-win-exes-2.28.2.zip','wordpress-7.1.zip')){
 $items+=@{Source=('D:\Dowland\'+$name);Relative=('installers\Downloads-D\'+$name)}
}
foreach($name in @('setup-Happ.x64.exe','FACEITInstaller_64.exe')){
 $items+=@{Source=(Join-Path $env:USERPROFILE ('Downloads\'+$name));Relative=('installers\Downloads-C\'+$name)}
}
$allow=@($items | ForEach-Object {[IO.Path]::GetFullPath($_.Source)})
$active=@(Get-CimInstance Win32_Process | Where-Object {$_.ExecutablePath} | ForEach-Object {$_.ExecutablePath})
New-Item -ItemType Directory -Path $ArchiveRoot | Out-Null
$local=Join-Path $env:USERPROFILE 'CyberDeck\backup\archive-20261113'
New-Item -ItemType Directory -Path $local -Force | Out-Null
$journal=@();$total=0L
foreach($item in $items){
 $source=[IO.Path]::GetFullPath($item.Source)
 if(!(Test-Path -LiteralPath $source)){continue}
 $target=[IO.Path]::GetFullPath((Join-Path $ArchiveRoot $item.Relative))
 if($source -notin $allow -or !$target.StartsWith($ArchiveRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Resolved path outside reviewed move plan'}
 if(@($active | Where-Object {$_ -eq $source -or $_.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase)}).Count){throw "Active application under $source"}
 $entry=Get-Item -LiteralPath $source -Force
 if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse point: $source"}
 $isDirectory=$entry.PSIsContainer
 if($isDirectory){
  if(Get-ChildItem -LiteralPath $source -Recurse -Force -Attributes ReparsePoint){throw 'Source contains links; not archiving automatically'}
  $files=@(Get-ChildItem -LiteralPath $source -File -Recurse -Force)
  New-Item -ItemType Directory -Path $target | Out-Null
  & robocopy.exe $source $target /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ /NFL /NDL /NP /NJH /NJS > (Join-Path $local 'copy-last.log')
  if($LASTEXITCODE -ge 8){throw "Copy failed; original retained: $source"}
 }else{
  $files=@($entry)
  New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $target
 }
 $verified=@(foreach($file in $files){
  $relative=if($isDirectory){$file.FullName.Substring($source.Length+1)}else{$file.Name}
  $dest=if($isDirectory){Join-Path $target $relative}else{$target}
  $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  if((Get-Item -LiteralPath $dest -Force).Length -ne $file.Length -or (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $hash){throw "Verification failed; original retained: $($file.FullName)"}
  [pscustomobject]@{Relative=$relative;Length=$file.Length;SHA256=$hash}
 })
 if($isDirectory -and @(Get-ChildItem -LiteralPath $source -Recurse -File -Force).Count -ne $files.Count){throw 'Source changed during copy; retained'}
 $record=[pscustomobject]@{Source=$source;Destination=$target;Files=$verified;SourceRemoved=$false}
 $journal+=$record
 ConvertTo-Json -InputObject $journal -Depth 6 | Set-Content -LiteralPath (Join-Path $local 'manifest.json') -Encoding UTF8
 Copy-Item -LiteralPath (Join-Path $local 'manifest.json') -Destination (Join-Path $ArchiveRoot 'manifest.json') -Force
 # Re-check resolved absolute boundaries immediately before removal. Only copied,
 # hash-verified, explicitly listed roots can be recursively removed.
 $resolved=(Get-Item -LiteralPath $source -Force).FullName
 if($resolved -notin $allow -or $target -notlike ($ArchiveRoot+'\*')){throw 'Move boundary verification failed'}
 if($isDirectory){Remove-Item -LiteralPath $resolved -Recurse -Force}else{Remove-Item -LiteralPath $resolved -Force}
 if(Test-Path -LiteralPath $source){throw 'Source removal incomplete'}
 $record.SourceRemoved=$true
 $bytes=($verified | Measure-Object Length -Sum).Sum;$total+=$bytes
 ConvertTo-Json -InputObject $journal -Depth 6 | Set-Content -LiteralPath (Join-Path $local 'manifest.json') -Encoding UTF8
 Copy-Item -LiteralPath (Join-Path $local 'manifest.json') -Destination (Join-Path $ArchiveRoot 'manifest.json') -Force
 Write-Output ("Moved and SHA256 verified: $source -> $target ($bytes bytes)")
}
@("Archive=$ArchiveRoot","FreedBytes=$total",'Active CyberDeck, boot rollback and unique phone backups stayed on C:/D:.','Destination NTFS had an unrelated damaged directory index; offline repair still required.') | Set-Content -LiteralPath (Join-Path $local 'result.txt') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $local 'result.txt') -Destination (Join-Path $ArchiveRoot 'README.txt')
Write-Output "Total freed: $total bytes"
