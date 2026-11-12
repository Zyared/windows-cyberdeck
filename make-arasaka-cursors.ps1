# Arasaka cursor pack: native multi-resolution CUR plus animated ANI busy indicators.
param([Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null
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

$red=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#ED2438'))
$black=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#08080A'))
$white=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#FFE5E9'))
$edge=[Drawing.Pen]::new($white.Color,1)
$line=[Drawing.Pen]::new($red.Color,2)
$outline=[Drawing.Pen]::new($black.Color,4)
function Points($values) { [Drawing.PointF[]]@(for($i=0;$i -lt $values.Count;$i+=2){[Drawing.PointF]::new($values[$i],$values[$i+1])}) }
function Draw-Pointer($g,$kind,$frame=0) {
 $g.SmoothingMode='AntiAlias'
 if($kind -eq 'UpArrow'){
  $shape=Points @(16,2,4,15,12,15,12,29,20,29,20,15,28,15)
  $g.FillPolygon($black,$shape);$g.DrawPolygon($edge,$shape);$g.DrawLine($line,16,7,16,26)
 } elseif($kind -in 'Arrow','Help','AppStarting'){
  $shape=Points @(2,2,2,25,8,19,13,29,17,27,12,17,23,17)
  $g.FillPolygon($black,$shape); $g.DrawPolygon($edge,$shape)
  $g.FillPolygon($red,(Points @(4,6,4,20,8,16,16,16)))
  $g.DrawLine($line,7,8,17,14)
  if($kind -eq 'Help'){$font=[Drawing.Font]::new('Consolas',15,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel);$g.DrawString('?',$font,$white,19,14);$font.Dispose()}
  if($kind -eq 'AppStarting'){$g.FillRectangle($red,23,([single](8+($frame%4)*4)),5,4)}
 } elseif($kind -eq 'Wait'){
  # Twelve red perimeter segments, advancing around a static three-branch emblem.
  for($i=0;$i -lt 12;$i++){
   $a=($i*30-90)*[Math]::PI/180
   $x=16+12*[Math]::Cos($a);$y=16+12*[Math]::Sin($a)
   $g.FillRectangle($black,[single]($x-2.5),[single]($y-2.5),5,5)
   $g.FillRectangle($(if($i -eq $frame){$white}else{$red}),[single]($x-1.5),[single]($y-1.5),3,3)
  }
  $g.DrawLine($line,16,12,16,23);$g.DrawLine($line,16,19,10,14);$g.DrawLine($line,16,19,22,14)
  foreach($p in @(@(8,10),@(14,7),@(20,10))){$g.FillEllipse($red,[single]$p[0],[single]$p[1],4,4)}
 } elseif($kind -eq 'IBeam'){
  foreach($p in $outline,$line){$g.DrawLine($p,16,4,16,28);$g.DrawLine($p,11,4,21,4);$g.DrawLine($p,11,28,21,28)}
  $g.FillRectangle($white,15,12,2,8)
 } elseif($kind -in 'SizeNS','SizeWE','SizeNWSE','SizeNESW','SizeAll'){
  $state=$g.Save();$g.TranslateTransform(16,16)
  $angle=switch($kind){SizeWE{90};SizeNWSE{-45};SizeNESW{45};default{0}}
  $g.RotateTransform($angle);$g.TranslateTransform(-16,-16)
  foreach($p in $outline,$line){$g.DrawLine($p,16,4,16,28);$g.DrawLines($p,(Points @(10,10,16,4,22,10)));$g.DrawLines($p,(Points @(10,22,16,28,22,22)))}
  if($kind -eq 'SizeAll'){foreach($p in $outline,$line){$g.DrawLine($p,4,16,28,16);$g.DrawLines($p,(Points @(10,10,4,16,10,22)));$g.DrawLines($p,(Points @(22,10,28,16,22,22)))}}
  $g.Restore($state)
 } elseif($kind -eq 'Hand'){
  $shape=Points @(11,16,11,4,13,2,16,4,16,12,19,10,22,12,25,12,28,16,26,27,13,29,5,20,5,17,8,16)
  $g.FillPolygon($black,$shape);$g.DrawPolygon($edge,$shape);$g.DrawLine($line,13,6,13,21);$g.FillRectangle($red,14,23,10,3)
 } elseif($kind -eq 'No'){
  $g.DrawEllipse($outline,5,5,22,22);$g.DrawEllipse($line,5,5,22,22);$g.DrawLine($outline,8,8,24,24);$g.DrawLine($line,8,8,24,24)
 } elseif($kind -eq 'NWPen'){
  $shape=Points @(4,28,8,18,23,3,28,8,13,23)
  $g.FillPolygon($red,$shape);$g.DrawPolygon($edge,$shape);$g.DrawLine($outline,8,23,23,8)
 } else {
  foreach($p in $outline,$line){$g.DrawLine($p,3,16,12,16);$g.DrawLine($p,20,16,29,16);$g.DrawLine($p,16,3,16,12);$g.DrawLine($p,16,20,16,29)}
  $g.DrawRectangle($edge,13,13,6,6)
  if($kind -eq 'Person'){$g.FillEllipse($red,13,5,6,6)}
  if($kind -eq 'Pin'){$g.FillEllipse($red,12,5,8,8)}
 }
}
function Chunk($writer,$name,[byte[]]$bytes){$writer.Write([Text.Encoding]::ASCII.GetBytes($name));$writer.Write([int]$bytes.Length);$writer.Write($bytes);if($bytes.Length%2){$writer.Write([byte]0)}}
function Write-Animated($kind,$hotX,$hotY){
 $frames=[IO.MemoryStream]::new();$fw=[IO.BinaryWriter]::new($frames)
 $fw.Write([Text.Encoding]::ASCII.GetBytes('fram'))
 for($frame=0;$frame -lt 12;$frame++){
  $path=Join-Path $OutDir ($kind+'-frame.cur')
  Write-Cursor $path {param($g) Draw-Pointer $g $kind $frame} $hotX $hotY
  Chunk $fw 'icon' ([IO.File]::ReadAllBytes($path))
 }
 $body=[IO.MemoryStream]::new();$bw=[IO.BinaryWriter]::new($body);$bw.Write([Text.Encoding]::ASCII.GetBytes('ACON'))
 $header=[IO.MemoryStream]::new();$hw=[IO.BinaryWriter]::new($header)
 foreach($n in @(36,12,12,0,0,32,1,5,1)){$hw.Write([int]$n)}
 Chunk $bw 'anih' $header.ToArray();Chunk $bw 'LIST' $frames.ToArray()
 $file=[IO.MemoryStream]::new();$w=[IO.BinaryWriter]::new($file);Chunk $w 'RIFF' $body.ToArray()
 [IO.File]::WriteAllBytes((Join-Path $OutDir ($kind+'.ani')),$file.ToArray())
 $hw.Dispose();$header.Dispose();$fw.Dispose();$frames.Dispose();$bw.Dispose();$body.Dispose();$w.Dispose();$file.Dispose()
}
$roles='Arrow','Help','AppStarting','Wait','Crosshair','IBeam','NWPen','No','SizeNS','SizeWE','SizeNWSE','SizeNESW','SizeAll','UpArrow','Hand','Pin','Person'
$preview=[Drawing.Bitmap]::new(850,210);$pg=[Drawing.Graphics]::FromImage($preview);$pg.Clear([Drawing.ColorTranslator]::FromHtml('#16161C'))
$label=[Drawing.Font]::new('Consolas',10)
for($i=0;$i -lt $roles.Count;$i++){
 $kind=$roles[$i];$hotX=16;$hotY=16
 if($kind -in 'Arrow','Help','AppStarting','UpArrow'){$hotX=2;$hotY=2}
 if($kind -eq 'UpArrow'){$hotX=16;$hotY=2}
 if($kind -eq 'Hand'){$hotX=13;$hotY=3}
 if($kind -eq 'NWPen'){$hotX=4;$hotY=28}
 if($kind -in 'Wait','AppStarting'){Write-Animated $kind $hotX $hotY}else{Write-Cursor (Join-Path $OutDir ($kind+'.cur')) {param($g) Draw-Pointer $g $kind} $hotX $hotY}
 $x=($i%9)*94;$y=[Math]::Floor($i/9)*100
 $state=$pg.Save();$pg.TranslateTransform([single]($x+25),[single]($y+10));$pg.ScaleTransform(1.5,1.5);Draw-Pointer $pg $kind 0;$pg.Restore($state)
 $pg.DrawString($kind,$label,$white,[single]$x,[single]($y+65))
}
$preview.Save((Join-Path $OutDir 'cursor-preview.png'),[Drawing.Imaging.ImageFormat]::Png)
$pg.Dispose();$preview.Dispose();$label.Dispose();$red.Dispose();$white.Dispose();$black.Dispose();$edge.Dispose();$line.Dispose();$outline.Dispose()
