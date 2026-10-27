param([switch]$Package,[string]$BuildDirectory='HD2D_ALCH002')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$aliasRoot = 'D:\03_UEProject\AlchemyHD2DResearch'
if (-not (Test-Path -LiteralPath $aliasRoot)) {
    New-Item -ItemType Junction -Path $aliasRoot -Target $projectRoot | Out-Null
}
$engineRoot = 'D:\02_UnrealEngine\UE_5.8'
& "$engineRoot\Engine\Build\BatchFiles\Build.bat" AlchemyHD2DEditor Win64 Development "-Project=$aliasRoot\AlchemyHD2D.uproject" "-Log=$aliasRoot\Evidence\build-editor.log" -WaitMutex -NoHotReloadFromIDE -NoUBA
if ($LASTEXITCODE -ne 0) { throw 'Editor build failed.' }
if ($Package) {
    & "$engineRoot\Engine\Build\BatchFiles\RunUAT.bat" BuildCookRun "-project=$aliasRoot\AlchemyHD2D.uproject" -noP4 -platform=Win64 -clientconfig=Development -build -cook -stage -pak -archive "-archivedirectory=$projectRoot\..\..\03_Build\$BuildDirectory" -utf8output -unattended
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed.' }
}
