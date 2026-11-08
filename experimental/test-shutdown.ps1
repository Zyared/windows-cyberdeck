$ErrorActionPreference='Stop'
$root='C:\Program Files\Windhawk'
$build=Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force $build | Out-Null
& "$root\Compiler\bin\clang++.exe" -std=c++23 -O2 -target x86_64-w64-mingw32 "$PSScriptRoot\test-shutdown-visuals.cpp" -lruntimeobject -lole32 -loleaut32 -luser32 -o "$build\test-shutdown-visuals.exe"
if ($LASTEXITCODE) { throw 'Test compilation failed' }
Copy-Item "$PSScriptRoot\test-xaml.manifest" $build -Force
Copy-Item "$env:ProgramData\Windhawk\Engine\Mods\64\libc++.whl" $build -Force
Copy-Item "$env:ProgramData\Windhawk\Engine\Mods\64\libunwind.whl" $build -Force
python "$PSScriptRoot\embed-test-manifest.py"
if ($LASTEXITCODE) { throw 'Manifest embedding failed' }
$result=& "$build\test-shutdown-visuals.exe"
if ($LASTEXITCODE -or $result -notmatch '^PASS:') { throw "Test failed: $result" }
$result
