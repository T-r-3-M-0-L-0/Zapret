@echo off
chcp 65001 >nul
setlocal DisableDelayedExpansion

:: ============================================================
:: ZAPRET2 Service Manager v2.1.1
:: ============================================================

set "BASE_DIR=%~dp0"
set "BASE_DIR=%BASE_DIR:~0,-1%"
set "BIN_DIR=%BASE_DIR%\bin"
set "SERVICE_NAME=zapret2"
set "WRAPPER_NAME=zapret2-wrapper.bat"
set "STARTUP_NAME=Zapret2.lnk"

:: Get Startup folder path
for %%A in ("%APPDATA%") do set "STARTUP_PATH=%%~A\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT_PATH=%STARTUP_PATH%\%STARTUP_NAME%"

title ZAPRET2 SERVICE MANAGER

:menu
cls
echo ================================================
echo        ZAPRET2 SERVICE MANAGER
echo ================================================
echo  Base dir : %BASE_DIR%
echo  Bin dir  : %BIN_DIR%
echo ================================================
echo.
echo  [1] Install strategy as Startup shortcut
echo  [2] Install strategy as Windows Service
echo  [3] Start service
echo  [4] Stop service
echo  [5] Remove service / Startup shortcut
echo  [6] Show status
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
if "%choice%"=="0" exit /b 0
goto menu

:: ============================================================
:: List available strategy files
:: ============================================================
:list_strategies
cls
echo Scanning folder: %BASE_DIR%
echo.
set "count=0"

for %%F in ("%BASE_DIR%\*.bat") do (
    call :check_file "%%~nxF"
)

echo.
if %count%==0 (
    echo [ERROR] No strategy .bat files found!
    echo         Place strategy files in: %BASE_DIR%
    set "SEL_FILE="
    pause
    exit /b 1
)

echo.
set /p sel="Select strategy (1-%count%): "

if "%sel%"=="" (
    echo [ERROR] Empty input.
    set "SEL_FILE="
    pause
    exit /b 1
)

echo %sel%| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [ERROR] Input is not a number.
    set "SEL_FILE="
    pause
    exit /b 1
)

if %sel% lss 1 (
    echo [ERROR] Number too small.
    set "SEL_FILE="
    pause
    exit /b 1
)
if %sel% gtr %count% (
    echo [ERROR] Number too big (max: %count%).
    set "SEL_FILE="
    pause
    exit /b 1
)

call set "SEL_FILE=%%file%sel%%%"
echo [OK] Selected: %SEL_FILE%
timeout /t 1 >nul
exit /b 0

:check_file
set "f=%~1"
if /I "%f%"=="service2.bat" exit /b
if /I "%f%"=="%WRAPPER_NAME%" exit /b
if /I "%f:~0,4%"=="serv" exit /b
if /I "%f:~0,4%"=="inst" exit /b
set /a count+=1
echo   %count%. %f%
set "file%count%=%f%"
exit /b

:: ============================================================
:: [1] Install as Startup shortcut via VBS (most reliable)
:: ============================================================
:install_startup
call :list_strategies
if "%SEL_FILE%"=="" goto menu

echo.
echo ================================================
echo  Creating startup shortcut...
echo ================================================
echo  Strategy     : %SEL_FILE%
echo  Shortcut     : %SHORTCUT_PATH%
echo  Target       : %BASE_DIR%\%SEL_FILE%
echo  WorkDir      : %BIN_DIR%
echo.

:: Remove existing shortcut
if exist "%SHORTCUT_PATH%" (
    del "%SHORTCUT_PATH%" >nul 2>&1
    echo [OK] Old shortcut removed.
)

:: Create shortcut via VBS (avoids PowerShell escaping issues)
set "VBS_FILE=%TEMP%\mkzapretlnk.vbs"
(
echo Set WshShell = WScript.CreateObject("WScript.Shell"
echo Set oLink = WshShell.CreateShortcut("%SHORTCUT_PATH%"
echo oLink.TargetPath = "%BASE_DIR%\%SEL_FILE%"
echo oLink.WorkingDirectory = "%BIN_DIR%"
echo oLink.WindowStyle = 7
echo oLink.Save
) > "%VBS_FILE%"

cscript //nologo "%VBS_FILE%"
set "VBS_RESULT=%errorlevel%"
del "%VBS_FILE%" >nul 2>&1

if %VBS_RESULT%==0 (
    if exist "%SHORTCUT_PATH%" (
        echo [OK] Startup shortcut created successfully!
        echo.
        echo Strategy will auto-start on next login (hidden window).
        echo.
        set /p startnow="Start now? (Y/N): "
        if /I "%startnow%"=="Y" (
            start "" /D "%BIN_DIR%" "%BASE_DIR%\%SEL_FILE%"
            echo [OK] Started.
        )
    ) else (
        echo [ERROR] Shortcut was not created. Check permissions.
    )
) else (
    echo [ERROR] Failed to create shortcut. Error: %VBS_RESULT%
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
echo ================================================
echo  Installing Windows Service...
echo ================================================
echo  Strategy     : %SEL_FILE%
echo  Service name : %SERVICE_NAME%
echo.

:: Remove existing service
echo [Step 1] Stopping existing service...
net stop %SERVICE_NAME% >nul 2>&1
timeout /t 1 >nul 2>&1
sc delete %SERVICE_NAME% >nul 2>&1
echo [OK] Old service removed (if existed).

:: Create wrapper batch with FULL paths
echo [Step 2] Creating wrapper.bat...
set "WRAPPER_PATH=%BASE_DIR%\%WRAPPER_NAME%"
(
echo @echo off
echo :: Zapret2 Service Wrapper
echo cd /d "%BASE_DIR%"
echo call "%BASE_DIR%\%SEL_FILE%"
) > "%WRAPPER_PATH%"

if not exist "%WRAPPER_PATH%" (
    echo [ERROR] Failed to create wrapper.bat
    pause
    goto menu
)
echo [OK] Wrapper created: %WRAPPER_PATH%

:: Install service with FULL path to wrapper
echo [Step 3] Registering service...
sc create %SERVICE_NAME% binPath= "cmd.exe /c ""%WRAPPER_PATH%""" start= auto displayname= "Zapret2 DPI Bypass"

if %errorlevel%==0 (
    echo [OK] Service registered.
    echo [Step 4] Starting service...
    sc start %SERVICE_NAME%
    echo.
    echo ================================================
    echo  [SUCCESS] Service installed and started!
    echo ================================================
) else (
    echo.
    echo [ERROR] Failed to register service.
    echo         Run this script as Administrator!
    del "%WRAPPER_PATH%" >nul 2>&1
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
    echo [TIP] Run as Administrator if access denied.
)
pause
goto menu

:: ============================================================
:: [4] Stop service
:: ============================================================
:stop_svc
echo.
sc stop %SERVICE_NAME% >nul 2>&1
if %errorlevel% neq 0 (
    echo Service not running or access denied.
)
tasklist /FI "IMAGENAME eq winws2.exe" | find /I "winws2.exe" > nul
if %errorlevel%==0 (
    echo Stopping standalone winws2.exe...
    taskkill /IM winws2.exe /F > nul 2>&1
    echo [OK] winws2.exe stopped.
) else (
    echo winws2.exe is not running.
)
pause
goto menu

:: ============================================================
:: [5] Remove
:: ============================================================
:remove
cls
echo ================================================
echo  Remove:
echo   [1] Windows Service only
echo   [2] Startup shortcut only
echo   [3] Both
echo   [0] Back
echo ================================================
echo.
set /p remchoice="Choice: "

if "%remchoice%"=="1" call :remove_service && pause && goto menu
if "%remchoice%"=="2" call :remove_shortcut && pause && goto menu
if "%remchoice%"=="3" call :remove_service && call :remove_shortcut && pause && goto menu
if "%remchoice%"=="0" goto menu
goto remove

:remove_service
echo.
echo Stopping service...
net stop %SERVICE_NAME% >nul 2>&1
timeout /t 1 >nul 2>&1
echo Deleting service...
sc delete %SERVICE_NAME% >nul 2>&1
if %errorlevel%==0 (
    echo [OK] Service removed.
) else (
    echo Service not found (may already be removed).
)
if exist "%BASE_DIR%\%WRAPPER_NAME%" (
    del "%BASE_DIR%\%WRAPPER_NAME%" >nul 2>&1
    echo [OK] Wrapper.bat cleaned up.
)
exit /b 0

:remove_shortcut
if exist "%SHORTCUT_PATH%" (
    del "%SHORTCUT_PATH%" >nul 2>&1
    echo [OK] Startup shortcut removed.
) else (
    echo Startup shortcut not found.
)
exit /b 0

:: ============================================================
:: [6] Status
:: ============================================================
:status
cls
echo ================================================
echo  SERVICE STATUS
echo ================================================
echo.
echo --- Windows Service ---
sc query %SERVICE_NAME% 2>nul
echo.
echo --- Startup Shortcut ---
if exist "%SHORTCUT_PATH%" (
    echo [OK] Found: %SHORTCUT_PATH%
) else (
    echo [NOT FOUND]
)
echo.
echo --- Running Processes ---
tasklist /FI "IMAGENAME eq winws2.exe" 2>nul | find /I "winws2.exe"
if errorlevel 1 echo winws2.exe is NOT running.
echo.
pause
goto menu
