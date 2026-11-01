@echo off
setlocal
set "PS1=%~dp0Install-Pi.ps1"
if not exist "%PS1%" (
  echo ERROR: Install-Pi.ps1 not found next to this file.
  echo Put both files in the same folder, then double-click again.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
echo.
pause
