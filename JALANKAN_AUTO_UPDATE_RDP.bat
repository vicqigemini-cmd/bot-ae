@echo off
title Auto-Sync Bot AE from GitHub
echo ==========================================================
echo   MENJALANKAN AUTO-SYNC EA DARI GITHUB KE RDP
echo ==========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0auto_sync_rdp.ps1"
pause
