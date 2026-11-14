@echo off
cd /d "%~dp0"
where godot.exe >nul 2>&1
if %ERRORLEVEL%==0 (
    start "" godot.exe -e --path .
) else (
    start "" "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" -e --path .
)
