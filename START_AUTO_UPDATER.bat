@echo off
title Sentinel RDP Auto-Updater Daemon 24/7
color 0A
echo ========================================================
echo   SENTINEL METATRADER 5 AUTO-UPDATER & AUTO-COMPILER
echo   (Download Otomatis + Auto-Compile F7 Tanpa Sentuh RDP)
echo ========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0auto_updater.ps1"
pause
