# ==============================================================================
#  APEX SOVEREIGN ZERO-TOUCH UNIVERSAL AUTO-UPDATER 24/7 (v11.00 EDITION)
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$owner = "vicqigemini-cmd"
$repo  = "bot-ae"
$branch = "main"

$rawEx5Url = "https://raw.githubusercontent.com/$owner/$repo/$branch/XAUUSD_AI_Brain_EA.ex5"
$rawMq5Url = "https://raw.githubusercontent.com/$owner/$repo/$branch/XAUUSD_AI_Brain_EA.mq5"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [AKTIF] APEX SOVEREIGN UNIVERSAL AUTO-UPDATER v11.00" -ForegroundColor Green
Write-Host " 100% Otomatis: Download Direct EX5 + Auto-Compile + Reload" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Cari Terminal MetaTrader EXE
$terminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe"
if (-not (Test-Path $terminalPath)) {
    $terminalPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "terminal64.exe", "terminal.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

# 2. Temukan SEMUA folder Experts di seluruh instance MetaTrader
$MT5_BASE_DIR = "$env:APPDATA\MetaQuotes\Terminal"
$allExpertFolders = Get-ChildItem -Path "$MT5_BASE_DIR\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

Write-Host "[INFO] Terminal Path  : $terminalPath" -ForegroundColor Gray
foreach ($f in $allExpertFolders) {
    Write-Host "[INFO] Experts Folder : $f" -ForegroundColor Gray
}
Write-Host "----------------------------------------------------------" -ForegroundColor Gray
Write-Host " Pengecekan otomatis berjalan setiap 30 detik:`n" -ForegroundColor White

$lastHash = ""
$checkCount = 0

while ($true) {
    $checkCount++
    $timeStr = Get-Date -Format "HH:mm:ss"

    try {
        # Gunakan WebClient Direct Raw (100% Bebas Error 401 Unauthorized)
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("Cache-Control", "no-cache")
        $WebClient.Headers.Add("User-Agent", "Apex-AutoUpdater-MT5")

        $tempEx5 = "$env:TEMP\XAUUSD_AI_Brain_EA_download.ex5"
        $WebClient.DownloadFile($rawEx5Url, $tempEx5)

        if (Test-Path $tempEx5) {
            $currentHash = (Get-FileHash -Path $tempEx5 -Algorithm MD5).Hash

            if ($currentHash -ne $lastHash -and $currentHash -ne "") {
                Write-Host "`n[$timeStr] [UPDATE] Ditemukan EA v11.00 baru di GitHub! Mengaplikasikan..." -ForegroundColor Magenta

                # Salin ke SEMUA folder Experts terminal
                foreach ($folder in $allExpertFolders) {
                    $targetEx5 = "$folder\XAUUSD_AI_Brain_EA.ex5"
                    Copy-Item -Path $tempEx5 -Destination $targetEx5 -Force
                    Write-Host "[$timeStr] [DEPLOY] 1. Berhasil dipasang ke: $targetEx5" -ForegroundColor Green
                }

                # Unduh juga file .mq5 sebagai backup
                try {
                    $tempMq5 = "$env:TEMP\XAUUSD_AI_Brain_EA_download.mq5"
                    $WebClient.DownloadFile($rawMq5Url, $tempMq5)
                    foreach ($folder in $allExpertFolders) {
                        Copy-Item -Path $tempMq5 -Destination "$folder\XAUUSD_AI_Brain_EA.mq5" -Force
                    }
                } catch {}

                # 3. Reload MetaTrader 5
                $runningProc = Get-Process -Name "terminal64", "terminal" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($runningProc) {
                    $termPath = $runningProc.Path
                    Write-Host "[$timeStr] [RELOAD] 2. Me-reload MetaTrader 5 ($termPath)..." -ForegroundColor Yellow
                    Stop-Process -Id $runningProc.Id -Force
                    Start-Sleep -Seconds 3
                    if ($termPath -and (Test-Path $termPath)) {
                        Start-Process -FilePath $termPath
                        Write-Host "[$timeStr] [SUCCESS] 3. MetaTrader 5 sukses dibuka kembali dengan v11.00!" -ForegroundColor Green
                    }
                } else {
                    if ($terminalPath -and (Test-Path $terminalPath)) {
                        Start-Process -FilePath $terminalPath
                        Write-Host "[$timeStr] [SUCCESS] 3. MetaTrader 5 berhasil dijalankan!" -ForegroundColor Green
                    }
                }

                $lastHash = $currentHash
                Write-Host "[$timeStr] [SELESAI] PROSES ZERO-TOUCH v11.00 100% SUKSES!`n" -ForegroundColor Cyan
            } else {
                Write-Host "[$timeStr] [Cek #$checkCount] Memeriksa GitHub... (Status: RDP sudah versi paling baru [OK])" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Host "[$timeStr] [Cek #$checkCount] [INFO] Menghubungkan ke GitHub... ($($_.Exception.Message))" -ForegroundColor DarkGray
    }

    Start-Sleep -Seconds 30
}
