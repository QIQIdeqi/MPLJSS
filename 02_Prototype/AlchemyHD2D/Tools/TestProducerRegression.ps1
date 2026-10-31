param([string]$EngineRoot,[string]$BuildDirectory,[switch]$Visual)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path $project 'Evidence/ProducerRegression'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$log=Join-Path $evidence $(if($Visual){'visual.log'}else{'rules.log'})
if($BuildDirectory){
    $exe=[IO.Path]::GetFullPath((Join-Path $project "../../03_Build/$BuildDirectory/Windows/AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe"))
    $launch=@('/Game/Greyford/Maps/Greyford_Flow')
}else{
    if(!$EngineRoot){$EngineRoot=$env:UE_ENGINE_ROOT}
    if(!$EngineRoot){$EngineRoot=@('D:\02_UnrealEngine\UE_5.8','F:\EPIC GAME\UE_5.8') | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe')} | Select-Object -First 1}
    if(!$EngineRoot){throw 'UE5.8 not found. Pass -EngineRoot.'}
    $exe=Join-Path $EngineRoot 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe'
    $launch=@("`"$(Join-Path $project 'AlchemyHD2D.uproject')`"",'/Game/Greyford/Maps/Greyford_Flow','-game')
}
$launch+=@('-unattended','-nosound','-ProducerRegression',"-abslog=`"$log`"")
if($Visual){$launch+=@('-ProducerVisual','-d3d12','-RenderOffscreen','-windowed','-ForceRes','-ResX=1280','-ResY=720','-benchmark','-fps=60')}
else{$launch+='-nullrhi'}
$process=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$process.WaitForExit(120000)){Stop-Process -Id $process.Id;throw 'Producer regression timed out.'}
if($process.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'PRODUCER_REGRESSION_PASS' -Quiet)){throw "Producer regression failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'PRODUCER_CHECK .* FAIL|Fatal error:|Ensure condition failed' -Quiet){throw "Producer regression reported errors: $log"}
if($Visual){foreach($name in @('nuclear-result.png','unfinished-tutorial-boss-alchemy.png')){if(!(Test-Path -LiteralPath (Join-Path $evidence $name))){throw "Missing visual capture: $name"}}}
Write-Output "PRODUCER_REGRESSION_PASS -- $log"
