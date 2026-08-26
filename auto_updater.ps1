# ==============================================================================
#  SENTINEL METATRADER 5 AUTO-UPDATER DAEMON (RDP 24/7)
# ==============================================================================

$token = "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"
$headers = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github.raw" }
$metaHeaders = @{ "Authorization" = "Bearer $token"; "Accept" = "application/vnd.github+json" }
$apiUrl = "https://api.github.com/repos/vicqigemini-cmd/bot-ae/contents/XAUUSD_AI_Brain_EA.mq5"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [AKTIF] SENTINEL RDP AUTO-UPDATER SERVICE BERJALAN 24/7" -ForegroundColor Green
Write-Host " Memantau update dari GitHub dan auto-compile di background" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# Temukan folder MetaTrader & MetaEditor
$expertFolder = (Get-ChildItem -Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Experts" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName

# Cari metaeditor64.exe
$metaEditorPath = Get-ChildItem -Path "C:\Program Files" -Filter "metaeditor64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $metaEditorPath) {
    $metaEditorPath = Get-ChildItem -Path "C:\Program Files (x86)" -Filter "metaeditor64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

$lastSha = ""

while ($true) {
    try {
        $info = Invoke-RestMethod -Uri $apiUrl -Headers $metaHeaders -ErrorAction Stop
        $currentSha = $info.sha

        if ($currentSha -ne $lastSha -and $currentSha -ne "") {
            $timeStr = Get-Date -Format "HH:mm:ss"
            Write-Host "[$timeStr] Ditemukan Pembaruan Kode Baru di GitHub!" -ForegroundColor Magenta
            
            $targetMq5 = "$expertFolder\XAUUSD_AI_Brain_EA.mq5"
            Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $targetMq5 -ErrorAction Stop
            Write-Host "[$timeStr] File MQ5 berhasil diunduh!" -ForegroundColor Green

            if ($metaEditorPath -and (Test-Path $metaEditorPath)) {
                Write-Host "[$timeStr] Sedang mengompilasi (F7 Otomatis)..." -ForegroundColor Yellow
                $argCompile = "/compile:$targetMq5"
                $argLog = "/log:$expertFolder\compile.log"
                Start-Process -FilePath $metaEditorPath -ArgumentList @($argCompile, $argLog, "/s") -Wait
                Write-Host "[$timeStr] SUKSES! EA di chart MetaTrader otomatis ter-update!" -ForegroundColor Green
            }

            $lastSha = $currentSha
        }
    }
    catch {
        # Silent retry
    }

    Start-Sleep -Seconds 30
}
