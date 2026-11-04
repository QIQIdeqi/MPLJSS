@echo off
setlocal
set "DEMO=%~dp0Windows\AlchemyHD2D.exe"
set "GAME=%~dp0Windows\AlchemyHD2D\Binaries\Win64\AlchemyHD2D.exe"
set "SCENE=/Game/Greyford/Maps/Greyford_Flow"
if /I "%~1"=="Outskirts" set "SCENE=/Game/Greyford/Maps/Outskirts_Blockout"
if not exist "%DEMO%" goto missing
if not exist "%GAME%" goto missing
for %%I in ("%GAME%") do if %%~zI LSS 1048576 goto missing
if not exist "%~dp0Windows\AlchemyHD2D\Content\Paks\AlchemyHD2D-Windows.pak" goto missing
if not exist "%~dp0Windows\AlchemyHD2D\Content\Paks\AlchemyHD2D-Windows.ucas" goto missing
if not exist "%~dp0Windows\AlchemyHD2D\Content\Paks\AlchemyHD2D-Windows.utoc" goto missing
start "" /D "%~dp0Windows" "%DEMO%" %SCENE% -windowed -ResX=1280 -ResY=720
exit /b 0
:missing
echo Windows game files are incomplete. Keep this launcher beside the complete Windows folder.
pause
exit /b 1
