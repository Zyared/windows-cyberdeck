# Read-only regression checks: emulate dependency inventories without changing Windows.
$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\install.ps1'))
$fixture = @'
function Find-ArasakaProgram([string]$Name) {
  if ($Name -eq 'Lively') { return $script:testLively }
  return $null
}
function Get-WallpaperEngineDir { return $script:testEngine }
function Get-ArasakaMods {
  [pscustomobject]@{ Id = 'missing-test-mod'; Installed = $false; Version = $null }
}
'@
$entry = ". (Join-Path `$PSScriptRoot 'detect.ps1')"
if (-not $source.Contains($entry)) { throw 'Dependency seam changed; update the test.' }
$check = [scriptblock]::Create($source.Replace($entry, $fixture))
foreach ($case in @(
  @{ Lively = $null; Engine = $null; Expected = 'Static' },
  @{ Lively = $null; Engine = 'X:\Steam Library\wallpaper_engine'; Expected = 'WallpaperEngine' },
  @{ Lively = 'X:\Apps\Lively.exe'; Engine = 'X:\Steam Library\wallpaper_engine'; Expected = 'Lively' }
)) {
  $script:testLively = $case.Lively
  $script:testEngine = $case.Engine
  $output = (& $check -CheckOnly 6>&1 3>&1 | Out-String)
  if ($output -notmatch ('Wallpaper: ' + $case.Expected + ';')) { throw "Wrong automatic backend: $output" }
  if ($output -notmatch 'missing-test-mod: MISSING') { throw 'Missing mod was not reported.' }
  Write-Host "PASS: automatic $($case.Expected), missing mods reported, no installation."
}
