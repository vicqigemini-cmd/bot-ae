@echo off
title Apex Sovereign Citadel - Silent Background Sync Engine
:: ==============================================================================
:: 👑 APEX SOVEREIGN CITADEL - SILENT BACKGROUND AUTO-UPDATER
:: ==============================================================================
:: File ini berjalan di background 24/7 untuk otomatis mengunduh biner EA terbaru
:: dari GitHub dan memasangnya ke seluruh terminal MetaTrader 5 di RDP Anda.
:: ==============================================================================

set REPO_URL=https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main
set EX5_URL=%REPO_URL%/XAUUSD_AI_Brain_EA.ex5
set MQ5_URL=%REPO_URL%/XAUUSD_AI_Brain_EA.mq5

:SYNC_LOOP
cls
echo ======================================================================
echo  APEX EA SILENT BACKGROUND SYNC RUNNING (24/7)
echo  Waktu Terakhir Cek: %date% %time%
echo ======================================================================

:: Jalankan download via PowerShell diam-diam ke seluruh folder terminal MT5
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$repo = 'https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main';" ^
    "$ex5 = $repo + '/XAUUSD_AI_Brain_EA.ex5';" ^
    "$mq5 = $repo + '/XAUUSD_AI_Brain_EA.mq5';" ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "$folders = Get-ChildItem -Path \"$env:APPDATA\MetaQuotes\Terminal\" -Directory -ErrorAction SilentlyContinue;" ^
    "if ($folders) {" ^
    "    foreach ($f in $folders) {" ^
    "        $exp = Join-Path $f.FullName 'MQL5\Experts';" ^
    "        if (Test-Path $exp) {" ^
    "            try {" ^
    "                Invoke-WebRequest -Uri $ex5 -OutFile (Join-Path $exp 'XAUUSD_AI_Brain_EA.ex5') -UseBasicParsing -TimeoutSec 15;" ^
    "                Invoke-WebRequest -Uri $mq5 -OutFile (Join-Path $exp 'XAUUSD_AI_Brain_EA.mq5') -UseBasicParsing -TimeoutSec 15;" ^
    "                Write-Host 'Synced to:' $exp -ForegroundColor Green;" ^
    "            } catch {}" ^
    "        }" ^
    "        $cache = Join-Path $f.FullName 'Tester\cache';" ^
    "        if (Test-Path $cache) {" ^
    "            Remove-Item -Path ($cache + '\*') -Force -Recurse -ErrorAction SilentlyContinue;" ^
    "        }" ^
    "    }" ^
    "}"

echo.
echo [STATUS] Sinkronisasi selesai. Menunggu 5 menit untuk siklus berikutnya...
timeout /t 300 /nobreak >nul
goto SYNC_LOOP
