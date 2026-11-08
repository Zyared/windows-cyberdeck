# Dedicated lock-screen composition. The real Windows clock remains above the image.
param(
  [Parameter(Mandatory)][string]$OutDir,
  [int]$Width = 0,
  [int]$Height = 0,
  [switch]$Preview
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
if ($Width -le 0 -or $Height -le 0) {
  $screen = [Windows.Forms.Screen]::PrimaryScreen.Bounds
  $Width = $screen.Width; $Height = $screen.Height
}
if ($Width -lt 320 -or $Height -lt 320) { throw 'The image must be at least 320 x 320.' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$bitmap = New-Object Drawing.Bitmap($Width, $Height)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = 'AntiAlias'
$graphics.TextRenderingHint = 'AntiAliasGridFit'
$graphics.Clear([Drawing.ColorTranslator]::FromHtml('#07090D'))
# Fit the whole design without stretching. Extend the quiet background at other ratios.
$scale = [Math]::Min($Width / 1920.0, $Height / 1080.0)
$graphics.TranslateTransform([single](($Width - 1920 * $scale) / 2), [single](($Height - 1080 * $scale) / 2))
$graphics.ScaleTransform([single]$scale, [single]$scale)
function Draw-Line($Color, $Thickness, $X1, $Y1, $X2, $Y2) {
  $pen = New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml($Color), [single]$Thickness)
  try { $graphics.DrawLine($pen, [single]$X1, [single]$Y1, [single]$X2, [single]$Y2) } finally { $pen.Dispose() }
}
function Draw-Box($Color, $X, $Y, $W, $H) {
  $brush = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml($Color))
  try { $graphics.FillRectangle($brush, [single]$X, [single]$Y, [single]$W, [single]$H) } finally { $brush.Dispose() }
}
function Draw-Text($Text, $Size, $X, $Y, $Color, [string]$Alignment = 'Near') {
  $font = New-Object Drawing.Font('Bahnschrift', [single]$Size, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
  $brush = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml($Color))
  $format = New-Object Drawing.StringFormat
  $format.Alignment = $Alignment
  try { $graphics.DrawString($Text, $font, $brush, (New-Object Drawing.PointF([single]$X, [single]$Y)), $format) }
  finally { $font.Dispose(); $brush.Dispose(); $format.Dispose() }
}

# Peripheral detail only: the upper middle is reserved for the live Windows clock.
for ($x = 0; $x -le 1920; $x += 80) { Draw-Line '#10151D' 1 $x 0 $x 1080 }
for ($y = 0; $y -le 1080; $y += 80) { Draw-Line '#10151D' 1 0 $y 1920 $y }
Draw-Box '#07090D' 630 40 660 340
Draw-Box '#ED2438' 0 0 1920 4
Draw-Line '#501725' 1 48 88 560 88
Draw-Line '#501725' 1 1360 88 1872 88
Draw-Text 'ARASAKA' 30 48 36 '#ED2438'
Draw-Text 'CORPORATE SYSTEMS  /  荒坂' 16 1872 48 '#7D8591' 'Far'
Draw-Text 'NC-01  /  PERSONNEL TERMINAL' 15 48 104 '#626D7C'
Draw-Text 'NIGHT CITY  /  2077' 15 1872 104 '#626D7C' 'Far'

# Architectural side frames guide the eye toward the emblem without crowding the clock.
Draw-Line '#30131D' 1 140 300 140 850
Draw-Line '#30131D' 1 1780 300 1780 850
foreach ($y in 320, 460, 600, 740, 840) {
  Draw-Line '#6B1B2D' 2 140 $y 156 $y
  Draw-Line '#6B1B2D' 2 1764 $y 1780 $y
}
Draw-Text '01 / CORPORATE' 16 188 440 '#7D8591'
Draw-Text 'PERSONNEL ACCESS' 22 188 468 '#D0D3DA'
Draw-Box '#ED2438' 188 510 116 2
Draw-Text 'SECURE YOUR FUTURE.' 15 188 536 '#626D7C'
Draw-Text '荒坂' 58 1730 440 '#8F2334' 'Far'
Draw-Text 'ARASAKA CORPORATION' 15 1730 526 '#7D8591' 'Far'

# Three branches, three circles: the Arasaka emblem.
Draw-Line '#ED2438' 14 960 472 960 660
Draw-Line '#ED2438' 14 960 584 852 504
Draw-Line '#ED2438' 14 960 584 1068 504
$red = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#ED2438'))
try {
  foreach ($point in @(@(928,410), @(820,442), @(1036,442))) {
    $graphics.FillEllipse($red, [single]$point[0], [single]$point[1], [single]64, [single]64)
  }
} finally { $red.Dispose() }
Draw-Text 'ARASAKA' 82 960 690 '#ED2438' 'Center'
Draw-Text 'CORPORATE ACCESS TERMINAL' 18 960 786 '#9BA2AE' 'Center'
Draw-Line '#6B1B2D' 1 700 834 1220 834
Draw-Text 'AUTHORIZED PERSONNEL ONLY' 13 960 854 '#626D7C' 'Center'

# Quiet bottom edge leaves room for Windows status icons and optional widgets.
Draw-Line '#30131D' 1 48 1010 1872 1010
Draw-Text 'PROPERTY OF ARASAKA CORPORATION' 13 48 1032 '#7D8591'
Draw-Text 'CYBERPUNK 2077  //  PERSONAL DESKTOP' 13 1872 1032 '#626D7C' 'Far'
if ($Preview) {
  # Mock placement, not a screenshot of LockApp or an implemented replacement clock.
  Draw-Text (Get-Date -Format 'HH:mm') 112 120 160 '#ED2438'
  Draw-Text (Get-Date -Format 'dddd, d MMMM') 24 124 294 '#E0E3E8'
}
$fileName = if ($Preview) { 'lockscreen-preview.png' } else { 'lockscreen.png' }
try { $bitmap.Save((Join-Path $OutDir $fileName), [Drawing.Imaging.ImageFormat]::Png) }
finally { $graphics.Dispose(); $bitmap.Dispose() }
Write-Host "Lock screen artwork: $(Join-Path $OutDir $fileName)"
