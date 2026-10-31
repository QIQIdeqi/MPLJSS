param([int]$Width=1280,[int]$Height=720,[int]$FPS=60)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$dir=Join-Path $project 'Evidence/UnifiedPresentation_20261031'
$log=Join-Path $dir "native-$Width`x$Height.log"
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','-game','-UnifiedPresentationTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark',"-fps=$FPS",'-unattended','-nosound',"-abslog=`"$log`"")
$p=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$p.WaitForExit(240000)){Stop-Process -Id $p.Id;throw "Unified presentation test timeout: $log"}
if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -Pattern 'UNIFIED_PRESENTATION_PASS' -SimpleMatch -Quiet)){throw "Unified presentation test failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'UNIFIED_PRESENTATION_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "Unified presentation test reported errors: $log"}
"UNIFIED_PRESENTATION_PASS $Width`x$Height"
