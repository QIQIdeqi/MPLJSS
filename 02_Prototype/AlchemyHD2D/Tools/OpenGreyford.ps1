param([ValidateSet('Village','Outskirts')][string]$Scene='Village',[switch]$Play)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$engineExe='D:\02_UnrealEngine\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe'
$projectFile=Join-Path $projectRoot 'AlchemyHD2D.uproject'
if(-not (Test-Path -LiteralPath $engineExe)) {throw 'UE5.8 editor not found.'}
if(-not (Test-Path -LiteralPath (Join-Path $projectRoot ('Content/Greyford/Maps/'+$Scene+'_Blockout.umap')))) {throw 'Greyford map is missing. Run the documented builder first.'}
$editorArgs=@(('"'+$projectFile+'"'),('/Game/Greyford/Maps/'+$Scene+'_Blockout'))
if($Play){$editorArgs+=@('-game','-windowed','-ResX=1280','-ResY=720')}
else {
    $aliasRoot='D:\03_UEProject\AlchemyHD2DResearch'
    $target=@((Get-Item -LiteralPath $aliasRoot).Target)[0]
    if([IO.Path]::GetFullPath($target) -ne [IO.Path]::GetFullPath($projectRoot)){throw 'Project alias belongs to another workspace.'}
    $focusScript=(Join-Path $aliasRoot 'Tools/FocusGreyford.py').Replace('\','/')
    $editorArgs+=('-ExecCmds="py '+$focusScript+'"')
}
Start-Process -FilePath $engineExe -ArgumentList $editorArgs -WorkingDirectory $projectRoot -WindowStyle Normal
