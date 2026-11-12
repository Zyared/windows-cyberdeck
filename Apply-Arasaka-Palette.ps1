param([switch]$Undo)
$ErrorActionPreference='Stop'
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(!$admin){
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'"'
 if($Undo){$arguments+=' -Undo'}
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
 exit $child.ExitCode
}
$home2=Join-Path $env:USERPROFILE 'CyberDeck'
$backup=Join-Path $home2 'backup\palette-v3'
New-Item -ItemType Directory -Force $backup | Out-Null
$ids='lock-screen-clock-styler','translucent-windows','windows-11-start-menu-styler','windows-11-file-explorer-styler','windows-11-taskbar-styler','windows-11-notification-center-styler','windows-11-settings-styler'
$root='HKLM:\SOFTWARE\Windhawk\Engine\Mods'
Start-Transcript (Join-Path $backup 'apply.log') -Force | Out-Null
try{
 if($Undo){
  foreach($id in $ids){
   if(!(Test-Path (Join-Path $backup "$id.reg"))){throw "Backup missing: $id"}
  }
  foreach($id in $ids){
   $settings="$root\$id\Settings"
   foreach($name in (Get-Item $settings).GetValueNames()){
    if($name -match '^(controlStyles|themeResourceVariables)\['){Remove-ItemProperty $settings $name}
   }
   & reg.exe import (Join-Path $backup "$id.reg")
   if($LASTEXITCODE){throw "Restore failed: $id"}
   Set-ItemProperty "$root\$id" SettingsChangeTime ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  }
  return
 }
 # Fail before touching installed settings when build inputs or PS5 syntax are invalid.
 $tokens=$null; $parseErrors=$null
 [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'windhawk-settings.ps1'),[ref]$tokens,[ref]$parseErrors)
 if($parseErrors.Count){throw ($parseErrors | Out-String)}
 foreach($dll in 'arasaka-clock-v2.dll','translucent-arasaka-v4.dll'){
  if(!(Test-Path (Join-Path $PSScriptRoot ('experimental\build\'+$dll)))){throw "Build input missing: $dll"}
 }
 foreach($id in $ids){
  $file=Join-Path $backup "$id.reg"
  if(!(Test-Path $file)){
   & reg.exe export ("HKLM\SOFTWARE\Windhawk\Engine\Mods\"+$id) $file /y
   if($LASTEXITCODE){throw "Backup failed: $id"}
  }
 }
 foreach($pair in @(@('lock-screen-clock-styler','arasaka-clock-v2.dll'),@('translucent-windows','translucent-arasaka-v4.dll'))){
  $source=Join-Path $PSScriptRoot ('experimental\build\'+$pair[1])
  $dest=Join-Path $env:ProgramData ('Windhawk\Engine\Mods\64\'+$pair[1])
  if(!(Test-Path $dest) -or (Get-FileHash $source).Hash -ne (Get-FileHash $dest).Hash){Copy-Item $source $dest -Force}
  if((Get-FileHash $source).Hash -ne (Get-FileHash $dest).Hash){throw 'DLL verification failed'}
  Set-ItemProperty "$root\$($pair[0])" LibraryFileName $pair[1] -Type String
 }
 & (Join-Path $PSScriptRoot 'windhawk-settings.ps1') -WithTranslucent
 foreach($id in $ids){Set-ItemProperty "$root\$id" SettingsChangeTime ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())}
 Get-ItemProperty "$root\lock-screen-clock-styler","$root\translucent-windows" | Select-Object PSChildName,LibraryFileName,Disabled | Format-Table
}catch{ $_ | Out-String | Set-Content (Join-Path $backup 'error.txt'); throw }finally{Stop-Transcript | Out-Null}
