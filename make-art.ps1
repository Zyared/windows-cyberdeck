# Draws the CYBER//DECK wallpaper, lock screen and cursors. All artwork is generated here, nothing is downloaded.
param([Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$colY = [Drawing.Color]::FromArgb(237, 36, 56)
$colR = [Drawing.Color]::FromArgb(255, 92, 104)
$colC = [Drawing.Color]::FromArgb(219, 219, 224)
$colK = [Drawing.Color]::FromArgb(8, 8, 10)
function A($color, $alpha) { [Drawing.Color]::FromArgb($alpha, $color) }
function Brush($color) { New-Object Drawing.SolidBrush $color }
function P($x, $y) { New-Object Drawing.PointF([single]$x, [single]$y) }

function Get-Font($size) {
  $fam = (New-Object Drawing.Text.InstalledFontCollection).Families | Where-Object { $_.Name -eq 'Bahnschrift' }
  $name = 'Bahnschrift SemiBold Condensed'
  $f = New-Object Drawing.Font($name, [single]$size, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
  if ($f.Name -ne $name) { $f = New-Object Drawing.Font($(if ($fam) { 'Bahnschrift' } else { 'Segoe UI' }), [single]$size, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel) }
  return $f
}

function Draw-Scene($W, $H, [bool]$Lock, $Path) {
  $bmp = New-Object Drawing.Bitmap($W, $H)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.Clear([Drawing.Color]::FromArgb(8,9,12))
  $g.ScaleTransform([single]($W/1920), [single]($H/1080))
  function Box($x,$y,$w,$h,$hex) { $g.FillRectangle((Brush ([Drawing.ColorTranslator]::FromHtml($hex))),[single]$x,[single]$y,[single]$w,[single]$h) }
  function Txt($text,$size,$x,$y,$hex) { $f=Get-Font $size; $g.DrawString($text,$f,(Brush ([Drawing.ColorTranslator]::FromHtml($hex))),[single]$x,[single]$y); $f.Dispose() }
  $line=New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#25151b'),1)
  for($x=0;$x -lt 1920;$x+=60){$g.DrawLine($line,$x,0,$x,1080)}
  for($y=0;$y -lt 1080;$y+=60){$g.DrawLine($line,0,$y,1920,$y)}
  Box 0 0 1920 6 '#ed2438'; Box 0 1000 1920 80 '#101014'
  Box 40 100 4 830 '#ed2438'
  Txt 'ARASAKA CORPORATION' 22 70 100 '#ed2438'
  Txt 'NIGHT CITY  /  NORTH AMERICAN DIVISION' 17 70 137 '#92929c'
  Txt '荒坂' 76 1520 110 '#ed2438'
  # Three-branched Arasaka emblem; native geometry stays crisp at any resolution.
  $red=Brush ([Drawing.ColorTranslator]::FromHtml('#ed2438'))
  $pen=New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#ed2438'),20)
  $g.DrawLine($pen,1100,400,1100,630); $g.DrawLine($pen,1100,540,960,440); $g.DrawLine($pen,1100,540,1240,440)
  foreach($xy in @(@(1055,310),@(915,370),@(1195,370))){$g.FillEllipse($red,[single]$xy[0],[single]$xy[1],90,90)}
  Txt 'ARASAKA' 136 730 650 '#ed2438'
  Txt 'SECURE YOUR FUTURE.' 28 825 810 '#dbdbe0'
  Box 70 310 295 4 '#ed2438'
  Txt 'CORPORATE' 36 70 345 '#dbdbe0'; Txt 'ACCESS TERMINAL' 31 70 390 '#dbdbe0'
  Txt '01  /  PERSONNEL INTERFACE' 16 70 465 '#92929c'
  Txt '02  /  NIGHT CITY NETWORK' 16 70 505 '#92929c'
  Txt '03  /  COUNTERINTELLIGENCE' 16 70 545 '#92929c'
  Box 70 650 295 100 '#251017'
  Txt 'RESTRICTED' 30 88 664 '#ed2438'
  Txt 'AUTHORIZED PERSONNEL ONLY' 15 88 714 '#dbdbe0'
  Txt 'CYBERPUNK 2077  /  ARASAKA SYSTEMS' 17 70 942 '#92929c'
  Txt 'PROPERTY OF ARASAKA CORPORATION' 18 40 1023 '#ed2438'
  Txt 'NC-01     //     CORPORATE NETWORK     //     2077' 17 1250 1023 '#92929c'
  $g.Dispose(); $bmp.Save($Path,[Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

# Writes a real .cur file: 32-bit images with the hotspot in the header, one image per size.
function Write-Cursor($Path, [scriptblock]$Painter, $HotX, $HotY) {
  $sizes = 32, 48, 64
  $images = foreach ($size in $sizes) {
    $bmp = New-Object Drawing.Bitmap($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.ScaleTransform([single]($size / 32.0), [single]($size / 32.0))
    & $Painter $g
    $g.Dispose()
    $ms = New-Object IO.MemoryStream
    $w = New-Object IO.BinaryWriter($ms)
    $w.Write([int]40); $w.Write([int]$size); $w.Write([int]($size * 2)); $w.Write([int16]1); $w.Write([int16]32)
    $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0)
    for ($yy = $size - 1; $yy -ge 0; $yy--) { for ($xx = 0; $xx -lt $size; $xx++) {
      $p = $bmp.GetPixel($xx, $yy); $w.Write([byte]$p.B); $w.Write([byte]$p.G); $w.Write([byte]$p.R); $w.Write([byte]$p.A)
    } }
    $maskRow = [int]([Math]::Ceiling($size / 32.0) * 4)
    $w.Write((New-Object byte[] ($maskRow * $size)))
    $w.Flush()
    $bmp.Dispose()
    , @{ Size = $size; Data = $ms.ToArray() }
  }
  $out = New-Object IO.MemoryStream
  $w = New-Object IO.BinaryWriter($out)
  $w.Write([int16]0); $w.Write([int16]2); $w.Write([int16]$sizes.Count)
  $offset = 6 + 16 * $sizes.Count
  foreach ($img in $images) {
    $f = $img.Size / 32.0
    $w.Write([byte]$img.Size); $w.Write([byte]$img.Size); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([int16]([int]($HotX * $f))); $w.Write([int16]([int]($HotY * $f)))
    $w.Write([int]$img.Data.Length); $w.Write([int]$offset)
    $offset += $img.Data.Length
  }
  foreach ($img in $images) { $w.Write($img.Data) }
  $w.Flush()
  [IO.File]::WriteAllBytes($Path, $out.ToArray())
}

$arrowShape = [Drawing.PointF[]]@((P 1 1), (P 1 22), (P 6.5 17), (P 10.5 26), (P 14.5 24.2), (P 10.5 15.4), (P 18 15.4))
$arrowYellow = {
  param($g)
  $g.FillPolygon((Brush $colY), $arrowShape)
  $g.FillPolygon((Brush $colR), [Drawing.PointF[]]@((P 3 6), (P 3 15.5), (P 7.5 11.2)))
  $g.DrawPolygon((New-Object Drawing.Pen([Drawing.Color]::Black, [single]1.3)), $arrowShape)
}
$arrowRed = {
  param($g)
  $g.FillPolygon((Brush $colR), $arrowShape)
  $g.FillPolygon((Brush $colY), [Drawing.PointF[]]@((P 3 6), (P 3 15.5), (P 7.5 11.2)))
  $g.DrawPolygon((New-Object Drawing.Pen([Drawing.Color]::Black, [single]1.3)), $arrowShape)
}
$beam = {
  param($g)
  $blk = New-Object Drawing.Pen([Drawing.Color]::Black, [single]3.6)
  $yel = New-Object Drawing.Pen($colY, [single]1.8)
  foreach ($pn in $blk, $yel) {
    $g.DrawLine($pn, 16, 5, 16, 27); $g.DrawLine($pn, 11, 4, 21, 4); $g.DrawLine($pn, 11, 28, 21, 28)
  }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$scr = [Windows.Forms.Screen]::PrimaryScreen.Bounds
$script:LiveWindows = New-Object Collections.ArrayList
$script:LiveNeon = New-Object Collections.ArrayList
Draw-Scene $scr.Width $scr.Height $false (Join-Path $OutDir 'wallpaper.png')
Draw-Scene $scr.Width $scr.Height $true (Join-Path $OutDir 'lockscreen.png')

# Data for the animated wallpaper: the same picture plus where its lights are, so the real windows flicker.
$live = Join-Path $OutDir 'live'
New-Item -ItemType Directory -Force -Path $live | Out-Null
Copy-Item (Join-Path $OutDir 'wallpaper.png') (Join-Path $live 'base.png') -Force
$sc = $scr.Height / 1080.0
$fsLive = 176 * $sc
$data = [ordered]@{
  w = $scr.Width; h = $scr.Height; s = $sc
  tx = $scr.Width * 0.36; ty = $scr.Height * 0.17; fs = $fsLive
  hudY = $scr.Height * 0.17 + $fsLive * 1.2
  tapeY = $scr.Height - 2; tapeH = 2
  windows = $script:LiveWindows; neon = $script:LiveNeon
}
[IO.File]::WriteAllText((Join-Path $live 'data.js'), 'window.CD = ' + ($data | ConvertTo-Json -Depth 5 -Compress) + ';')
$src = [Drawing.Image]::FromFile((Join-Path $OutDir 'wallpaper.png'))
$thumb = New-Object Drawing.Bitmap(320, 180)
$tg = [Drawing.Graphics]::FromImage($thumb); $tg.InterpolationMode = 'HighQualityBicubic'; $tg.DrawImage($src, 0, 0, 320, 180); $tg.Dispose()
$thumb.Save((Join-Path $live 'thumbnail.jpg'), [Drawing.Imaging.ImageFormat]::Jpeg); $thumb.Dispose(); $src.Dispose()
Write-Cursor (Join-Path $OutDir 'arrow.cur') $arrowYellow 1 1
Write-Cursor (Join-Path $OutDir 'link.cur') $arrowRed 1 1
Write-Cursor (Join-Path $OutDir 'beam.cur') $beam 16 16
Write-Host "Artwork saved to $OutDir"
