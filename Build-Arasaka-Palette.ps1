$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'experimental\build'
New-Item -ItemType Directory -Force $out | Out-Null
$clock=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'vendor\lock-screen-clock-styler.wh.cpp'))
# Compile a theme-specific variant; keep the upstream source intact.
foreach($color in @('0, 245, 255','252, 238, 10','255, 0, 128')){
 if(!$clock.Contains(', '+$color+')')){throw "Expected clock palette entry missing: $color"}
 $clock=$clock.Replace(', '+$color+')',', 237, 36, 56)')
}
$clock=$clock.Replace(', 235, 252, 255)',', 255, 229, 233)').Replace('SYS.LOC // TIME_SYNC','ARASAKA // TIME_SYNC')
$clock=$clock.Replace('Segoe UI Variable Display','Bahnschrift')
[IO.File]::WriteAllText((Join-Path $out 'arasaka-clock.cpp'),$clock,[Text.UTF8Encoding]::new($false))
foreach($mod in @(
 @('lock-screen-clock-styler','0.6.0',(Join-Path $out 'arasaka-clock.cpp'),'arasaka-clock-v2.dll',@('-lole32','-loleaut32','-lruntimeobject','-lpowrprof')),
 @('translucent-windows','1.8.2',(Join-Path $PSScriptRoot 'experimental\translucent-arasaka.wh.cpp'),'translucent-arasaka-v4.dll',@('-ldwmapi','-luxtheme','-lcomctl32','-lgdi32','-ld2d1','-lmsimg32','-lshcore','-lversion','-lole32','-loleaut32'))
)){
 $header=Join-Path $out ($mod[0]+'-palette-defines.h')
 [IO.File]::WriteAllLines($header,@(('#define WH_MOD_ID L"'+$mod[0]+'"'),('#define WH_MOD_VERSION L"'+$mod[1]+'"')),[Text.Encoding]::ASCII)
 $argsList=@('-std=c++23','-O2','-shared','-DUNICODE','-D_UNICODE','-DWINVER=0x0A00','-D_WIN32_WINNT=0x0A00','-DNTDDI_VERSION=0x0A000008','-DWH_MOD','-include',$header,'-include','windhawk_api.h','-target','x86_64-w64-mingw32',$mod[2],'C:\Program Files\Windhawk\Engine\1.7.3\64\windhawk.lib')+$mod[4]+@('-o',(Join-Path $out $mod[3]))
 & 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' @argsList
 if($LASTEXITCODE){throw "Build failed: $($mod[0])"}
}
