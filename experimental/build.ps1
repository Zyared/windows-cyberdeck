param([string]$WindhawkRoot = 'C:\Program Files\Windhawk', [string]$EngineVersion = '1.7.3', [switch]$VmResearchOnly, [switch]$Shutdown)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $WindhawkRoot 'Compiler\bin\clang++.exe'
$library = Join-Path $WindhawkRoot "Engine\$EngineVersion\64\windhawk.lib"
if (!(Test-Path -LiteralPath $compiler) -or !(Test-Path -LiteralPath $library)) {
    throw 'Windhawk compiler or matching x64 engine import library missing.'
}
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$modId = if ($Shutdown) { 'arasaka-shutdown-styler' } else { 'arasaka-logon-styler' }
$version = if ($Shutdown) { '0.1.0' } else { '0.1.1' }
$source = Join-Path $PSScriptRoot ($modId + '.wh.cpp')
$output = Join-Path $build ($modId + '.dll')
# Based on Windhawk compiler/flags.rs plus the installed compile_flags.txt.
# No WH_EDITING: this links the real API, not IDE stub functions.
$compilerArgs = @('-std=c++23', '-O2', '-shared', '-ffp-exception-behavior=maytrap',
    '-mguard=cf-nochecks', '-DUNICODE', '-D_UNICODE', '-DWINVER=0x0A00',
    '-D_WIN32_WINNT=0x0A00', '-D_WIN32_IE=0x0A00', '-DNTDDI_VERSION=0x0A000008',
    '-D__USE_MINGW_ANSI_STDIO=0', '-DWH_MOD', ('-DWH_MOD_ID=L"' + $modId + '"'),
    ('-DWH_MOD_VERSION=L"' + $version + '"'), '-DWH_WINDHAWK_VERSION=0x01070300',
    '-include', 'windhawk_api.h', '-target', 'x86_64-w64-mingw32',
    '-Wl,--export-all-symbols', $source, $library, '-luser32', '-lole32',
    '-loleaut32', '-lruntimeobject', '-o', $output)
if ($VmResearchOnly) { $compilerArgs += '-DARASAKA_VM_RESEARCH=1' }
& $compiler @compilerArgs
if ($LASTEXITCODE -ne 0) { throw "Compiler exited with $LASTEXITCODE" }
Get-FileHash -LiteralPath $output -Algorithm SHA256
Write-Output 'Compile/link only: nothing installed, injected, or enabled.'
if (!$VmResearchOnly -and !$Shutdown) { Write-Output 'Activation disabled by compile-time gate; teardown validation remains incomplete.' }
