param([int]$Width=1280,[int]$Height=720,[int]$FPS=60)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$dir=Join-Path $project 'Evidence/VillagePresentation_20261031'
$log=Join-Path $dir "native-$Width`x$Height.log"
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','-game','-VillagePresentationTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark',"-fps=$FPS",'-unattended','-nosound',"-abslog=`"$log`"")
$p=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$p.WaitForExit(240000)){Stop-Process -Id $p.Id;throw "Village test timeout: $log"}
if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -Pattern 'VILLAGE_PRESENTATION_PASS' -SimpleMatch -Quiet)){throw "Village test failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'VILLAGE_PRESENTATION_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "Village test reported errors: $log"}
"VILLAGE_PRESENTATION_PASS $Width`x$Height"
