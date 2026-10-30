@echo off
setlocal
set "DEMO=%~dp0Windows\AlchemyHD2D.exe"
set "SCENE=/Game/Greyford/Maps/Greyford_Flow"
if /I "%~1"=="Outskirts" set "SCENE=/Game/Greyford/Maps/Outskirts_Blockout"
if not exist "%DEMO%" goto missing
if not exist "%~dp0Windows\AlchemyHD2D\Content\Paks\AlchemyHD2D-Windows.ucas" goto missing
start "" /D "%~dp0Windows" "%DEMO%" %SCENE% -windowed -ResX=1280 -ResY=720
exit /b 0
:missing
echo Extract the ENTIRE Greyford Win64 ZIP before playing.
pause
exit /b 1
