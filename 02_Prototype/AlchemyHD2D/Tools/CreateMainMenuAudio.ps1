$ErrorActionPreference='Stop'
$root='F:\Fork\MPLJSS\02_Prototype\AlchemyHD2D'
$project=Join-Path $root 'AlchemyHD2D.uproject'
$script=Join-Path $root 'Tools\CreateMainMenuAudio.py'
$log=Join-Path $root 'Evidence\main-menu-audio.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$launch=@($project,'-ExecutePythonScript='+$script,'-nullrhi','-unattended','-nosound','-nosplash','-nop4',("-abslog=`"{0}`"" -f $log))
$exe='F:\EPIC GAME\UE_5.8\Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
$run=Start-Process -FilePath $exe -ArgumentList $launch -WindowStyle Hidden -PassThru
if(!$run.WaitForExit(200000)){Stop-Process -Id $run.Id;throw 'MainMenuAudio creation timed out.'}
if($run.ExitCode -ne 0){throw "MainMenuAudio creation failed: $log"}
if(!(Select-String -LiteralPath $log -SimpleMatch 'MAIN_MENU_AUDIO_PASS' -Quiet)){throw "MainMenuAudio did not report pass: $log"}
Write-Output "MAIN_MENU_AUDIO_PASS $log"
