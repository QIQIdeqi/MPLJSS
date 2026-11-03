param(
    [string]$EngineRoot,
    [ValidateRange(10,120)][int]$FPS=60
)

$ErrorActionPreference='Stop'
$brewProject=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$brewProjectFile=Join-Path $brewProject 'AlchemyHD2D.uproject'
$brewMap=Join-Path $brewProject 'Content/Greyford/Maps/Greyford_Flow.umap'
if(!(Test-Path -LiteralPath $brewProjectFile) -or !(Test-Path -LiteralPath $brewMap)) {
    throw "Brew V0.2 test requires the current AlchemyHD2D project and Greyford_Flow map: $brewProject"
}

$brewExe=$null
if($EngineRoot) {
    if(!(Test-Path -LiteralPath $EngineRoot)) {throw "UE 5.8 editor not found under -EngineRoot: $EngineRoot"}
    $brewExe=Join-Path $EngineRoot 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe'
    if(!(Test-Path -LiteralPath $brewExe)) {throw "UE 5.8 editor not found under -EngineRoot: $EngineRoot"}
} else {
    $brewRoots=@()
    if($env:UE_ENGINE_ROOT) {$brewRoots+=,$env:UE_ENGINE_ROOT}
    $brewInstalled=(Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\EpicGames\Unreal Engine\5.8' -ErrorAction SilentlyContinue).InstalledDirectory
    if($brewInstalled) {$brewRoots+=,$brewInstalled}
    $brewRoots+=@('D:\02_UnrealEngine\UE_5.8','F:\EPIC GAME\UE_5.8')
    foreach($brewRoot in $brewRoots) {
        if(!(Test-Path -LiteralPath $brewRoot)) {continue}
        $brewCandidate=Join-Path $brewRoot 'Engine/Binaries/Win64/UnrealEditor-Cmd.exe'
        if(Test-Path -LiteralPath $brewCandidate) {$brewExe=$brewCandidate;break}
    }
    if(!$brewExe) {
        $brewCommand=Get-Command 'UnrealEditor-Cmd.exe' -ErrorAction SilentlyContinue
        if($brewCommand) {$brewExe=$brewCommand.Source}
    }
    if(!$brewExe) {throw 'UE 5.8 UnrealEditor-Cmd.exe is unavailable. Pass -EngineRoot or set UE_ENGINE_ROOT.'}
}

$brewRunId=('{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'),[Guid]::NewGuid().ToString('N').Substring(0,8))
$brewEvidence=Join-Path $brewProject "Evidence/BrewV02/${FPS}fps-$brewRunId"
New-Item -ItemType Directory -Force -Path $brewEvidence | Out-Null
$brewLog=Join-Path $brewEvidence 'native.log'
$brewLaunch=@(
    "`"$brewProjectFile`"",
    '/Game/Greyford/Maps/Greyford_Flow',
    '-game',
    '-BrewV02Test',
    '-nullrhi',
    '-benchmark',
    "-fps=$FPS",
    '-unattended',
    '-nosound',
    "-abslog=`"$brewLog`""
)
$brewProcess=Start-Process -FilePath $brewExe -ArgumentList $brewLaunch -WindowStyle Hidden -PassThru
if(!$brewProcess.WaitForExit(180000)) {
    Stop-Process -Id $brewProcess.Id
    throw "Brew V0.2 test timed out: $brewLog"
}
if(!(Test-Path -LiteralPath $brewLog)) {throw "Brew V0.2 test produced no log: $brewLog"}
if($brewProcess.ExitCode -ne 0 -or !(Select-String -LiteralPath $brewLog -SimpleMatch 'BREW_V02_PASS' -Quiet)) {
    throw "Brew V0.2 test failed (exit $($brewProcess.ExitCode)): $brewLog"
}
if(Select-String -LiteralPath $brewLog -Pattern 'BREW_V02_CHECK .* FAIL|Fatal error:|Ensure condition failed' -Quiet) {
    throw "Brew V0.2 test reported an error: $brewLog"
}
Write-Output "BREW_V02_PASS ${FPS}fps $brewLog"
