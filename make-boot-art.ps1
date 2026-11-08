# 24-bit BMP with 54-byte header for HackBGRT. Generates artwork only; no EFI writes.
param([Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null
$bmp=[Drawing.Bitmap]::new(640,400,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::Black);$g.SmoothingMode='AntiAlias';$g.TextRenderingHint='AntiAliasGridFit'
$red=[Drawing.Color]::FromArgb(237,36,56);$brush=[Drawing.SolidBrush]::new($red);$pen=[Drawing.Pen]::new($red,12)
$g.DrawLine($pen,320,75,320,232);$g.DrawLine($pen,320,180,235,115);$g.DrawLine($pen,320,180,405,115)
foreach($xy in @(@(290,35),@(205,80),@(375,80))){$g.FillEllipse($brush,[single]$xy[0],[single]$xy[1],60,60)}
$fmt=[Drawing.StringFormat]::new();$fmt.Alignment='Center'
$font=[Drawing.Font]::new('Bahnschrift',62,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('ARASAKA',$font,$brush,[single]320,[single]250,$fmt)
$small=[Drawing.Font]::new('Consolas',15,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel)
$g.DrawString('SECURE YOUR FUTURE.',$small,$brush,[single]320,[single]336,$fmt)
$g.DrawLine([Drawing.Pen]::new($red,2),160,375,480,375)
$g.Dispose();$bmp.Save((Join-Path $OutDir 'splash.bmp'),[Drawing.Imaging.ImageFormat]::Bmp)
$bmp.Save((Join-Path $OutDir 'boot-preview.png'),[Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose();$pen.Dispose();$brush.Dispose();$font.Dispose();$small.Dispose();$fmt.Dispose()
Write-Host 'Boot artwork generated; boot configuration unchanged.'
