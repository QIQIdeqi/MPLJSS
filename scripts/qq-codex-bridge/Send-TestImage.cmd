@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Send-TestImage.ps1"
set "bridgeExit=%ERRORLEVEL%"
if not "%bridgeExit%"=="0" pause
exit /b %bridgeExit%
