# Shared helpers: paths and the Win32 calls that make Windows pick up changes without signing out.
# Outside AppData on purpose: a packaged app's AppData writes are invisible to Explorer and the rest of Windows.
$Home2 = Join-Path $env:USERPROFILE 'CyberDeck'
$BackupDir = Join-Path $Home2 'backup'
$RegBackups = @(
  @{ File = 'cursors.reg';  Key = 'HKCU\Control Panel\Cursors' },
  @{ File = 'personalize.reg'; Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' },
  @{ File = 'dwm.reg';      Key = 'HKCU\Software\Microsoft\Windows\DWM' },
  @{ File = 'accent.reg';   Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' },
  @{ File = 'lock.reg';     Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' },
  @{ File = 'wallpapers.reg'; Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' }
)
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IDesktopWallpaper {
  void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorId, [MarshalAs(UnmanagedType.LPWStr)] string path);
  [return: MarshalAs(UnmanagedType.LPWStr)] string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorId);
  [return: MarshalAs(UnmanagedType.LPWStr)] string GetMonitorDevicePathAt(uint index);
  uint GetMonitorDevicePathCount();
  void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorId, out long rect);
  void SetBackgroundColor(uint color);
  uint GetBackgroundColor();
  void SetPosition(int position);
  int GetPosition();
  void SetSlideshow(IntPtr items);
  void GetSlideshow(out IntPtr items);
  void SetSlideshowOptions(int options, uint tick);
  void GetSlideshowOptions(out int options, out uint tick);
  void AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorId, int direction);
  void GetStatus(out int state);
  void Enable([MarshalAs(UnmanagedType.Bool)] bool enable);
}
[ComImport, Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")] public class DesktopWallpaperCo {}
public static class CdNative {
  [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern bool SystemParametersInfo(uint action, uint param, string pv, uint flags);
  [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
  // Goes through the shell interface: the older SystemParametersInfo call reports success
  // but changes nothing on screen while Windows is in slideshow mode.
  public static void SetWallpaper(string path) {
    var w = (IDesktopWallpaper)new DesktopWallpaperCo();
    w.Enable(true);
    w.SetPosition(4); // Fill
    w.SetWallpaper(null, path);
    SystemParametersInfo(0x14, 0, path, 3);
  }
  public static void ReloadCursors() { SystemParametersInfo(0x57, 0, null, 3); }
  public static void Broadcast(string area) {
    UIntPtr r; SendMessageTimeout((IntPtr)0xFFFF, 0x1A, UIntPtr.Zero, area, 2, 3000, out r);
  }
}
'@
# Windhawk keeps its settings in HKLM, so this one step asks for administrator rights.
function Invoke-WindhawkSettings([string]$Mode) {
  if (-not (Test-Path 'HKLM:\SOFTWARE\Windhawk\Engine\Mods')) { return }
  $args2 = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $Home2 'windhawk-settings.ps1') + '" ' + $(if ($Mode) { $Mode } else { '-WithTranslucent' })
  $process = Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList $args2
  if ($process.ExitCode -ne 0) { throw "Windhawk settings failed (exit $($process.ExitCode))." }
}
function Refresh-Appearance {
  [CdNative]::ReloadCursors()
  foreach ($area in 'ImmersiveColorSet', 'WindowsThemeElement', 'Environment') { [CdNative]::Broadcast($area) }
  # The taskbar and Start keep their colours cached until Explorer restarts. Open folder windows close, programs keep running.
  Stop-Process -Name StartMenuExperienceHost -Force -ErrorAction SilentlyContinue
  Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
  Start-Sleep 2
  # The icon cache would keep showing old icons; Windows rebuilds it on its own.
  # File by file: a cache file can vanish mid-delete, and that error must not stop Explorer from coming back.
  Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer\iconcache_*.db') -Force -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop } catch {} }
  try { Remove-Item (Join-Path $env:LOCALAPPDATA 'IconCache.db') -Force -ErrorAction Stop } catch {}
  Start-Sleep 1
  if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}
# WinRT from Windows PowerShell 5.1: runs an async call and waits for it.
function Wait-Async($op, [Type]$type) {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $m = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
  $t = $m.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(); return $t.Result
}
function Wait-AsyncAction($op) {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $m = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and -not $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
  $t = $m.Invoke($null, @($op)); $t.Wait()
}
function Set-LockImage($path) {
  $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
  $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
  $file = Wait-Async ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
  Wait-AsyncAction ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file))
}
function Get-TerminalSettings {
  $d = Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -Filter 'Microsoft.WindowsTerminal_*' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($d) { $f = Join-Path $d.FullName 'LocalState\settings.json'; if (Test-Path $f) { return $f } }
  return $null
}
