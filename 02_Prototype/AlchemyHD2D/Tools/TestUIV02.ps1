param([int]$Width=1280,[int]$Height=720)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/UIV02_20261031/$Width`x$Height"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-UIV02Test','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60','-unattended','-nosound',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "UIV02 timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'UIV02_PASS' -Quiet)){throw "UIV02 failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'UIV02_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){throw "UIV02 reported errors: $log"}
foreach($name in @('01-ten-upgrades.png','02-alchemy-notes.png','03-battle-guidance-toast.png','04-codex-high-IDs.png')){Copy-Item -LiteralPath (Join-Path $project "Evidence/UIV02_20261031/$name") -Destination (Join-Path $folder $name) -Force}
Write-Output "UIV02_PASS $Width`x$Height $log"
