param([string]$BuildDirectory='Greyford_Ambient_Win64_20261030')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$build=[IO.Path]::GetFullPath((Join-Path $project "../../03_Build/$BuildDirectory"))
$exe=Join-Path $build 'Windows/AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe'
foreach($mode in @('1280x720','1024x768','overview','tour')) {
    $size=if($mode -eq '1024x768'){@(1024,768)}elseif($mode -eq 'overview'){@(1672,941)}else{@(1280,720)}
    $log="D:/03_UEProject/AlchemyHD2DResearch/Evidence/ambient-packaged-$mode.log"
    $launch=@('/Game/Greyford/Maps/Greyford_Flow','-d3d12','-RenderOffscreen','-windowed','-ForceRes',"-ResX=$($size[0])","-ResY=$($size[1])",'-unattended','-nosound','-benchmark','-fps=60',"-abslog=$log")
    if($mode -eq 'tour'){$launch+=@('-GreyfordAmbientTest','-GreyfordReferenceCapture')}
    else {$launch+='-GreyfordFlowTest'}
    if($mode -eq 'overview'){$launch+=@('-GreyfordReferenceOverview','-GreyfordReferenceCapture','-GreyfordReferenceClean')}
    $p=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -Wait -PassThru
    $dest=Join-Path $project "Evidence/Greyford/Ambient/Packaged-$mode"
    New-Item -ItemType Directory -Force $dest | Out-Null
    $relative=if($mode -eq 'tour'){'Ambient/Tour'}else{'Flow'}
    Copy-Item (Join-Path $build "Windows/AlchemyHD2D/Evidence/Greyford/$relative/*") $dest
    $marker=if($mode -eq 'tour'){'GREYFORD_AMBIENT_PASS'}else{'GREYFORD_FLOW_PASS'}
    if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -Pattern $marker -SimpleMatch -Quiet)){throw "Ambient verification failed: $mode"}
    if(Select-String -LiteralPath $log -Pattern 'Failed to compile Material|Ensure condition failed|Fatal error:|LogShaderCompilers: Error:|LogMaterial: Error:' -Quiet){throw "Rendering errors: $mode"}
    Write-Output "Ambient D3D12 $mode PASS"
}
& (Join-Path $PSScriptRoot 'Smoke.ps1') -Packaged -BuildDirectory $BuildDirectory
