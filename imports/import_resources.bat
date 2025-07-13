@echo off
REM Import Resources Script for Windows
REM This script runs the Python import script using the configured virtual environment

REM NOTE: Adjust the path as necessary
set PYTHON_EXE=../.venv/Scripts/python.exe 

echo Terraform Resource Import Script
echo =================================
echo.

if "%1"=="--help" (
    echo Usage: import_resources.bat [--dry-run] [--workspace WORKSPACE]
    echo.
    echo Arguments:
    echo   --dry-run    Show what would be imported without actually doing it
    echo   --workspace  Specify the workspace (default: current terraform workspace)
    echo.
    goto :eof
)

if "%1"=="--dry-run" (
    echo Running in DRY RUN mode - no actual imports will be performed
    echo.
)

%PYTHON_EXE% import_resources.py %*
