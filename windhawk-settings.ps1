# Writes the CYBER//DECK styles into the Windhawk mod settings and the system folder icons. Needs administrator rights (HKLM).
# -Off disables the mods and removes those icons, -On enables the mods again. Styles stay stored either way.
param([switch]$Off, [switch]$On, [switch]$WithTranslucent, [switch]$NoTray, [string]$LogPath)
$ErrorActionPreference = 'Stop'
if ($LogPath) { Start-Transcript -Path $LogPath -Force | Out-Null }
trap {
  Write-Host ($_ | Out-String)
  if ($LogPath) { Stop-Transcript | Out-Null }
  exit 1
}
$root = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods'
$ids = 'windows-11-start-menu-styler', 'windows-11-file-explorer-styler', 'windows-11-taskbar-styler', 'translucent-windows', 'local@translucent-windows-fork', 'windows-11-notification-center-styler', 'windows-11-settings-styler'
$home2 = Join-Path $env:USERPROFILE 'CyberDeck'
$icons = Join-Path $home2 'icons'
$shellIcons = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'

function Stamp($id) { Set-ItemProperty "$root\$id" SettingsChangeTime ([int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Type DWord }

if ($Off -or $On) {
  foreach ($id in ($ids[0, 1, 2, 5, 6] + 'lock-screen-clock-styler')) { if (Test-Path "$root\$id") { Set-ItemProperty "$root\$id" Disabled ([int][bool]$Off) -Type DWord; Stamp $id } }
  if ($Off) { foreach ($id in $ids[3..4]) { if (Test-Path "$root\$id") { Set-ItemProperty "$root\$id" Disabled 1 -Type DWord; Stamp $id } } }
  if ($Off -and (Test-Path $shellIcons)) { Remove-Item $shellIcons -Recurse -Force }
  Write-Host "Mods disabled: $([bool]$Off)"
  if ($LogPath) { Stop-Transcript | Out-Null }
  return
}

$K = '#08080A'; $Y = '#ED2438'; $R = '#FF5C68'; $T = '#DBDBE0'; $D = '#92929C'
$FONT = 'Bahnschrift'
$Glow = '#33ED2438'; $Faint = '#14ED2438'; $Hair = '#44ED2438'
# Thin neon line that fades from yellow through nothing into red.
$NeonH = '<LinearGradientBrush StartPoint="0,0" EndPoint="1,0"><GradientStop Color="#FFED2438" Offset="0"/><GradientStop Color="#33ED2438" Offset="0.55"/><GradientStop Color="#FFFF5C68" Offset="1"/></LinearGradientBrush>'
# The same idea for a whole frame: bright at two opposite corners, nearly gone between them.
$NeonD = '<LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#FFED2438" Offset="0"/><GradientStop Color="#22ED2438" Offset="0.4"/><GradientStop Color="#22FF5C68" Offset="0.7"/><GradientStop Color="#FFFF5C68" Offset="1"/></LinearGradientBrush>'
$Glass = '<WindhawkBlur BlurAmount="30" TintColor="#EE08090C"/>'
$GlassBar = '<WindhawkBlur BlurAmount="25" TintColor="#EB08090C"/>'
$TabFill = '<LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#55ED2438" Offset="0"/><GradientStop Color="#10ED2438" Offset="1"/></LinearGradientBrush>'
function Uri($n) { 'file:///' + ((Join-Path $icons $n) -replace '\\', '/') }

$start = @(
  # frame: dark frosted glass over the wallpaper, with a hairline neon edge
  @('Border#AcrylicBorder', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0')),
  @('Border#AppBorder, Border#AccentAppBorder', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0')),
  @('Border#AcrylicOverlay', @('Opacity=0')),
  @('Border#LayerBorder, Border#AccentLayerBorder', @('Visibility=Collapsed')),
  @('StartMenu.StartBlendedFlexFrame', @('CornerRadius=0')),
  @('Grid#OuterBorderGrid', @('CornerRadius=0')),
  # search: a tinted strip with a neon underline
  @('Border#TaskbarSearchBackground', @("Background=$Faint", "BorderBrush:=$NeonH", 'BorderThickness=0,0,0,1', 'CornerRadius=0')),
  @('StartMenu.SearchBoxToggleButton > Grid > Border', @("Background=$Faint", "BorderBrush:=$NeonH", 'BorderThickness=0,0,0,1', 'CornerRadius=0')),
  @('StartMenu.SearchBoxToggleButton > Grid > Border#BorderElement', @("Background=$Faint", "BorderBrush:=$NeonH", 'BorderThickness=0,0,0,1', 'CornerRadius=0')),
  @('Cortana.UI.Views.TaskbarSearchPage > Grid#RootGrid@SearchBoxLocationStates > Border#TaskbarSearchBackground', @("Background=$Faint", "BorderBrush:=$NeonH", 'BorderThickness=0,0,0,1', 'CornerRadius=0')),
  @('TextBlock#PlaceholderText', @("Foreground=$Y", "FontFamily=$FONT", 'CharacterSpacing=60', 'Text=ARASAKA / ПОИСК')),
  @('TextBlock#PlaceholderTextContentPresenter', @("Foreground=$Y", "FontFamily=$FONT", 'CharacterSpacing=60', 'Text=ARASAKA / ПОИСК')),
  @('Cortana.UI.Views.CortanaRichSearchBox#SearchTextBox', @("Foreground=$Y", "FontFamily=$FONT")),
  # section headers in HUD style
  @('TextBlock#PinnedListHeaderText', @("Foreground=$Y", "FontFamily=$FONT", 'FontWeight=SemiBold', 'FontSize=17', 'CharacterSpacing=140', 'Text=ARASAKA / ПРИЛОЖЕНИЯ')),
  @('TextBlock[Text=Все]', @("Foreground=$Y", "FontFamily=$FONT", 'FontWeight=SemiBold', 'FontSize=17', 'CharacterSpacing=140', 'Text=// ВСЕ')),
  @('TextBlock#AppDisplayName', @("Foreground=$T", "FontFamily=$FONT")),
  # category plates stay glass until hovered
  @('StartMenu.CategoryControl > Grid > Border', @("Background=$Faint", "BorderBrush=$Hair", 'BorderThickness=1', 'CornerRadius=0')),
  @('Button#FolderPlate > Grid@CommonStates > Border', @("Background@PointerOver=$Glow", "BorderBrush@PointerOver=$Y", 'BorderThickness=1', 'CornerRadius=0')),
  @('StartMenu.CategoryControl > * > TextBlock', @("FontFamily=$FONT", "Foreground=$T")),
  @('Border#ContentBorder@CommonStates > Grid#DroppedFlickerWorkaroundWrapper > Border', @("Background@PointerOver=$Glow", "BorderBrush@PointerOver=$Y", 'BorderThickness=1', 'CornerRadius=0')),
  @('Grid#ContentBorder > Border#BackgroundBorder', @('CornerRadius=0')),
  @('StartDocked.NavigationPaneButton#PowerButton > Grid@CommonStates > Border', @("Background@PointerOver=$R", 'CornerRadius=0')),
  @('StartDocked.NavigationPaneButton#UserTileButton > Grid@CommonStates > Border', @("Background@PointerOver=$Glow", 'CornerRadius=0')),
  @('MenuFlyoutPresenter > Border', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0'))
)
$startVars = @("MenuFlyoutItemBackgroundPointerOver=$Glow", "MenuFlyoutItemForegroundPointerOver=$Y")

# Named visual elements provided by Lock Screen Clock Styler 0.6.x.
$clockMod = 'lock-screen-clock-styler'
$formatMod = 'lockscreen-datetime-format'
$hasClockMod = Test-Path "$root\$clockMod\Settings"
if ($hasClockMod) {
  $hud = 'Grid#WindhawkCyberpunkHUDContainer'
  $start += @(
    @($hud, @('HorizontalAlignment=Left', 'VerticalAlignment=Top', 'Margin=120,160,0,0')),
    @('TextBlock#WindhawkCyberHourText, TextBlock#WindhawkCyberMinText, TextBlock#WindhawkCyberSecText', @("Foreground=$Y", 'FontFamily=Bahnschrift')),
    @('TextBlock#WindhawkCyberDateText, TextBlock#WindhawkCyberBatteryText', @("Foreground=$T")),
    @("$hud > StackPanel > Grid > Border", @('Background=#EE08090C', "BorderBrush=$Y", 'CornerRadius=0')),
    @("$hud > StackPanel > Grid > Grid > Rectangle", @("Fill=$Y")),
    @("$hud > StackPanel > Grid > Border > StackPanel > Rectangle", @("Fill=$Hair")),
    @("$hud > StackPanel > Grid > Border > StackPanel > Grid > TextBlock", @("Foreground=$Y", 'Text=ARASAKA // TIME_SYNC')),
    @("$hud > StackPanel > Grid > Border > StackPanel > Grid > StackPanel > Rectangle", @("Fill=$Y")),
    @("$hud > StackPanel > Grid > Border > StackPanel > Grid > StackPanel > TextBlock", @("Foreground=$T")),
    @("$hud > StackPanel > Grid > Border > StackPanel > StackPanel > Border", @("Background=$Y", 'CornerRadius=0'))
  )
} else {
  # Fallback for installations without the optional clock mod.
  $start += @(
    @('StackPanel#TimeAndDatePanel', @('HorizontalAlignment=Left', 'VerticalAlignment=Top', 'Margin=120,160,0,0', 'Width=620')),
    @('StackPanel#TimePanel', @('HorizontalAlignment=Left')),
    @('StackPanel#TimePanel > TextBlock#Time', @('HorizontalAlignment=Left', "Foreground=$Y", 'FontFamily=Bahnschrift', 'FontSize=112')),
    @('StackPanel#TimeAndDatePanel > TextBlock#Date', @('HorizontalAlignment=Left', "Foreground=$T", 'FontFamily=Bahnschrift', 'FontSize=24'))
  )
}
$explorer = @(
  # everything on top is see-through, so the window backdrop shows through as one sheet of glass
  @('Grid#TabContainerGrid', @('Background=Transparent')),
  @('Microsoft.UI.Xaml.Controls.Grid#TabContainer', @('CornerRadius=0')),
  @('TabViewItem > Grid#LayoutRoot > Canvas > Microsoft.UI.Xaml.Shapes.Path#SelectedBackgroundPath', @("Fill:=$TabFill")),
  @('Microsoft.UI.Xaml.Shapes.Path#LeftRadiusRenderArc', @('Fill=Transparent')),
  @('Microsoft.UI.Xaml.Shapes.Path#RightRadiusRenderArc', @('Fill=Transparent')),
  @('Grid#NavigationBarControlGrid', @('Background=Transparent')),
  @('Microsoft.UI.Xaml.Controls.Grid#FileExplorerAddressBarGrid', @("Background=$Faint", "BorderBrush:=$NeonH", 'BorderThickness=0,0,0,1', 'CornerRadius=0')),
  @('FileExplorerExtensions.AddressBarControl > Grid#PART_LayoutRoot', @('Background=Transparent', 'BorderThickness=0', 'CornerRadius=0')),
  @('AutoSuggestBox#FileExplorerSearchBox > Grid#LayoutRoot > TextBox > Grid@CommonStates > Border#BorderElement', @("Background=$Faint", "BorderBrush:=$NeonH", 'BorderThickness=0,0,0,1', 'CornerRadius=0')),
  @('FileExplorerExtensions.CommandBarControl_Wave1 > Grid, Grid#CommandBarControlRootGrid', @('Background=Transparent', "BorderBrush:=$NeonH", 'BorderThickness=0,0,0,1')),
  @('CommandBar#FileExplorerCommandBar', @('Background=Transparent')),
  @('Microsoft.UI.Xaml.Controls.AppBarButton', @("Foreground=$Y", 'CornerRadius=0')),
  @('Microsoft.UI.Xaml.Controls.AppBarToggleButton', @("Foreground=$Y", 'CornerRadius=0')),
  @('Microsoft.UI.Xaml.Controls.CommandBar > * > Microsoft.UI.Xaml.Controls.TextBlock#TextLabel', @("FontFamily=$FONT", 'CharacterSpacing=30', "Foreground=$T")),
  @('AppBarButton > Grid#Root@CommonStates > Border#AppBarButtonInnerBorder', @("Background@PointerOver=$Glow", 'CornerRadius=0')),
  @('Grid#DetailsViewControlRootGrid', @('Background=Transparent')),
  @('Grid#HomeViewRootGrid', @('Background=Transparent')),
  @('FileExplorerExtensions.GalleryViewControl#GalleryViewControl > Grid', @('Background=Transparent')),
  @('Microsoft.UI.Xaml.Controls.Grid#GalleryRootGrid', @('Background=Transparent')),
  @('StackPanel#DetailsViewThumbnail > Grid', @('Background=Transparent')),
  @('MenuFlyoutPresenter > Border', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0')),
  @('Grid#OuterOverflowContentRootV2 > Grid#OverflowContentRoot > CommandBarOverflowPresenter#SecondaryItemsControl > Grid#LayoutRoot', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0')),
  @('Grid#SecondaryItemsControlShadowWrapper > CommandBarOverflowPresenter#SecondaryItemsControl > Grid#LayoutRoot', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0'))
)
$explorerVars = @(
  "MenuFlyoutItemBackgroundPointerOver=$Glow", "MenuFlyoutItemForegroundPointerOver=$Y",
  "TabViewItemHeaderForegroundSelected=$Y", "TabViewItemIconForegroundSelected=$Y",
  "TabViewItemHeaderCloseButtonForegroundSelected=$Y", "TabViewItemHeaderForeground=$D"
)

$startBtn = 'Taskbar.ExperienceToggleButton#LaunchListButton[AutomationProperties.AutomationId=StartButton]'
$viewBtn = 'Taskbar.ExperienceToggleButton#LaunchListButton[AutomationProperties.AutomationId=TaskViewButton]'
$taskbar = @(
  # bar: frosted glass with a hairline neon top edge
  @('Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundFill', @("Fill:=$GlassBar")),
  @('Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundStroke', @("Fill:=$NeonH", 'Height=1')),
  # own Start and Task View marks
  @("$startBtn > Taskbar.TaskListButtonPanel > Grid > Microsoft.UI.Xaml.Controls.AnimatedVisualPlayer#Icon, $startBtn > Taskbar.TaskListButtonPanel > Microsoft.UI.Xaml.Controls.AnimatedVisualPlayer#Icon", @('Visibility=Collapsed')),
  @("$startBtn > Taskbar.TaskListButtonPanel", @("Background:=<ImageBrush Stretch=`"Uniform`" ImageSource=`"$(Uri 'start.png')`"/>", 'Padding=0')),
  @("$viewBtn > Taskbar.TaskListButtonPanel > Grid > Microsoft.UI.Xaml.Controls.AnimatedVisualPlayer#Icon, $viewBtn > Taskbar.TaskListButtonPanel > Microsoft.UI.Xaml.Controls.AnimatedVisualPlayer#Icon", @('Visibility=Collapsed')),
  @("$viewBtn > Taskbar.TaskListButtonPanel", @("Background:=<ImageBrush Stretch=`"Uniform`" ImageSource=`"$(Uri 'taskview.png')`"/>")),
  # window buttons
  @('Taskbar.TaskListButton', @('CornerRadius=0')),
  @('Grid#IconPanel@CommonStates > Border#BackgroundElement, Taskbar.TaskListLabeledButtonPanel@CommonStates > Border#BackgroundElement', @('CornerRadius=0', "Background@PointerOver=$Glow")),
  @('Taskbar.TaskListButtonPanel@CommonStates > Grid > Border#BackgroundElement, Taskbar.TaskListButtonPanel@CommonStates > Border#BackgroundElement', @('CornerRadius=0', "Background@PointerOver=$Glow")),
  @('Grid#IconPanel@RunningIndicatorStates > Rectangle#RunningIndicator, Taskbar.TaskListLabeledButtonPanel@RunningIndicatorStates > Rectangle#RunningIndicator', @("Fill=$Y", 'Height=2', 'Width=12', 'RadiusX=0', 'RadiusY=0', "Fill@ActiveRunningIndicator=$R", 'Width@ActiveRunningIndicator=28')),
  @('Grid#IconPanel@RunningIndicatorStates > Border#BackgroundElement, Taskbar.TaskListLabeledButtonPanel@RunningIndicatorStates > Border#BackgroundElement', @('CornerRadius=0', "Background@ActiveRunningIndicator=$Faint")),
  # search: no mascot picture, just a tinted strip
  @('SearchUx.SearchUI.SearchBoxButton > SearchUx.SearchUI.SearchButtonRootGrid@CommonStates > Grid > Border#BackgroundElement, SearchUx.SearchUI.SearchBoxButton > SearchUx.SearchUI.SearchButtonRootGrid@CommonStates > Border#BackgroundElement', @("Background=$Faint", "BorderBrush=$Hair", 'BorderThickness=1', 'CornerRadius=0', "Background@PointerOver=$Glow")),
  @('SearchUx.SearchUI.SearchBoxButton > SearchUx.SearchUI.SearchButtonRootGrid > Grid > Grid > Image', @('Visibility=Collapsed')),
  @('Grid#DynamicSearchBoxGleamContainer', @('Visibility=Collapsed')),
  @('SearchUx.SearchUI.SearchBoxButton > SearchUx.SearchUI.SearchButtonRootGrid > Grid > TextBlock, SearchUx.SearchUI.SearchBoxButton > SearchUx.SearchUI.SearchButtonRootGrid > TextBlock', @("Foreground=$Y", "FontFamily=$FONT", 'CharacterSpacing=60')),
  @('TextBlock#SearchBoxTextBlock', @("Foreground=$Y", "FontFamily=$FONT", 'CharacterSpacing=60')),
  # clock and tray
  @('TextBlock#TimeInnerTextBlock', @("Foreground=$Y", "FontFamily=$FONT", 'FontWeight=SemiBold', 'CharacterSpacing=60')),
  @('TextBlock#DateInnerTextBlock', @("Foreground=$T", "FontFamily=$FONT", 'CharacterSpacing=40')),
  @('SystemTray.AdaptiveTextBlock#LanguageInnerTextBlock > TextBlock#InnerTextBlock', @("Foreground=$Y", "FontFamily=$FONT")),
  # Tray glyphs. Only these two targets: a Foreground on SystemTray.ChevronIconView or on a wider TextBlock rule
  # crash-looped Explorer in Windows.UI.Xaml.dll (c000027b), so nothing broader may go here.
  $(if (-not $NoTray) { , @('SystemTray.TextIconContent > Grid#ContainerGrid > SystemTray.AdaptiveTextBlock#Base > TextBlock#InnerTextBlock', @("Foreground=$Y")) }),
  $(if (-not $NoTray) { , @('SystemTray.BatteryIconContent > Grid#ContainerGrid > StackPanel > Grid > TextBlock[1]', @("Foreground=$Y")) }),
  $(if (-not $NoTray) { , @('SystemTray.BatteryIconContent > Grid#ContainerGrid > StackPanel > TextBlock', @("Foreground=$Y")) }),
  @('SystemTray.OmniButton#ControlCenterButton > Grid > Border#BackgroundBorder', @('CornerRadius=0')),
  @('SystemTray.NotifyIconView@CommonStates > Grid#ContainerGrid > Border#BackgroundBorder', @('CornerRadius=0', "Background@PointerOver=$Glow")),
  # hidden tray icons flyout
  @('Border#OverflowFlyoutBackgroundBorder', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0')),
  # thumbnails and right-click menus
  @('Taskbar.TaskbarBackground#HoverFlyoutBackgroundControl > Grid > Rectangle#BackgroundFill', @("Fill:=$Glass")),
  @('Taskbar.TaskbarBackground#HoverFlyoutBackgroundControl > Grid > Rectangle#BackgroundStroke', @("Fill:=$NeonD")),
  @('MenuFlyoutPresenter > Border', @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0'))
)
$taskbar = @($taskbar | Where-Object { $_ })   # the $NoTray switch leaves empty slots
$taskbarVars = @("MenuFlyoutItemBackgroundPointerOver=$Glow", "MenuFlyoutItemForegroundPointerOver=$Y")

# Quick settings with their inner pages (Wi-Fi, Bluetooth, sound), notifications and the calendar.
$panel = @("Background:=$Glass", "BorderBrush:=$NeonD", 'BorderThickness=1', 'CornerRadius=0')
$see = @('Background:=Transparent')
$notify = @(
  # the outer panels carry the glass, so everything inside has to let it through
  @('Grid#ControlCenterRegion', $panel),
  @('Grid#NotificationCenterGrid', $panel),
  @('Grid#CalendarCenterGrid', $panel),
  @('Grid#MediaTransportControlsRegion', $panel),
  @('Border#ToastBackgroundBorder, Border#ToastBackgroundBorder2', $panel),
  @('MenuFlyoutPresenter > Border', $panel),
  @('Grid#L1Grid > Border', @('Background:=Transparent', 'BorderThickness=0')),
  @('ContentPresenter#PageContent', $see),
  @('ContentPresenter#PageContent > Grid > Border', $see),
  @('QuickActions.ControlCenter.AccessibleWindow#PageWindow > ContentPresenter > Grid#FullScreenPageRoot', $see),
  @('QuickActions.ControlCenter.AccessibleWindow#PageWindow > ContentPresenter > Grid#FullScreenPageRoot > ContentPresenter#PageHeader', $see),
  @('ScrollViewer#ListContent', $see),
  @('Grid#MediaTransportControlsRoot', $see),
  @('ActionCenter.FlexibleToastView#FlexibleNormalToastView', $see),
  @('ScrollViewer#CalendarControlScrollViewer', @('Background:=Transparent', 'BorderThickness=0')),
  @('Border#CalendarHeaderMinimizedOverlay', @('Background:=Transparent', 'BorderThickness=0')),
  @('ActionCenter.FocusSessionControl#FocusSessionControl > Grid#FocusGrid', @('Background:=Transparent', 'BorderThickness=0')),
  @('Grid#FooterGrid', @('BorderThickness=0')),
  @('ActionCenter.FlexibleItemView', @('CornerRadius=0'))
)

# The Settings app: black page and one neutral colour for every card, so nothing clashes. The home page is React Native, so it has its own card target.
$Card = '#101013'
$cardStyle = @("Background=$Card", 'CornerRadius=0')
$settingsApp = @(
  @('Windows.UI.Xaml.Controls.Grid#RootPageGrid', @("Background=$K")),
  @('SystemSettings.View.RootPage', @('Background=Transparent')),
  @('Microsoft.UI.Xaml.Controls.NavigationView#PermanentNavigationView', @("Background=$K")),
  @('SplitView#RootSplitView > Grid > Grid#PaneRoot', @('Background=Transparent')),
  @('SplitView#RootSplitView > Grid > Grid#ContentRoot > Border > Grid#ContentGrid', @("Background=$K", "BorderBrush=$Glow", 'BorderThickness=1,1,0,0', 'CornerRadius=0')),
  @('SystemSettings.View.AlignableContentControl#PermanentNavViewHeaderAlignControl > ContentPresenter', @('Background=Transparent')),
  @('SystemSettings.View.ButtonEntityItem > Button#ContainerButton > ContentPresenter#ContentPresenter', $cardStyle),
  @('SystemSettings.View.ExpanderToggleButton#ContainerButton > ContentPresenter#ContentPresenter', $cardStyle),
  @('SystemSettings.View.EntityItem', @("Background=$Card")),
  @('StackPanel#BackgroundStackPanel', @("Background=$Card")),
  @('ContentControl#GridViewItemContentControl > ContentPresenter > Grid', $cardStyle),
  @('Microsoft.ReactNative.ReactRootView > Microsoft.ReactNative.ViewPanel > Microsoft.ReactNative.ViewPanel > Microsoft.ReactNative.ViewPanel > Microsoft.ReactNative.ViewPanel > Border', $cardStyle),
  @('Windows.UI.Xaml.Controls.Primitives.ListViewItemPresenter > Border', @('Background=Transparent', 'CornerRadius=0')),
  @('Windows.UI.Xaml.Controls.StackPanel#SettingsCommandSearchBoxBackground', @("Background=$Card")),
  @('Windows.UI.Xaml.Controls.TextBox#CommandSearchTextBox', @("Background=$Card")),
  @('ContentPresenter#TitleContent > TextBlock', @("Foreground=$T")),
  @('ContentPresenter#SubtitleContent > TextBlock', @("Foreground=$D")),
  @('Microsoft.ReactNative.ViewPanel > TextBlock', @("Foreground=$T"))
)

function Write-Mod($id, $styles, $vars) {
  $key = "$root\$id\Settings"
  if (-not (Test-Path $key)) { Write-Warning "Mod is not installed, skipping: $id"; return }
  foreach ($v in (Get-Item $key).Property) {
    if ($v -match '^(controlStyles|themeResourceVariables)\[') { $writeKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(($key -replace '^HKLM:\\', ''), $true); try { $writeKey.DeleteValue($v, $false) } finally { $writeKey.Close() } }
  }
  for ($i = 0; $i -lt $styles.Count; $i++) {
    Set-ItemProperty $key "controlStyles[$i].target" $styles[$i][0] -Type String
    $list = @($styles[$i][1])
    for ($j = 0; $j -lt $list.Count; $j++) { Set-ItemProperty $key "controlStyles[$i].styles[$j]" $list[$j] -Type String }
  }
  for ($i = 0; $i -lt $vars.Count; $i++) { Set-ItemProperty $key "themeResourceVariables[$i]" $vars[$i] -Type String }
  Set-ItemProperty "$root\$id" Disabled 0 -Type DWord
  Stamp $id
  Write-Host "$id : $($styles.Count) style rules"
}

$bak = Join-Path $home2 'backup\windhawk-mods.reg'
if (-not (Test-Path $bak)) { & cmd.exe /c "reg export HKLM\SOFTWARE\Windhawk\Engine\Mods `"$bak`" /y >nul 2>&1" }
$colors = Join-Path $home2 'backup\colors.reg'
if (-not (Test-Path $colors)) { & cmd.exe /c "reg export `"HKCU\Control Panel\Colors`" `"$colors`" /y >nul 2>&1" }
Write-Mod $ids[0] $start $startVars
if (Test-Path "$root\$($ids[0])") {
  $startKey = Get-Item -LiteralPath "$root\$($ids[0])"
  $included = @(([string]$startKey.GetValue('Include')).Split('|') | Where-Object { $_ })
  if ($included -notcontains 'LockApp.exe') {
    Set-ItemProperty -LiteralPath "$root\$($ids[0])" -Name Include -Value (($included + 'LockApp.exe') -join '|') -Type String
  }
  Stamp $ids[0]
}
# Search results are a web page inside SearchHost, so they take CSS.
$sk = "$root\$($ids[0])\Settings"
if (Test-Path -LiteralPath $sk) {
Set-ItemProperty $sk 'webContentStyles[0].target' 'body' -Type String
Set-ItemProperty $sk 'webContentStyles[0].styles[0]' 'background: transparent !important' -Type String
Set-ItemProperty $sk 'webContentStyles[0].styles[1]' 'color: #DBDBE0 !important' -Type String
Stamp $ids[0]
}
Write-Mod $ids[1] $explorer $explorerVars
# The window backdrop comes from Translucent Windows when it is installed, because only it takes a custom tint.
# Without it, Acrylic is the best frosted backdrop the classic file list can sit on.
$translucent = $ids[3..4] | Where-Object { Test-Path "$root\$_" } | Select-Object -First 1
if (Test-Path "$root\$($ids[1])\Settings") {
  Set-ItemProperty "$root\$($ids[1])\Settings" backgroundTranslucentEffect $(if ($translucent -and $WithTranslucent) { 'none' } else { 'mica' }) -Type String
  Stamp $ids[1]
}
# Off unless asked for: it stays out of Explorer until it has been tested on its own.
if ($translucent -and -not $WithTranslucent) { Set-ItemProperty "$root\$translucent" Include 'explorer.exe' -Type String; Set-ItemProperty "$root\$translucent" Disabled 1 -Type DWord; Stamp $translucent }
if ($translucent -and $WithTranslucent) {
  # Explorer only: by default this mod loads into every process. SysColors stays off, it changes colours system-wide and can outlive the mod.
  Set-ItemProperty "$root\$translucent" Include 'explorer.exe' -Type String
  $ts = "$root\$translucent\Settings"
  Set-ItemProperty $ts 'RenderingMod.ThemeBackground' 1 -Type DWord
  Set-ItemProperty $ts 'RenderingMod.SysColors' 0 -Type DWord
  Set-ItemProperty $ts 'RenderingMod.AccentColorControls' 1 -Type DWord
  Set-ItemProperty $ts 'BackgroundEffects.type' 'acrylicblur' -Type String
  Set-ItemProperty $ts 'BackgroundEffects.AccentBlurBehind' 'EE08090C' -Type String
  Set-ItemProperty $ts 'FlyoutsEffects' 1 -Type DWord
  Set-ItemProperty "$root\$translucent" Disabled 0 -Type DWord
  Stamp $translucent
  Write-Host "$translucent : explorer only, tint EE08090C"
}
if (Test-Path "$root\$($ids[2])") { Write-Mod $ids[2] $taskbar $taskbarVars }
if (Test-Path "$root\$($ids[5])") { Write-Mod $ids[5] $notify $startVars }
if (Test-Path "$root\$($ids[6])") { Write-Mod $ids[6] $settingsApp @() }

# Folder, open folder and fixed drive icons are read from HKLM. The key did not exist before, so -Off simply removes it.
if (-not (Test-Path $shellIcons)) { New-Item $shellIcons -Force | Out-Null }
Set-ItemProperty $shellIcons '3' ((Join-Path $icons 'folder.ico') + ',0') -Type String
Set-ItemProperty $shellIcons '4' ((Join-Path $icons 'folderopen.ico') + ',0') -Type String
Set-ItemProperty $shellIcons '8' ((Join-Path $icons 'drive.ico') + ',0') -Type String
Write-Host 'Shell icons set.'

# Clock Styler draws its own live time and date; the format mod is kept installed
# but disabled while this clock is selected because it formats the hidden stock clock.
if ($hasClockMod) {
  $saved = Join-Path $home2 'backup\lockscreen-mods.reg'
  if (-not (Test-Path -LiteralPath $saved)) {
    & reg.exe export "HKLM\SOFTWARE\Windhawk\Engine\Mods\lock-screen-clock-styler" $saved /y | Out-Null
    if (Test-Path "$root\$formatMod") { & reg.exe export "HKLM\SOFTWARE\Windhawk\Engine\Mods\lockscreen-datetime-format" (Join-Path $home2 'backup\lockscreen-format-mod.reg') /y | Out-Null }
  }
  $clockSettings = "$root\$clockMod\Settings"
  foreach ($pair in @{clockStyle='cyberpunk';timeFormat='24h';clockAlignment='left'}.GetEnumerator()) { Set-ItemProperty -LiteralPath $clockSettings -Name $pair.Key -Value $pair.Value -Type String }
  foreach ($pair in @{showSeconds=1;clockFontSize=80;verticalOffset=0;hideDefaultClock=1;showDateCapsule=1;showBatteryStatus=1;hideDefaultWidgets=0}.GetEnumerator()) { Set-ItemProperty -LiteralPath $clockSettings -Name $pair.Key -Value $pair.Value -Type DWord }
  Set-ItemProperty "$root\$clockMod" Disabled 0 -Type DWord
  Stamp $clockMod
  if (Test-Path "$root\$formatMod") { Set-ItemProperty "$root\$formatMod" Disabled 1 -Type DWord; Stamp $formatMod }
  Write-Host 'Lock Screen Clock Styler: Cyberpunk HUD, 24h + seconds, Arasaka palette rules.'
}
if ($LogPath) { Stop-Transcript | Out-Null }
