@echo off
rem ARC-Icons.cmd - double-click launcher for the ARC icon theme controller.
rem Runs the all-in-one PowerShell script beside it; it will ask for Administrator itself.
setlocal
set "HERE=%~dp0"
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%HERE%ARC-Icons.ps1" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%ARC-Icons.ps1" %*
)
if %errorlevel% neq 0 (
  echo.
  echo Script exited with code %errorlevel%.
  pause
)
endlocal
