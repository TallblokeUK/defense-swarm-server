@echo off
rem Defense Swarm dedicated server -- Windows one-click launcher.
rem Put this file NEXT TO the game exe and double-click it.
rem The console prints your web-admin link (http://...:8080/?t=...).
setlocal
set EXE=DefenseSwarm.exe
if not exist "%~dp0%EXE%" (
  echo Could not find %EXE% next to this script.
  echo Edit start-server.bat and set EXE= to your game exe name.
  pause
  exit /b 1
)
"%~dp0%EXE%" --headless -- --server %*
pause
