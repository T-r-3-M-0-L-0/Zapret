@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo   ZAPRET2 SERVICE MANAGER
echo   ======================
echo.

:: List strategy files
dir *.bat /b | findstr /v /i "^service" | findstr /v /i "^install" | findstr /v /i "^zapret2-wrapper"
echo.

set /p "f=Enter strategy filename: "
if not exist "%f%" (
    echo [ERROR] File not found: %f%
    pause
    exit /b 1
)

echo.
echo Selected: %f%
echo.

:: Check for NSSM (best option)
if exist "%~dp0bin\nssm.exe" (
    echo [NSSM] Found nssm.exe, using it for service installation.
    goto install_nssm
)

:: Fallback to Task Scheduler (built into Windows)
echo [TASK SCHEDULER] nssm.exe not found in bin\, using Task Scheduler.
echo                  ^(To use Windows Service mode, download nssm.exe to bin\ folder^)
echo.
goto install_schtasks

:: ============================================================
:: NSSM mode - real Windows Service
:: ============================================================
:install_nssm
net stop zapret2 >nul 2>&1
sc delete zapret2 >nul 2>&1
"%~dp0bin\nssm.exe" install zapret2 "%~dp0%f%" >nul 2>&1
"%~dp0bin\nssm.exe" set zapret2 Application "%~dp0%f%" >nul 2>&1
"%~dp0bin\nssm.exe" set zapret2 AppDirectory "%~dp0" >nul 2>&1
"%~dp0bin\nssm.exe" set zapret2 AppParameters "" >nul 2>&1
"%~dp0bin\nssm.exe" set zapret2 DisplayName "Zapret2 DPI Bypass" >nul 2>&1
"%~dp0bin\nssm.exe" set zapret2 Start SERVICE_AUTO_START >nul 2>&1
"%~dp0bin\nssm.exe" set zapret2 ObjectName LocalSystem >nul 2>&1
sc start zapret2
echo [OK] Service installed and started.
pause
exit /b 0

:: ============================================================
:: Task Scheduler mode - built into Windows, no extra tools
:: ============================================================
:install_schtasks
:: Delete old task if exists
schtasks /delete /tn "Zapret2" /f >nul 2>&1

:: Create task: run at logon, hidden window, highest privileges
schtasks /create /tn "Zapret2" /tr "\"%~dp0%f%\"" /sc onlogon /rl highest /f >nul 2>&1

echo [OK] Task 'Zapret2' created in Task Scheduler.
echo.
echo It will start automatically on next logon.
echo.
set /p runnow="Start now? (Y/N): "
if /I "%runnow%"=="Y" (
    start "" /D "%~dp0" "%~dp0%f%"
    echo Started.
)
pause
