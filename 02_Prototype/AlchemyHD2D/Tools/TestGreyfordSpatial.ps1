param([string]$BuildDirectory='Greyford_Spatial_Win64_20261030')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$build=[IO.Path]::GetFullPath((Join-Path $project "../../03_Build/$BuildDirectory"))
$exe=Join-Path $build 'Windows/AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe'
$root='D:/03_UEProject/AlchemyHD2DResearch'
foreach($mode in @('spatial','flow-wide','flow-tall')) {
    $size=if($mode -eq 'flow-tall'){@(1024,768)}else{@(1280,720)}
    $log="$root/Evidence/spatial-packaged-$mode.log"
    $dest="$root/Evidence/Greyford/Spatial/Packaged-$mode"
    New-Item -ItemType Directory -Force $dest | Out-Null
    $launch=@('/Game/Greyford/Maps/Greyford_Flow','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$($size[0])","-ResY=$($size[1])",'-unattended','-nosound','-benchmark','-fps=60',"-abslog=$log")
    if($mode -eq 'spatial'){$launch+=@('-GreyfordSpatialTest','-GreyfordReferenceCapture',"-GreyfordSpatialSpec=$root/Tools/GreyfordSpatial.json","-GreyfordSpatialOut=$dest");$marker='GREYFORD_SPATIAL_PASS'}
    else{$launch+='-GreyfordFlowTest';$marker='GREYFORD_FLOW_PASS'}
    $p=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -Wait -PassThru
    if($mode -ne 'spatial'){Copy-Item (Join-Path $build 'Windows/AlchemyHD2D/Evidence/Greyford/Flow/*') $dest}
    if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch $marker -Quiet)){throw "Spatial build verification failed: $mode"}
    if(Select-String -LiteralPath $log -Pattern 'Failed to compile Material|Ensure condition failed|Fatal error:|LogShaderCompilers: Error:|LogMaterial: Error:' -Quiet){throw "Rendering error: $mode"}
    Write-Output "$mode D3D12 PASS"
}
& (Join-Path $PSScriptRoot 'Smoke.ps1') -Packaged -BuildDirectory $BuildDirectory
