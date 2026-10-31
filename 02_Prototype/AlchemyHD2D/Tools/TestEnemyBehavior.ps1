param([ValidateRange(10,120)][int]$FPS=60)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/EnemyBehavior_20261101/${FPS}fps"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-EnemyBehaviorTest','-nullrhi','-benchmark',"-fps=$FPS",'-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "EnemyBehavior timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'ENEMY_BEHAVIOR_PASS' -Quiet)){throw "EnemyBehavior failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'ENEMY_BEHAVIOR_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "EnemyBehavior reported errors: $log"}
Write-Output "ENEMY_BEHAVIOR_PASS ${FPS}fps $log"
