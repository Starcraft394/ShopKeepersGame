# Godot Headless Validation Script (PowerShell)
# Runs Godot in headless mode to validate project files and run tests
#
# Godot Discovery Order:
#   1. DevTools/Godot_v4.5.1-stable_win64_console.exe (preferred)
#   2. GODOT_EXE environment variable (full path)
#   3. Exit with code 2 if not found

# Don't treat stderr output as terminating errors (Godot logs warnings to stderr)
$ErrorActionPreference = "Continue"

# ============================================================================
# PATH RESOLUTION
# ============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

# Normalize paths (resolve .. and ensure absolute)
$ProjectDir = (Resolve-Path $ProjectDir).Path

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  GODOT HEADLESS VALIDATION" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# GODOT EXECUTABLE DISCOVERY
# ============================================================================
$GodotExe = $null
$GodotConsoleExe = Join-Path $ScriptDir "Godot_v4.5.1-stable_win64_console.exe"
$GodotGuiExe = Join-Path $ScriptDir "Godot_v4.5.1-stable_win64.exe"

# Option 1: DevTools-local console exe (preferred)
if (Test-Path $GodotConsoleExe) {
    # Verify GUI exe also exists (paired requirement for full functionality)
    if (-not (Test-Path $GodotGuiExe)) {
        Write-Host "[Headless] WARNING: Console exe found but GUI exe missing" -ForegroundColor Yellow
        Write-Host "[Headless]   Console: $GodotConsoleExe" -ForegroundColor Yellow
        Write-Host "[Headless]   Missing: $GodotGuiExe" -ForegroundColor Yellow
        Write-Host "[Headless]   Some import operations may fail without GUI exe" -ForegroundColor Yellow
        Write-Host ""
    }
    $GodotExe = $GodotConsoleExe
    Write-Host "[Headless] Found DevTools-local Godot console exe" -ForegroundColor Green
}
# Option 2: GODOT_EXE environment variable
elseif ($env:GODOT_EXE -and (Test-Path $env:GODOT_EXE)) {
    $GodotExe = $env:GODOT_EXE
    Write-Host "[Headless] Using GODOT_EXE environment variable" -ForegroundColor Green
}

# Exit if no Godot found
if (-not $GodotExe) {
    Write-Host "[Headless] ERROR: Godot executable not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "[Headless] Attempted locations:" -ForegroundColor Yellow
    Write-Host "  1. $GodotConsoleExe" -ForegroundColor Yellow
    Write-Host "  2. GODOT_EXE env var: $(if ($env:GODOT_EXE) { $env:GODOT_EXE } else { '(not set)' })" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[Headless] To fix, either:" -ForegroundColor Cyan
    Write-Host "  a) Download Godot 4.5.1 console exe to DevTools/" -ForegroundColor Cyan
    Write-Host "     https://godotengine.org/download" -ForegroundColor Cyan
    Write-Host "  b) Set GODOT_EXE environment variable to Godot console exe path" -ForegroundColor Cyan
    Write-Host ""
    exit 2
}

# Print resolved paths
Write-Host "[Headless] GodotExe=$GodotExe"
Write-Host "[Headless] ProjectPath=$ProjectDir"
Write-Host ""

# ============================================================================
# STAGE 1: Import/Validation (parse errors, resource loading)
# ============================================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "[Headless] Stage=1 (Import/Validation)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$Stage1Cmd = "`"$GodotExe`" --headless --path `"$ProjectDir`" --import --quit"
Write-Host "[Headless] Command=$Stage1Cmd"
Write-Host ""

& $GodotExe --headless --path $ProjectDir --import --quit 2>&1

$ValidationExitCode = $LASTEXITCODE

Write-Host ""
if ($ValidationExitCode -eq 0) {
    Write-Host "[Headless] Stage 1 PASSED (exit code 0)" -ForegroundColor Green
} else {
    Write-Host "[Headless] Stage 1 FAILED (exit code $ValidationExitCode)" -ForegroundColor Red
    Write-Host ""
    Write-Host "FOOTER: Headless validation exit code = $ValidationExitCode" -ForegroundColor Red
    exit $ValidationExitCode
}
Write-Host ""

# ============================================================================
# STAGE 2: Run Test Suite
# ============================================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "[Headless] Stage=2 (Test Suite)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$Stage2Cmd = "`"$GodotExe`" --headless --path `"$ProjectDir`" --script `"res://DevTools/run_tests_headless.gd`" --quit"
Write-Host "[Headless] Command=$Stage2Cmd"
Write-Host ""

& $GodotExe --headless --path $ProjectDir --script "res://DevTools/run_tests_headless.gd" --quit 2>&1

$TestsExitCode = $LASTEXITCODE

Write-Host ""
if ($TestsExitCode -eq 0) {
    Write-Host "[Headless] Stage 2 PASSED (exit code 0)" -ForegroundColor Green
} else {
    Write-Host "[Headless] Stage 2 FAILED (exit code $TestsExitCode)" -ForegroundColor Red
}
Write-Host ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  FINAL SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Validation (Stage 1): $(if ($ValidationExitCode -eq 0) { 'PASSED' } else { 'FAILED' })"
Write-Host "  Tests (Stage 2):      $(if ($TestsExitCode -eq 0) { 'PASSED' } else { 'FAILED' })"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "FOOTER: Headless validation exit code = $ValidationExitCode"
Write-Host "FOOTER: Headless tests exit code = $TestsExitCode"

# Exit with test exit code (or validation if tests didn't run)
if ($TestsExitCode -ne 0) {
    exit $TestsExitCode
}
exit $ValidationExitCode
