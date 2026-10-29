param([switch]$Editor,[switch]$BossPreview,[switch]$MerchantPreview)
$ErrorActionPreference='Stop'
$project='D:\03_UEProject\AlchemyHD2DResearch\AlchemyHD2D.uproject'
$engine='D:\02_UnrealEngine\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe'
$arguments=@($project,'/Game/Maps/Research','-AlchemyStartCombat','-ExecCmds="r.AntiAliasingMethod 0"')
if($BossPreview){$arguments+=@('-AlchemyBossPreview')}
if($MerchantPreview){$arguments+=@('-AlchemyMerchantPreview')}
if(-not $Editor){$arguments+=@('-game','-windowed','-ResX=1280','-ResY=720')}
# Visible: the user requested a controllable test in the actual combat level.
Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory (Split-Path $project)
