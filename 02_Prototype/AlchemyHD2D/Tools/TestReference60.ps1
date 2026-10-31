param([int]$Width=1672,[int]$Height=940)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/Reference60_20261031/$Width`x$Height"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-Reference60Test','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60','-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "Reference60 timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'REFERENCE60_PASS' -Quiet)){throw "Reference60 failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'REFERENCE60_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "Reference60 reported errors: $log"}
foreach($name in @('01-field-reference-ui.png','02-running-side.png','03-running-back.png','04-running-front.png','05-hurt-frame.png','06-death-early.png','07-death-late.png')){Copy-Item -LiteralPath (Join-Path $project "Evidence/Reference60_20261031/$name") -Destination (Join-Path $folder $name) -Force}
Write-Output "REFERENCE60_PASS $Width`x$Height $log"
