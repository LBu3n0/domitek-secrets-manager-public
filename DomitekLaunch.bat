@echo off
set SCRIPT=C:\DomitekVault\DomitekLaunch.ps1
if not exist "%SCRIPT%" (
    echo [ERROR] DomitekLaunch.ps1 not found at C:\DomitekVault
    pause
    exit /b 1
)
powershell -Command "Unblock-File -Path '%SCRIPT%'" >nul 2>&1
start /wait powershell -ExecutionPolicy Bypass -File "%SCRIPT%"
