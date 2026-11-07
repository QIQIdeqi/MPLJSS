@echo off
setlocal
choice /C AB /M "A = scatter, B = fence and crates"
if errorlevel 255 exit /b 1
if errorlevel 2 goto variantB
if not errorlevel 1 exit /b 0
set "variant=A"
goto launch
:variantB
set "variant=B"
:launch
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\OpenGreyford.ps1" -Play -RecoveryCompare %variant%
if errorlevel 1 pause
