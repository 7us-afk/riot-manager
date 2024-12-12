@echo off
setlocal enabledelayedexpansion

REM Request administrative privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrative privileges...
    powershell Start-Process "%0" -Verb RunAs
    exit /b
)

REM Set Vanguard directory and registry path
set "VANGUARD_DIR=%PROGRAMFILES%\Riot Vanguard"
set "REGISTER_PATH=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
set "RIOT_CLIENT_DIR=%LOCALAPPDATA%\Riot Games\Riot Client"

REM Check if Vanguard directory exists
if not exist "%VANGUARD_DIR%" (
    echo Vanguard directory not found. Is it installed in the default location?
    pause
    exit /b
)

:MENU
cls
echo Riot Games Manager
echo 1. Disable Vanguard and Riot Services
echo 2. Enable Vanguard
echo 3. Check Status
echo 4. Exit
choice /C 1234 /N /M "Enter your choice (1-4): "
if errorlevel 4 goto :EOF
if errorlevel 3 goto CHECK_STATUS
if errorlevel 2 goto ENABLE
if errorlevel 1 goto DISABLE_ALL

:DISABLE_ALL
echo Disabling Vanguard and Riot Services...
echo.

REM Stop and disable Vanguard services
echo Stopping and disabling Vanguard services...
for %%S in (vgc vgk) do (
    echo Stopping %%S service...
    sc stop %%S >nul 2>&1
    echo Disabling %%S service...
    sc config %%S start= disabled >nul 2>&1
)

REM Stop and disable other Riot services
echo Stopping and disabling other Riot services...
for /f "tokens=1" %%S in ('sc query state^= all ^| findstr "Riot"') do (
    echo Stopping %%S service...
    sc stop %%S >nul 2>&1
    echo Disabling %%S service...
    sc config %%S start= disabled >nul 2>&1
)

REM Kill Riot processes
echo Terminating Riot processes...
taskkill /F /IM RiotClientServices.exe >nul 2>&1
taskkill /F /IM RiotClientUx.exe >nul 2>&1
taskkill /F /IM RiotClientUxRender.exe >nul 2>&1
taskkill /F /IM VALORANT.exe >nul 2>&1
taskkill /F /IM vgtray.exe >nul 2>&1

REM Remove registry entries
echo Removing Riot entries from startup...
reg delete "%REGISTER_PATH%" /v "Riot Client" /f >nul 2>&1
reg delete "%REGISTER_PATH%" /v "Riot Vanguard" /f >nul 2>&1

REM Rename key Vanguard files
echo Renaming key Vanguard files...
pushd "%VANGUARD_DIR%"
for %%F in (vgc.exe vgk.sys vgtray.exe) do (
    if exist "%%F" (
        echo Renaming %%F to %%F.bak
        ren "%%F" "%%F.bak"
    )
)
popd

REM Delete logs
echo Deleting Vanguard and Riot logs...
if exist "%VANGUARD_DIR%\Logs" rmdir /S /Q "%VANGUARD_DIR%\Logs"
if exist "%RIOT_CLIENT_DIR%\Logs" rmdir /S /Q "%RIOT_CLIENT_DIR%\Logs"
if exist "%LOCALAPPDATA%\VALORANT\Saved\Logs" rmdir /S /Q "%LOCALAPPDATA%\VALORANT\Saved\Logs"

echo.
echo Vanguard and Riot services have been disabled and logs deleted.
pause
goto MENU

:ENABLE
echo Enabling Vanguard...
echo.

REM Rename key files back
echo Restoring key Vanguard files...
pushd "%VANGUARD_DIR%"
for %%F in (vgc.exe.bak vgk.sys.bak vgtray.exe.bak) do (
    if exist "%%F" (
        echo Renaming %%F to %%~nF
        ren "%%F" "%%~nF"
    )
)
popd

REM Enable and start Vanguard services
echo Configuring vgc service to start on demand...
sc config vgc start= demand >nul 2>&1
echo Configuring vgk service to start with system...
sc config vgk start= system >nul 2>&1
echo Starting vgc service...
sc start vgc >nul 2>&1
echo Starting vgk service...
sc start vgk >nul 2>&1

REM Add registry entry
echo Adding Vanguard to startup...
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\vgc" /v "ImagePath"') do (
    set "VANGUARD_PATH=%%B"
)
reg add "%REGISTER_PATH%" /v "Riot Vanguard" /t REG_SZ /d "%VANGUARD_PATH%" /f >nul 2>&1

echo.
echo Vanguard has been enabled. The system will restart in 10 seconds.
echo Press any key to restart now, or close this window to cancel the restart.
timeout /t 10
shutdown /r /f /t 00
goto :EOF

:CHECK_STATUS
echo Checking Riot Games Status...
echo.

REM Check Riot services status
echo Riot Services Status:
for /f "tokens=1" %%S in ('sc query state^= all ^| findstr "Riot"') do (
    echo Service: %%S
    sc query %%S | findstr STATE
    echo.
)

REM Check Vanguard services status
echo Vanguard Services Status:
for %%S in (vgc vgk) do (
    echo Service: %%S
    sc query %%S | findstr STATE
    echo.
)

REM Check if logs exist
echo Log Directories:
if exist "%VANGUARD_DIR%\Logs" (
    echo Vanguard logs exist at: %VANGUARD_DIR%\Logs
) else (
    echo Vanguard logs do not exist.
)
if exist "%RIOT_CLIENT_DIR%\Logs" (
    echo Riot Client logs exist at: %RIOT_CLIENT_DIR%\Logs
) else (
    echo Riot Client logs do not exist.
)
if exist "%LOCALAPPDATA%\VALORANT\Saved\Logs" (
    echo VALORANT logs exist at: %LOCALAPPDATA%\VALORANT\Saved\Logs
) else (
    echo VALORANT logs do not exist.
)

REM Check if key files are present or renamed
echo.
echo Key Vanguard File Status:
pushd "%VANGUARD_DIR%"
for %%F in (vgc.exe vgk.sys vgtray.exe) do (
    if exist "%%F" (
        echo %%F is present
    ) else if exist "%%F.bak" (
        echo %%F is renamed to %%F.bak
    ) else (
        echo %%F is missing
    )
)
popd

echo.
pause
goto MENU