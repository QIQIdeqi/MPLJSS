param([string]$BuildDirectory='Greyford_Flow_Win64_20261030')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath((Join-Path $projectRoot "../../03_Build/$BuildDirectory"))
& (Join-Path $PSScriptRoot 'Build.ps1') -Package -BuildDirectory $BuildDirectory
if($LASTEXITCODE -ne 0){throw 'Greyford packaging failed.'}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LaunchGreyford.cmd') -Destination (Join-Path $output 'PlayGreyford.cmd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LaunchGreyford.cmd') -Destination (Join-Path $output '启动完整试玩.cmd')
Copy-Item -LiteralPath (Join-Path $projectRoot 'Docs/Greyford_Windows试玩说明.txt') -Destination (Join-Path $output '运行说明.txt')
Write-Output "Greyford Windows build: $output"
