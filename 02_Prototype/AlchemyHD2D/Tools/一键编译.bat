@echo off
echo ============================================
echo  Alchemy Build (Editor Win64)
echo ============================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build.ps1"
echo.
if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] Build succeeded. You can now open the editor.
) else (
    echo.
    echo [FAIL] Build failed. See the messages above.
)
echo.
pause
