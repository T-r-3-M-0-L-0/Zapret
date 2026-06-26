@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
:: ZAPRET2 Service Manager v2.1.0
:: Based on approaches by youtubediscord & Player1545
:: ============================================================
:: Modes:
::   1. Startup shortcut - creates .lnk in Windows Startup folder
::   2. Windows Service  - installs as system service via wrapper
:: ============================================================

set "LOCAL_VERSION=2.1.0"
set "BASE_DIR=%~dp0"
set "BASE_DIR=%BASE_DIR:~0,-1%"
set "SERVICE_NAME=zapret2"
set "WRAPPER_NAME=zapret2-wrapper.bat"
set "STARTUP_NAME=Zapret2.lnk"

:: Get Startup folder path
for %%A in ("%APPDATA%") do set "STARTUP_PATH=%%~A\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_PATH%\%STARTUP_NAME%"

title ZAPRET2 SERVICE MANAGER v%LOCAL_VERSION%

:menu
cls
call :get_strategy_name

echo ================================================
echo        ZAPRET2 SERVICE MANAGER v%LOCAL_VERSION%
echo   !CurrentStrategy!
echo ================================================
echo.
echo  [1] Install strategy as Startup shortcut ^(recommended^)
echo  [2] Install strategy as Windows Service
echo  [3] Start service
echo  [4] Stop service
echo  [5] Remove service / Startup shortcut
echo  [6] Show current status
echo  [7] Run Diagnostics
echo.
echo  [0] Exit
echo.
echo ================================================
set /p choice="Choice: "

if "%choice%"=="1" goto install_startup
if "%choice%"=="2" goto install_service
if "%choice%"=="3" goto start_svc
if "%choice%"=="4" goto stop_svc
if "%choice%"=="5" goto remove
if "%choice%"=="6" goto status
if "%choice%"=="7" goto service_diagnostics
if "%choice%"=="0" exit /b 0
goto menu

:: ============================================================
:: List available strategy files
:: ============================================================
:list_strategies
cls
echo Available strategies:
echo.

set "count=0"
for %%F in ("%~dp0*.bat") do (
    set "fname=%%~nxF"
    if /I not "!fname!"=="service2.bat" (
        if /I not "!fname!"=="%WRAPPER_NAME%" (
            if /I not "!fname:~0,4!"=="serv" (
                if /I not "!fname:~0,4!"=="inst" (
                    set /a count+=1
                    set "file!count!=%%~nxF"
                    echo   !count!. %%~nxF
                )
            )
        )
    )
)

if %count%==0 (
    echo   No strategy .bat files found!
    echo   Place strategy files in: %BASE_DIR%
    set "SEL_FILE="
    pause
    exit /b 1
)

echo.
set /p sel="Select strategy (1-%count%): "

if "%sel%"=="" (
    set "SEL_FILE="
    exit /b 1
)
echo !sel!| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    set "SEL_FILE="
    exit /b 1
)
if !sel! lss 1 (
    set "SEL_FILE="
    exit /b 1
)
if !sel! gtr !count! (
    set "SEL_FILE="
    exit /b 1
)

set "SEL_FILE=!file%sel%!"
exit /b 0

:: ============================================================
:: [1] Install as Startup shortcut (most reliable)
:: Based on Player1545 approach - no parsing needed!
:: ============================================================
:install_startup
call :list_strategies
if "%SEL_FILE%"=="" goto menu

echo.
echo Selected strategy: %SEL_FILE%
echo.

:: Remove existing shortcut
if exist "%SHORTCUT_PATH%" (
    del "%SHORTCUT_PATH%" >nul 2>&1
)

:: Create shortcut via PowerShell (WindowStyle=7 = hidden window)
powershell -NoProfile -Command "& {$ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut('%SHORTCUT_PATH%'); $s.TargetPath='%BASE_DIR%\%SEL_FILE%'; $s.WorkingDirectory='%BASE_DIR%'; $s.WindowStyle=7; $s.Save(); Write-Host 'Done.'}"

if %errorlevel%==0 (
    echo.
    echo [OK] Startup shortcut created!
    echo      Strategy : %SEL_FILE%
    echo      Shortcut : %SHORTCUT_PATH%
    echo.
    echo The strategy will start automatically on next login.
    echo It runs in hidden window (no console visible).
    echo.
    echo Start now? (Y/N)
    set /p startnow=""
    if /I "!startnow!"=="Y" (
        start "" /D "%BASE_DIR%" "%BASE_DIR%\%SEL_FILE%"
        echo Started.
    )
) else (
    echo.
    echo [ERROR] Failed to create shortcut.
)
pause
goto menu

:: ============================================================
:: [2] Install as Windows Service
:: ============================================================
:install_service
call :list_strategies
if "%SEL_FILE%"=="" goto menu

echo.
echo Selected strategy: %SEL_FILE%
echo.

:: Remove existing service if any
call :remove_service_internal

:: Create wrapper batch file that calls the selected strategy
echo @echo off                          > "%BASE_DIR%\%WRAPPER_NAME%"
echo cd /d "%BASE_DIR%"                 >> "%BASE_DIR%\%WRAPPER_NAME%"
echo call "%BASE_DIR%\%SEL_FILE%"      >> "%BASE_DIR%\%WRAPPER_NAME%"

:: Install service via wrapper
sc create %SERVICE_NAME% binPath= "cmd.exe /c \"%%~dp0%WRAPPER_NAME%\"" start= auto displayname= "Zapret2 DPI Bypass" >nul 2>&1

if %errorlevel%==0 (
    echo [OK] Service installed successfully!
    echo      Strategy: %SEL_FILE%
    echo      Service : %SERVICE_NAME%
    echo.
    echo Starting service...
    sc start %SERVICE_NAME%
) else (
    echo.
    echo [ERROR] Failed to install service.
    echo         Make sure you are running as Administrator!
    echo.
    echo Tip: Right-click on service2.bat and select "Run as administrator"
    if exist "%BASE_DIR%\%WRAPPER_NAME%" del "%BASE_DIR%\%WRAPPER_NAME%" >nul 2>&1
)
pause
goto menu

:: ============================================================
:: [3] Start service
:: ============================================================
:start_svc
echo.
sc start %SERVICE_NAME%
if %errorlevel% neq 0 (
    echo.
    echo If access denied - run as Administrator.
)
pause
goto menu

:: ============================================================
:: [4] Stop service
:: ============================================================
:stop_svc
echo.
sc stop %SERVICE_NAME%
if %errorlevel% neq 0 (
    echo.
    echo Also checking for standalone winws2.exe...
    tasklist /FI "IMAGENAME eq winws2.exe" | find /I "winws2.exe" > nul
    if !errorlevel!==0 (
        taskkill /IM winws2.exe /F > nul 2>&1
        echo winws2.exe killed.
    )
)
pause
goto menu

:: ============================================================
:: [5] Remove service / Startup shortcut
:: ============================================================
:remove
cls
echo Remove:
echo   [1] Windows Service
echo   [2] Startup shortcut
echo   [3] Both
echo   [0] Back
echo.
set /p remchoice="Choice: "

if "%remchoice%"=="1" call :remove_service_internal && pause && goto menu
if "%remchoice%"=="2" call :remove_startup_internal && pause && goto menu
if "%remchoice%"=="3" call :remove_service_internal && call :remove_startup_internal && pause && goto menu
if "%remchoice%"=="0" goto menu
goto remove

:remove_service_internal
sc stop %SERVICE_NAME% >nul 2>&1
timeout /t 1 >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
if %errorlevel%==0 (
    echo [OK] Service removed.
    if exist "%BASE_DIR%\%WRAPPER_NAME%" del "%BASE_DIR%\%WRAPPER_NAME%" >nul 2>&1
) else (
    echo Service not found (may already be removed).
)
exit /b 0

:remove_startup_internal
if exist "%SHORTCUT_PATH%" (
    del "%SHORTCUT_PATH%" >nul 2>&1
    echo [OK] Startup shortcut removed.
) else (
    echo Startup shortcut not found.
)
exit /b 0

:: ============================================================
:: [6] Show status
:: ============================================================
:status
cls
echo --- Windows Service Status ---
sc query %SERVICE_NAME% 2>nul
echo.
echo --- Startup Shortcut ---
if exist "%SHORTCUT_PATH%" (
    echo [OK] Found: %SHORTCUT_PATH%
    for /f "delims=" %%L in ('powershell -NoProfile -Command "(New-Object -ComObject WScript.Shell).CreateShortcut('%SHORTCUT_PATH%').TargetPath" 2^>nul') do echo      Target: %%L
) else (
    echo [NOT FOUND] No startup shortcut.
)
echo.
echo --- Running Processes ---
tasklist /FI "IMAGENAME eq winws2.exe" 2>nul
echo.
pause
goto menu

:: ============================================================
:: [7] Diagnostics
:: ============================================================
:service_diagnostics
chcp 437 > nul
cls

echo === Zapret2 Diagnostics ===
echo.

call :tcp_enable

set "BIN_PATH=%~dp0bin\"
if exist "%BIN_PATH%winws2.exe" (
    call :PrintGreen "[OK] winws2.exe found"
) else (
    call :PrintRed "[X] winws2.exe NOT found"
    call :PrintYellow "Download: https://github.com/bol-van/zapret2/releases"
)
echo.

if exist "%~dp0lua\zapret-lib.lua" (
    call :PrintGreen "[OK] zapret-lib.lua found"
) else (
    call :PrintRed "[X] zapret-lib.lua NOT found"
)

if exist "%~dp0lua\zapret-antidpi.lua" (
    call :PrintGreen "[OK] zapret-antidpi.lua found"
) else (
    call :PrintRed "[X] zapret-antidpi.lua NOT found"
)
echo.

tasklist /FI "IMAGENAME eq winws2.exe" | find /I "winws2.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "[OK] winws2.exe is RUNNING"
) else (
    call :PrintYellow "[!] winws2.exe is NOT running"
)
echo.

sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "[OK] BFE service is RUNNING"
) else (
    call :PrintRed "[X] BFE service is NOT running"
)
echo.

sc query %SERVICE_NAME% >nul 2>&1
if !errorlevel!==0 (
    echo Service '%SERVICE_NAME%' is INSTALLED
    sc query %SERVICE_NAME% | findstr /I "STATE"
) else (
    echo Service '%SERVICE_NAME%' is NOT installed
)

if exist "%SHORTCUT_PATH%" (
    echo Startup shortcut: EXISTS
) else (
    echo Startup shortcut: NOT FOUND
)
echo.

pause
goto menu

:: ============================================================
:: Utility functions
:: ============================================================

:get_strategy_name
set "CurrentStrategy="
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do set "CurrentStrategy=Strategy: %%B"
if not defined CurrentStrategy set "CurrentStrategy=No active strategy"
exit /b

:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b

:PrintGreen
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Green"
exit /b

:PrintRed
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Red"
exit /b

:PrintYellow
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Yellow"
exit /b
