$ErrorActionPreference='Stop'
$root='F:\Fork\MPLJSS\02_Prototype\AlchemyHD2D'
$project=Join-Path $root 'AlchemyHD2D.uproject'
$script=Join-Path $root 'Tools\CreateMainMenuMap.py'
$log=Join-Path $root 'Evidence\main-menu-map.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$launch=@($project,'-ExecutePythonScript='+$script,'-unattended','-nosound','-nosplash','-nop4',("-abslog=`"{0}`"" -f $log))
$exe='F:\EPIC GAME\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
$run=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(240000)){Stop-Process -Id $run.Id;throw 'MainMenuMap creation timed out.'}
if($run.ExitCode -ne 0){throw "MainMenuMap creation failed: $log"}
if(!(Select-String -LiteralPath $log -SimpleMatch 'MAIN_MENU_MAP_PASS' -Quiet)){throw "MainMenuMap did not report pass: $log"}
Write-Output "MAIN_MENU_MAP_PASS $log"
