@echo off
setlocal EnableDelayedExpansion
rem ------------------------------------------------------------------
rem  Card Sharks - mobile playtest
rem  1) exports the Web build to build\web
rem  2) serves it over HTTPS on your Wi-Fi so your phone can open it
rem  Usage: double-click, or drag your Godot .exe onto this file.
rem ------------------------------------------------------------------
cd /d "%~dp0"

set "GODOT_EXE=%~1"
if "!GODOT_EXE!"=="" set "GODOT_EXE=%GODOT%"
if "!GODOT_EXE!"=="" (
  for %%G in (godot.exe godot4.exe Godot_v4.6.3-stable_win64_console.exe Godot_v4.6.3-stable_win64.exe) do (
    if "!GODOT_EXE!"=="" for /f "delims=" %%P in ('where %%G 2^>nul') do if "!GODOT_EXE!"=="" set "GODOT_EXE=%%P"
  )
)
if "!GODOT_EXE!"=="" (
  echo Could not find Godot.
  echo Drag your Godot .exe onto playtest_mobile.bat, or set a GODOT environment variable to its path.
  pause
  exit /b 1
)

rem Prefer the console build so the server's output (the URL) is visible.
set "CONSOLE_EXE=!GODOT_EXE:_console.exe=.exe!"
set "CONSOLE_EXE=!CONSOLE_EXE:.exe=_console.exe!"
if exist "!CONSOLE_EXE!" set "GODOT_EXE=!CONSOLE_EXE!"
echo Using Godot: !GODOT_EXE!

if not exist build\web mkdir build\web
echo Exporting Web build...
"!GODOT_EXE!" --headless --path . --export-release "Web" build/web/index.html
if errorlevel 1 (
  echo Export failed.
  pause
  exit /b 1
)

echo.
echo Starting HTTPS server. If Windows Firewall asks, allow access on Private networks.
"!GODOT_EXE!" --headless --path . --script res://tools/serve_web.gd -- 8443
pause
