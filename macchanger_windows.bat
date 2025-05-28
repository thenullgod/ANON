@echo off
setlocal enabledelayedexpansion

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please run this script as administrator.
    exit /b 1
)

:: List available network interfaces
for /f "tokens=2 delims=:" %%a in ('netsh interface show interface ^| findstr "Connected"') do (
    set "interface=%%a"
    set "interface=!interface:~1!"
    echo Available interface: !interface!
)

:: Prompt user to select an interface
set /p "selectedInterface=Enter the interface name: "

:: Validate the selected interface
netsh interface show interface name="%selectedInterface%" >nul 2>&1
if %errorLevel% neq 0 (
    echo Invalid interface name: %selectedInterface%
    exit /b 2
)

:: Backup original MAC address
for /f "tokens=2 delims= " %%a in ('netsh interface show interface name="%selectedInterface%" ^| findstr "Physical Address"') do (
    set "originalMac=%%a"
    reg add "HKLM\SOFTWARE\MAC_Backup" /v OriginalMAC_%selectedInterface% /d "!originalMac!" /f >nul
)

:: Generate a random MAC address
:generateMac
for /f "delims=" %%a in ('powershell -command "0x%(Get-Random -Maximum 256).ToString('X2')%-$(Get-Random -Maximum 256).ToString('X2')%-$(Get-Random -Maximum 256).ToString('X2')%-$(Get-Random -Maximum 256).ToString('X2')%-$(Get-Random -Maximum 256).ToString('X2')%-$(Get-Random -Maximum 256).ToString('X2')"') do set "randomMac=%%a"

:: Validate MAC address (not 00-00-00-00-00-00)
if "%randomMac%"=="00-00-00-00-00-00" goto :generateMac

:: Display the generated MAC address
echo Generated MAC Address: %randomMac%

:: Confirm with the user
set /p "confirm=Do you want to change the MAC address to %randomMac%? (y/n): "
if /i "%confirm%" neq "y" (
    echo MAC address change aborted.
    exit /b 0
)

:: Disable the network interface
netsh interface set interface name="%selectedInterface%" admin=disable

:: Change the MAC address
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}" /v NetworkAddress /d %randomMac% /f

:: Enable the network interface
netsh interface set interface name="%selectedInterface%" admin=enable

echo MAC address has been changed to %randomMac%
pause