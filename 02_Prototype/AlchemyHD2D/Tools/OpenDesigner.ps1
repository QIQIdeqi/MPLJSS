param([string]$EngineRoot)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Build.ps1') -EngineRoot $EngineRoot
$focusScript=(Join-Path $aliasRoot 'Tools/FocusDesigner.py').Replace('\','/')
$editorArgs=@(('"'+(Join-Path $aliasRoot 'AlchemyHD2D.uproject')+'"'),'/Game/Maps/Research',('-ExecCmds="py '+$focusScript+'"'))
Start-Process -FilePath (Join-Path $EngineRoot 'Engine/Binaries/Win64/UnrealEditor.exe') -ArgumentList $editorArgs -WorkingDirectory $projectRoot -WindowStyle Normal
