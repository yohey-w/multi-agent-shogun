@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul 2>&1
title multi-agent-shogun Agent Configurator

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo.
echo   +============================================================+
echo   ^|  [SHOGUN] multi-agent-shogun - Agent Configurator         ^|
echo   ^|      Runs agent configuration inside Ubuntu/WSL            ^|
echo   +============================================================+
echo.

if not exist "%SCRIPT_DIR%\scripts\configure_agents.py" (
    echo   [ERROR] scripts\configure_agents.py not found next to this launcher.
    echo           Run this bat from the multi-agent-shogun folder.
    echo.
    pause
    exit /b 1
)

wsl.exe -d Ubuntu -- echo test >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   [ERROR] Ubuntu on WSL is not ready.
    echo           Finish Ubuntu initial setup, then run first_setup.sh in WSL.
    echo.
    pause
    exit /b 1
)

for /f "usebackq delims=" %%I in (`wsl.exe -d Ubuntu -- wslpath -a "%SCRIPT_DIR%"`) do set "REPO_WSL=%%I"
if not defined REPO_WSL (
    echo   [ERROR] Failed to resolve WSL path from:
    echo           %SCRIPT_DIR%
    echo.
    pause
    exit /b 1
)

wsl.exe -d Ubuntu -- bash -lc "cd \"%REPO_WSL%\" && python3 scripts/configure_agents.py %*"
set "CONFIG_EXIT=%ERRORLEVEL%"
if not "%CONFIG_EXIT%"=="0" (
    echo.
    echo   [ERROR] Configurator failed with exit code %CONFIG_EXIT%.
    echo.
    pause
    exit /b %CONFIG_EXIT%
)

echo.
echo   [OK] Agent configuration finished.
echo        Restart runtime with:
echo        bash shutsujin_departure.sh -c
echo.
pause
exit /b 0
