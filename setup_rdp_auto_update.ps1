# ==============================================================================
# 👑 APEX SOVEREIGN CITADEL - RDP 1-CLICK AUTO-UPDATE BOOTSTRAPPER (v23.00)
# ==============================================================================
# Script ini secara otomatis:
# 1. Mendeteksi seluruh direktori instalasi MT5 di RDP / VPS Anda.
# 2. Mengunduh binary biner EA v23.00 terbaru langsung dari GitHub.
# 3. Mendaftarkan Windows Scheduled Task background sync 24/7 (setiap 5 menit).
# ==============================================================================

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " 🏛️  APEX SOVEREIGN CITADEL: RDP AUTO-UPDATE INSTALLER v23.00 🚀" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$RepoUrl = "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main"
$Ex5Url  = "$RepoUrl/XAUUSD_AI_Brain_EA.ex5"
$Mq5Url  = "$RepoUrl/XAUUSD_AI_Brain_EA.mq5"

# 1. Cari seluruh folder data MT5 di AppData
$TerminalBase = "$env:APPDATA\MetaQuotes\Terminal"
$TargetFolders = @()

if (Test-Path $TerminalBase) {
    $Terminals = Get-ChildItem -Path $TerminalBase -Directory
    foreach ($t in $Terminals) {
        $expertsPath = Join-Path $t.FullName "MQL5\Experts"
        if (Test-Path $expertsPath) {
            $TargetFolders += $expertsPath
        }
    }
}

if ($TargetFolders.Count -eq 0) {
    # Coba cari di folder Program Files jika portabel
    Write-Host "🔍 Mencari direktori terminal MT5 alternatif..." -ForegroundColor Yellow
    $CommonPaths = @(
        "C:\Program Files\MetaTrader 5\MQL5\Experts",
        "C:\Program Files (x86)\MetaTrader 5\MQL5\Experts"
    )
    foreach ($p in $CommonPaths) {
        if (Test-Path $p) { $TargetFolders += $p }
    }
}

if ($TargetFolders.Count -eq 0) {
    Write-Host "⚠️ Tidak menemukan folder MetaTrader 5 secara otomatis." -ForegroundColor Red
    Write-Host "Pastikan MetaTrader 5 sudah pernah dibuka minimal sekali di RDP ini." -ForegroundColor Yellow
    return
}

Write-Host "✅ Ditemukan $($TargetFolders.Count) folder Experts MT5:" -ForegroundColor Green
foreach ($f in $TargetFolders) {
    Write-Host "   📂 $f" -ForegroundColor Gray
}

# 2. Unduh dan pasang EA terbaru
Write-Host ""
Write-Host "📥 Mengunduh EA versi v23.00 terbaru dari GitHub..." -ForegroundColor Cyan

foreach ($f in $TargetFolders) {
    $dstEx5 = Join-Path $f "XAUUSD_AI_Brain_EA.ex5"
    $dstMq5 = Join-Path $f "XAUUSD_AI_Brain_EA.mq5"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Ex5Url -OutFile $dstEx5 -UseBasicParsing
        Invoke-WebRequest -Uri $Mq5Url -OutFile $dstMq5 -UseBasicParsing
        
        $item = Get-Item $dstEx5
        Write-Host "   ✅ Sukses terpasang di: $f ($([math]::Round($item.Length/1KB, 1)) KB)" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Gagal mengunduh ke $f : $_" -ForegroundColor Red
    }
}

# 3. Buat script sync background permanen
$SyncScriptPath = "$env:USERPROFILE\.apex_auto_sync.ps1"
$SyncScriptContent = @"
`$RepoUrl = "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main"
`$Ex5Url  = "`$RepoUrl/XAUUSD_AI_Brain_EA.ex5"
`$TerminalBase = "`$env:APPDATA\MetaQuotes\Terminal"

if (Test-Path `$TerminalBase) {
    `$Terminals = Get-ChildItem -Path `$TerminalBase -Directory
    foreach (`$t in `$Terminals) {
        `$expertsPath = Join-Path `$t.FullName "MQL5\Experts"
        if (Test-Path `$expertsPath) {
            `$dstEx5 = Join-Path `$expertsPath "XAUUSD_AI_Brain_EA.ex5"
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri `$Ex5Url -OutFile `$dstEx5 -UseBasicParsing -TimeoutSec 15
            } catch {}
        }
    }
}
"@

Set-Content -Path $SyncScriptPath -Value $SyncScriptContent -Force
Write-Host ""
Write-Host "💾 Script Background Sync disimpan di: $SyncScriptPath" -ForegroundColor Green

# 4. Daftarkan Windows Scheduled Task (Berjalan otomatis setiap 5 menit 24/7)
$TaskName = "Apex_EA_AutoSync"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SyncScriptPath`""
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

try {
    # Hapus task lama jika ada
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Otomatis mengunduh rilis EA terbaru dari GitHub vicqigemini-cmd/bot-ae" | Out-Null
    Write-Host "🏆 Windows Scheduled Task [$TaskName] AKTIF (Sync otomatis setiap 5 menit)!" -ForegroundColor Green
}
catch {
    Write-Host "ℹ️ Registrasi task: Jalankan PowerShell sebagai Administrator untuk mengaktifkan scheduled task 5 menit." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " 🎉 INSTALASI SELESAI! EA v23.00 TELAH TERPASANG & SIAP AUTO-UPDATE! 👑" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""
