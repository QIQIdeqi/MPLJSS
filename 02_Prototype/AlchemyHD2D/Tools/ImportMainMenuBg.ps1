$ErrorActionPreference='Stop'
$root='F:\Fork\MPLJSS\02_Prototype\AlchemyHD2D'
$project=Join-Path $root 'AlchemyHD2D.uproject'
$script=Join-Path $root 'Tools\ImportMainMenuBg.py'
$log=Join-Path $root 'Evidence\main-menu-bg-import.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$launch=@($project,'-ExecutePythonScript='+$script,'-nullrhi','-unattended','-nosound','-nosplash','-nop4',("-abslog=`"{0}`"" -f $log))
$exe='F:\EPIC GAME\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
$run=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(180000)){Stop-Process -Id $run.Id;throw 'MainMenuBg import timed out.'}
if($run.ExitCode -ne 0){throw "MainMenuBg import failed: $log"}
if(!(Select-String -LiteralPath $log -SimpleMatch 'MAIN_MENU_BG_IMPORT_PASS' -Quiet)){throw "MainMenuBg import did not report pass: $log"}
Write-Output "MAIN_MENU_BG_IMPORT_PASS $log"
