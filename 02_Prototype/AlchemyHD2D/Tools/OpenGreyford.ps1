param([ValidateSet('Village','Outskirts')][string]$Scene='Village',[switch]$Play,
      [ValidateSet('A','B')][string]$RecoveryCompare,[int]$Seed=77)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$engineExe='D:\02_UnrealEngine\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe'
$projectFile=Join-Path $projectRoot 'AlchemyHD2D.uproject'
if(-not (Test-Path -LiteralPath $engineExe)) {throw 'UE5.8 editor not found.'}
$map='/Game/Greyford/Maps/'+$Scene+'_Blockout'
if($Play){$map=if($Scene -eq 'Outskirts'){'/Game/Greyford/Maps/BattleReference'}else{'/Game/Greyford/Maps/Greyford_Flow'}}
$mapFile=Join-Path $projectRoot ('Content/'+$map.Substring(6)+'.umap')
if(-not (Test-Path -LiteralPath $mapFile)) {throw "Greyford map is missing: $mapFile. Restore this map before launching."}
$editorArgs=@(('"'+$projectFile+'"'),$map)
if($Play){
    $editorArgs+=@('-game','-windowed','-ResX=1280','-ResY=720')
    if($RecoveryCompare){
        $editorArgs+=@('-AlchemyRecoveryCompare','-AlchemyStartCombat',"-MapSeed=$Seed")
        if($RecoveryCompare -eq 'B'){$editorArgs+='-AlchemyRecoveryTrial'}
    }
}
else {
    $aliasRoot='D:\03_UEProject\AlchemyHD2DResearch'
    $target=@((Get-Item -LiteralPath $aliasRoot).Target)[0]
    if([IO.Path]::GetFullPath($target) -ne [IO.Path]::GetFullPath($projectRoot)){throw 'Project alias belongs to another workspace.'}
    $focusScript=(Join-Path $aliasRoot 'Tools/FocusGreyford.py').Replace('\','/')
    $editorArgs+=('-ExecCmds="py '+$focusScript+'"')
}
Start-Process -FilePath $engineExe -ArgumentList $editorArgs -WorkingDirectory $projectRoot -WindowStyle Normal
