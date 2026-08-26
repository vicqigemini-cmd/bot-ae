# 🧠 XAUUSD Apex Pure Profit Sovereign Master (v8.00)

Sistem Trading Otomatis Hybrid Canggih Emas (XAUUSD) untuk MetaTrader 5 dengan arsitektur **Dual-Engine (M1 Pure Scalping + H4 Swing Mastery)** dan **OTA Cloud Auto-Sync**.

---

## 🚀 Panduan Pemasangan Cepat (Hanya Gunakan File `.ex5`):

### Langkah 1: Unduh File EA
* Unduh file biner terenkripsi: **[`XAUUSD_AI_Brain_EA.ex5`](./XAUUSD_AI_Brain_EA.ex5)**

### Langkah 2: Pasang ke MetaTrader 5
1. Buka MetaTrader 5 di PC / Laptop / VPS Anda.
2. Klik menu **File** ➡️ **Open Data Folder**.
3. Buka folder **`MQL5`** ➡️ **`Experts`**.
4. Salin / Paste file **`XAUUSD_AI_Brain_EA.ex5`** ke dalam folder `Experts` tersebut.
5. Kembali ke MT5, pada jendela *Navigator* (kiri), klik kanan **Expert Advisors** ➡️ klik **Refresh**.

### Langkah 3: Beri Izin WebRequest (Untuk Cloud Auto-Sync & Discord)
1. Di MetaTrader 5, tekan **`Ctrl + O`** (Menu **Tools** ➡️ **Options**).
2. Pilih tab **Expert Advisors**.
3. Centang **`Allow Algo Trading`**.
4. Centang **`Allow WebRequest for listed URL`**.
5. Tambahkan 2 URL berikut:
   * `https://raw.githubusercontent.com`
   * `https://discord.com`
6. Klik **OK**.

### Langkah 4: Jalankan Bot di Chart
1. Buka chart **XAUUSD / GOLD** pada Timeframe **M1** (atau M5).
2. Drag & Drop **`XAUUSD_AI_Brain_EA`** dari Navigator ke chart.
3. Di tab *Common*, pastikan **Allow Algo Trading** tercentang.
4. Klik **OK** dan pastikan tombol **Algo Trading** di toolbar atas menyala (Hijau).

---

## ⚡ Fitur Utama v8.00 Pure Profit:
* 🚀 **Pure Profit Scalp M1:** Target TP penuh (+22 pips / RR 1:1.83) tanpa Break-Even prematur yang mencekik.
* 🛡️ **Wide-Angle Trailing Stop:** Mengunci profit saat harga sudah melesat tebal $\ge +15	ext{ pips}$.
* 🌊 **Swing Runner H4:** Rasio 1:3 Institusional (TP1 +80 pips lock + TP2 +240 pips Mega Runner).
* 🧺 **Basket Take-Profit Grid:** Penutupan serentak 3 layer saat total akumulasi cuan $\ge +\$5.00$.
* ☁️ **OTA Cloud Auto-Sync:** Konfigurasi & parameter otomatis tersinkronisasi 24/7 dari cloud GitHub.
