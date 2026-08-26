# ==============================================================================
#  🤖 SENTINEL METATRADER 5 ZERO-TOUCH AUTO-UPDATER & AUTO-RELOAD (RDP 24/7)
#  100% OTOMATIS: Download + Compile F7 + Auto-Reload MetaTrader Tanpa Sentuh RDP!
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
Write-Host " [AKTIF] SENTINEL ZERO-TOUCH AUTO-RELOAD SERVICE 24/7" -ForegroundColor Green
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
Write-Host " Service aktif! Pengecekan otomatis berjalan setiap 30 detik:`n" -ForegroundColor White

$lastSha = ""
$checkCount = 0

while ($true) {
    $checkCount++
    $timeStr = Get-Date -Format "HH:mm:ss"

    try {
        $info = Invoke-RestMethod -Uri $apiUrl -Headers $metaHeaders -ErrorAction Stop
        $currentSha = $info.sha

        if ($currentSha -ne $lastSha -and $currentSha -ne "") {
            Write-Host "`n[$timeStr] 🚨 DITEMUKAN PEMBARUAN KODE BARU DI GITHUB!" -ForegroundColor Magenta
            
            $targetMq5 = "$expertFolder\XAUUSD_AI_Brain_EA.mq5"
            $compileLog = "$expertFolder\compile.log"
            
            # 1. Download file terbaru
            Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $targetMq5 -ErrorAction Stop
            Write-Host "[$timeStr] 📥 1. File MQ5 terbaru berhasil diunduh!" -ForegroundColor Green

            # 2. Compile silent ke EX5
            if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
                Write-Host "[$timeStr] ⚙️ 2. Mengompilasi file EX5 di background..." -ForegroundColor Yellow
                Start-Process -FilePath $metaEditorPath -ArgumentList "/compile:`"$targetMq5`"", "/log:`"$compileLog`"", "/s" -Wait
                Write-Host "[$timeStr] ✅ 2. Kompilasi selesai!" -ForegroundColor Green
            }

            # 3. Auto-Reload MetaTrader 5 (Tutup & Buka Kembali Otomatis dalam 2 Detik)
            Write-Host "[$timeStr] 🔄 3. Me-reload MetaTrader 5 agar versi baru langsung aktif..." -ForegroundColor Yellow
            $runningTerminal = Get-Process -Name "terminal64", "terminal" -ErrorAction SilentlyContinue
            if ($runningTerminal) {
                Stop-Process -Name $runningTerminal.Name -Force
                Start-Sleep -Seconds 2
            }

            if ($terminalPath -and (Test-Path $terminalPath)) {
                Start-Process -FilePath $terminalPath
                Write-Host "[$timeStr] 🎉 3. MetaTrader 5 sukses dibuka kembali dengan versi terbaru!" -ForegroundColor Green
            }

            Write-Host "[$timeStr] 🚀 SELURUH PROSES 100% SUKSES TANPA PERLU SENTUH RDP!`n" -ForegroundColor Cyan
            $lastSha = $currentSha
        } else {
            Write-Host "[$timeStr] [Cek #$checkCount] 🔍 Memeriksa GitHub... (Status: RDP sudah versi paling baru ✅)" -ForegroundColor DarkGray
        }
    }
    catch {
        $err = $_.Exception.Message
        Write-Host "[$timeStr] [Cek #$checkCount] ⚠️ Info: $err" -ForegroundColor DarkYellow
    }

    Start-Sleep -Seconds 30
}
