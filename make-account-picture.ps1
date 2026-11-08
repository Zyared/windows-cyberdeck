# Optional avatar asset. Setting it is a separate user-account preference, not part of setup.
param([Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$bitmap = New-Object Drawing.Bitmap(512, 512)
$g = [Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.ColorTranslator]::FromHtml('#08090C'))
$red = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#ED2438'))
$pen = New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#ED2438'), 14)
$rim = New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#6B1B2D'), 3)
try {
  $g.DrawEllipse($rim, 28, 28, 456, 456)
  $g.DrawLine($pen, 256, 164, 256, 378)
  $g.DrawLine($pen, 256, 304, 145, 220)
  $g.DrawLine($pen, 256, 304, 367, 220)
  foreach ($point in @(@(221,97), @(110,153), @(332,153))) {
    $g.FillEllipse($red, [single]$point[0], [single]$point[1], [single]70, [single]70)
  }
  $bitmap.Save((Join-Path $OutDir 'arasaka-account.png'), [Drawing.Imaging.ImageFormat]::Png)
} finally { $red.Dispose(); $pen.Dispose(); $rim.Dispose(); $g.Dispose(); $bitmap.Dispose() }
