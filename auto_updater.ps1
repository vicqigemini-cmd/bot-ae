# ==============================================================================
#  SENTINEL METATRADER 5 AUTO-UPDATER & AUTO-COMPILER DAEMON (RDP 24/7)
# ==============================================================================

$token = "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"
$headers = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github.raw" }
$metaHeaders = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github+json" }
$apiUrl = "https://api.github.com/repos/vicqigemini-cmd/bot-ae/contents/XAUUSD_AI_Brain_EA.mq5"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [AKTIF] SENTINEL RDP AUTO-UPDATER SERVICE BERJALAN 24/7" -ForegroundColor Green
Write-Host " Memantau update dari GitHub dan auto-compile di background" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Temukan folder Experts
$expertFolder = (Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
Write-Host "[INFO] Folder Experts: $expertFolder" -ForegroundColor Gray

# 2. Cari MetaEditor di seluruh drive C
$metaEditorPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "metaeditor64.exe", "metaeditor.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if ($metaEditorPath) {
    Write-Host "[INFO] MetaEditor Compiler Ditemukan: $metaEditorPath" -ForegroundColor Green
} else {
    Write-Host "[WARNING] MetaEditor EXE belum terdeteksi otomatis. File MQ5 akan tetap diunduh!" -ForegroundColor Yellow
}

$lastSha = ""

# Lakukan kompilasi awal saat pertama kali script dijalankan
$initialRun = $true

while ($true) {
    try {
        $info = Invoke-RestMethod -Uri $apiUrl -Headers $metaHeaders -ErrorAction Stop
        $currentSha = $info.sha

        if (($currentSha -ne $lastSha -and $currentSha -ne "") -or $initialRun) {
            $timeStr = Get-Date -Format "HH:mm:ss"
            Write-Host "`n[$timeStr] 🔔 Memproses Update EA Terbaru dari GitHub..." -ForegroundColor Magenta
            
            $targetMq5 = "$expertFolder\XAUUSD_AI_Brain_EA.mq5"
            Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $targetMq5 -ErrorAction Stop
            Write-Host "[$timeStr] 📥 File MQ5 berhasil diunduh ke Experts!" -ForegroundColor Green

            if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
                Write-Host "[$timeStr] ⚙️ Mengompilasi (F7 Otomatis)..." -ForegroundColor Yellow
                $argCompile = "/compile:$targetMq5"
                $argLog = "/log:$expertFolder\compile.log"
                Start-Process -FilePath $metaEditorPath -ArgumentList @($argCompile, $argLog, "/s") -Wait
                Write-Host "[$timeStr] 🎉 KOMPILASI SUKSES! File .ex5 baru sudah terpasang!" -ForegroundColor Green
                Write-Host "[$timeStr] 💡 Tips: Di chart MT5, klik timeframe M5 lalu M1 untuk refresh layar." -ForegroundColor Cyan
            } else {
                Write-Host "[$timeStr] 💡 Silakan buka MetaEditor dan tekan F7 satu kali." -ForegroundColor Yellow
            }

            $lastSha = $currentSha
            $initialRun = $false
        }
    }
    catch {
        # Silent retry
    }

    Start-Sleep -Seconds 30
}
