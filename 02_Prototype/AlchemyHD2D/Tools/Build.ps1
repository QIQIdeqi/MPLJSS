param([switch]$Package,[string]$BuildDirectory='HD2D_PC_UI',[string]$EngineRoot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $EngineRoot) { $EngineRoot = $env:UE_ENGINE_ROOT }
if (-not $EngineRoot) {
    $engineCandidates=@('D:\02_UnrealEngine\UE_5.8','F:\EPIC GAME\UE_5.8')
    $installed=(Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\EpicGames\Unreal Engine\5.8' -ErrorAction SilentlyContinue).InstalledDirectory
    if($installed) {$engineCandidates=@($installed)+$engineCandidates}
    $EngineRoot=$engineCandidates | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'Engine/Build/BatchFiles/Build.bat')} | Select-Object -First 1
}
if(-not $EngineRoot -or -not (Test-Path -LiteralPath (Join-Path $EngineRoot 'Engine/Build/BatchFiles/Build.bat'))) {throw 'UE5.8 not found. Pass -EngineRoot or set UE_ENGINE_ROOT.'}
$aliasRoot=$projectRoot
if($projectRoot -match '[^\x00-\x7F]|\s') {
    $aliasRoot=Join-Path ([IO.Path]::GetPathRoot($EngineRoot)) '03_UEProject/AlchemyHD2DResearch'
    if(-not (Test-Path -LiteralPath $aliasRoot)) {New-Item -ItemType Directory -Path (Split-Path -Parent $aliasRoot) -Force | Out-Null;New-Item -ItemType Junction -Path $aliasRoot -Target $projectRoot | Out-Null}
    $existing=@((Get-Item -LiteralPath $aliasRoot).Target) | Select-Object -First 1
    if($existing -and [IO.Path]::GetFullPath($existing) -ne [IO.Path]::GetFullPath($projectRoot)) {throw 'Project alias belongs to another workspace.'}
}
& "$engineRoot\Engine\Build\BatchFiles\Build.bat" AlchemyHD2DEditor Win64 Development "-Project=$aliasRoot\AlchemyHD2D.uproject" "-Log=$aliasRoot\Evidence\build-editor.log" -WaitMutex -NoHotReloadFromIDE -NoUBA
if ($LASTEXITCODE -ne 0) { throw 'Editor build failed.' }
if ($Package) {
    & "$engineRoot\Engine\Build\BatchFiles\RunUAT.bat" BuildCookRun "-project=$aliasRoot\AlchemyHD2D.uproject" -noP4 -platform=Win64 -clientconfig=Development -build -cook -stage -pak -archive "-archivedirectory=$projectRoot\..\..\03_Build\$BuildDirectory" -utf8output -unattended
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed.' }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LaunchDemo.cmd') -Destination (Join-Path $projectRoot "../../03_Build/$BuildDirectory/启动Demo.cmd")
}
