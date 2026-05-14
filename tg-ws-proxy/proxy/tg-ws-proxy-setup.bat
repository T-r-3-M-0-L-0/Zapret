@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting administrator rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [INFO] Started tg-ws-proxy setup.

:: 1. Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Python not found. Downloading installer...
    set "PYTHON_URL=https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    set "PYTHON_INSTALLER=%TEMP%\python-installer.exe"

    powershell -Command "Invoke-WebRequest -Uri '!PYTHON_URL!' -OutFile '!PYTHON_INSTALLER!'"
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to download Python.
        pause
        exit /b 1
    )
    echo [INFO] Python installer downloaded. Installing silently...
    start /wait "" "!PYTHON_INSTALLER!" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    if exist "!PYTHON_INSTALLER!" del "!PYTHON_INSTALLER!"

    :: Обновляем PATH
    for /f "tokens=2*" %%i in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul ^| find "Path"') do set "SysPath=%%j"
    if defined SysPath set "PATH=%SysPath%;%PATH%"

    python --version >nul 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Python installed but not accessible. Please reboot and try again.
        pause
        exit /b 1
    )
    echo [OK] Python installed successfully.
) else (
    echo [OK] Python is already installed.
)

:: 2. Modules
echo [INFO] Checking required modules...
set "NEED_INSTALL="
python -c "import cryptography" 2>nul || set "NEED_INSTALL=!NEED_INSTALL! cryptography"
python -c "import websockets" 2>nul || set "NEED_INSTALL=!NEED_INSTALL! websockets"

if defined NEED_INSTALL (
    echo [INFO] Installing modules:!NEED_INSTALL!
    python -m pip install --upgrade pip --quiet --disable-pip-version-check
    python -m pip install!NEED_INSTALL! --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org --quiet --disable-pip-version-check
    if %errorlevel% neq 0 (
        echo [ERROR] Module installation failed. Try running manually:
        echo python -m pip install!NEED_INSTALL! --trusted-host pypi.org --trusted-host files.pythonhosted.org
        pause
        exit /b 1
    )
    echo [OK] Modules installed.
) else (
    echo [OK] Required modules already installed.
)

:: 3. Launch
echo [INFO] Starting tg-ws-proxy in background...
start "" /min pythonw "%~dp0tg_ws_proxy.py" --port 1080 --host 127.0.0.1 --secret c36be8ffc5f480784b4c5fc31f1eefe8

echo [OK] Proxy launched. This window will close in 5 seconds.

:: Авто-добавление прокси в Telegram Desktop (с задержкой на поднятие прокси)
timeout /t 7 >nul
start tg://proxy?server=127.0.0.1^&port=1080^&secret=c36be8ffc5f480784b4c5fc31f1eefe8

timeout /t 5 >nul
exit /b