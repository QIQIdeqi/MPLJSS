param(
    [Parameter(Mandatory=$true)][string]$EngineRoot,
    [ValidateRange(800,7680)][int]$Width=1280,
    [ValidateRange(600,4320)][int]$Height=720,
    [ValidateRange(0,2)][int]$Main=2,
    [ValidateRange(1,3)][int]$Count=2,
    [ValidateRange(0,10)][int]$SupportStock=8
)

$ErrorActionPreference='Stop'
$project=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$editor=Join-Path $EngineRoot 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe'
if(!(Test-Path -LiteralPath $editor)){throw "UE5.8 editor not found: $editor"}
$projectFile=Join-Path $project 'AlchemyHD2D.uproject'
$evidence=Join-Path $project 'Evidence/BrewV02'
$imageFolder=Join-Path $project 'Evidence/PC_UI'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$runId=('{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'),[Guid]::NewGuid().ToString('N').Substring(0,8))
$log=Join-Path $evidence ("visual-{0}x{1}-main{2}-count{3}-support{4}-{5}.log" -f $Width,$Height,$Main,$Count,$SupportStock,$runId)
$launchArgs=@(
    "`"$projectFile`"",
    '/Game/Greyford/Maps/Greyford_Flow',
    '-game','-AlchemyPCCapture','-BrewV02Visual',
    "-BrewVisualMain=$Main","-BrewVisualCount=$Count","-BrewVisualSupportStock=$SupportStock",
    '-d3d12','-RenderOffscreen','-windowed','-ForceRes',
    "-ResX=$Width","-ResY=$Height",
    '-benchmark','-fps=60','-unattended','-nosound',
    "-abslog=`"$log`""
)
$started=Get-Date
$process=Start-Process -FilePath $editor -ArgumentList $launchArgs -WindowStyle Hidden -PassThru
if(!$process.WaitForExit(180000)){
    Stop-Process -Id $process.Id
    throw "Brew V0.2 visual capture timed out: $log"
}
if(!(Test-Path -LiteralPath $log)){throw "Brew V0.2 visual capture produced no log: $log"}
if($process.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'BREW_V02_VISUAL_PASS' -Quiet)){
    throw "Brew V0.2 visual capture failed (exit $($process.ExitCode)): $log"
}
if(Select-String -LiteralPath $log -Pattern 'BREW_V02_VISUAL_FAIL|PC_UI_BUTTON_OVERFLOW|Fatal error:|Ensure condition failed' -Quiet){
    throw "Brew V0.2 visual capture reported an error: $log"
}
$image=Get-ChildItem -LiteralPath $imageFolder -Filter ("BrewV02_PC_{0}x{1}_*.png" -f $Width,$Height) |
    Where-Object {$_.LastWriteTime -ge $started.AddSeconds(-1)} |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if(!$image -or $image.Length -le 0){throw "Brew V0.2 visual capture has no current image: $log"}
Write-Output "BREW_V02_VISUAL_PASS main=$Main count=$Count support=$SupportStock $Width x $Height $($image.FullName) $log"
