@echo off
start "" "D:\02_UnrealEngine\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe" "%~dp0..\AlchemyHD2D.uproject" -ExecCmds="py %~dp0OpenGreyfordCollisionEditor.py"
