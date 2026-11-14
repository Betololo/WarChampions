@echo off
cd /d "%~dp0"
where godot.exe >nul 2>&1
if %ERRORLEVEL%==0 (
    start "" godot.exe --path .
) else (
    start "" "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" --path .
)
