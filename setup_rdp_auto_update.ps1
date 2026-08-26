# ==============================================================================
# 👑 APEX SOVEREIGN CITADEL - RDP AUTO-UPDATE & AUTO-RESTART ENGINE (v25.00)
# ==============================================================================
# Script ini secara otomatis:
# 1. Mendeteksi proses MT5 yang sedang berjalan.
# 2. Menutup MT5 secara aman agar file biner tidak terkunci.
# 3. Mengunduh biner EA v25.00 terbaru dari GitHub.
# 4. Membersihkan cache lama Tester (.tst).
# 5. Menyalakan kembali MetaTrader 5 secara otomatis dengan versi terbaru!
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$RepoUrl = "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main"
$Ex5Url  = "$RepoUrl/XAUUSD_AI_Brain_EA.ex5"
$Mq5Url  = "$RepoUrl/XAUUSD_AI_Brain_EA.mq5"

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " 🏛️  APEX AUTO-UPDATE & RESTART ENGINE (v25.00) 🚀" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Cari path terminal MT5 dan tutup jika sedang berjalan
$proc = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue | Select-Object -First 1
$terminalExe = if ($proc) { $proc.Path } else { "C:\Program Files\MetaTrader 5\terminal64.exe" }

if ($proc) {
    Write-Host "🔄 Menutup MetaTrader 5 untuk menimpa file biner..." -ForegroundColor Yellow
    Stop-Process -Name "terminal64" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# 2. Pasang EA terbaru ke seluruh folder MT5
$TerminalBase = "$env:APPDATA\MetaQuotes\Terminal"
$TargetFolders = @()

if (Test-Path $TerminalBase) {
    $Terminals = Get-ChildItem -Path $TerminalBase -Directory
    foreach ($t in $Terminals) {
        $expertsPath = Join-Path $t.FullName "MQL5\Experts"
        if (Test-Path $expertsPath) {
            $TargetFolders += $expertsPath
        }
        # Bersihkan cache tester
        $cachePath = Join-Path $t.FullName "Tester\cache"
        if (Test-Path $cachePath) {
            Remove-Item -Path ($cachePath + "\*") -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}

if ($TargetFolders.Count -eq 0) {
    $CommonPaths = @("C:\Program Files\MetaTrader 5\MQL5\Experts", "C:\Program Files (x86)\MetaTrader 5\MQL5\Experts")
    foreach ($p in $CommonPaths) {
        if (Test-Path $p) { $TargetFolders += $p }
    }
}

Write-Host "📥 Mengunduh dan memasang EA v25.00 terbaru..." -ForegroundColor Cyan
foreach ($f in $TargetFolders) {
    $dstEx5 = Join-Path $f "XAUUSD_AI_Brain_EA.ex5"
    $dstMq5 = Join-Path $f "XAUUSD_AI_Brain_EA.mq5"
    try {
        Invoke-WebRequest -Uri $Ex5Url -OutFile $dstEx5 -UseBasicParsing
        Invoke-WebRequest -Uri $Mq5Url -OutFile $dstMq5 -UseBasicParsing
        $item = Get-Item $dstEx5
        Write-Host "   ✅ Sukses terpasang di: $f ($([math]::Round($item.Length/1KB, 1)) KB)" -ForegroundColor Green
    }
    catch {
        Write-Host "   ❌ Gagal pasang ke $f : $_" -ForegroundColor Red
    }
}

# 3. Nyalakan kembali MetaTrader 5 otomatis
if (Test-Path $terminalExe) {
    Write-Host ""
    Write-Host "🚀 Menyalakan kembali MetaTrader 5 dengan versi v25.00..." -ForegroundColor Green
    Start-Process -FilePath $terminalExe
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " 🎉 UPDATE & RESTART SUKSES! MT5 KINI BERJALAN DENGAN v25.00! 👑" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""
