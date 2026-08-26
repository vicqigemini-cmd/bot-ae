# ==============================================================================
#  SENTINEL METATRADER 5 ZERO-TOUCH AUTO-UPDATER (ALL TERMINALS & VERIFICATION)
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

# 1. Cari MetaEditor Compiler
$metaEditorPath = "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
if (-not (Test-Path $metaEditorPath)) {
    $metaEditorPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "metaeditor64.exe", "metaeditor.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

# 2. Cari Terminal MetaTrader EXE
$terminalPath = "C:\Program Files\MetaTrader 5\terminal64.exe"
if (-not (Test-Path $terminalPath)) {
    $terminalPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "terminal64.exe", "terminal.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

# 3. Temukan SEMUA folder Experts di seluruh instance MetaTrader
$allExpertFolders = Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

Write-Host "[INFO] Compiler Path  : $metaEditorPath" -ForegroundColor Gray
Write-Host "[INFO] Terminal Path  : $terminalPath" -ForegroundColor Gray
foreach ($f in $allExpertFolders) {
    Write-Host "[INFO] Experts Folder : $f" -ForegroundColor Gray
}
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
            
            # Download file terbaru ke file temporer
            $tempMq5 = "$env:TEMP\XAUUSD_AI_Brain_EA_latest.mq5"
            Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $tempMq5 -ErrorAction Stop
            Write-Host "[$timeStr] [DOWNLOAD] 1. File EA MQ5 v3.50 berhasil diunduh!" -ForegroundColor Green

            # Salin ke SEMUA folder Experts terminal dan compile
            foreach ($folder in $allExpertFolders) {
                $target1 = "$folder\XAUUSD_AI_Brain_EA.mq5"
                $target2 = "$folder\Discord_Sentinel_EA_MT5.mq5"
                $logFile = "$folder\compile.log"

                Copy-Item -Path $tempMq5 -Destination $target1 -Force
                Copy-Item -Path $tempMq5 -Destination $target2 -Force

                # Hapus file binary lama agar terkompilasi segar
                Remove-Item -Path "$folder\XAUUSD_AI_Brain_EA.ex5" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "$folder\Discord_Sentinel_EA_MT5.ex5" -Force -ErrorAction SilentlyContinue

                if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
                    Write-Host "[$timeStr] [COMPILE] 2. Mengompilasi di folder: $folder" -ForegroundColor Yellow
                    Start-Process -FilePath $metaEditorPath -ArgumentList "/compile:`"$target1`"", "/log:`"$logFile`"" -Wait
                    Start-Process -FilePath $metaEditorPath -ArgumentList "/compile:`"$target2`"", "/log:`"$logFile`"" -Wait

                    if (Test-Path $logFile) {
                        $logTxt = Get-Content $logFile -Tail 2
                        Write-Host "[$timeStr] [COMPILER LOG] $logTxt" -ForegroundColor Cyan
                    }
                }
            }

            # 3. Tangkap proses MetaTrader yang aktif dan reload
            $runningProc = Get-Process -Name "terminal64", "terminal" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($runningProc) {
                $termPath = $runningProc.Path
                Write-Host "[$timeStr] [RELOAD] 3. Me-reload MetaTrader 5 ($termPath)..." -ForegroundColor Yellow
                Stop-Process -Id $runningProc.Id -Force
                Start-Sleep -Seconds 3
                if ($termPath -and (Test-Path $termPath)) {
                    Start-Process -FilePath $termPath
                    Write-Host "[$timeStr] [RELOAD] 3. MetaTrader 5 sukses dibuka kembali dengan versi terbaru!" -ForegroundColor Green
                }
            } elseif ($terminalPath -and (Test-Path $terminalPath)) {
                Start-Process -FilePath $terminalPath
                Write-Host "[$timeStr] [RELOAD] 3. MetaTrader 5 diluncurkan otomatis!" -ForegroundColor Green
            }

            Write-Host "[$timeStr] [SELESAI] PROSES ZERO-TOUCH 100% SUKSES!`n" -ForegroundColor Green
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
