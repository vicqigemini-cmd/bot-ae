# ==============================================================================
#  SENTINEL ZERO-TOUCH UNIVERSAL AUTO-UPDATER (PUBLIC & ENCRYPTED EX5 BINARY)
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$owner = "vicqigemini-cmd"
$repo  = "bot-ae"
$file  = "XAUUSD_AI_Brain_EA.ex5"

$apiUrl = "https://api.github.com/repos/$owner/$repo/contents/$file"
$rawUrl = "https://raw.githubusercontent.com/$owner/$repo/main/$file"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [AKTIF] APEX SOVEREIGN UNIVERSAL AUTO-UPDATER 24/7" -ForegroundColor Green
Write-Host " 100% Otomatis: Download Encrypted Binary EX5 + Auto-Reload" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Cari Terminal MetaTrader EXE
$terminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe"
if (-not (Test-Path $terminalPath)) {
    $terminalPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "terminal64.exe", "terminal.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

# 2. Temukan SEMUA folder Experts di seluruh instance MetaTrader
$allExpertFolders = Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

Write-Host "[INFO] Terminal Path  : $terminalPath" -ForegroundColor Gray
foreach ($f in $allExpertFolders) {
    Write-Host "[INFO] Experts Folder : $f" -ForegroundColor Gray
}
Write-Host "----------------------------------------------------------" -ForegroundColor Gray
Write-Host " Pengecekan otomatis berjalan setiap 30 detik:`n" -ForegroundColor White

$lastSha = ""

while ($true) {
    $timeStr = Get-Date -Format "HH:mm:ss"

    try {
        $headers = @{ "User-Agent" = "Apex-AutoUpdater-MT5" }
        $info = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
        $currentSha = $info.sha

        if ($currentSha -ne $lastSha -and $currentSha -ne "") {
            Write-Host "`n[$timeStr] [UPDATE] Ditemukan versi baru di GitHub! Mengunduh binary EX5 terenkripsi..." -ForegroundColor Magenta
            
            $tempEx5 = "$env:TEMP\XAUUSD_AI_Brain_EA_latest.ex5"
            Invoke-WebRequest -Uri $rawUrl -OutFile $tempEx5 -UseBasicParsing -ErrorAction Stop
            Write-Host "[$timeStr] [DOWNLOAD] 1. File Binary Terenkripsi (EX5) berhasil diunduh!" -ForegroundColor Green

            # Salin ke SEMUA folder Experts terminal
            foreach ($folder in $allExpertFolders) {
                $target = "$folder\XAUUSD_AI_Brain_EA.ex5"
                Copy-Item -Path $tempEx5 -Destination $target -Force
                Write-Host "[$timeStr] [DEPLOY] 2. Berhasil dipasang ke: $target" -ForegroundColor Yellow
            }

            # 3. Reload MetaTrader 5
            $runningProc = Get-Process -Name "terminal64", "terminal" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($runningProc) {
                $termPath = $runningProc.Path
                Write-Host "[$timeStr] [RELOAD] 3. Me-reload MetaTrader 5 ($termPath)..." -ForegroundColor Yellow
                Stop-Process -Id $runningProc.Id -Force
                Start-Sleep -Seconds 3
                if ($termPath -and (Test-Path $termPath)) {
                    Start-Process -FilePath $termPath
                    Write-Host "[$timeStr] [SUCCESS] 4. MetaTrader 5 berhasil di-reload dengan versi terbaru!" -ForegroundColor Green
                }
            } else {
                if ($terminalPath -and (Test-Path $terminalPath)) {
                    Start-Process -FilePath $terminalPath
                    Write-Host "[$timeStr] [SUCCESS] 4. MetaTrader 5 berhasil dijalankan!" -ForegroundColor Green
                }
            }

            $lastSha = $currentSha
            Write-Host "[$timeStr] [STANDBY] Update selesai 100%! Memantau kembali...`n" -ForegroundColor Cyan
        } else {
            Write-Host -NoNewline "."
        }
    }
    catch {
        Write-Host "`n[$timeStr] [INFO] Menunggu koneksi / respon GitHub..." -ForegroundColor DarkGray
    }

    Start-Sleep -Seconds 30
}
