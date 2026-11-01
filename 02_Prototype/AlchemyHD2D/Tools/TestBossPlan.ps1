param([string]$BuildDirectory,[switch]$Visual,[string]$EngineRoot)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path $project 'Evidence/BossPlan'
New-Item -ItemType Directory -Force $evidence | Out-Null
if($BuildDirectory){
    $build=[IO.Path]::GetFullPath((Join-Path $project "../../03_Build/$BuildDirectory"))
    $exe=Join-Path $build 'Windows/AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe'
    $launch=@('/Game/Greyford/Maps/Greyford_Flow');$mode='packaged'
}else{
    if(!$EngineRoot){$EngineRoot=$env:UE_ENGINE_ROOT}
    if(!$EngineRoot){$EngineRoot=@('D:/02_UnrealEngine/UE_5.8','F:/EPIC GAME/UE_5.8') | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe')} | Select-Object -First 1}
    if(!$EngineRoot){throw 'UE5.8 not found. Pass -EngineRoot.'}
    $exe=Join-Path $EngineRoot 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe'
    $launch=@("`"$(Join-Path $project 'AlchemyHD2D.uproject')`"",'/Game/Greyford/Maps/Greyford_Flow','-game');$mode='current'
}
if(!(Test-Path -LiteralPath $exe)){throw "Boss test executable missing: $exe"}
$log=Join-Path $evidence ($mode+$(if($Visual){'-visual-'}else{'-rules-'})+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'.log')
$launch+=@('-unattended','-nosound',"-abslog=`"$log`"")
if($Visual){$launch+=@('-d3d12','-RenderOffscreen','-windowed','-ForceRes','-ResX=1280','-ResY=720','-benchmark','-fps=60','-PlannedBossCapture')}
else{$launch+=@('-nullrhi','-PlannedBossTest')}
$started=Get-Date
$p=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$p.WaitForExit(120000)){Stop-Process -Id $p.Id;throw 'Boss check timed out.'}
$marker=if($Visual){'PLANNED_BOSS_CAPTURE_PASS'}else{'PLANNED_BOSS_PASS'}
if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch $marker -Quiet)){throw "Boss check failed; inspect $log"}
if(Select-String -LiteralPath $log -Pattern 'PLANNED_BOSS_CHECK .* FAIL|Fatal error:|Ensure condition failed' -Quiet){throw "Boss check error: $log"}
if($Visual){
    if(!$BuildDirectory -and !(Select-String -LiteralPath $log -SimpleMatch 'PLANNED_BOSS_PAUSE_FRAME_PASS' -Quiet)){throw "Boss pause frame not verified: $log"}
    $images=Join-Path $evidence ([IO.Path]::GetFileNameWithoutExtension($log))
    New-Item -ItemType Directory -Force -Path $images | Out-Null
    foreach($name in @('01-preparation.png','02-dash-aiming.png','03-dash-locked.png','04-first-fan.png','05-second-wave-lock.png','06-two-wave-flight.png','07-paused-config.png')){
        $source=Join-Path $(if($BuildDirectory){Join-Path $build 'Windows/AlchemyHD2D/Evidence/BossPlan/Visual'}else{Join-Path $evidence 'Visual'}) $name
        if(!(Test-Path -LiteralPath $source) -or (Get-Item -LiteralPath $source).LastWriteTime -lt $started){throw "Boss screenshot missing or stale: $source"}
        Copy-Item -LiteralPath $source -Destination (Join-Path $images $name)
    }
}
Write-Output "$marker -- $log"
