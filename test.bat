@echo off
setlocal
cd /d "%~dp0"
set SETUP_NO_PAUSE=1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tests\Invoke-RunnerTests.ps1"
exit /b %ERRORLEVEL%
