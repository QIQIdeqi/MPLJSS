param([string]$EngineRoot,[ValidateSet('Normal','Boss','Legacy')][string]$Scene='Normal')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Build.ps1') -EngineRoot $EngineRoot
$focusScript=(Join-Path $aliasRoot 'Tools/FocusDesigner.py').Replace('\','/')
$map=switch($Scene){'Normal'{'/Game/Greyford/Maps/Greyford_Flow'} 'Boss'{'/Game/Greyford/Maps/Greyford_Flow'} 'Legacy'{'/Game/Maps/Research'}}
$editorArgs=@(('"'+(Join-Path $aliasRoot 'AlchemyHD2D.uproject')+'"'),$map,('-ExecCmds="py '+$focusScript+'"'))
if($Scene -ne 'Legacy'){$editorArgs+='-AlchemyRandomDesigner'}
if($Scene -eq 'Boss'){$editorArgs+='-AlchemyDesignerBoss'}
Start-Process -FilePath (Join-Path $EngineRoot 'Engine/Binaries/Win64/UnrealEditor.exe') -ArgumentList $editorArgs -WorkingDirectory $projectRoot -WindowStyle Normal
