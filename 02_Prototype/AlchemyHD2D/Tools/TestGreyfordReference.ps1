$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$build=[IO.Path]::GetFullPath((Join-Path $project '../../03_Build/Greyford_Reference_Win64_20261030'))
$exe=Join-Path $build 'Windows/AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe'
foreach($mode in @('1672x941','1024x768','clean')) {
    $size=if($mode -eq '1024x768'){@(1024,768)}else{@(1672,941)}
    $log="D:\03_UEProject\AlchemyHD2DResearch\Evidence\reference-packaged-$mode.log"
    $launch=@('/Game/Greyford/Maps/Greyford_Flow','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$($size[0])","-ResY=$($size[1])",'-unattended','-nosound','-benchmark','-fps=60','-GreyfordFlowTest',"-abslog=$log")
    if($mode -ne '1024x768'){$launch+='-GreyfordReferenceCapture'}
    if($mode -eq 'clean'){$launch+='-GreyfordReferenceClean'}
    $p=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -Wait -PassThru
    $dest=Join-Path $project "Evidence/Greyford/Reference/Packaged-$mode"
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item (Join-Path $build 'Windows/AlchemyHD2D/Evidence/Greyford/Flow/*') $dest
    if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -Pattern 'GREYFORD_FLOW_PASS' -SimpleMatch -Quiet)){throw "Reference verification failed: $mode"}
    Write-Output "Reference D3D12 $mode PASS"
}
& (Join-Path $PSScriptRoot 'Smoke.ps1') -Packaged -BuildDirectory 'Greyford_Reference_Win64_20261030'
