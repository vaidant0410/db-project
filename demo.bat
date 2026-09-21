@echo off
setlocal
rem ---------------------------------------------------------------------
rem  demo.bat - one-click launcher for the Airline Reservation System demo
rem  Double-click it, or run it from any terminal. No typing needed.
rem ---------------------------------------------------------------------
set "CONN=ars/ars_pass@//localhost:1521/XEPDB1"
set "SQLDIR=%~dp0sql"

title Airline Reservation System - demo
mode con: cols=200 lines=50 >nul 2>&1
color 0A
cd /d "%SQLDIR%"

:menu
cls
echo.
echo   ==========================================================
echo     AIRLINE RESERVATION SYSTEM  -  demo launcher
echo   ==========================================================
echo.
echo     [1]  Rebuild database, then run everything   (run_all.sql)
echo          Do this once, shortly before presenting.
echo.
echo     [2]  End-to-end demo only                    (09_demo.sql)
echo          Press Enter in the demo to advance.
echo.
echo     [3]  The 15 queries only                     (08_queries.sql)
echo.
echo     [4]  Open a plain SQL*Plus prompt
echo.
echo     [Q]  Quit
echo.
choice /c 1234Q /n /m "  Choose: "
if errorlevel 5 goto :eof
if errorlevel 4 sqlplus -L %CONN% & goto menu
if errorlevel 3 sqlplus -L %CONN% @08_queries.sql & goto menu
if errorlevel 2 sqlplus -L %CONN% @09_demo.sql & goto menu
if errorlevel 1 sqlplus -L %CONN% @run_all.sql & goto menu
