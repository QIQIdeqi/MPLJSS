param([switch]$Visual,[int]$Width=1280,[int]$Height=720)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/BattlePresentation_20261031/$Width`x$Height"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder $(if($Visual){'visual.log'}else{'rules.log'})
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-unattended','-nosound',"-abslog=`"$log`"")
if($Visual){$launch+=@('-BattlePresentationCapture','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60')}
else{$launch+=@('-BattlePresentationTest','-nullrhi')}
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw 'Battle presentation check timed out.'}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'BATTLE_PRESENTATION_PASS' -Quiet)){throw "Battle presentation check failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'BATTLE_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "Battle presentation error: $log"}
if($Visual){foreach($name in @('01-field.png','02-boss-preparation.png')){Copy-Item -LiteralPath (Join-Path $project "Evidence/BattlePresentation_20261031/$name") -Destination (Join-Path $folder $name) -Force}}
Write-Output "BATTLE_PRESENTATION_PASS $Width`x$Height visual=$Visual"
