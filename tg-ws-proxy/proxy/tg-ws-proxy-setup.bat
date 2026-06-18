@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting administrator rights
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [INFO] Started tg-ws-proxy setup

:: 1. Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Python not found. Downloading installer
    set "PYTHON_URL=https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    set "PYTHON_INSTALLER=%TEMP%\python-installer.exe"

    powershell -Command "Invoke-WebRequest -Uri '!PYTHON_URL!' -OutFile '!PYTHON_INSTALLER!'"
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to download Python
        pause
        exit /b 1
    )
    echo [INFO] Python installer downloaded. Installing silently
    start /wait "" "!PYTHON_INSTALLER!" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    if exist "!PYTHON_INSTALLER!" del "!PYTHON_INSTALLER!"

    :: Update PATH
    for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul ^| find "Path"') do set "SysPath=%%j"
    if defined SysPath set "PATH=%SysPath%;%PATH%"

    python --version >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Python installed but not accessible. Please reboot and try again
        pause
        exit /b 1
    )
    echo [OK] Python installed successfully
) else (
    echo [OK] Python is already installed
)

:: 2. Modules (cryptography recommended, but optional - fallback to OpenSSL ctypes)
echo [INFO] Checking required modules

set "HAS_CRYPTO=0"
call python -c "import cryptography" >nul 2>nul
if not errorlevel 1 set "HAS_CRYPTO=1"

if "%HAS_CRYPTO%"=="1" (
    echo [OK] cryptography is already installed
) else (
    echo [INFO] Installing cryptography for better performance
    call python -m pip install --upgrade pip --quiet --disable-pip-version-check >nul 2>nul
    call python -m pip install cryptography --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org --quiet --disable-pip-version-check >nul 2>nul
    if not errorlevel 1 (
        echo [OK] cryptography installed
    ) else (
        echo [WARN] cryptography installation failed. Will use OpenSSL fallback (slower but works)
    )
)

:: Note: websockets module is NOT needed - tg-ws-proxy uses built-in RawWebSocket

:: 3. Launch
echo [INFO] Starting tg-ws-proxy in background

:: Check pythonw exists
call pythonw --version >nul 2>nul
if errorlevel 1 (
    echo [WARN] pythonw not found, trying python
    call python --version >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] Neither pythonw nor python found in PATH
        pause
        exit /b 1
    )
    set "PYTHON_EXE=python"
) else (
    set "PYTHON_EXE=pythonw"
)

:: Check tg_ws_proxy.py exists
if not exist "%~dp0tg_ws_proxy.py" (
    echo [ERROR] tg_ws_proxy.py not found at %~dp0tg_ws_proxy.py
    pause
    exit /b 1
)

:: Launch with error log
set "START_LOG=%TEMP%\tg-ws-proxy-start.log"
if exist "%START_LOG%" del "%START_LOG%"

start "" /min cmd /c "%PYTHON_EXE% "%~dp0tg_ws_proxy.py" --port 1080 --host 127.0.0.1 --secret c36be8ffc5f480784b4c5fc31f1eefe8 2>"%START_LOG%""

:: Wait and verify process started
timeout /t 2 >nul
tasklist /FI "IMAGENAME eq %PYTHON_EXE%.exe" /NH | find /I "%PYTHON_EXE%.exe" >nul
if errorlevel 1 (
    echo [ERROR] Proxy process did not start. Check log: %START_LOG%
    if exist "%START_LOG%" type "%START_LOG%"
    pause
    exit /b 1
)

echo [OK] Proxy launched (%PYTHON_EXE%). Log: %START_LOG%

:: Auto-add proxy to Telegram Desktop (wait for proxy to start)
timeout /t 7 >nul
start tg://proxy?server=127.0.0.1^&port=1080^&secret=c36be8ffc5f480784b4c5fc31f1eefe8

timeout /t 5 >nul
exit /b
