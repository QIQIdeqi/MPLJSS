param([int]$Width=1280,[int]$Height=720)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/RoseMageAttack_20261101/$Width`x$Height"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-BattlePresentationCapture','-RoseAttackCapture','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60','-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "RoseMage attack timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'BATTLE_PRESENTATION_PASS' -Quiet)){throw "RoseMage attack failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'BATTLE_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "RoseMage attack reported errors: $log"}
foreach($name in @('01-side-attack.png','02-front-attack.png','03-back-attack.png','04-left-attack.png')){Copy-Item -LiteralPath (Join-Path $project "Evidence/RoseMageAttack_20261101/$name") -Destination (Join-Path $folder $name) -Force}
Write-Output "ROSE_ATTACK_PASS $Width`x$Height $log"
