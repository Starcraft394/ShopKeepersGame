@echo off
REM AutoPlay Bot launcher — runs game with automated playthrough
REM Usage: run_autoplay.bat R1-R3
REM        run_autoplay.bat R4-R5
REM        run_autoplay.bat R6-R7

set CHUNK=%1
if "%CHUNK%"=="" set CHUNK=R1-R3

REM Find Godot executable (check common locations)
set GODOT=
if exist "%~dp0Godot_v4.6.1-stable_mono_win64_console.exe" (
    set GODOT="%~dp0Godot_v4.6.1-stable_mono_win64_console.exe"
) else if exist "%~dp0..\Godot_v4.6.1-stable_mono_win64_console.exe" (
    set GODOT="%~dp0..\Godot_v4.6.1-stable_mono_win64_console.exe"
) else (
    REM Try PATH
    where godot >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        set GODOT=godot
    ) else (
        echo [AutoPlay] ERROR: Godot executable not found!
        echo [AutoPlay] Place Godot_v4.6.1-stable_mono_win64_console.exe in DevTools/ or project root
        echo [AutoPlay] Or add Godot to your PATH
        pause
        exit /b 1
    )
)

set PROJECT="%~dp0.."

echo ==========================================
echo [AutoPlay] Starting chunk: %CHUNK%
echo [AutoPlay] Godot: %GODOT%
echo [AutoPlay] Project: %PROJECT%
echo ==========================================

%GODOT% --path %PROJECT% -- --autoplay %CHUNK%

echo.
echo ==========================================
echo [AutoPlay] Done. Screenshots saved to:
echo   %%APPDATA%%\Godot\app_userdata\ShopKeepersGame\playtest_screenshots\
echo ==========================================
pause
