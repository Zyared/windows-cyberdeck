param([switch]$Undo)
$ErrorActionPreference='Stop'
$root=Join-Path $env:USERPROFILE 'CyberDeck'
$startup=[Environment]::GetFolderPath('Startup')
$desktop=[Environment]::GetFolderPath('DesktopDirectory')
$links=@(
 @{Path=(Join-Path $startup 'Arasaka Session.lnk');Mode='Startup'},
 @{Path=(Join-Path $desktop 'Arasaka - Shutdown.lnk');Mode='Shutdown'},
 @{Path=(Join-Path $desktop 'Arasaka - Restart.lnk');Mode='Restart'},
 @{Path=(Join-Path $desktop 'Arasaka - Preview.lnk');Mode='Startup'}
)
if($Undo){foreach($item in $links){if(Test-Path -LiteralPath $item.Path){Remove-Item -LiteralPath $item.Path}};return}
if(-not(Test-Path (Join-Path $root 'session-screen.ps1'))){throw 'Apply the theme first.'}
$shell=New-Object -ComObject WScript.Shell
foreach($item in $links){
 $shortcut=$shell.CreateShortcut($item.Path)
 $shortcut.TargetPath="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
 $shortcut.Arguments='-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $root 'session-screen.ps1')+'" -Mode '+$item.Mode
 if($item.Path -like '*Preview.lnk'){$shortcut.Arguments+=' -Preview'}
 $shortcut.WorkingDirectory=$root; $shortcut.WindowStyle=7
 $shortcut.Description='Arasaka session animation. Escape cancels. Power actions allow applications to save.'
 $shortcut.IconLocation=(Join-Path $root 'icons\thispc.ico')+',0'; $shortcut.Save()
}
Write-Host 'Startup animation and desktop power shortcuts installed.'
