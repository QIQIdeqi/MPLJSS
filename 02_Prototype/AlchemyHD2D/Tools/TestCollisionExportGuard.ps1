$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project 'Evidence/CollisionExportGuard_20261101'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder ('editor_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.log')
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','-CollisionExportGuardTest','-nullrhi','-RenderOffscreen','-unattended','-nosound','-ExecutePythonScript=D:/03_UEProject/AlchemyHD2DResearch/Tools/TestCollisionExportGuard.py',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "Collision guard timeout: $log"}
$result=Get-Content -LiteralPath (Join-Path $folder 'editor-checks.json') -Raw | ConvertFrom-Json
if($run.ExitCode -ne 0 -or $result.result -ne 'PASS' -or !(Select-String -LiteralPath $log -SimpleMatch 'COLLISION_EXPORT_GUARD_PASS' -Quiet)){throw "Collision guard failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'Fatal error:|Ensure condition failed|Assertion failed:|COLLISION_EXPORT_GUARD_FAIL' -Quiet){throw "Collision guard engine/script error: $log"}
Write-Output "COLLISION_EXPORT_GUARD_PASS $log"
