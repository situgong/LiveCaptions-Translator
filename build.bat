@echo off
chcp 65001
setlocal enabledelayedexpansion

set VERSION=1.0.0
set BUILD_DIR=publish\x64-self-contained

echo ===== LiveCaptionsTranslator Build Script =====

if exist "%BUILD_DIR%" (
    rd /s /q "%BUILD_DIR%"
)
mkdir "%BUILD_DIR%"

echo Cleaning solution...
dotnet clean
if %errorlevel% neq 0 (
    echo Error: Clean failed
    exit /b 1
)

echo Restoring packages...
dotnet restore
if %errorlevel% neq 0 (
    echo Error: Restore failed
    exit /b 1
)

echo Building release version...
dotnet build -c Release
if %errorlevel% neq 0 (
    echo Error: Build failed
    exit /b 1
)

echo Publishing...
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o "%BUILD_DIR%"
if %errorlevel% neq 0 (
    echo Error: Publish failed
    exit /b 1
)

echo.
echo Build completed successfully!
echo Release files are in: %BUILD_DIR%
echo.