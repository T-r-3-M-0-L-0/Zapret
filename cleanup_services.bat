@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting administrator rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ==============================================
echo   FULL CLEANUP OF OLD ZAPRET / WINDIVERT SERVICES
echo ==============================================

taskkill /f /im winws.exe >nul 2>&1

set "SERVICES=WinDivert zapret zapret1 zapret2 zapret3 zapret4 zapret5"
for %%s in (%SERVICES%) do (
    echo [INFO] Processing %%s...
    sc query %%s >nul 2>&1
    if !errorlevel! equ 0 (
        sc stop %%s >nul 2>&1
        timeout /t 2 >nul
        sc delete %%s >nul 2>&1
        if !errorlevel! neq 0 (
            echo [WARN] Could not delete %%s. Reboot may be required.
        ) else (
            echo [OK] %%s removed.
        )
    ) else (
        echo [INFO] %%s not found.
    )
)

echo.
echo Cleanup completed. You can now run install.bat.
timeout /t 5 >nul
exit /b