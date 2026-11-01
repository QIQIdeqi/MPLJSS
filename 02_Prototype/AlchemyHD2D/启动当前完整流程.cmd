@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\OpenGreyford.ps1" -Play
if errorlevel 1 pause
