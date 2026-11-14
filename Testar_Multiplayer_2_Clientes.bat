@echo off
cd /d "%~dp0"
set "GODOT_BIN=godot.exe"
where godot.exe >nul 2>&1
if not %ERRORLEVEL%==0 (
    set "GODOT_BIN=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"
)
echo Iniciando Host (Royal) + Cliente (National) em Multiplayer Local...
start "WarChampions_Host" "%GODOT_BIN%" --path . --position 40,60 --resolution 820x600 -- --host
timeout /t 2 /nobreak >nul
start "WarChampions_Client" "%GODOT_BIN%" --path . --position 880,60 --resolution 820x600 -- --join=127.0.0.1
