param([int]$Width=1280,[int]$Height=720,[ValidateRange(10,120)][int]$FPS=60)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/StateFlow_20261101/${Width}x${Height}/${FPS}fps"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-StateFlowTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark',"-fps=$FPS",'-unattended','-nosound',"-abslog=`"$log`"")
$started=Get-Date
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "StateFlow timeout: $log"}
$name='01-death-settlement.png'
$source=Join-Path $project "Evidence/StateFlow_20261101/$name"
$hasCurrentImage=(Test-Path -LiteralPath $source) -and (Get-Item -LiteralPath $source).LastWriteTime -ge $started
if($hasCurrentImage){Copy-Item -LiteralPath $source -Destination (Join-Path $folder $name) -Force}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'STATE_FLOW_PASS' -Quiet)){throw "StateFlow failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'STATE_FLOW_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:|Failed to add hitbox named' -Quiet){throw "StateFlow reported errors: $log"}
if(!$hasCurrentImage){throw "StateFlow missing current native screenshot: $folder"}
Write-Output "STATE_FLOW_PASS $Width`x$Height $FPS fps $log"
