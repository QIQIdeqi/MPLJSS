param([int]$Width=2560,[int]$Height=1080)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/EliteSpawn_20261101/$Width`x$Height"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-EliteSpawnTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60','-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "EliteSpawn timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'ELITESPAWN_PASS' -Quiet)){throw "EliteSpawn failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'ELITESPAWN_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "EliteSpawn reported errors: $log"}
foreach($name in @('01-pre-spawn-state.png','02-reposition-or-recheck.png','03-actual-elite.png')){Copy-Item -LiteralPath (Join-Path $project "Evidence/EliteSpawn_20261101/$name") -Destination (Join-Path $folder $name) -Force}
Write-Output "ELITESPAWN_PASS $Width`x$Height $log"
