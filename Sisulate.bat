@echo off
setlocal
if "%~1"=="" (
  echo Usage: Sisulate ^<folder^> [server] [/STW]
  exit /b 1
)
set "filters=%~3"
if not defined filters set "filters=STW"
if "%filters:~0,1%"=="/" set "filters=%filters:~1%"
if "%~2"=="" (
  powershell.exe -NoProfile -File "%~dp0Sisulate.ps1" -FolderPath "%~1" -Filters "%filters%"
) else (
  powershell.exe -NoProfile -File "%~dp0Sisulate.ps1" -FolderPath "%~1" -Server "%~2" -Filters "%filters%"
)
exit /b %ERRORLEVEL%
