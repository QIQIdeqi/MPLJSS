@echo off
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Tools\OpenDesigner.ps1" -Scene Boss %*
if errorlevel 1 pause
