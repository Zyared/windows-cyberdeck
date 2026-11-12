param([switch]$Disable)
$ErrorActionPreference='Stop'
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(!$admin){
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'"'
 if($Disable){$arguments+=' -Disable'}
 $child=Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
 exit $child.ExitCode
}
$home2=Join-Path $env:USERPROFILE 'CyberDeck'
Start-Transcript -Path (Join-Path $home2 'backup\theme-addons.log') -Force | Out-Null
try {
 $root='HKLM:\SOFTWARE\Windhawk\Engine\Mods'
 $mods=@(@('icon-resource-redirect','1.3','explorer.exe'),@('lock-screen-clock-styler','0.6.0','LockApp.exe'))
 if($Disable){
  foreach($mod in $mods){if(Test-Path "$root\$($mod[0])"){Set-ItemProperty "$root\$($mod[0])" Disabled 1; Set-ItemProperty "$root\$($mod[0])" SettingsChangeTime ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())}}
  return
 }
 foreach($mod in $mods){
  $id=$mod[0]; $key="$root\$id"
  if(Test-Path $key){throw "Already installed: $id. Review settings instead of overwriting."}
  $dll=Join-Path $PSScriptRoot "experimental\build\$id.dll"
  if(!(Test-Path $dll)){throw "Build required: $dll"}
 }
 if(!(Test-Path (Join-Path $home2 'icon-resources\theme.ini'))){throw 'Build icon resources first'}
 foreach($mod in $mods){
  $id=$mod[0]; $key="$root\$id"; $library=$id+'_'+$mod[1]+'_arasaka.dll'
  Copy-Item (Join-Path $PSScriptRoot "experimental\build\$id.dll") (Join-Path $env:ProgramData "Windhawk\Engine\Mods\64\$library") -Force
  Copy-Item (Join-Path $PSScriptRoot "vendor\$id.wh.cpp") (Join-Path $env:ProgramData "Windhawk\ModsSource\$id.wh.cpp") -Force
  New-Item "$key\Settings" -Force | Out-Null
  foreach($p in @{LibraryFileName=$library;Include=$mod[2];Exclude='';Architecture='x86-64';Version=$mod[1]}.GetEnumerator()){New-ItemProperty $key $p.Key -Value $p.Value -PropertyType String -Force | Out-Null}
  New-ItemProperty $key Disabled -Value 1 -PropertyType DWord -Force | Out-Null
 }
 $s="$root\icon-resource-redirect\Settings"
 foreach($p in @{iconTheme='';'themePaths[0]'=(Join-Path $home2 'icon-resources');themeFolder=''}.GetEnumerator()){New-ItemProperty $s $p.Key -Value $p.Value -PropertyType String -Force | Out-Null}
 foreach($name in 'allResourceRedirect','disableThumbnails'){New-ItemProperty $s $name -Value 0 -PropertyType DWord -Force | Out-Null}
 New-ItemProperty "$root\lock-screen-clock-styler\Settings" glassOpacity -Value 45 -PropertyType DWord -Force | Out-Null
 # Uses the existing Arasaka rules, including the named Cyberpunk clock elements.
 & (Join-Path $PSScriptRoot 'windhawk-settings.ps1') -WithTranslucent
 foreach($mod in $mods){Set-ItemProperty "$root\$($mod[0])" Disabled 0; New-ItemProperty "$root\$($mod[0])" SettingsChangeTime -Value ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -PropertyType DWord -Force | Out-Null}
} finally {Stop-Transcript | Out-Null}
