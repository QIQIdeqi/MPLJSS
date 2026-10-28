$ErrorActionPreference = 'Stop'
$buildRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../03_Build/HD2D_PC_UI/Windows'))
$gameExe = Join-Path $buildRoot 'AlchemyHD2D/Binaries/Win64/AlchemyHD2D.exe'
if (-not (Test-Path -LiteralPath $gameExe)) { throw 'Demo files missing. Extract the complete latest Win64 ZIP into 03_Build/HD2D_PC_UI first.' }
if ((Get-Item -LiteralPath $gameExe).Length -lt 1MB) { throw 'EXE is a Git LFS pointer. Run git lfs pull or extract the complete Win64 ZIP.' }
Start-Process -FilePath (Join-Path $buildRoot 'AlchemyHD2D.exe') -WorkingDirectory $buildRoot -ArgumentList @('-windowed','-ResX=1280','-ResY=720','-nosound') -WindowStyle Normal
