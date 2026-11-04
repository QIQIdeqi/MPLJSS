param([switch]$Boss)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$name=if($Boss){'boss'}else{'normal'}
$log=Join-Path $root "Evidence/RandomLayers_20261104/editor-entry-$name.log"
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','/Game/Greyford/Maps/Greyford_Flow','-AlchemyRandomDesigner','-AlchemyVerifyRandomEditor','-ExecCmds="py D:/03_UEProject/AlchemyHD2DResearch/Tools/FocusDesigner.py"','-nullrhi','-unattended','-nosound','-nosplash','-nop4',"-abslog=`"$log`"")
if($Boss){$launch+='-AlchemyDesignerBoss'}
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw "Editor entry timeout: $log"}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'RANDOM_EDITOR_ENTRY_PASS' -Quiet)){throw "Editor entry failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'ALCHEMY_DESIGNER_FOCUS_ERROR|Ensure condition failed|LogPython: Error:|Fatal error:' -Quiet){throw "Editor entry errors: $log"}
Write-Output "RANDOM_EDITOR_ENTRY_PASS $name"
