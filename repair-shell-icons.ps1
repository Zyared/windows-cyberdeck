# Elevated shell metadata overrides. Originals are preserved per value; no DLL patching.
param([switch]$Undo)
$ErrorActionPreference='Stop'
$root=Join-Path $env:USERPROFILE 'CyberDeck'
$backup=Join-Path $root 'backup\shell-metadata.json'
$saved=if(Test-Path $backup){@(Get-Content $backup -Raw|ConvertFrom-Json)}else{@()}
if($Undo){foreach($v in $saved){$k=[Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($v.Key);try{if($null -eq $v.Value){$k.DeleteValue($v.Name,$false)}else{$k.SetValue($v.Name,$v.Value,[Microsoft.Win32.RegistryValueKind]::$($v.Kind))}}finally{$k.Close()}};return}
$changes=@()
$desc='SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions'
foreach($item in Get-ChildItem ('HKLM:\'+$desc)){
 $v=Get-ItemProperty $item.PSPath
 if(-not $v.Icon){continue}
 $icon=switch -Regex ($v.Name){'Desktop'{'desktop';break};'Download'{'downloads';break};'Music'{'music';break};'Picture'{'pictures';break};'Video|RecordedTV'{'videos';break};'Personal|Document'{'documents';break};default{'folder'}}
 $changes+=@{Key=$desc+'\'+$item.PSChildName;Name='Icon';Icon=$icon}
}
# DriveIcons is the shell's dedicated drive override, including mapped drives.
foreach($letter in 'C','D','X','Y','Z'){$changes+=@{Key='SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\DriveIcons\'+$letter+'\DefaultIcon';Name='';Icon='drive'}}
foreach($change in $changes){
 $k=$null
 try{
  $k=[Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($change.Key)
  if(-not @($saved|Where-Object {$_.Key -eq $change.Key -and $_.Name -eq $change.Name}).Count){
   $exists=$k.GetValueNames() -contains $change.Name
   $saved= @($saved) + [pscustomobject]@{Key=$change.Key;Name=$change.Name;Value=$k.GetValue($change.Name,$null,'DoNotExpandEnvironmentNames');Kind=$(if($exists){$k.GetValueKind($change.Name).ToString()}else{'String'})}
   $saved|ConvertTo-Json -Depth 5|Set-Content $backup -Encoding UTF8
  }
  $k.SetValue($change.Name,((Join-Path $root ('icons\'+$change.Icon+'.ico'))+',0'),'String')
  Write-Output ('Applied '+$change.Key)
 }catch{Write-Warning ($change.Key+': '+$_.Exception.Message)}finally{if($k){$k.Close()}}
}
