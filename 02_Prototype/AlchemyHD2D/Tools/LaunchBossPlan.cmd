@echo off
setlocal
set "DEMO=%~dp0Windows\AlchemyHD2D.exe"
if not exist "%DEMO%" goto missing
start "" /D "%~dp0Windows" "%DEMO%" /Game/Greyford/Maps/Greyford_Flow -PlannedBossPreview -windowed -ResX=1280 -ResY=720
exit /b 0
:missing
echo Extract the ENTIRE Windows build before playing.
pause
exit /b 1
