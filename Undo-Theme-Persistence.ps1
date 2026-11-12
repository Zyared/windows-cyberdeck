# Undo only the 2026-11-13 persistence changes; no restart or boot modification.
$ErrorActionPreference='Stop'
$root=Join-Path $env:USERPROFILE 'CyberDeck'
Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'CyberDeck Theme Restore' -ErrorAction SilentlyContinue
$backup=Join-Path $root 'backup\cursor-persistence.json'
if(Test-Path $backup){
 foreach($v in (Get-Content $backup -Raw | ConvertFrom-Json)){
  $k=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($v.Key)
  try{if($v.Exists){$k.SetValue($v.Name,$v.Value,[Microsoft.Win32.RegistryValueKind]::$($v.Kind))}else{$k.DeleteValue($v.Name,$false)}}finally{$k.Dispose()}
 }
}
if(Test-Path (Join-Path $root 'backup\prelogon-appearance.json')){
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'Repair-PreLogon-Appearance.ps1') -Undo
 if($LASTEXITCODE -ne 0){throw 'Pre-logon settings rollback failed'}
}
# Restore this single preference, preserving subsequent Wallpaper Engine changes.
$config='D:\SteamLibrary\steamapps\common\wallpaper_engine\config.json'
$saved=Join-Path $root 'backup\persistence-20261113\wallpaper-engine-before.json'
if((Test-Path $config) -and (Test-Path $saved)){
 $old=Get-Content $saved -Raw | ConvertFrom-Json
 $running=Get-Process wallpaper64,wallpaper32 -ErrorAction SilentlyContinue
 $exe=@($running | ForEach-Object {$_.Path}) | Select-Object -First 1
 $running | Stop-Process
 try{
  $now=Get-Content $config -Raw | ConvertFrom-Json
  $now.Zyared.general.user.overridelockscreen=$old.Zyared.general.user.overridelockscreen
  $json=ConvertTo-Json -InputObject $now -Depth 100
  [IO.File]::WriteAllText($config,$json,(New-Object Text.UTF8Encoding($false)))
 }finally{if($exe){Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden}}
}
Write-Output 'Theme persistence changes undone. Boot animation was not changed.'
