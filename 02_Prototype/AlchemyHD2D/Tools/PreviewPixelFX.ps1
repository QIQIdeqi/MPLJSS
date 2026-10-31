param([switch]$EncodeOnly)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$workspace=[IO.Path]::GetFullPath((Join-Path $project '../..'))
$evidence=Join-Path $project 'Evidence/PixelFX'
$frames=Join-Path $evidence 'Capture'
$engine='D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor.exe'
if(!$EncodeOnly){
    $launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-game','-d3d12','-RenderOffscreen','-windowed','-ForceRes','-ResX=1280','-ResY=720','-unattended','-nosound','-benchmark','-fps=60','-PixelFXCapture','-GreyfordReferenceCapture','-abslog=D:/03_UEProject/AlchemyHD2DResearch/Evidence/PixelFX/capture.log')
    $p=Start-Process -FilePath $engine -ArgumentList $launch -WindowStyle Hidden -Wait -PassThru
    if($p.ExitCode -ne 0){throw "Unreal preview failed: $($p.ExitCode)"}
}
if(!(Select-String -LiteralPath (Join-Path $frames 'result.txt') -Pattern '^result=PASS$' -Quiet)){throw 'PixelFX visual sequence checks failed'}
if(!(Select-String -LiteralPath (Join-Path $evidence 'capture.log') -Pattern 'PIXELFX_CHECK_PASS' -SimpleMatch -Quiet)){throw 'Current Unreal run did not finish the preview checks'}
if(Select-String -LiteralPath (Join-Path $evidence 'capture.log') -Pattern 'LogMaterial: Error:|Failed to compile Material|Fatal error:|Ensure condition failed|PIXELFX_MISSING_ASSET' -Quiet){throw 'Unreal rendering or asset error'}
$ffmpeg=Join-Path $workspace '01_Skill/tools/ffmpeg/ffmpeg.exe'
$ffprobe=Join-Path $workspace '01_Skill/tools/ffmpeg/ffprobe.exe'
$dest=Join-Path $workspace '03_Build/Previews';New-Item -ItemType Directory -Force $dest | Out-Null
$video=Join-Path $dest 'PixelFX_命中_毒雾_传送门_2026-10-31.mp4'
$labels=@('命中火花 · 实际受击事件','毒雾 · 人物穿过前后烟层','传送门 · 人物比例与前后遮挡','桥梁遮挡 · 栏杆与特效分层')
$filters=@("drawbox=x=18:y=18:w=640:h=54:color=black@0.65:t=fill")
for($i=0;$i -lt $labels.Count;$i++){
    $file=Join-Path $evidence "caption-$i.txt"
    [IO.File]::WriteAllText($file,$labels[$i],[Text.UTF8Encoding]::new($false))
    $escaped=$file.Replace('\','/').Replace(':','\:')
    $filters+="drawtext=fontfile='D\:/02_UnrealEngine/UE_5.8/Engine/Content/Slate/Fonts/DroidSansFallback.ttf':textfile='$escaped':fontsize=25:fontcolor=white:x=32:y=32:enable='gte(t,$($i*5))*lt(t,$(($i+1)*5))'"
}
& $ffmpeg -hide_banner -loglevel error -y -framerate 20 -i (Join-Path $frames 'frame-%05d.png') -vf ($filters -join ',') -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -movflags +faststart -an $video
if($LASTEXITCODE -ne 0){throw 'Video encode failed'}
& $ffprobe -v error -show_streams -show_format -of json $video | Set-Content -Encoding utf8 (Join-Path $evidence 'video-ffprobe.json')
if($LASTEXITCODE -ne 0){throw 'Video probe failed'}
& $ffmpeg -v error -i $video -f null -
if($LASTEXITCODE -ne 0){throw 'Video decode failed'}
Get-FileHash -Algorithm SHA256 -LiteralPath $video | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $evidence 'video-sha256.json')
Write-Output "PIXELFX_VIDEO_PASS $video"
