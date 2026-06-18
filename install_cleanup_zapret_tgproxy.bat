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
echo   Zapret 1.9.9c + tg-ws-proxy AUTO-INSTALLER
echo ==============================================
echo.

:: Cleanup old services (if cleanup_services.bat exists)
if exist "%~dp0cleanup_services.bat" (
    echo [PREP] Running cleanup of old services
    cmd /c ""%~dp0cleanup_services.bat""
    echo [PREP] Cleanup finished. Continuing installation...
    echo.
)

set "ZAPRET_DIR=%~dp0"
set "BIN=%ZAPRET_DIR%bin\"
set "LISTS=%ZAPRET_DIR%lists\"
set "SVC_BAT=%ZAPRET_DIR%zapret_svc.bat"

:: --------------------------------------------------
:: 1. Install WinDivert driver
:: --------------------------------------------------
echo [1/4] Installing WinDivert driver...

set "WD_DRIVER=%BIN%WinDivert64.sys"
if not exist "%WD_DRIVER%" (
    echo [ERROR] WinDivert64.sys not found in bin folder!
    pause
    exit /b 1
)

set "WD_SERVICE=WinDivert"
sc query %WD_SERVICE% >nul 2>&1
if %errorlevel% equ 0 (
    sc stop %WD_SERVICE% >nul 2>&1
    sc delete %WD_SERVICE% >nul 2>&1
    timeout /t 2 >nul
)
sc create %WD_SERVICE% type= kernel binPath= "%WD_DRIVER%" start= auto
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create WinDivert service.
    pause
    exit /b 1
)
sc start %WD_SERVICE%
echo [OK] WinDivert driver installed and started.

:: --------------------------------------------------
:: 2. Generate service launcher (ALT13_01 strategy)
:: --------------------------------------------------
echo [2/4] Generating service launcher...
(
echo @echo off
echo cd /d "%ZAPRET_DIR%"
echo "%BIN%winws.exe" --wf-tcp=80,443,2053,2083,2087,2096,8443 --wf-udp=443,19294-19344,50000-50100,1024-65535 --filter-udp=443 --hostlist="%LISTS%list-general.txt" --hostlist="%LISTS%list-general-user.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial_www_google_com.bin" --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="%BIN%tls_clienthello_www_google_com.bin" --new --filter-tcp=443 --hostlist="%LISTS%list-google.txt" --ip-id=zero --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="%BIN%tls_clienthello_www_google_com.bin" --new --filter-tcp=80,443 --hostlist="%LISTS%list-general.txt" --hostlist="%LISTS%list-general-user.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="%BIN%stun.bin" --dpi-desync-fake-tls="%BIN%tls_clienthello_4pda_to.bin" --dpi-desync-fake-http="%BIN%tls_clienthello_max_ru.bin" --new --filter-udp=443 --ipset="%LISTS%ipset-all.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic="%BIN%quic_initial_www_google_com.bin" --new --filter-tcp=80,443,8443 --ipset="%LISTS%ipset-all.txt" --hostlist-exclude="%LISTS%list-exclude.txt" --hostlist-exclude="%LISTS%list-exclude-user.txt" --ipset-exclude="%LISTS%ipset-exclude.txt" --ipset-exclude="%LISTS%ipset-exclude-user.txt" --dpi-desync=fake,fakedsplit --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fakedsplit-pattern=0x00 --dpi-desync-fake-tls="%BIN%stun.bin" --dpi-desync-fake-tls="%BIN%tls_clienthello_4pda_to.bin" --dpi-desync-fake-http="%BIN%tls_clienthello_max_ru.bin" --new --filter-udp=1024-3477,3481-19293,19345-49999,50101-65535 --dpi-desync=fake --dpi-desync-repeats=12 --dpi-desync-any-protocol=1 --dpi-desync-autottl=1 --dpi-desync-fake-unknown-udp="%BIN%quic_initial_dbankcloud_ru.bin" --dpi-desync-cutoff=n2
) > "%SVC_BAT%"

echo [OK] Service launcher created.

:: --------------------------------------------------
:: 3. Install zapret service
:: --------------------------------------------------
echo [3/4] Installing zapret service...

set "SERVICE_NAME=zapret"
set "RETRY_COUNT=0"

:try_create
sc query %SERVICE_NAME% >nul 2>&1
if %errorlevel% equ 0 (
    sc stop %SERVICE_NAME% >nul 2>&1
    sc delete %SERVICE_NAME% >nul 2>&1
    timeout /t 3 >nul
)

sc create %SERVICE_NAME% binPath= "\"%SVC_BAT%\"" start= auto depend= WinDivert DisplayName= "Zapret DPI bypass (1.9.9c)"
if %errorlevel% equ 0 (
    sc description %SERVICE_NAME% "DPI bypass using zapret (winws) 1.9.9c"
    sc start %SERVICE_NAME%
    echo [OK] zapret service installed and started as '%SERVICE_NAME%'.
    goto :task
)

echo [WARN] Failed to create '%SERVICE_NAME%' (error %errorlevel%).
set /a RETRY_COUNT+=1
if %RETRY_COUNT% leq 5 (
    set "SERVICE_NAME=zapret%RETRY_COUNT%"
    echo [INFO] Retrying with service name '%SERVICE_NAME%'...
    goto :try_create
) else (
    echo [ERROR] Could not create zapret service after multiple attempts.
    pause
    exit /b 1
)

:: --------------------------------------------------
:: 4. Create scheduled task for tg-ws-proxy
:: --------------------------------------------------
:task
echo [4/4] Creating scheduled task for Telegram proxy...

set "TG_PROXY_SETUP=%ZAPRET_DIR%tg-ws-proxy\proxy\tg-ws-proxy-setup.bat"
set "TASK_NAME=Telegram WS Proxy AutoStart"

schtasks /delete /tn "%TASK_NAME%" /f 2>nul
schtasks /create /tn "%TASK_NAME%" /tr "\"%TG_PROXY_SETUP%\"" /sc onlogon /it /f

if %errorlevel% equ 0 (
    echo [OK] Scheduled task created. Proxy will start on every logon, and MTProto proxy will be auto-added to Telegram.
) else (
    echo [ERROR] Failed to create scheduled task.
    pause
    exit /b 1
)

echo.
echo ==============================================
echo   INSTALLATION COMPLETE!
echo   Service name: %SERVICE_NAME%
echo   Version: 1.9.9c
echo ==============================================
pause
exit /b
