@echo off
setlocal
setlocal enabledelayedexpansion

set WORK_DIR=%~dp0
set REPO_PATH=%~1%
if not defined REPO_PATH goto :usage
goto :run
:usage
exit /b 1
:run

set _OLD_DIR=%cd%

cd "%REPO_PATH%"
for /f "delims=" %%a in ('git rev-list --count HEAD') do @set RESULT=%%a
echo %RESULT%

cd "%_OLD_DIR%"
exit /b 0

