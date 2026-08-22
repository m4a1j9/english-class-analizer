@echo off
setlocal enableextensions
color 0A
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Transcribe Folder.ps1" %*
echo.
pause
color
exit /b
