@echo off
rem Double-click launcher for sync_all.ps1 (live sync for the match, lobby and
rem art places). Arguments pass through: sync_all.cmd [match] [lobby] [art]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_all.ps1" %*
pause
