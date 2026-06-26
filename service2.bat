@echo off
set "LOCAL_VERSION=2.0.0-z2"

:: External commands
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="load_user_lists" (
    call :load_user_lists
    exit /b
)

if "%1"=="admin" (
    call :check_command chcp
    call :check_command find
    call :check_command findstr
    call :check_command netsh
    call :load_user_lists
    echo Started with admin rights
) else (
    call :check_extracted
    call :check_command powershell
    echo Requesting admin rights...
    powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)


:: MENU ================================
setlocal EnableDelayedExpansion
title ZAPRET2 SERVICE MANAGER v!LOCAL_VERSION!
:menu
cls
call :get_strategy_name

set "menu_choice=null"

echo.
echo   ZAPRET2 SERVICE MANAGER v!LOCAL_VERSION!
echo.  !CurrentStrategy!
echo   ----------------------------------------
echo.
echo   :: SERVICE
echo      1. Install Service
echo      2. Remove Services
echo      3. Check Status
echo.
echo   :: TOOLS
echo      4. Run Diagnostics
echo.
echo   ----------------------------------------
echo      0. Exit
echo.

set /p menu_choice=   Select option (0-4): 

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto service_diagnostics
if "%menu_choice%"=="0" exit /b
goto menu


:: LOAD USER LISTS =====================
:load_user_lists
set "LISTS_PATH=%~dp0lists\"

if not exist "%LISTS_PATH%ipset-exclude-user.txt" (
    echo 203.0.113.113/32>"%LISTS_PATH%ipset-exclude-user.txt"
)
if not exist "%LISTS_PATH%list-general-user.txt" (
    echo # Never leave this file empty>"%LISTS_PATH%list-general-user.txt"
    echo domain.example.abc>>"%LISTS_PATH%list-general-user.txt"
)
if not exist "%LISTS_PATH%list-exclude-user.txt" (
    echo domain.example.abc>"%LISTS_PATH%list-exclude-user.txt"
)
exit /b


:: TCP ENABLE ==========================
:tcp_enable
chcp 437 > nul
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b


:: STATUS ==============================
:service_status
cls
chcp 437 > nul

sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo Service strategy installed from "%%B"
)

call :test_service zapret
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%winws2.exe" (
    call :PrintRed "winws2.exe NOT found. Download from https://github.com/bol-van/zapret2/releases"
)
if not exist "%BIN_PATH%WinDivert64.sys" (
    call :PrintRed "WinDivert64.sys NOT found."
)
echo:

tasklist /FI "IMAGENAME eq winws2.exe" | find /I "winws2.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "zapret2 (winws2.exe) is RUNNING."
) else (
    call :PrintRed "zapret2 (winws2.exe) is NOT running."
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" is ALREADY RUNNING as service. Remove first.
        pause
        exit /b
    ) else (
        echo "%ServiceName%" service is RUNNING.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! is STOP_PENDING"
) else if not "%~2"=="soft" (
    echo "%ServiceName%" service is NOT running.
)
exit /b


:: REMOVE ==============================
:service_remove
cls
chcp 65001 > nul

set SRVCNAME=zapret
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
) else (
    echo Service "%SRVCNAME%" is not installed.
)

tasklist /FI "IMAGENAME eq winws2.exe" | find /I "winws2.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws2.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    echo Stopping WinDivert...
    net stop "WinDivert" >nul 2>&1
    timeout /t 3 >nul
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        echo Forcing WinDivert removal...
        sc delete "WinDivert" >nul 2>&1
        timeout /t 2 >nul
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu


:: INSTALL =============================
:service_install
cls
chcp 437 > nul

cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "BIN=%BIN_PATH%"
set "LISTS_PATH=%~dp0lists\"

echo Pick a strategy file:
set "count=0"
for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '.' -Filter '*.bat' | Where-Object { $_.Name -notlike 'service*' -and $_.Name -notlike 'install*' } | Sort-Object Name | ForEach-Object { $_.Name }"') do (
    set /a count+=1
    echo !count!. %%F
    set "file!count!=%%F"
)

if !count! equ 0 (
    echo No strategy files found.
    pause
    goto menu
)

set "stratChoice="
set /p "stratChoice=Input file index (number): "

if not defined stratChoice (
    echo Empty choice, exiting...
    pause
    goto menu
)

echo !stratChoice!| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo Invalid input. Enter a number.
    pause
    goto menu
)

if !stratChoice! lss 1 (
    echo Must be 1 or greater.
    pause
    goto menu
)
if !stratChoice! gtr !count! (
    echo Must be !count! or less.
    pause
    goto menu
)

set "selectedFile=!file%stratChoice%!"
if not defined selectedFile (
    echo Invalid choice.
    pause
    goto menu
)

if not exist "!selectedFile!" (
    echo File not found: !selectedFile!
    pause
    goto menu
)

echo Flattening strategy file...

:: Step 1: PowerShell flattens multi-line bat into single line
:: Replaces " ^\r\n  " patterns with single space
set "TEMP_FILE=%TEMP%\zapret2_flat.txt"
powershell -NoProfile -Command "
    $content = [IO.File]::ReadAllText('!selectedFile!');
    $content = $content -replace ' \^\r?\n\s*', ' ';
    $content = $content -replace '\r?\n', ' ';
    $content = $content -replace '\s+', ' ';
    [IO.File]::WriteAllText('%TEMP_FILE%', $content.Trim());
"

if not exist "%TEMP_FILE%" (
    echo ERROR: Failed to flatten strategy file.
    pause
    goto menu
)

echo Parsing flattened strategy...

:: Step 2: Parse flattened single line exactly like original service.bat
set "args_with_value=sni host altorder"
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=* eol=" %%a in ('type "%TEMP_FILE%"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws2.exe" >nul 2>&1
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws2.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul 2>&1
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%LUA%%" (
                        set "arg=\!QUOTE!%~dp0lua\!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,4!"=="%%WF%%" (
                        set "arg=\!QUOTE!%~dp0windivert.filter\!arg:~4!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                ) else if "!arg:~0,15!" EQU "%%GameFilterTCP%%" (
                    set "arg=%GameFilterTCP%"
                ) else if "!arg:~0,15!" EQU "%%GameFilterUDP%%" (
                    set "arg=%GameFilterUDP%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

del "%TEMP_FILE%" >nul 2>&1

call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Final args: !ARGS!
set SRVCNAME=zapret

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws2.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret2 DPI bypass software"
sc start %SRVCNAME%

for %%F in ("!file%stratChoice%!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

pause
goto menu


:: DIAGNOSTICS =========================
:service_diagnostics
chcp 437 > nul
cls

echo === Zapret2 Diagnostics ===
echo.

set "BIN_PATH=%~dp0bin\"
if exist "%BIN_PATH%winws2.exe" (
    call :PrintGreen "winws2.exe found"
) else (
    call :PrintRed "[X] winws2.exe NOT found"
    call :PrintYellow "Download: https://github.com/bol-van/zapret2/releases"
)
echo:

if exist "%~dp0lua\zapret-lib.lua" (
    call :PrintGreen "zapret-lib.lua found"
) else (
    call :PrintRed "[X] zapret-lib.lua NOT found"
)

if exist "%~dp0lua\zapret-antidpi.lua" (
    call :PrintGreen "zapret-antidpi.lua found"
) else (
    call :PrintRed "[X] zapret-antidpi.lua NOT found"
)
echo:

set "WF_OK=1"
for %%f in (discord_media stun quic_initial_ietf) do (
    if exist "%~dp0windivert.filter\windivert_part.%%f.txt" (
        echo [OK] windivert_part.%%f.txt
    ) else (
        call :PrintRed "[X] windivert_part.%%f.txt NOT found"
        set "WF_OK=0"
    )
)
if !WF_OK!==0 (
    call :PrintYellow "Download from zapret2 release zip"
)
echo:

for %%b in (quic_initial_www_google_com stun tls_clienthello_www_google_com) do (
    if exist "%~dp0bin\%%b.bin" (
        echo [OK] %%b.bin
    ) else (
        call :PrintRed "[X] %%b.bin NOT found"
    )
)
echo:

sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "BFE: RUNNING"
) else (
    call :PrintRed "[X] BFE not running"
)

tasklist /FI "IMAGENAME eq winws2.exe" | find /I "winws2.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "winws2.exe: RUNNING"
) else (
    call :PrintYellow "winws2.exe: NOT running"
)
echo:

pause
goto menu


:: Get strategy name
:get_strategy_name
set "CurrentStrategy="
for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do set "CurrentStrategy=Strategy: %%B"
if not defined CurrentStrategy set "CurrentStrategy=No active strategy"
exit /b


:: Utility functions
:PrintGreen
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Green"
exit /b

:PrintRed
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Red"
exit /b

:PrintYellow
powershell -NoProfile -Command "Write-Host '%~1' -ForegroundColor Yellow"
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] %1 not found in PATH
    pause
    exit /b 1
)
exit /b 0

:check_extracted
set "extracted=1"
if not exist "%~dp0bin\winws2.exe" (
    call :PrintRed "winws2.exe not found"
    call :PrintYellow "Download: https://github.com/bol-van/zapret2/releases"
    set "extracted=0"
)
if "%extracted%"=="0" (
    pause
    exit
)
exit /b 0
