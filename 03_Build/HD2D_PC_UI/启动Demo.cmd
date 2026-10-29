@echo off
setlocal
set "DEMO=%~dp0Windows\AlchemyHD2D\Binaries\Win64\AlchemyHD2D.exe"
if not exist "%DEMO%" goto missing
for %%I in ("%DEMO%") do if %%~zI LSS 1048576 goto lfs
if not exist "%~dp0Windows\AlchemyHD2D\Content\Paks\AlchemyHD2D-Windows.pak" goto missing
if not exist "%~dp0Windows\AlchemyHD2D\Content\Paks\AlchemyHD2D-Windows.ucas" goto missing
if not exist "%~dp0Windows\AlchemyHD2D\Content\Paks\AlchemyHD2D-Windows.utoc" goto missing
start "" /D "%~dp0Windows" "%~dp0Windows\AlchemyHD2D.exe" -windowed -ResX=1280 -ResY=720 %*
exit /b 0
:missing
echo Demo files are incomplete. Extract the ENTIRE latest Win64 ZIP first.
echo Keep this CMD beside the complete Windows folder. Do not download only the CMD.
echo Expected: "%DEMO%"
pause
exit /b 1
:lfs
echo This EXE is a Git LFS pointer, not the real game binary.
echo Run git lfs install and git lfs pull, or extract the complete latest Win64 ZIP.
pause
exit /b 1
