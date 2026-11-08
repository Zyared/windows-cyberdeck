# Applies the icon set per user, or puts the previous icons back with -Undo.
# The folder and fixed-drive icons that need HKLM are handled in windhawk-settings.ps1.
param([switch]$Undo)
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:USERPROFILE 'CyberDeck'
$icons = Join-Path $root 'icons'
$bak = Join-Path $root 'backup\icons'
$regFile = Join-Path $bak 'registry.json'
New-Item -ItemType Directory -Force -Path $bak | Out-Null

$cl = 'HKCU:\Software\Classes\CLSID'
$ex = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID'
$items = @(
  @("$cl\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon", '(default)', 'thispc'),
  @("$ex\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon", '(default)', 'thispc'),
  @("$cl\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon", '(default)', 'network'),
  @("$cl\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}\DefaultIcon", '(default)', 'home'),
  @("$cl\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}\DefaultIcon", '(default)', 'gallery'),
  @("$ex\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon", '(default)', 'recycle'),
  @("$ex\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon", 'empty', 'recycle'),
  @("$ex\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon", 'full', 'recyclefull'),
  @('HKCU:\Software\Classes\Applications\Explorer.exe\Drives\C\DefaultIcon', '(default)', 'drive'),
  # The library folders in the navigation pane and under This PC have shell items of their own.
  @("$cl\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\DefaultIcon", '(default)', 'desktop'),
  @("$cl\{088e3905-0323-4b02-9826-5d99428e115f}\DefaultIcon", '(default)', 'downloads'),
  @("$cl\{374DE290-123F-4565-9164-39C4925E467B}\DefaultIcon", '(default)', 'downloads'),
  @("$cl\{d3162b92-9365-467a-956b-92703aca08af}\DefaultIcon", '(default)', 'documents'),
  @("$cl\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}\DefaultIcon", '(default)', 'pictures'),
  @("$cl\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}\DefaultIcon", '(default)', 'music'),
  @("$cl\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}\DefaultIcon", '(default)', 'videos'),
  @("$cl\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}\DefaultIcon", '(default)', 'documents'),
  @("$cl\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}\DefaultIcon", '(default)', 'pictures'),
  @("$cl\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}\DefaultIcon", '(default)', 'music'),
  @("$cl\{A0953C92-50DC-43bf-BE83-3742FED03C9C}\DefaultIcon", '(default)', 'videos')
)
# Additional shell surfaces, both namespace views, physical and network drives.
$more=@{
 '{645FF040-5081-101B-9F08-00AA002F954E}'='recycle'
 '{26EE0668-A00A-44D7-9371-BEB064C98683}'='settings'
 '{21EC2020-3AEA-1069-A2DD-08002B30309D}'='settings'
 '{2227A280-3AEA-1069-A2DE-08002B30309D}'='printer'
 '{59031a47-3f72-44a7-89c5-5595fe6b30ee}'='home'
 '{031E4825-7B94-4dc3-B131-E946B44C8DD5}'='documents'
}
foreach($id in $more.Keys){foreach($prefix in $cl,$ex){$items+=,@("$prefix\$id\DefaultIcon",'(default)',$more[$id])}}
foreach($prefix in $cl,$ex){foreach($state in 'empty','full'){
 $items+=,@("$prefix\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon",$state,$(if($state -eq 'full'){'recyclefull'}else{'recycle'}))
}}
foreach($kind in @(@('Folder','folder'),@('Directory','folder'),@('Drive','drive'),@('Unknown','generic'))){
 $items+=,@("HKCU:\Software\Classes\$($kind[0])\DefaultIcon",'(default)',$kind[1])
}
foreach($drive in Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -match '^[A-Z]$'}){
 $items+=,@("HKCU:\Software\Classes\Applications\Explorer.exe\Drives\$($drive.Name)\DefaultIcon",'(default)','drive')
}
# Mirror existing special-folder mappings into Explorer's per-user namespace too.
foreach($item in @($items)){
 if($item[0].StartsWith($cl+'\') -and $item[1] -eq '(default)'){
  $items+=,@($item[0].Replace($cl,$ex),$item[1],$item[2])
 }
}
$seen=@{}; $items=@(foreach($item in $items){$identity=$item[0]+'|'+$item[1];if(-not $seen.ContainsKey($identity)){$seen[$identity]=$true;,$item}})
$dl = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
if (-not $dl) { $dl = Join-Path $env:USERPROFILE 'Downloads' }
$folders = [ordered]@{
  desktop = [Environment]::GetFolderPath('DesktopDirectory'); downloads = $dl; documents = [Environment]::GetFolderPath('MyDocuments')
  pictures = [Environment]::GetFolderPath('MyPictures'); music = [Environment]::GetFolderPath('MyMusic'); videos = [Environment]::GetFolderPath('MyVideos')
}

# Fresh profiles and redirected user folders may not have every known folder.
foreach ($folderName in @($folders.Keys)) {
  if (-not $folders[$folderName] -or -not (Test-Path -LiteralPath $folders[$folderName] -PathType Container)) {
    Write-Host "Folder is not present, skipping desktop.ini: $folderName"
    $folders.Remove($folderName)
  }
}

function Get-Val($key, $name) {
  if (-not (Test-Path $key)) { return $null }
  $it = Get-Item $key
  if ($name -eq '(default)') { return $it.GetValue('', $null, 'DoNotExpandEnvironmentNames') }
  return $it.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
}
function Write-Ini($file, $text) {
  if (Test-Path $file) { (Get-Item $file -Force).Attributes = 'Normal' }
  [IO.File]::WriteAllText($file, $text, [Text.Encoding]::Unicode)
  (Get-Item $file -Force).Attributes = 'Hidden, System'
}

if ($Undo) {
  if (Test-Path $regFile) {
    foreach ($e in (Get-Content $regFile -Raw | ConvertFrom-Json)) {
      if ($null -eq $e.value) {
        if (Test-Path $e.key) { if ($e.name -eq '(default)') { Set-ItemProperty $e.key '(default)' '' } else { Remove-ItemProperty $e.key -Name $e.name -ErrorAction SilentlyContinue } }
      } else {
        New-Item -Path $e.key -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty $e.key $e.name $e.value -Type ExpandString
      }
    }
    # Keys this script created would otherwise keep an empty DefaultIcon.
    foreach ($e in (Get-Content $regFile -Raw | ConvertFrom-Json)) { if ($e.created -and (Test-Path $e.key)) { Remove-Item $e.key -Recurse -Force } }
  }
  foreach ($n in $folders.Keys) {
    $ini = Join-Path $folders[$n] 'desktop.ini'; $saved = Join-Path $bak "$n.ini"
    if (Test-Path $saved) {
      if (Test-Path $ini) { (Get-Item $ini -Force).Attributes = 'Normal' }
      Copy-Item $saved $ini -Force
      (Get-Item $ini -Force).Attributes = 'Hidden, System'
    } elseif (Test-Path (Join-Path $bak "$n.none")) {
      if (Test-Path $ini) { (Get-Item $ini -Force).Attributes = 'Normal'; Remove-Item $ini -Force }
    }
  }
  Write-Host 'Icons restored.'
  return
}

# Backup once, so a repeated run cannot overwrite the originals with themed values.
$known = if (Test-Path $regFile) { @(Get-Content $regFile -Raw | ConvertFrom-Json) } else { @() }
$new = foreach ($i in $items) { if (-not ($known | Where-Object { $_.key -eq $i[0] -and $_.name -eq $i[1] })) { [pscustomobject]@{ key = $i[0]; name = $i[1]; value = (Get-Val $i[0] $i[1]); created = (-not (Test-Path $i[0])) } } }
if ($new) { @($known) + @($new) | ConvertTo-Json | Set-Content $regFile -Encoding UTF8 }
if (-not ($known.Count)) {
  foreach ($n in $folders.Keys) {
    $ini = Join-Path $folders[$n] 'desktop.ini'
    if (Test-Path $ini) { Copy-Item $ini (Join-Path $bak "$n.ini") -Force; (Get-Item (Join-Path $bak "$n.ini") -Force).Attributes = 'Normal' }
    else { Set-Content (Join-Path $bak "$n.none") 'no desktop.ini before' }
  }
}

foreach ($i in $items) {
  # Through .NET with an explicit type: Set-ItemProperty left the Recycle Bin values empty, which blanks its icon.
  $sub = ($i[0] -replace '^HKCU:\\', '')
  $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($sub)
  $name = if ($i[1] -eq '(default)') { '' } else { $i[1] }
  $rk.SetValue($name, ((Join-Path $icons "$($i[2]).ico") + ',0'), 'ExpandString')
  $rk.Close()
}
foreach ($n in $folders.Keys) {
  $dir = $folders[$n]; $ini = Join-Path $dir 'desktop.ini'
  $text = if (Test-Path $ini) { [IO.File]::ReadAllText($ini) } else { "[.ShellClassInfo]`r`n" }
  $lines = @($text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*(IconResource|IconFile|IconIndex)\s*=' })
  if (-not ($lines -match '^\[\.ShellClassInfo\]')) { $lines = @('[.ShellClassInfo]') + $lines }
  $out = foreach ($l in $lines) { $l; if ($l -match '^\[\.ShellClassInfo\]') { 'IconResource=' + (Join-Path $icons "$n.ico") + ',0' } }
  Write-Ini $ini ($out -join "`r`n")
  (Get-Item $dir -Force).Attributes = (Get-Item $dir -Force).Attributes -bor [IO.FileAttributes]::ReadOnly
}
Write-Host 'Icons applied.'
