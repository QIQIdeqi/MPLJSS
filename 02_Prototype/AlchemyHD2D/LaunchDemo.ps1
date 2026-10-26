$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot '..\..\03_Build\HD2D_v0_1\Windows'))
$gameExe = Join-Path $buildRoot 'AlchemyHD2D\Binaries\Win64\AlchemyHD2D.exe'
if (Test-Path -LiteralPath $gameExe) {
    Start-Process -FilePath $gameExe -WorkingDirectory $buildRoot -ArgumentList @('-windowed','-ResX=1280','-ResY=720','-NoSound',"-abslog=`"$projectRoot\Evidence\play-packaged.log`"") -WindowStyle Normal
    exit
}
$engineRoot = 'D:\02_UnrealEngine\UE_5.8'
$aliasRoot = 'D:\03_UEProject\AlchemyHD2DResearch'
if (-not (Test-Path -LiteralPath $aliasRoot)) {
    New-Item -ItemType Junction -Path $aliasRoot -Target $projectRoot | Out-Null
}
if (-not (Test-Path -LiteralPath "$aliasRoot\Binaries\Win64\UnrealEditor-AlchemyHD2D.dll")) {
    throw 'Build the editor target with Tools\Build.ps1 first.'
}
Start-Process -FilePath "$engineRoot\Engine\Binaries\Win64\UnrealEditor.exe" -WorkingDirectory $aliasRoot -ArgumentList @(
    "`"$aliasRoot\AlchemyHD2D.uproject`"", '-game', '-windowed', '-ResX=1280', '-ResY=720', '-NoSplash', '-NoSound',
    "-abslog=`"$aliasRoot\Evidence\play.log`""
) -WindowStyle Normal
