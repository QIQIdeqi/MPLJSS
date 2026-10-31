param([int]$Width=1280,[int]$Height=720,[int]$Seed=77)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/TeachingJourney_20261101/${Width}x${Height}/seed_${Seed}"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$jsonPath=Join-Path $folder 'journey.json'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-TeachingJourneyTest',"-JourneySeed=$Seed",'-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60','-unattended','-nosound',"-abslog=`"$log`"")
$started=Get-Date
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "TeachingJourney timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'TEACHING_JOURNEY_DONE' -Quiet)){throw "TeachingJourney observation failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'TEACHING_JOURNEY_FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "TeachingJourney reported technical errors: $log"}
if(!(Test-Path -LiteralPath $jsonPath) -or (Get-Item -LiteralPath $jsonPath).LastWriteTime -lt $started){throw "TeachingJourney missing current JSON: $jsonPath"}
$result=Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
if($result.schemaVersion -ne 1 -or !$result.invariantOK -or $result.outcome -notin @('complete','death','timebox') -or $result.seed -ne $Seed -or $result.width -ne $Width -or $result.height -ne $Height){throw "TeachingJourney JSON schema/invariant mismatch: $jsonPath"}
Write-Output "TEACHING_JOURNEY_DONE outcome=$($result.outcome) seed=$Seed viewport=${Width}x${Height} seconds=$($result.runTime) $jsonPath"
