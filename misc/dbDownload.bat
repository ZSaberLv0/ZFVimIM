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
cd /d "%REPO_PATH%"

for /f "delims=" %%a in ('git branch') do @set BRANCH=%%a
set BRANCH=!BRANCH:* =!

git checkout .
git fetch --all
git reset --hard origin/%BRANCH%
git clean -xdf
git pull
if not "!errorlevel!" == "0" (
    cd /d "%_OLD_DIR%"
    exit /b 1
)
git gc --prune=now

cd /d "%_OLD_DIR%"

exit /b 0

