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

:: Stop and remove old service
net stop zapret2 >nul 2>&1
sc delete zapret2 >nul 2>&1

:: Create wrapper that sets correct working dir and PATH
> "zapret2-wrapper.bat" (
    echo @echo off
    echo cd /d "%~dp0"
    echo set "PATH=%~dp0bin;%%PATH%%"
    echo call "%~dp0%f%"
)

:: Install service via wrapper
sc create zapret2 binPath= "cmd.exe /c \"%~dp0zapret2-wrapper.bat\"" start= auto displayname= "Zapret2 DPI Bypass"
sc description zapret2 "Zapret2 DPI bypass software"

echo.
sc start zapret2

pause
