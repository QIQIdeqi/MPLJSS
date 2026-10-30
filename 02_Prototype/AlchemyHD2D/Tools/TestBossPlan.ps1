param([string]$BuildDirectory='Greyford_BossPlan_Win64_20261030',[switch]$Visual)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$build=[IO.Path]::GetFullPath((Join-Path $project "../../03_Build/$BuildDirectory"))
$exe=Join-Path $build 'Windows/AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe'
$evidence=Join-Path $project 'Evidence/BossPlan'
New-Item -ItemType Directory -Force $evidence | Out-Null
$log=Join-Path $evidence $(if($Visual){'packaged-visual.log'}else{'packaged-rules.log'})
$launch=@('/Game/Greyford/Maps/Greyford_Flow','-unattended','-nosound',"-abslog=`"$log`"")
if($Visual){$launch+=@('-d3d12','-RenderOffscreen','-windowed','-ForceRes','-ResX=1280','-ResY=720','-benchmark','-fps=60','-PlannedBossCapture')}
else{$launch+=@('-nullrhi','-PlannedBossTest')}
$p=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$p.WaitForExit(120000)){Stop-Process -Id $p.Id;throw 'Boss check timed out.'}
$marker=if($Visual){'PLANNED_BOSS_CAPTURE_PASS'}else{'PLANNED_BOSS_PASS'}
if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch $marker -Quiet)){throw "Boss check failed; inspect $log"}
if(Select-String -LiteralPath $log -Pattern 'PLANNED_BOSS_CHECK .* FAIL|Fatal error:|Ensure condition failed' -Quiet){throw "Boss check error: $log"}
Write-Output "$marker -- $log"
