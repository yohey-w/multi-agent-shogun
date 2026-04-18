@echo off
chcp 65001 >nul 2>&1
title multi-agent-shogun Installer

echo.
echo   +============================================================+
echo   ^|  [SHOGUN] multi-agent-shogun - WSL Installer                ^|
echo   ^|           WSL2 + Ubuntu セットアップ                       ^|
echo   +============================================================+
echo.

REM ===== Step 1: Check/Install WSL2 =====
echo   [1/2] Checking WSL2...
echo         WSL2 確認中...

wsl.exe --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   WSL2 not found. Installing automatically...
    echo   WSL2 が見つかりません。自動インストール中...
    echo.

    REM 管理者権限で実行されているか確認
    net session >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo   +============================================================+
        echo   ^|  [WARN] Administrator privileges required!                 ^|
        echo   ^|         管理者権限が必要です                               ^|
        echo   +============================================================+
        echo.
        echo   Right-click install.bat and select "Run as administrator"
        echo   install.bat を右クリック→「管理者として実行」
        echo.
        pause
        exit /b 1
    )

    echo   Installing WSL2...
    powershell -Command "wsl --install --no-launch"

    echo.
    echo   +============================================================+
    echo   ^|  [!] Restart required!                                     ^|
    echo   ^|      再起動が必要です                                      ^|
    echo   +============================================================+
    echo.
    echo   After restart, run install.bat again.
    echo   再起動後、もう一度 install.bat を実行してください。
    echo.
    pause
    exit /b 0
)
echo   [OK] WSL2 OK
echo.

REM ===== Step 2: Check/Install Ubuntu =====
echo   [2/2] Checking Ubuntu...
echo         Ubuntu 確認中...

REM Ubuntu check: use -d Ubuntu directly (avoids UTF-16LE pipe issue with findstr)
wsl.exe -d Ubuntu -- echo test >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :ubuntu_ok

REM echo test failed - check if Ubuntu distro exists but needs initial setup
wsl.exe -d Ubuntu -- exit 0 >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :ubuntu_needs_setup

REM Ubuntu not installed
echo.
echo   Ubuntu not found. Installing automatically...
echo   Ubuntu が見つかりません。自動インストール中...
echo.

powershell -Command "wsl --install -d Ubuntu --no-launch"

echo.
echo   +============================================================+
echo   ^|  [NOTE] Ubuntu installation started!                       ^|
echo   ^|         Ubuntu インストール開始                            ^|
echo   +============================================================+
echo.
echo   Restart your PC, then run install.bat again.
echo   PCを再起動してから、もう一度 install.bat を実行してください。
echo.
pause
exit /b 0

:ubuntu_needs_setup
REM Ubuntu exists but initial setup not completed
echo.
echo   +============================================================+
echo   ^|  [WARN] Ubuntu initial setup required!                     ^|
echo   ^|         Ubuntu の初期設定が必要です                        ^|
echo   +============================================================+
echo.
echo   1. Open Ubuntu from Start Menu
echo      スタートメニューで「Ubuntu」を検索して開く
echo.
echo   2. Set your username and password
echo      ユーザー名とパスワードを設定
echo.
echo   3. Run install.bat again
echo      もう一度 install.bat を実行
echo.
pause
exit /b 1

:ubuntu_ok
echo   [OK] Ubuntu OK
echo.

REM Set Ubuntu as default WSL distribution
wsl --set-default Ubuntu

echo.
echo   +============================================================+
echo   ^|  [OK] WSL2 + Ubuntu ready!                                 ^|
echo   ^|       WSL2 + Ubuntu 準備完了！                             ^|
echo   +============================================================+
echo.
echo   +------------------------------------------------------------+
echo   ^|  [NEXT] Open Ubuntu and follow these steps:               ^|
echo   ^|         Ubuntu を開いて以下の手順を実行:                   ^|
echo   +------------------------------------------------------------+
echo   ^|                                                            ^|
echo   ^|  First time only / 初回のみ:                               ^|
echo   ^|    1. Set username and password when prompted              ^|
echo   ^|       ユーザー名とパスワードを設定                        ^|
echo   ^|    2. cd /mnt/c/tools/feature-shogun                      ^|
echo   ^|    3. ./first_setup.sh                                    ^|
echo   ^|                                                            ^|
echo   ^|  Every time you use / 使うたびに:                          ^|
echo   ^|    cd /mnt/c/tools/feature-shogun                          ^|
echo   ^|    ./shutsujin_departure.sh                                ^|
echo   ^|                                                            ^|
echo   +------------------------------------------------------------+
echo.
pause
exit /b 0
