# Draws the CYBER//DECK icon set as real multi-size .ico files, plus two PNGs for the taskbar. Nothing is downloaded.
param([Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$colY = [Drawing.Color]::FromArgb(237, 36, 56)
$colD = [Drawing.Color]::FromArgb(114, 21, 35)
$colR = [Drawing.Color]::FromArgb(255, 0, 60)
$colK = [Drawing.Color]::FromArgb(10, 10, 12)
$colP = [Drawing.Color]::FromArgb(30, 30, 36)
$colT = [Drawing.Color]::FromArgb(219, 219, 224)

function Brush($c) { New-Object Drawing.SolidBrush $c }
function PenOf($c, $w) { $p = New-Object Drawing.Pen($c, [single]$w); $p.LineJoin = 'Miter'; $p }
function Poly($g, $c, [double[]]$xy) {
  $pts = for ($i = 0; $i -lt $xy.Count; $i += 2) { New-Object Drawing.PointF([single]$xy[$i], [single]$xy[$i + 1]) }
  $g.FillPolygon((Brush $c), [Drawing.PointF[]]$pts)
}
function Outline($g, $c, $w, [double[]]$xy) {
  $pts = for ($i = 0; $i -lt $xy.Count; $i += 2) { New-Object Drawing.PointF([single]$xy[$i], [single]$xy[$i + 1]) }
  $g.DrawPolygon((PenOf $c $w), [Drawing.PointF[]]$pts)
}
function Line($g, $c, $w, $x1, $y1, $x2, $y2) { $g.DrawLine((PenOf $c $w), [single]$x1, [single]$y1, [single]$x2, [single]$y2) }

# All icons are drawn on a 32-unit grid and scaled, so they stay vector-sharp at each size.
function Arasaka-Mark($g,$x,$y,$scale,$color) {
  $state=$g.Save(); $g.TranslateTransform([single]$x,[single]$y); $g.ScaleTransform([single]$scale,[single]$scale)
  Line $g $color 2.4 16 6 16 30
  Line $g $color 2.4 16 21 5 12
  Line $g $color 2.4 16 21 27 12
  foreach($xy in @(@(12,1),@(1,7),@(23,7))){$g.FillEllipse((Brush $color),[single]$xy[0],[single]$xy[1],8,8)}
  $g.Restore($state)
}
function FolderBase($g) {
  Poly $g $colD @(2,6, 12,6, 15,9, 30,9, 30,14, 2,14)
  $rect = New-Object Drawing.RectangleF(2, 12, 28, 18)
  $br = New-Object Drawing.Drawing2D.LinearGradientBrush($rect, [Drawing.Color]::FromArgb(255, 104, 118), $colY, [single]90)
  $pts = [Drawing.PointF[]]@((New-Object Drawing.PointF(2, 13)), (New-Object Drawing.PointF(30, 13)), (New-Object Drawing.PointF(30, 25)), (New-Object Drawing.PointF(25.5, 29.5)), (New-Object Drawing.PointF(2, 29.5)))
  $g.FillPolygon($br, $pts)
  Line $g $colR 1.8 4 27 11 27
}
$painters = @{
  folder = { param($g) FolderBase $g }
  folderopen = { param($g)
    Poly $g $colD @(2,6, 12,6, 15,9, 28,9, 28,14, 2,14)
    Poly $g $colY @(6,14, 31,14, 26.5,29.5, 2,29.5, 2,20)
    Line $g $colR 1.8 5 27 11 27
  }
  drive = { param($g)
    Poly $g $colP @(2,9, 30,9, 30,23, 25,28, 2,28)
    Outline $g $colY 1.6 @(2,9, 30,9, 30,23, 25,28, 2,28)
    Poly $g $colY @(5,12.5, 27,12.5, 27,15.5, 5,15.5)
    Poly $g $colR @(5,21, 10,21, 10,24, 5,24)
    Line $g $colD 1.4 14 22.5 24 22.5
  }
  thispc = { param($g)
    Poly $g $colP @(2,4, 30,4, 30,19, 26,23, 2,23)
    Outline $g $colY 1.8 @(2,4, 30,4, 30,19, 26,23, 2,23)
    Line $g $colR 1.8 6 18.5 14 18.5
    Poly $g $colY @(13,23, 19,23, 20,27, 12,27)
    Poly $g $colY @(8,27, 24,27, 24,29.5, 8,29.5)
  }
  network = { param($g)
    Line $g $colD 1.8 16 8 16 16
    Line $g $colD 1.8 6 24 6 16
    Line $g $colD 1.8 26 24 26 16
    Line $g $colD 1.8 6 16 26 16
    Poly $g $colY @(11,2, 21,2, 21,8, 19,10, 11,10)
    Poly $g $colY @(2,22, 10,22, 10,28, 8,30, 2,30)
    Poly $g $colR @(22,22, 30,22, 30,28, 28,30, 22,30)
  }
  home = { param($g)
    Poly $g $colY @(16,3, 31,16, 27,16, 16,7, 5,16, 1,16)
    Poly $g $colP @(6,16, 16,8, 26,16, 26,26, 22,29.5, 6,29.5)
    Outline $g $colY 1.6 @(6,16, 16,8, 26,16, 26,26, 22,29.5, 6,29.5)
    Poly $g $colR @(13,20, 19,20, 19,29, 13,29)
  }
  gallery = { param($g)
    Poly $g $colP @(2,5, 30,5, 30,23, 25,28, 2,28)
    Outline $g $colY 1.6 @(2,5, 30,5, 30,23, 25,28, 2,28)
    Poly $g $colY @(5,25, 12,14, 17,21, 21,17, 27,25)
    Poly $g $colR @(21,8, 26,8, 26,13, 21,13)
  }
  desktop = { param($g) FolderBase $g
    Outline $g $colK 1.6 @(9,16, 23,16, 23,24, 9,24)
    Line $g $colK 1.6 13 27 19 27
  }
  downloads = { param($g) FolderBase $g
    Poly $g $colK @(14.3,15, 17.7,15, 17.7,20.5, 21,20.5, 16,26, 11,20.5, 14.3,20.5)
  }
  documents = { param($g) FolderBase $g
    Line $g $colK 1.8 9 17 23 17
    Line $g $colK 1.8 9 21 23 21
    Line $g $colK 1.8 9 25 18 25
  }
  pictures = { param($g) FolderBase $g
    Poly $g $colK @(8,26.5, 13,18, 17,23, 20,20, 25,26.5)
    Poly $g $colK @(20,15.5, 23.5,15.5, 23.5,18.5, 20,18.5)
  }
  music = { param($g) FolderBase $g
    Poly $g $colK @(13,16, 23,15, 23,24, 20,24, 20,18.5, 15.5,19, 15.5,26, 12,26, 12,22.5, 13,22.5)
    Poly $g $colK @(17.5,22.5, 23,22.5, 23,25, 17.5,25)
  }
  videos = { param($g) FolderBase $g
    Poly $g $colK @(12,15.5, 22.5,21, 12,26.5)
  }
  recycle = { param($g)
    Line $g $colY 2 6 8 26 8
    Poly $g $colY @(12,4, 20,4, 20,7, 12,7)
    Outline $g $colY 1.8 @(8,11, 24,11, 22,29, 10,29)
    Line $g $colD 1.4 13 14 13.8 26
    Line $g $colD 1.4 19 14 18.2 26
  }
  recyclefull = { param($g)
    Line $g $colY 2 6 8 26 8
    Poly $g $colY @(12,4, 20,4, 20,7, 12,7)
    Poly $g $colY @(8,11, 24,11, 22,29, 10,29)
    Line $g $colK 1.6 13 14 13.8 26
    Line $g $colK 1.6 19 14 18.2 26
    Poly $g $colR @(10,27, 22,27, 22,29, 10,29)
  }
}

$painters['generic']={param($g)
  Poly $g $colP @(5,2,22,2,28,8,28,30,5,30)
  Outline $g $colY 1.5 @(5,2,22,2,28,8,28,30,5,30)
  Arasaka-Mark $g 8 9 0.55 $colY
}
$painters['settings']={param($g)
  $g.DrawEllipse((PenOf $colY 2),4,4,24,24)
  Arasaka-Mark $g 7 5 0.56 $colY
}
$painters['printer']={param($g)
  Outline $g $colY 1.7 @(3,11,29,11,29,24,3,24)
  Poly $g $colP @(8,3,24,3,24,15,8,15)
  Outline $g $colY 1.5 @(8,3,24,3,24,15,8,15)
  Poly $g $colY @(9,21,23,21,23,30,9,30)
}

function Draw-Icon($g, [scriptblock]$painter) {
  & $painter $g
  $g.FillRectangle((Brush $colK),20,19,12,13)
  Arasaka-Mark $g 21 20 0.33 $colY
}
function Write-Ico($path, [scriptblock]$painter) {
  $sizes = 16, 20, 24, 32, 40, 48, 64, 256
  $blobs = foreach ($size in $sizes) {
    $bmp = New-Object Drawing.Bitmap($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.ScaleTransform([single]($size / 32.0), [single]($size / 32.0))
    Draw-Icon $g $painter
    $g.Dispose()
    $ms = New-Object IO.MemoryStream
    if ($size -ge 256) {
      $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    } else {
      $w = New-Object IO.BinaryWriter($ms)
      $w.Write([int]40); $w.Write([int]$size); $w.Write([int]($size * 2)); $w.Write([int16]1); $w.Write([int16]32)
      foreach ($z in 1..6) { $w.Write([int]0) }
      for ($yy = $size - 1; $yy -ge 0; $yy--) { for ($xx = 0; $xx -lt $size; $xx++) { $p = $bmp.GetPixel($xx, $yy); $w.Write([byte]$p.B); $w.Write([byte]$p.G); $w.Write([byte]$p.R); $w.Write([byte]$p.A) } }
      $w.Write((New-Object byte[] ([int]([Math]::Ceiling($size / 32.0) * 4) * $size)))
      $w.Flush()
    }
    $bmp.Dispose()
    , @{ Size = $size; Data = $ms.ToArray() }
  }
  $out = New-Object IO.MemoryStream
  $w = New-Object IO.BinaryWriter($out)
  $w.Write([int16]0); $w.Write([int16]1); $w.Write([int16]$sizes.Count)
  $off = 6 + 16 * $sizes.Count
  foreach ($b in $blobs) {
    $d = if ($b.Size -ge 256) { 0 } else { $b.Size }
    $w.Write([byte]$d); $w.Write([byte]$d); $w.Write([byte]0); $w.Write([byte]0); $w.Write([int16]1); $w.Write([int16]32)
    $w.Write([int]$b.Data.Length); $w.Write([int]$off)
    $off += $b.Data.Length
  }
  foreach ($b in $blobs) { $w.Write($b.Data) }
  $w.Flush()
  [IO.File]::WriteAllBytes($path, $out.ToArray())
}

function Write-Png($path, $size, [scriptblock]$painter) {
  $bmp = New-Object Drawing.Bitmap($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  # The taskbar stretches the picture over the whole button, so the mark sits inside a wide margin.
  $g.TranslateTransform([single]($size * 0.25), [single]($size * 0.25))
  $g.ScaleTransform([single]($size / 64.0), [single]($size / 64.0))
  & $painter $g
  $g.Dispose()
  $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}


New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($name in $painters.Keys) { Write-Ico (Join-Path $OutDir "$name.ico") $painters[$name] }

# Taskbar: the Start mark is the Arasaka emblem, Task View two offset frames.
Write-Png (Join-Path $OutDir 'start.png') 96 { param($g)
  Line $g $colY 2.6 16 7 16 30
  Line $g $colY 2.6 16 22 5 13
  Line $g $colY 2.6 16 22 27 13
  foreach ($xy in @(@(12,2),@(1,8),@(23,8))) { $g.FillEllipse((Brush $colY),[single]$xy[0],[single]$xy[1],8,8) }
}
Write-Png (Join-Path $OutDir 'taskview.png') 96 { param($g)
  Outline $g $colD 2 @(10,5, 28,5, 28,19, 24,19)
  Poly $g $colP @(4,11, 22,11, 22,23, 18,27, 4,27)
  Outline $g $colY 2 @(4,11, 22,11, 22,23, 18,27, 4,27)
}

# Contact sheet for checking the set by eye.
$names = @($painters.Keys | Sort-Object)
$sheet = New-Object Drawing.Bitmap(($names.Count * 76 + 20), 190)
$sg = [Drawing.Graphics]::FromImage($sheet)
$sg.Clear([Drawing.Color]::FromArgb(18, 18, 14))
$sg.SmoothingMode = 'AntiAlias'
$i = 0
foreach ($n in $names) {
  $st = $sg.Save(); $sg.TranslateTransform([single](10 + $i * 76), 8); $sg.ScaleTransform(2, 2); Draw-Icon $sg $painters[$n]; $sg.Restore($st)
  $st = $sg.Save(); $sg.TranslateTransform([single](10 + $i * 76), 84); Draw-Icon $sg $painters[$n]; $sg.Restore($st)
  $st = $sg.Save(); $sg.TranslateTransform([single](50 + $i * 76), 90); $sg.ScaleTransform(0.5, 0.5); Draw-Icon $sg $painters[$n]; $sg.Restore($st)
  $sg.DrawString($n.Substring(0, [Math]::Min(9, $n.Length)), (New-Object Drawing.Font('Consolas', 9)), (Brush $colT), [single](8 + $i * 76), 130)
  $i++
}
$sheet.Save((Join-Path $OutDir '_sheet.png'), [Drawing.Imaging.ImageFormat]::Png)
$sg.Dispose(); $sheet.Dispose()
Write-Host "Icons saved to $OutDir"
