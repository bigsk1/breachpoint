@echo off
setlocal
cd /d "%~dp0"

where godot.exe >nul 2>nul
if %errorlevel%==0 set "GODOT=godot.exe"
if not defined GODOT where godot4.exe >nul 2>nul
if not defined GODOT if %errorlevel%==0 set "GODOT=godot4.exe"

if not defined GODOT (
  echo Godot 4.6 was not found on PATH.
  echo Install it from https://godotengine.org/download/windows/ and install export templates.
  pause
  exit /b 1
)

if not exist builds mkdir builds
%GODOT% --headless --path "%CD%" --export-release "Windows Desktop" "builds\BreachpointZeroHour.exe"
if %errorlevel% neq 0 (
  echo Export failed. In Godot, choose Editor ^> Manage Export Templates and install the 4.6 templates.
  pause
  exit /b %errorlevel%
)

echo Export complete: builds\BreachpointZeroHour.exe
pause
