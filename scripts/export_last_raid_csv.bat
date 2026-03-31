@echo off
setlocal

if /i not "%~1"=="__run" (
  start "" cmd /k ""%~f0" __run"
  exit /b
)

shift
cd /d "%~dp0"

set "ACCOUNT=%~1"
if "%ACCOUNT%"=="" (
  set /p "ACCOUNT=Enter account name (for example ELITZIA): "
)

if "%ACCOUNT%"=="" (
  echo Account name is required.
  goto end
)

py export_last_raid_csv.py "%ACCOUNT%"
if errorlevel 9009 (
  python export_last_raid_csv.py "%ACCOUNT%"
)

:end
echo.
pause
