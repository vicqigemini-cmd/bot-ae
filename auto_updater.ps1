# ==============================================================================
#  🤖 AUTO-UPDATER & AUTO-COMPILER DAEMON FOR METATRADER 5 (RDP 24/7)
#  Otomatis Download & Otomatis Compile F7 di Background tanpa perlu buka MetaEditor!
# ==============================================================================

$token = "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"
$headers = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github.raw" }
$apiUrl = "https://api.github.com/repos/vicqigemini-cmd/bot-ae/contents/XAUUSD_AI_Brain_EA.mq5"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🚀 SENTINEL RDP AUTO-UPDATER SERVICE AKTIF 24/7" -ForegroundColor Green
Write-Host " Memantau update dari GitHub & auto-compile di background..." -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# Temukan folder MetaTrader & MetaEditor
$expertFolder = (Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
$terminalBase = Split-Path (Split-Path (Split-Path $expertFolder))

# Cari metaeditor64.exe di Program Files
$metaEditorPath = Get-ChildItem -Path "C:\Program Files" -Filter "metaeditor64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $metaEditorPath) {
    $metaEditorPath = Get-ChildItem -Path "C:\Program Files (x86)" -Filter "metaeditor64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

$lastSha = ""

while ($true) {
    try {
        # Cek SHA file terbaru dari GitHub
        $metaHeaders = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github+json" }
        $info = Invoke-RestMethod -Uri "https://api.github.com/repos/vicqigemini-cmd/bot-ae/contents/XAUUSD_AI_Brain_EA.mq5" -Headers $metaHeaders -ErrorAction Stop
        $currentSha = $info.sha

        if ($currentSha -ne $lastSha -and $currentSha -ne "") {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] 🔔 Ditemukan Pembaruan Kode Baru di GitHub!" -ForegroundColor Magenta
            
            $targetMq5 = "$expertFolder\XAUUSD_AI_Brain_EA.mq5"
            Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $targetMq5 -ErrorAction Stop
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 📥 File MQ5 berhasil diunduh!" -ForegroundColor Green

            # Jika MetaEditor ditemukan, lakukan Silent Compilation (F7 otomatis)
            if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⚙️ Sedang mengompilasi (F7 Otomatis)..." -ForegroundColor Yellow
                Start-Process -FilePath $metaEditorPath -ArgumentList "/compile:`"$targetMq5`"", "/log:`"$expertFolder\compile.log`"", "/s" -Wait
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 🎉 Selesai! EA di chart MetaTrader otomatis ter-update!" -ForegroundColor Green
            }

            $lastSha = $currentSha
        }
    }
    catch {
        # Abaikan error koneksi sementara
    }

    Start-Sleep -Seconds 30
}
