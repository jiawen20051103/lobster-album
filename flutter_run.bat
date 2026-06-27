@echo off
setlocal

rem Android SDK tools (aapt/adb) cannot read APK paths with non-ASCII characters on Windows.
rem Map the project to drive L: so all tool paths stay ASCII-only during build and install.

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "DEV_DRIVE=L:"

subst %DEV_DRIVE% "%PROJECT_DIR%" >nul 2>&1
if errorlevel 1 (
  echo Failed to map %DEV_DRIVE% to project directory.
  echo Close other terminals using %DEV_DRIVE% or run: subst %DEV_DRIVE% /d
  exit /b 1
)

cd /d %DEV_DRIVE%\
echo Running from %CD%
flutter %*
set "EXIT_CODE=%ERRORLEVEL%"

subst %DEV_DRIVE% /d >nul 2>&1
exit /b %EXIT_CODE%
