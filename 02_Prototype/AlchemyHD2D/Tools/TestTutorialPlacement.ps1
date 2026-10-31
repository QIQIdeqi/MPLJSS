param([int]$Width=1280,[int]$Height=720)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/TutorialPlacement_20261101/${Width}x${Height}"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$started=Get-Date
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-TutorialPlacementTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60','-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
$finished=$run.WaitForExit(180000)
if(!$finished){Stop-Process -Id $run.Id}
# Preserve a warning image on assertion failure too; never copy a stale prior-run image.
$warning=Join-Path $project "Evidence/TutorialPlacement_20261101/01-warning_${Width}x${Height}.png"
if((Test-Path -LiteralPath $warning) -and (Get-Item -LiteralPath $warning).LastWriteTime -ge $started){Copy-Item -LiteralPath $warning -Destination (Join-Path $folder '01-warning.png') -Force}
if(!$finished){throw "TutorialPlacement timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'TUTORIAL_PLACEMENT_PASS' -Quiet)){throw "TutorialPlacement failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'TUTORIAL_PLACEMENT_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:|Failed to add hitbox named' -Quiet){throw "TutorialPlacement reported errors: $log"}
Select-String -LiteralPath $log -Pattern 'TUTORIAL_PLACEMENT_BRANCH|TUTORIAL_PLACEMENT_SKIP|TUTORIAL_PLACEMENT_SUMMARY' | ForEach-Object {$_.Line}
Write-Output "TUTORIAL_PLACEMENT_PASS ${Width}x${Height} $log"
