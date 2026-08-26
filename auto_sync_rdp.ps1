# =====================================================================
# SCRIPT AUTO-SYNC & AUTO-COMPILE OTOMATIS DARI GITHUB KE METATRADER RDP
# =====================================================================

$GITHUB_RAW_URL = "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/Discord_Sentinel_EA_MT5.mq5"

# Cari lokasi folder MetaTrader 5 Data Folder secara otomatis di RDP
$MT5_BASE_DIR = "$env:APPDATA\MetaQuotes\Terminal"
$TERMINAL_DIRS = Get-ChildItem -Path $MT5_BASE_DIR -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path "$($_.FullName)\MQL5\Experts" }

if (!$TERMINAL_DIRS) {
    Write-Host "⚠️ Folder MetaTrader 5 tidak ditemukan otomatis di AppData." -ForegroundColor Yellow
    $EXPERTS_PATH = Read-Host "Masukkan path lengkap folder MQL5\Experts di RDP kamu"
} else {
    $EXPERTS_PATH = "$($TERMINAL_DIRS[0].FullName)\MQL5\Experts"
    Write-Host "✅ Ditemukan Terminal MT5 di: $EXPERTS_PATH" -ForegroundColor Green
}

$TARGET_FILE = "$EXPERTS_PATH\Discord_Sentinel_EA_MT5.mq5"
$METAEDITOR_PATH = "C:\Program Files\MetaTrader 5\metaeditor64.exe"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 AUTO-SYNC BOT AE DIAKTIFKAN DI RDP!" -ForegroundColor Cyan
Write-Host "Setiap kali GitHub di-update, file di RDP akan otomatis diperbarui & di-compile!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$LAST_HASH = ""

while ($true) {
    try {
        # Download konten terbaru dari GitHub
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("Cache-Control", "no-cache")
        $Content = $WebClient.DownloadString($GITHUB_RAW_URL)

        # Hitung Hash untuk mendeteksi perubahan
        $Stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($Content))
        $CurrentHash = (Get-FileHash -InputStream $Stream -Algorithm MD5).Hash

        if ($CurrentHash -ne $LAST_HASH) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⚡ Terdeteksi Update Baru di GitHub! Mengunduh..." -ForegroundColor Yellow
            
            # Simpan file baru ke folder Experts
            [System.IO.File]::WriteAllText($TARGET_FILE, $Content, [System.Text.Encoding]::UTF8)
            $LAST_HASH = $CurrentHash
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 💾 File tersimpan di: $TARGET_FILE" -ForegroundColor Green

            # Auto-Compile dengan MetaEditor jika ada
            if (Test-Path $METAEDITOR_PATH) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⚙️ Meng-compile EA otomatis (.ex5)..." -ForegroundColor Cyan
                Start-Process -FilePath $METAEDITOR_PATH -ArgumentList "/compile:`"$TARGET_FILE`"" -NoNewWindow -Wait
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ SUKSES AUTO-COMPILE! EA siap dipakai tanpa restart!" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "⚠️ Gagal cek update: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Cek update setiap 30 detik
    Start-Sleep -Seconds 30
}
