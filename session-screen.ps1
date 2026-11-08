# User-session animation. This does not replace UEFI, Winlogon or the Windows shutdown screen.
param([ValidateSet('Startup','Shutdown','Restart')][string]$Mode='Startup',[switch]$Preview)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" WindowStyle="None" ResizeMode="NoResize" Background="#08090C" Topmost="True" ShowInTaskbar="False" Title="Arasaka session">
 <Viewbox Stretch="Uniform"><Grid Width="1920" Height="1080" Background="#08090C">
  <Rectangle Height="6" Fill="#ED2438" VerticalAlignment="Top"/>
  <TextBlock Text="ARASAKA CORPORATION" Foreground="#ED2438" FontFamily="Bahnschrift" FontSize="26" Margin="80,70,0,0"/>
  <TextBlock Text="NIGHT CITY / PERSONNEL TERMINAL" Foreground="#92929C" FontFamily="Consolas" FontSize="18" Margin="80,112,0,0"/>
  <Canvas Width="360" Height="320" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,220,0,0">
   <Path Data="M180 65 L180 290 M180 205 L60 110 M180 205 L300 110" Stroke="#ED2438" StrokeThickness="21"/>
   <Ellipse Width="86" Height="86" Canvas.Left="137" Canvas.Top="7" Fill="#ED2438"/>
   <Ellipse Width="86" Height="86" Canvas.Left="17" Canvas.Top="57" Fill="#ED2438"/>
   <Ellipse Width="86" Height="86" Canvas.Left="257" Canvas.Top="57" Fill="#ED2438"/>
  </Canvas>
  <TextBlock Text="ARASAKA" Foreground="#ED2438" FontFamily="Bahnschrift" FontWeight="Bold" FontSize="114" HorizontalAlignment="Center" Margin="0,565,0,0"/>
  <TextBlock x:Name="Headline" Text="INITIALIZING PERSONNEL SESSION" Foreground="#DBDBE0" FontFamily="Bahnschrift" FontSize="28" HorizontalAlignment="Center" Margin="0,720,0,0"/>
  <Border Width="720" Height="3" Background="#36131B" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,795,0,0"><Rectangle x:Name="Progress" Width="0" Fill="#ED2438" HorizontalAlignment="Left"/></Border>
  <TextBlock x:Name="Detail" Foreground="#92929C" FontFamily="Consolas" FontSize="17" HorizontalAlignment="Center" Margin="0,825,0,0"/>
  <TextBlock x:Name="Hint" Text="ESC / DISMISS" Foreground="#92929C" FontFamily="Consolas" FontSize="16" Margin="80,1000,0,0"/>
  <TextBlock Text="SECURE YOUR FUTURE. / CYBERPUNK 2077" Foreground="#ED2438" FontFamily="Consolas" FontSize="16" HorizontalAlignment="Right" Margin="0,1000,80,0"/>
 </Grid></Viewbox>
</Window>
'@
$window=[Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
$bounds=[Windows.Forms.Screen]::PrimaryScreen.Bounds
# WPF uses device-independent units. Maximizing avoids pixel/DPI mismatches.
$window.WindowStartupLocation='CenterScreen'; $window.WindowState='Maximized'
$headline=$window.FindName('Headline'); $detail=$window.FindName('Detail'); $progress=$window.FindName('Progress'); $hint=$window.FindName('Hint')
$script:cancelled=$false; $script:completed=$false
$watch=[Diagnostics.Stopwatch]::new()
$seconds=if($Mode -eq 'Startup'){6}else{9}
if($Mode -eq 'Shutdown'){$headline.Text='TERMINATING PERSONNEL SESSION'}
if($Mode -eq 'Restart'){$headline.Text='REINITIALIZING PERSONNEL SESSION'}
if($Mode -ne 'Startup'){$hint.Text='ESC / CANCEL POWER ACTION'}
if($Preview){$hint.Text='PREVIEW / NO POWER ACTION / ESC TO CLOSE'}
$timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromMilliseconds(40)
$timer.Add_Tick({
 $fraction=[Math]::Min([double]1,[double]($watch.Elapsed.TotalSeconds/$seconds)); $progress.Width=720*$fraction
 if($Mode -eq 'Startup'){
  $messages=@('ARASAKA OS / PERSONAL DESKTOP','LOADING CORPORATE INTERFACE','ESTABLISHING PERSONNEL SESSION','WELCOME BACK. SECURE YOUR FUTURE.')
  $detail.Text=$messages[[Math]::Min(3,[int][Math]::Floor($fraction*4))]
 }else{$detail.Text=('{0} IN {1:00}s / ESC TO CANCEL' -f $Mode.ToUpper(),[Math]::Ceiling($seconds-$watch.Elapsed.TotalSeconds))}
 if($fraction -ge 1){$script:completed=$true;$timer.Stop();$window.Close()}
})
$window.Add_KeyDown({if($_.Key -eq 'Escape'){$script:cancelled=$true;$window.Close()}})
$window.Add_Closed({$timer.Stop()})
$window.Add_ContentRendered({$watch.Start();$timer.Start()})
$null=$window.ShowDialog()
if($script:completed -and -not $script:cancelled -and -not $Preview -and $Mode -ne 'Startup'){
 # /t 0 does not imply /f: unsaved applications can block shutdown normally.
 $flag=if($Mode -eq 'Restart'){'/r'}else{'/s'}
 & "$env:SystemRoot\System32\shutdown.exe" $flag /t 0
 if($LASTEXITCODE -ne 0){throw "Windows rejected the power action: $LASTEXITCODE"}
}
