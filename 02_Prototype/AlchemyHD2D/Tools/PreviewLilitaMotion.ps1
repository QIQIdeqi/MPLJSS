param([switch]$EncodeOnly,[string]$Frames)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$workspace=[IO.Path]::GetFullPath((Join-Path $project '../..'))
if(!$Frames){$Frames=Join-Path $project ('Evidence/MotionPreview_20261101/'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))}
$Frames=[IO.Path]::GetFullPath($Frames)
New-Item -ItemType Directory -Force -Path $Frames | Out-Null
$log=Join-Path $Frames 'native.log'
if(!$EncodeOnly){
    $launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-MotionPreview',"-MotionPreviewOut=`"$Frames`"",'-d3d12','-RenderOffscreen','-windowed','-ForceRes','-ResX=1280','-ResY=720','-benchmark','-fps=20','-unattended','-nosound',"-abslog=`"$log`"")
    $run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
    if(!$run.WaitForExit(240000)){Stop-Process -Id $run.Id;throw "Motion preview timeout: $log"}
    if($run.ExitCode -ne 0){throw "Motion preview failed: $log"}
}
$result=Get-Content -LiteralPath (Join-Path $Frames 'result.json') -Raw | ConvertFrom-Json
if($result.result -ne 'PASS' -or !(Select-String -LiteralPath $log -SimpleMatch 'MOTION_PREVIEW_PASS' -Quiet)){throw "Motion preview checks failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'Fatal error:|Ensure condition failed|MOTION_PREVIEW_FAIL|LogMaterial: Error:' -Quiet){throw "Motion preview engine error: $log"}
for($i=0;$i -lt $result.frames;$i++){if(!(Test-Path -LiteralPath (Join-Path $Frames ('frame-{0:D5}.png' -f $i)))){throw "Missing frame $i"}}
$video=Join-Path $Frames 'Lilita-motion.mp4'
$ffmpeg=Join-Path $workspace '01_Skill/tools/ffmpeg/ffmpeg.exe'
$ffprobe=Join-Path $workspace '01_Skill/tools/ffmpeg/ffprobe.exe'
& $ffmpeg -hide_banner -loglevel error -y -framerate 20 -i (Join-Path $Frames 'frame-%05d.png') -frames:v $result.frames -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -movflags +faststart -an $video
if($LASTEXITCODE -ne 0){throw 'Motion video encode failed'}
& $ffprobe -v error -count_frames -show_streams -show_format -of json $video | Set-Content -LiteralPath (Join-Path $Frames 'ffprobe.json') -Encoding utf8
if($LASTEXITCODE -ne 0){throw 'Motion video probe failed'}
$probe=Get-Content -LiteralPath (Join-Path $Frames 'ffprobe.json') -Raw | ConvertFrom-Json
$stream=$probe.streams | Where-Object {$_.codec_type -eq 'video'} | Select-Object -First 1
if(!$stream -or [int]$stream.nb_read_frames -ne [int]$result.frames -or $stream.avg_frame_rate -ne '20/1' -or $stream.width -ne 1280 -or $stream.height -ne 720){throw 'Encoded motion frames/rate/size do not match native capture'}
& $ffmpeg -v error -i $video -f null -
if($LASTEXITCODE -ne 0){throw 'Motion video decode failed'}
Write-Output "MOTION_VIDEO_PASS $video"
