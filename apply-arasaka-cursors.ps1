param([switch]$Undo)
$ErrorActionPreference='Stop'
$root=Join-Path $env:USERPROFILE 'CyberDeck'
$backup=Join-Path $root 'backup\cursors-v2.json'
New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null
$key=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Control Panel\Cursors',$true)
$roles='Arrow','Help','AppStarting','Wait','Crosshair','IBeam','NWPen','No','SizeNS','SizeWE','SizeNWSE','SizeNESW','SizeAll','UpArrow','Hand','Pin','Person'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class ArasakaCursorNative {
 [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr LoadImage(IntPtr instance,string path,uint type,int cx,int cy,uint flags);
 [DllImport("user32.dll")] public static extern bool DestroyCursor(IntPtr cursor);
 [DllImport("user32.dll",SetLastError=true)] public static extern bool SystemParametersInfo(uint action,uint param,IntPtr value,uint flags);
}
'@
try {
 if($Undo){
  foreach($v in (Get-Content $backup -Raw | ConvertFrom-Json)){
   if($v.Exists){$key.SetValue($v.Name,$v.Value,[Microsoft.Win32.RegistryValueKind]::$($v.Kind))}else{$key.DeleteValue($v.Name,$false)}
  }
 }else{
  # Validate all 17 files through the Windows cursor loader before changing any setting.
  $paths=@{}
  foreach($role in $roles){
   $ext=if($role -in 'Wait','AppStarting'){'ani'}else{'cur'}
   $path=Join-Path $root "cursors-v2\$role.$ext"
   $handle=[ArasakaCursorNative]::LoadImage([IntPtr]::Zero,$path,2,0,0,0x10)
   if($handle -eq [IntPtr]::Zero){throw "Windows cannot load cursor: $path"}
   [void][ArasakaCursorNative]::DestroyCursor($handle)
   $paths[$role]=$path
  }
  if(!(Test-Path $backup)){
   $saved=foreach($role in $roles){$exists=$key.GetValueNames() -contains $role;[pscustomobject]@{Name=$role;Exists=$exists;Value=$key.GetValue($role,$null,'DoNotExpandEnvironmentNames');Kind=$(if($exists){$key.GetValueKind($role).ToString()}else{'ExpandString'})}}
   $saved | ConvertTo-Json | Set-Content $backup -Encoding UTF8
  }
  foreach($role in $roles){$key.SetValue($role,$paths[$role],'ExpandString')}
 }
 if(![ArasakaCursorNative]::SystemParametersInfo(0x57,0,[IntPtr]::Zero,2)){throw 'Cursor refresh failed'}
}finally{$key.Dispose()}
Write-Output 'Cursor scheme loaded successfully.'
