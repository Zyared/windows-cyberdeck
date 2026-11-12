param([string]$WindhawkRoot='C:\Program Files\Windhawk',[string]$EngineVersion='1.7.3')
$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'experimental\build'
New-Item -ItemType Directory -Force $out | Out-Null
foreach($mod in @(@('icon-resource-redirect','1.3',@('-lcomctl32','-lgdi32','-lole32','-loleaut32')), @('lock-screen-clock-styler','0.6.0',@('-lole32','-loleaut32','-lruntimeobject','-lpowrprof')))){
 $header=Join-Path $out ($mod[0]+'-defines.h')
 [IO.File]::WriteAllLines($header,@(('#define WH_MOD_ID L"'+$mod[0]+'"'),('#define WH_MOD_VERSION L"'+$mod[1]+'"')),[Text.Encoding]::ASCII)
 $flags=@('-std=c++23','-O2','-shared','-DUNICODE','-D_UNICODE','-DWINVER=0x0A00','-D_WIN32_WINNT=0x0A00','-DNTDDI_VERSION=0x0A000008','-DWH_MOD','-include',$header,'-include','windhawk_api.h','-target','x86_64-w64-mingw32',(Join-Path $PSScriptRoot ('vendor\'+$mod[0]+'.wh.cpp')),(Join-Path $WindhawkRoot ('Engine\'+$EngineVersion+'\64\windhawk.lib')))+$mod[2]+@('-o',(Join-Path $out ($mod[0]+'.dll')))
 & (Join-Path $WindhawkRoot 'Compiler\bin\clang++.exe') @flags
 if($LASTEXITCODE){throw ('Compilation failed: '+$mod[0])}
}
