param([int]$Width=1280,[int]$Height=720,[int]$FPS=60,[switch]$RecoveryTrial)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$evidence=if($RecoveryTrial){'Evidence/RandomLayers_20261106/RecoveryTrial'}else{'Evidence/RandomLayers_20261104/Native'}
$folder=Join-Path $root "$evidence/$Width`x$Height-$FPS"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-RandomLayersTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark',"-fps=$FPS",'-unattended','-nosound',"-abslog=`"$log`"")
if($RecoveryTrial){$launch+='-AlchemyRecoveryTrial'}
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "Random layers timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'RANDOM_LAYERS_PASS' -Quiet)){throw "Random layers failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'RANDOM_LAYERS_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "Random layers reported errors: $log"}
foreach($seed in 77,78,79){foreach($stage in 'field','boss'){Copy-Item -LiteralPath (Join-Path $root "$evidence/seed_$seed`_$stage.png") -Destination $folder -Force}}
Write-Output "RANDOM_LAYERS_PASS $Width`x$Height-$FPS $log"
