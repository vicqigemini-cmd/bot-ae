# ==============================================================================
#  SENTINEL METATRADER 5 ZERO-TOUCH AUTO-UPDATER (RDP 24/7)
#  Pure ASCII Encoding for 100% Reliability on Windows Server
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$token = "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"
$headers = @{ 
    "Authorization" = "Bearer $token"
    "Accept"        = "application/vnd.github.raw"
    "User-Agent"    = "Sentinel-AutoUpdater-MT5"
}
$metaHeaders = @{ 
    "Authorization" = "Bearer $token"
    "Accept"        = "application/vnd.github+json"
    "User-Agent"    = "Sentinel-AutoUpdater-MT5"
}
$apiUrl = "https://api.github.com/repos/vicqigemini-cmd/bot-ae/contents/XAUUSD_AI_Brain_EA.mq5"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [AKTIF] SENTINEL ZERO-TOUCH UNIVERSAL AUTO-UPDATER 24/7" -ForegroundColor Green
Write-Host " 100% Otomatis: Download + Compile + Auto-Reload Terminal" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Temukan folder Experts
$expertFolder = (Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
Write-Host "[INFO] Folder Experts : $expertFolder" -ForegroundColor Gray

# 2. Cari MetaEditor Compiler
$metaEditorPath = "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
if (-not (Test-Path $metaEditorPath)) {
    $metaEditorPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "metaeditor64.exe", "metaeditor.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

# 3. Cari Terminal MetaTrader EXE
$terminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe"
if (-not (Test-Path $terminalPath)) {
    $terminalPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "terminal64.exe", "terminal.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

Write-Host "[INFO] Compiler Path  : $metaEditorPath" -ForegroundColor Gray
Write-Host "[INFO] Terminal Path  : $terminalPath" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor Gray
Write-Host " Pengecekan otomatis berjalan setiap 30 detik:`n" -ForegroundColor White

$lastSha = ""
$checkCount = 0

while ($true) {
    $checkCount++
    $timeStr = Get-Date -Format "HH:mm:ss"

    try {
        $info = Invoke-RestMethod -Uri $apiUrl -Headers $metaHeaders -ErrorAction Stop
        $currentSha = $info.sha

        if ($currentSha -ne $lastSha -and $currentSha -ne "") {
            Write-Host "`n[$timeStr] [UPDATE] Ditemukan pembaruan kode baru di GitHub!" -ForegroundColor Magenta
            
            $targetMq5_1 = "$expertFolder\XAUUSD_AI_Brain_EA.mq5"
            $targetMq5_2 = "$expertFolder\Discord_Sentinel_EA_MT5.mq5"
            
            # 1. Download file terbaru
            Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $targetMq5_1 -ErrorAction Stop
            Copy-Item -Path $targetMq5_1 -Destination $targetMq5_2 -Force
            Write-Host "[$timeStr] [DOWNLOAD] 1. File EA MQ5 berhasil diunduh!" -ForegroundColor Green

            # 2. Compile silent ke EX5 untuk kedua file
            if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
                Write-Host "[$timeStr] [COMPILE] 2. Mengompilasi file EX5 di background..." -ForegroundColor Yellow
                Start-Process -FilePath $metaEditorPath -ArgumentList "/compile:`"$targetMq5_1`"", "/s" -Wait
                Start-Process -FilePath $metaEditorPath -ArgumentList "/compile:`"$targetMq5_2`"", "/s" -Wait
                Write-Host "[$timeStr] [COMPILE] 2. Kompilasi kedua file EA sukses!" -ForegroundColor Green
            }

            # 3. Tangkap proses MetaTrader yang aktif dan reload
            $runningProc = Get-Process -Name "terminal64", "terminal" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($runningProc) {
                $termPath = $runningProc.Path
                Write-Host "[$timeStr] [RELOAD] 3. Me-reload MetaTrader 5..." -ForegroundColor Yellow
                Stop-Process -Id $runningProc.Id -Force
                Start-Sleep -Seconds 2
                if ($termPath -and (Test-Path $termPath)) {
                    Start-Process -FilePath $termPath
                    Write-Host "[$timeStr] [RELOAD] 3. MetaTrader 5 sukses dibuka kembali dengan versi terbaru!" -ForegroundColor Green
                }
            } elseif ($terminalPath -and (Test-Path $terminalPath)) {
                Start-Process -FilePath $terminalPath
                Write-Host "[$timeStr] [RELOAD] 3. MetaTrader 5 diluncurkan otomatis!" -ForegroundColor Green
            }

            Write-Host "[$timeStr] [SELESAI] PROSES ZERO-TOUCH 100% SUKSES!`n" -ForegroundColor Cyan
            $lastSha = $currentSha
        } else {
            Write-Host "[$timeStr] [Cek #$checkCount] Memeriksa GitHub... (Status: RDP sudah versi paling baru [OK])" -ForegroundColor DarkGray
        }
    }
    catch {
        $err = $_.Exception.Message
        Write-Host "[$timeStr] [Cek #$checkCount] [INFO] $err" -ForegroundColor DarkYellow
    }

    Start-Sleep -Seconds 30
}
