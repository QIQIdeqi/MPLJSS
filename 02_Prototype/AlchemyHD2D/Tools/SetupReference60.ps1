$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$log=Join-Path $root 'Evidence/Reference60_20261031/setup-final.log'
$launch=@('D:/03_UEProject/AlchemyHD2DResearch/AlchemyHD2D.uproject','-ExecutePythonScript=D:/03_UEProject/AlchemyHD2DResearch/Tools/SetupReference60.py','-nullrhi','-unattended','-nosound','-nosplash','-nop4',"-abslog=`"$log`"")
$run=Start-Process -FilePath 'D:/02_UnrealEngine/UE_5.8/Engine/Binaries/Win64/UnrealEditor-Cmd.exe' -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw 'Reference60 setup timed out.'}
if($run.ExitCode -ne 0 -or !(Select-String -LiteralPath $log -SimpleMatch 'REFERENCE60_SETUP_PASS' -Quiet)){throw "Reference60 asset setup failed: $log"}
if(Select-String -LiteralPath $log -Pattern 'Ensure condition failed|LogPython: Error:|Fatal error:' -Quiet){throw "Reference60 asset setup reported errors: $log"}
Write-Output "REFERENCE60_SETUP_PASS $log"
