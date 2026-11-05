# Draws the CYBER//DECK wallpaper, lock screen and cursors. All artwork is generated here, nothing is downloaded.
param([Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$colY = [Drawing.Color]::FromArgb(252, 238, 10)
$colR = [Drawing.Color]::FromArgb(255, 0, 60)
$colC = [Drawing.Color]::FromArgb(0, 240, 255)
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
  $bmp = New-Object Drawing.Bitmap($W, $H, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  $s = $H / 1080.0
  $rnd = New-Object Random 2077

  # background
  $rect = New-Object Drawing.Rectangle(0, 0, $W, $H)
  $bg = New-Object Drawing.Drawing2D.LinearGradientBrush($rect, [Drawing.Color]::FromArgb(6, 6, 8), [Drawing.Color]::FromArgb(26, 24, 8), [single]35)
  $g.FillRectangle($bg, $rect)

  # faint diagonal hatching
  $pen = New-Object Drawing.Pen((A $colY 7), [single]1)
  for ($x = -$H; $x -lt $W; $x += [int](26 * $s)) { $g.DrawLine($pen, $x, 0, $x + $H, $H) }

  # glow behind the city
  $path1 = New-Object Drawing.Drawing2D.GraphicsPath
  $gx = $W * 0.68; $gy = $H * 0.82; $gr = $W * 0.46
  $path1.AddEllipse([single]($gx - $gr), [single]($gy - $gr * 0.62), [single]($gr * 2), [single]($gr * 1.24))
  $pg = New-Object Drawing.Drawing2D.PathGradientBrush($path1)
  $pg.CenterColor = A $colY 62
  $pg.SurroundColors = @((A $colY 0))
  $g.FillPath($pg, $path1)

  # acid-yellow blade on the right
  $g.FillPolygon((Brush (A $colY 235)), [Drawing.PointF[]]@((P ($W * 0.885) 0), (P $W 0), (P $W ($H * 0.40)), (P ($W * 0.74) ($H * 0.40 + $W * 0.26 * 0.0)), (P ($W * 0.885) 0)) )
  $g.FillPolygon((Brush $colK), [Drawing.PointF[]]@((P ($W * 0.915) 0), (P ($W * 0.93) 0), (P ($W * 0.79) ($H * 0.40)), (P ($W * 0.775) ($H * 0.40))))
  $g.FillPolygon((Brush $colR), [Drawing.PointF[]]@((P ($W * 0.74) ($H * 0.40)), (P $W ($H * 0.40)), (P $W ($H * 0.414)), (P ($W * 0.735) ($H * 0.414))))

  # city: two layers of towers with lit windows
  $base = $H - [int](40 * $s)
  foreach ($layer in 0, 1) {
    $x = [int]($W * 0.30)
    $col = if ($layer -eq 0) { [Drawing.Color]::FromArgb(24, 23, 16) } else { [Drawing.Color]::FromArgb(11, 11, 13) }
    while ($x -lt $W) {
      $tw = [int]($rnd.Next(46, 120) * $s)
      $progress = ($x - $W * 0.30) / ($W * 0.70)
      $maxH = (150 + 400 * [Math]::Sin([Math]::PI * [Math]::Min(1, $progress) * 0.82)) * $s
      if ($layer -eq 1) { $maxH *= 0.66 }
      $th = [int]($maxH * (0.55 + $rnd.NextDouble() * 0.45))
      $top = $base - $th
      $g.FillRectangle((Brush $col), $x, $top, $tw, $th + [int](60 * $s))
      if ($rnd.NextDouble() -lt 0.3) { $g.FillRectangle((Brush $col), $x + [int]($tw / 2), $top - [int](46 * $s), [Math]::Max(2, [int](3 * $s)), [int](46 * $s)) }
      $winCol = if ($layer -eq 0) { 60 } else { 190 }
      for ($wy = $top + [int](10 * $s); $wy -lt $base; $wy += [int](13 * $s)) {
        for ($wx = $x + [int](6 * $s); $wx -lt $x + $tw - [int](6 * $s); $wx += [int](10 * $s)) {
          if ($rnd.NextDouble() -lt 0.16) {
            $r = $rnd.NextDouble()
            $c2 = if ($r -lt 0.74) { $colY } elseif ($r -lt 0.88) { $colR } else { $colC }
            $g.FillRectangle((Brush (A $c2 $winCol)), $wx, $wy, [Math]::Max(2, [int](5 * $s)), [Math]::Max(2, [int](6 * $s)))
            if (-not $Lock -and $layer -eq 1) { [void]$script:LiveWindows.Add(@($wx, $wy, [Math]::Max(2, [int](5 * $s)), [Math]::Max(2, [int](6 * $s)), ('#{0:X2}{1:X2}{2:X2}' -f $c2.R, $c2.G, $c2.B))) }
          }
        }
      }
      if ($layer -eq 1 -and $rnd.NextDouble() -lt 0.22) {
        $c3 = if ($rnd.NextDouble() -lt 0.6) { $colR } else { $colY }
        $g.FillRectangle((Brush (A $c3 215)), $x + [int](4 * $s), $top + [int](16 * $s), [Math]::Max(3, [int](5 * $s)), [int]($th * 0.34))
        if (-not $Lock) { [void]$script:LiveNeon.Add(@(($x + [int](4 * $s)), ($top + [int](16 * $s)), [Math]::Max(3, [int](5 * $s)), [int]($th * 0.34), ('#{0:X2}{1:X2}{2:X2}' -f $c3.R, $c3.G, $c3.B))) }
      }
      $x += $tw + [int]($rnd.Next(-6, 18) * $s)
    }
  }

  # wordmark, sheared, with red and cyan channel split and a few torn bands
  $fs = 176 * $s
  $font = Get-Font $fs
  $tx = if ($Lock) { $W * 0.09 } else { $W * 0.36 }
  $ty = if ($Lock) { $H * 0.60 } else { $H * 0.17 }
  $sf = New-Object Drawing.StringFormat
  $write = {
    param($gr, $dx, $partColA, $partColB)
    $st = $gr.Save()
    $gr.TranslateTransform([single]($tx + $dx), [single]$ty)
    $gr.MultiplyTransform((New-Object Drawing.Drawing2D.Matrix(1, 0, -0.18, 1, 0, 0)))
    $sz1 = $gr.MeasureString('CYBER', $font, 2000, [Drawing.StringFormat]::GenericTypographic)
    $gr.DrawString('CYBER', $font, (Brush $partColA), 0, 0, [Drawing.StringFormat]::GenericTypographic)
    $gr.DrawString('//', $font, (Brush $partColB), [single]($sz1.Width + 8 * $s), 0, [Drawing.StringFormat]::GenericTypographic)
    $sz2 = $gr.MeasureString('//', $font, 2000, [Drawing.StringFormat]::GenericTypographic)
    $gr.DrawString('DECK', $font, (Brush $partColA), [single]($sz1.Width + $sz2.Width + 16 * $s), 0, [Drawing.StringFormat]::GenericTypographic)
    $gr.Restore($st)
  }
  & $write $g (-3 * $s) (A $colC 215) (A $colC 215)
  & $write $g (3 * $s) (A $colR 225) (A $colR 225)
  & $write $g 0 $colY $colR

  # a few thin torn bands, limited to the wordmark so the letters stay readable
  $textW = [int]($g.MeasureString('CYBER//DECK', $font).Width)
  $bandX = [int]($tx - 50 * $s)
  $bandTop = [int]($ty + $fs * 0.12); $bandMax = [int]($ty + $fs * 0.95)
  foreach ($i in 1..4) {
    $by = $rnd.Next($bandTop, $bandMax)
    $bh = [Math]::Max(2, [int]($rnd.Next(3, 7) * $s))
    $shift = [int]($rnd.Next(-14, 14) * $s)
    $src = New-Object Drawing.Rectangle($bandX, $by, $textW, $bh)
    $slice = $bmp.Clone($src, $bmp.PixelFormat)
    $g.DrawImageUnscaled($slice, $bandX + $shift, $by)
    $slice.Dispose()
  }

  # small HUD text
  $small = Get-Font (22 * $s)
  $hudX = $tx + 4 * $s; $hudY = $ty + $fs * 1.2
  $g.DrawString('SYS ONLINE  //  NEURAL LINK STABLE  //  ICE ACTIVE', $small, (Brush $colC), [single]$hudX, [single]$hudY)
  $g.FillRectangle((Brush $colY), [single]$hudX, [single]($hudY + 34 * $s), [single](470 * $s), [single](3 * $s))

  # corner brackets
  $b = New-Object Drawing.Pen($colY, [single](3 * $s))
  $m = 26 * $s; $l = 62 * $s; $bot = if ($Lock) { $H - $m } else { $H - 78 * $s }
  if ($Lock) {   # on the desktop they would sit underneath the icons
    $g.DrawLines($b, [Drawing.PointF[]]@((P $m ($m + $l)), (P $m $m), (P ($m + $l) $m)))
    $g.DrawLines($b, [Drawing.PointF[]]@((P $m ($bot - $l)), (P $m $bot), (P ($m + $l) $bot)))
    $g.DrawLines($b, [Drawing.PointF[]]@((P ($W - $m - $l) $bot), (P ($W - $m) $bot), (P ($W - $m) ($bot - $l))))
  }


  # scanlines
  $sl = New-Object Drawing.Pen((A ([Drawing.Color]::Black) 44), [single]1)
  for ($y2 = 0; $y2 -lt $H; $y2 += 3) { $g.DrawLine($sl, 0, $y2, $W, $y2) }

  $g.Dispose()
  $bmp.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
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
