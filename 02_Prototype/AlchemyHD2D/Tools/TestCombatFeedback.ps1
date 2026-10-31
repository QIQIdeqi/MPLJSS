param([int]$Width=1280,[int]$Height=720,[ValidateRange(10,120)][int]$FPS=60)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/CombatFeedback_20261101/${Width}x${Height}-${FPS}fps"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-CombatFeedbackTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark',"-fps=$FPS",'-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "CombatFeedback timeout: $log"}
# Preserve the actual baseline image even when native assertions intentionally fail.
$name='01-last-windup-warning.png'
$source=Join-Path $project "Evidence/CombatFeedback_20261101/$name"
if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $folder $name) -Force}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'COMBAT_FEEDBACK_PASS' -Quiet)){throw "CombatFeedback failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'COMBAT_FEEDBACK_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:|Failed to add hitbox named' -Quiet){throw "CombatFeedback reported errors: $log"}
if(!(Test-Path -LiteralPath (Join-Path $folder $name))){throw "CombatFeedback missing native screenshot: $folder"}
Write-Output "COMBAT_FEEDBACK_PASS $Width`x$Height $FPS fps $log"
