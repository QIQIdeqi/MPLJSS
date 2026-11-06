param([int]$FPS=60,[string]$EngineRoot='D:/02_UnrealEngine/UE_5.8')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path $project 'Evidence/TOD_20261106/ArtMatch'
$runFolder=Join-Path $evidence "D3D12-$FPS"
New-Item -ItemType Directory -Force $runFolder | Out-Null
$log=Join-Path $runFolder 'native.log'
$exe=Join-Path $EngineRoot 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe'
$launch=@("`"$(Join-Path $project 'AlchemyHD2D.uproject')`"",'/Game/Greyford/Maps/Greyford_Flow',
    '-game','-GreyfordTODTest','-MapSeed=77','-d3d12','-RenderOffscreen','-windowed','-ForceRes',
    '-ResX=1280','-ResY=720','-benchmark',"-fps=$FPS",'-unattended','-nosound',"-abslog=`"$log`"")
$started=Get-Date
$run=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "TOD test timed out: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'GREYFORD_TOD_PASS' -Quiet)){
    throw "TOD test failed: $log"
}
if(Select-String -LiteralPath $log -Pattern 'TOD_CHECK .* FAIL|Fatal error:|Ensure condition failed|LogMaterial: Error:|LogShaderCompilers: Error:' -Quiet){
    throw "TOD runtime or material error: $log"
}
foreach($name in @('01-field-1300.png','02-field-1800.png','02a-field-1800-no-projection.png','03-field-2200.png','04-boss-entry.png','05-boss-warning.png')){
    $shot=Join-Path $evidence $name
    if(!(Test-Path -LiteralPath $shot) -or (Get-Item -LiteralPath $shot).LastWriteTime -lt $started){throw "Missing fresh capture: $shot"}
    Copy-Item -LiteralPath $shot -Destination $runFolder -Force
}
Write-Output "GREYFORD_TOD_PASS fps=$FPS $log"
