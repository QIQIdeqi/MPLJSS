param([int]$Width=1280,[int]$Height=720)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$folder=Join-Path $project "Evidence/UIAccess_20261101/$Width`x$Height"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$log=Join-Path $folder 'native.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-UIV02Test','-UIAccessTest','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$Width","-ResY=$Height",'-benchmark','-fps=60','-unattended','-nosound',"-abslog=`"$log`"")
$started=Get-Date
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "UIAccess timeout: $log"}
# Baseline failures still retain their current-run screenshot; never substitute an older image.
$hasCurrentImages=$true
foreach($name in @('01-keyboard-focus.png','03-boss-preparation.png','04-boss-idle.png')){
    $source=Join-Path $project "Evidence/UIAccess_20261101/$name"
    $current=(Test-Path -LiteralPath $source) -and (Get-Item -LiteralPath $source).LastWriteTime -ge $started
    if($current){Copy-Item -LiteralPath $source -Destination (Join-Path $folder $name) -Force}else{$hasCurrentImages=$false}
}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'UIACCESS_PASS' -Quiet)){throw "UIAccess failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'UIACCESS_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:|Failed to add hitbox named' -Quiet){throw "UIAccess reported errors: $log"}
if(!$hasCurrentImages){throw "UIAccess missing current native screenshot: $folder"}
Write-Output "UIACCESS_PASS $Width`x$Height $log"
