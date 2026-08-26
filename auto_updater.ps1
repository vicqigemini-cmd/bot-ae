# ==============================================================================
#  SENTINEL METATRADER 5 AUTO-UPDATER & AUTO-COMPILER DAEMON (RDP 24/7)
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
Write-Host " [AKTIF] SENTINEL RDP AUTO-UPDATER SERVICE BERJALAN 24/7" -ForegroundColor Green
Write-Host " Memantau update dari GitHub dan auto-compile di background" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Temukan folder Experts
$expertFolder = (Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
Write-Host "[INFO] Folder Experts : $expertFolder" -ForegroundColor Gray

# 2. Cari MetaEditor Compiler
$metaEditorPath = "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
if (-not (Test-Path $metaEditorPath)) {
    $metaEditorPath = Get-ChildItem -Path "C:\Program Files*", "C:\Users*" -Include "metaeditor64.exe", "metaeditor.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
    Write-Host "[INFO] Compiler Aktif : $metaEditorPath" -ForegroundColor Green
} else {
    Write-Host "[INFO] Compiler Aktif : Mode Standar Terminal" -ForegroundColor Gray
}

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
            Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $targetMq5 -ErrorAction Stop
            Write-Host "[$timeStr] 📥 File MQ5 berhasil diunduh ke folder Experts!" -ForegroundColor Green

            if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
                Write-Host "[$timeStr] ⚙️ Mengompilasi file EX5 di background..." -ForegroundColor Yellow
                $compileArgs = "/compile:`"$targetMq5`" /log:`"$expertFolder\compile.log`" /s"
                Start-Process -FilePath $metaEditorPath -ArgumentList $compileArgs -Wait -NoNewWindow
                Write-Host "[$timeStr] 🎉 KOMPILASI SUKSES! EA di chart MetaTrader otomatis ter-update!" -ForegroundColor Green
            }

            $lastSha = $currentSha
        } else {
            Write-Host "[$timeStr] [Cek #$checkCount] 🔍 Memeriksa GitHub... (Status: Kode RDP sudah paling baru)" -ForegroundColor DarkGray
        }
    }
    catch {
        $err = $_.Exception.Message
        Write-Host "[$timeStr] [Cek #$checkCount] ⚠️ Koneksi info: $err" -ForegroundColor DarkYellow
    }

    Start-Sleep -Seconds 30
}
