@echo off
REM Godot Headless Validation Script (Batch)
REM Runs Godot in headless mode to validate project files and run tests
REM
REM Godot Discovery Order:
REM   1. DevTools\Godot_v4.5.1-stable_win64_console.exe (preferred)
REM   2. GODOT_EXE environment variable (full path)
REM   3. Exit with code 2 if not found

setlocal EnableDelayedExpansion

REM ============================================================================
REM PATH RESOLUTION
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
REM Remove trailing backslash from SCRIPT_DIR for cleaner paths
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM Project root is parent of DevTools
for %%I in ("%SCRIPT_DIR%\..") do set "PROJECT_DIR=%%~fI"

echo.
echo ============================================
echo   GODOT HEADLESS VALIDATION
echo ============================================
echo.

REM ============================================================================
REM GODOT EXECUTABLE DISCOVERY
REM ============================================================================
set "GODOT_FOUND="
set "GODOT_CONSOLE_EXE=%SCRIPT_DIR%\Godot_v4.5.1-stable_win64_console.exe"
set "GODOT_GUI_EXE=%SCRIPT_DIR%\Godot_v4.5.1-stable_win64.exe"

REM Option 1: DevTools-local console exe (preferred)
if exist "%GODOT_CONSOLE_EXE%" (
    REM Verify GUI exe also exists (paired requirement)
    if not exist "%GODOT_GUI_EXE%" (
        echo [Headless] WARNING: Console exe found but GUI exe missing
        echo [Headless]   Console: %GODOT_CONSOLE_EXE%
        echo [Headless]   Missing: %GODOT_GUI_EXE%
        echo [Headless]   Some import operations may fail without GUI exe
        echo.
    )
    set "GODOT_FOUND=%GODOT_CONSOLE_EXE%"
    echo [Headless] Found DevTools-local Godot console exe
    goto :godot_found
)

REM Option 2: GODOT_EXE environment variable
if defined GODOT_EXE (
    if exist "%GODOT_EXE%" (
        set "GODOT_FOUND=%GODOT_EXE%"
        echo [Headless] Using GODOT_EXE environment variable
        goto :godot_found
    )
)

REM Exit if no Godot found
echo [Headless] ERROR: Godot executable not found!
echo.
echo [Headless] Attempted locations:
echo   1. %GODOT_CONSOLE_EXE%
if defined GODOT_EXE (
    echo   2. GODOT_EXE env var: %GODOT_EXE%
) else (
    echo   2. GODOT_EXE env var: ^(not set^)
)
echo.
echo [Headless] To fix, either:
echo   a^) Download Godot 4.5.1 console exe to DevTools\
echo      https://godotengine.org/download
echo   b^) Set GODOT_EXE environment variable to Godot console exe path
echo.
exit /b 2

:godot_found
REM Print resolved paths
echo [Headless] GodotExe=%GODOT_FOUND%
echo [Headless] ProjectPath=%PROJECT_DIR%
echo.

REM ============================================================================
REM STAGE 1: Import/Validation (parse errors, resource loading)
REM ============================================================================
echo ============================================
echo [Headless] Stage=1 ^(Import/Validation^)
echo ============================================
echo [Headless] Command="%GODOT_FOUND%" --headless --path "%PROJECT_DIR%" --import --quit
echo.

"%GODOT_FOUND%" --headless --path "%PROJECT_DIR%" --import --quit

set VALIDATION_EXIT_CODE=%ERRORLEVEL%

echo.
if %VALIDATION_EXIT_CODE%==0 (
    echo [Headless] Stage 1 PASSED ^(exit code 0^)
) else (
    echo [Headless] Stage 1 FAILED ^(exit code %VALIDATION_EXIT_CODE%^)
    echo.
    echo FOOTER: Headless validation exit code = %VALIDATION_EXIT_CODE%
    exit /b %VALIDATION_EXIT_CODE%
)
echo.

REM ============================================================================
REM STAGE 2: Run Test Suite
REM ============================================================================
echo ============================================
echo [Headless] Stage=2 ^(Test Suite^)
echo ============================================
echo [Headless] Command="%GODOT_FOUND%" --headless --path "%PROJECT_DIR%" --script "res://DevTools/run_tests_headless.gd" --quit
echo.

"%GODOT_FOUND%" --headless --path "%PROJECT_DIR%" --script "res://DevTools/run_tests_headless.gd" --quit

set TESTS_EXIT_CODE=%ERRORLEVEL%

echo.
if %TESTS_EXIT_CODE%==0 (
    echo [Headless] Stage 2 PASSED ^(exit code 0^)
) else (
    echo [Headless] Stage 2 FAILED ^(exit code %TESTS_EXIT_CODE%^)
)
echo.

REM ============================================================================
REM FINAL SUMMARY
REM ============================================================================
echo ============================================
echo   FINAL SUMMARY
echo ============================================
if %VALIDATION_EXIT_CODE%==0 (
    echo   Validation ^(Stage 1^): PASSED
) else (
    echo   Validation ^(Stage 1^): FAILED
)
if %TESTS_EXIT_CODE%==0 (
    echo   Tests ^(Stage 2^):      PASSED
) else (
    echo   Tests ^(Stage 2^):      FAILED
)
echo ============================================
echo.
echo FOOTER: Headless validation exit code = %VALIDATION_EXIT_CODE%
echo FOOTER: Headless tests exit code = %TESTS_EXIT_CODE%

REM Exit with test exit code (or validation if tests didn't run)
if not %TESTS_EXIT_CODE%==0 (
    exit /b %TESTS_EXIT_CODE%
)
exit /b %VALIDATION_EXIT_CODE%
