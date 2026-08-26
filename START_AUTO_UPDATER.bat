@echo off
title Sentinel RDP Auto-Updater Daemon 24/7
color 0A
echo ========================================================
echo   SENTINEL METATRADER 5 AUTO-UPDATER
echo   Download Otomatis dan Auto-Compile F7 Tanpa Sentuh RDP
echo ========================================================
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0auto_updater.ps1"
pause
