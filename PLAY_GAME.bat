@echo off
setlocal
cd /d "%~dp0"
set "BREACHPOINT_DATA_DIR=%~dp0save-data"
if not exist "%BREACHPOINT_DATA_DIR%" mkdir "%BREACHPOINT_DATA_DIR%"

if exist "builds\BreachpointZeroHour.exe" (
  start "" "builds\BreachpointZeroHour.exe"
  exit /b 0
)

where godot.exe >nul 2>nul
if %errorlevel%==0 (
  godot.exe --path "%CD%"
  exit /b 0
)

where godot4.exe >nul 2>nul
if %errorlevel%==0 (
  godot4.exe --path "%CD%"
  exit /b 0
)

echo.
echo BREACHPOINT: ZERO HOUR
echo ----------------------
echo No exported build or Godot executable was found.
echo Install Godot 4.6 from https://godotengine.org/download/windows/
echo Then run this file again, or import project.godot in the Godot Project Manager.
echo.
pause
exit /b 1
