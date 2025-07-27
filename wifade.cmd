@echo off
setlocal
REM Change to the directory where this script resides
cd /d "%~dp0"
set "EXEDIR=%~dp0"
set "COREEXE=%EXEDIR%WifadeCore.exe"
if not exist "%COREEXE%" (
    echo ❌ WifadeCore.exe not found!
    echo Expected location: %COREEXE%
    echo Current directory: %CD%
    echo.
    echo Please ensure both files are in the same directory:
    echo   - wifade.cmd (this launcher)
    echo   - WifadeCore.exe (main application)
    pause
    exit /b 1
)
"%COREEXE%" %*
set "ERRCODE=%ERRORLEVEL%"
if not "%ERRCODE%"=="0" (
    echo WifadeCore.exe exited with error code %ERRCODE%
    pause
)
endlocal
