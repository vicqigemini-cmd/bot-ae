# ⚡ SCALPING TRADING MASTERY (XAUUSD & FOREX)

Panduan strategi trading scalping profesional dan arsitektur Expert Advisor (EA):

## 🧭 1. Framework Multi-Timeframe
- **Bias Tren (M15):** EMA 20 vs EMA 50
- **Trigger Entry (M1):** EMA 9 vs EMA 21 Crossover + RSI Momentum 45–75

## 🎯 2. Manajemen Risiko & Auto-Lot
- **Formula Auto-Lot:** `$100 Saldo = 0.01 Lot` (Proporsional Compounding)
- **Stop Loss:** `15 Pips` | **Take Profit:** `30 Pips` (RRR 1:2)
- **Trailing Stop:** Mulai saat profit `+10 Pips`, step `5 Pips`

## ☁️ 3. OTA Cloud Auto-Sync
- EA terhubung langsung ke `ea_cloud_config.json` di GitHub sehingga parameter otomatis ter-update di RDP tanpa perlu compile ulang.
