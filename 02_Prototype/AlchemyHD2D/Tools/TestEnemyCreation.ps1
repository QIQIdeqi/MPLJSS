$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project 'Evidence/EnemyCreation_20261101'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder ('native_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.log')
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-EnemyCreationTest','-nullrhi','-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "EnemyCreation timeout: $log"}
# The fixture intentionally emits ordinary SavePackage errors inside named intervals.
# Reject failed checks and engine failures, but do not mistake expected ordinary errors for a crash.
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -Pattern 'ENEMY_CREATION_PASS checks=' -Quiet)){throw "EnemyCreation failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'ENEMY_CREATION_CHECK .* FAIL|Fatal error:|Ensure condition failed|Assertion failed:|LowLevelFatalError|appError called:|=== Critical error: ===' -Quiet){throw "EnemyCreation invariant/crash: $log"}
Write-Output "ENEMY_CREATION_PASS $log"
