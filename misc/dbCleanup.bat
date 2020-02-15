@echo off
setlocal
setlocal enabledelayedexpansion

set WORK_DIR=%~dp0
set REPO_PATH=%~1%
set GIT_USER_EMAIL=%~2%
set GIT_USER_NAME=%~3%
set GIT_USER_TOKEN=%~4%
set CLEANUP_SCRIPT=%~5%
set CACHE_PATH=%~6%
if not defined REPO_PATH goto :usage
if not defined GIT_USER_EMAIL goto :usage
if not defined GIT_USER_NAME goto :usage
if not defined GIT_USER_TOKEN goto :usage
if not defined CLEANUP_SCRIPT goto :usage
if not defined CACHE_PATH goto :usage
goto :run
:usage
exit /b 1
:run

mkdir "%CACHE_PATH%" >nul 2>&1
set _TMP_DIR="%CACHE_PATH%\ZFVimIM_cache_dbCleanup"
del /f/s/q "%_TMP_DIR%" >nul 2>&1
rmdir /s/q "%_TMP_DIR%" >nul 2>&1
mkdir "%_TMP_DIR%"
xcopy /s/e/y/r/h "%REPO_PATH%\.git" "%_TMP_DIR%\.git\" >nul 2>&1
call "%CLEANUP_SCRIPT%" "%_TMP_DIR%" "%GIT_USER_EMAIL%" "%GIT_USER_NAME%" "%GIT_USER_TOKEN%"
set result=%errorlevel%
del /f/s/q "%_TMP_DIR%" >nul 2>&1
rmdir /s/q "%_TMP_DIR%" >nul 2>&1
exit /b %result%

