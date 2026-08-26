# 🤖 Expert Advisor MetaTrader (Bot AE)

Repository khusus untuk **Expert Advisor (EA) MetaTrader 4 & MetaTrader 5** dengan integrasi notifikasi real-time ke **Discord Webhook Pribadi**.

---

## 📁 Daftar File:
- [`Discord_Sentinel_EA_MT5.mq5`](./Discord_Sentinel_EA_MT5.mq5) : Expert Advisor untuk **MetaTrader 5 (MT5)**.
- [`Discord_Sentinel_EA_MT4.mq4`](./Discord_Sentinel_EA_MT4.mq4) : Expert Advisor untuk **MetaTrader 4 (MT4)**.

---

## ⚡ Fitur Utama EA:
1. **Strategi Trend Following & RSI:** Eksekusi otomatis sinyal BUY/SELL berdasarkan persilangan EMA dan level RSI.
2. **Trailing Stop Otomatis:** Mengunci profit saat harga bergerak searah posisi.
3. **Notifikasi Discord Webhook:**
   - 🟢 Laporan Open BUY
   - 🔴 Laporan Open SELL
   - 💰 Laporan Profit / TP / SL
   - 📊 Status Saldo & Equity

---

## 📋 Cara Pasang di MetaTrader (RDP / PC):
1. Izinkan WebRequest di MT4/MT5: **Tools** -> **Options** -> **Expert Advisors** -> Tambahkan `https://discord.com`.
2. Copy file `.mq5` atau `.mq4` ke folder **`MQL5/Experts`** (atau `MQL4/Experts`).
3. Compile di MetaEditor atau Refresh panel Navigator di MetaTrader.
4. Pasang EA ke chart pair yang diinginkan (misal: `XAUUSD`, `EURUSD`).
