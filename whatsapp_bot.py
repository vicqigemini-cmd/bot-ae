# ==============================================================================
#  📱 WHATSAPP MULTI-GROUP BROADCASTER & DISPATCHER ENGINE
#  Mendukung pengiriman terpisah ke berbagai Grup WhatsApp & Komunitas Berbeda
# ==============================================================================

import requests
import json
import logging
from config import (
    WHATSAPP_TOKEN,
    WA_TARGET_BERITA,
    WA_TARGET_SWING,
    WA_TARGET_BSJP,
    WA_TARGET_EA,
    WA_TARGET_ADMIN,
    ENABLE_WHATSAPP
)

logger = logging.getLogger(__name__)

FONNTE_API_URL = "https://api.fonnte.com/send_message"

def send_whatsapp(target: str, message: str) -> bool:
    """
    Mengirim pesan WhatsApp ke target tertentu (Nomor HP / ID Grup).
    Menggunakan standard Fonnte / Universal WhatsApp Gateway API.
    """
    if not ENABLE_WHATSAPP or not WHATSAPP_TOKEN or not target:
        logger.info(f"[WHATSAPP SKIP] Target: {target} (Token atau target kosong/fitur nonaktif)")
        return False

    headers = {
        "Authorization": WHATSAPP_TOKEN
    }
    payload = {
        "target": target,
        "message": message,
        "countryCode": "62"
    }

    try:
        response = requests.post(FONNTE_API_URL, headers=headers, data=payload, timeout=10)
        if response.status_code == 200:
            logger.info(f"✅ [WHATSAPP SENT] Berhasil dikirim ke target: {target}")
            return True
        else:
            logger.error(f"❌ [WHATSAPP FAILED] Status {response.status_code}: {response.text}")
            return False
    except Exception as e:
        logger.error(f"❌ [WHATSAPP ERROR] Gagal mengirim pesan ke {target}: {e}")
        return False

def broadcast_berita_wa(title: str, summary: str, sentiment: str, source_url: str, ticker: str = ""):
    """Kirim berita / keterbukaan informasi BEI & OJK ke Grup Berita"""
    emoji_sentiment = "🟢 POSITIF" if sentiment == "POSITIF" else "🔴 NEGATIF" if sentiment == "NEGATIF" else "⚪ NETRAL"
    ticker_tag = f"#{ticker} " if ticker else ""

    pesan = (
        f"📢 *[SENTINEL NEWS] BERITA & EMITEN TERKINI*\n"
        f"--------------------------------------------------\n"
        f"🏷️ *Sentimen:* {emoji_sentiment}\n"
        f"📌 *Judul:* {ticker_tag}{title}\n\n"
        f"📝 *Ringkasan:* {summary}\n"
        f"🔗 *Sumber:* {source_url}\n"
        f"--------------------------------------------------\n"
        f"🤖 _Sentinel IDX AI Multi-Channel Engine_"
    )
    return send_whatsapp(WA_TARGET_BERITA, pesan)

def broadcast_swing_wa(recommendations: list):
    """Kirim rekomendasi saham Swing ke Grup Saham Swing (08:00 WIB)"""
    if not recommendations:
        return

    items_text = ""
    for idx, item in enumerate(recommendations, 1):
        items_text += (
            f"\n*{idx}. {item.get('ticker', 'EMITEN')}* - Skor: *{item.get('score', 80)}/100*\n"
            f"   • *Kategori:* {item.get('category', 'PRIORITAS')}\n"
            f"   • *Area Entry:* {item.get('entry', '-')}\n"
            f"   • *Target TP:* {item.get('tp', '-')}\n"
            f"   • *Stop Loss:* {item.get('sl', '-')}\n"
            f"   • *Katalis:* {item.get('catalyst', '-')}\n"
        )

    pesan = (
        f"📈 *[SENTINEL SWING] REKOMENDASI SAHAM PAGI (08:00 WIB)*\n"
        f"--------------------------------------------------\n"
        f"Daftar saham potensial berbasis Analisis Katalis 14 Hari:\n"
        f"{items_text}"
        f"--------------------------------------------------\n"
        f"💡 _Disclaimer On • Analisis Risiko & Money Management Prioritas Utama_"
    )
    return send_whatsapp(WA_TARGET_SWING, pesan)

def broadcast_bsjp_wa(recommendations: list):
    """Kirim rekomendasi saham BSJP ke Grup Saham Sore (14:00 WIB)"""
    if not recommendations:
        return

    items_text = ""
    for idx, item in enumerate(recommendations, 1):
        items_text += (
            f"\n*{idx}. {item.get('ticker', 'EMITEN')}* - Skor: *{item.get('score', 85)}/100*\n"
            f"   • *Area Beli Sore:* {item.get('entry', '-')}\n"
            f"   • *Target Jual Pagi:* {item.get('tp', '-')}\n"
            f"   • *Batas Cut Loss:* {item.get('sl', '-')}\n"
            f"   • *Trigger Volume:* {item.get('trigger', 'Akumulasi Asing & Breakout')}\n"
        )

    pesan = (
        f"⚡ *[SENTINEL BSJP] REKOMENDASI BELI SORE JUAL PAGI (14:00 WIB)*\n"
        f"--------------------------------------------------\n"
        f"Screener saham siap lonjak untuk sesi penutupan sore:\n"
        f"{items_text}"
        f"--------------------------------------------------\n"
        f"💡 _Beli di sesi 2 (14:00 - 15:50 WIB) dan pasang antrean jual di pembukaan besok pagi!_"
    )
    return send_whatsapp(WA_TARGET_BSJP, pesan)

def broadcast_ea_trade_wa(action: str, symbol: str, lot: float, price: float, sl: float, tp: float, conf: float, pnl: float = 0.0, balance: float = 0.0):
    """Kirim notifikasi Open/Close Order EA Gold MT5 ke Grup Trading EA"""
    if action in ["OPEN_BUY", "OPEN_SELL"]:
        tipe = "🟢 BUY" if "BUY" in action else "🔴 SELL"
        pesan = (
            f"🧠 *[AI NEURAL SCALPER] ORDER DIEKSEKUSI*\n"
            f"--------------------------------------------------\n"
            f"🏷️ *Order:* {tipe} {symbol} (*{lot:.2f} Lot*)\n"
            f"🎯 *AI Confidence:* *{conf*100:.1f}%* 🔥\n"
            f"🎯 *Harga Open:* `{price:.2f}`\n"
            f"🛡️ *Stop Loss:* `{sl:.2f}`\n"
            f"🎯 *Take Profit:* `{tp:.2f}`\n"
            f"💰 *Saldo Akun:* `${balance:.2f}`\n"
            f"--------------------------------------------------\n"
            f"🤖 _XAUUSD AI-Brain Institutional v3.55_"
        )
    else: # CLOSE ORDER
        result = "🟢 PROFIT CUAN" if pnl >= 0 else "🔴 LOSS TERKENDALI"
        sign = "+$" if pnl >= 0 else "-$"
        pesan = (
            f"🏁 *[AI SCALPER] POSISI SELESAI DITUTUP*\n"
            f"--------------------------------------------------\n"
            f"📊 *Hasil:* *{result}*\n"
            f"💵 *Realized PnL:* *{sign}{abs(pnl):.2f}*\n"
            f"🏦 *Saldo Akun Terkini:* *`${balance:.2f}`*\n"
            f"🏷️ *Simbol:* {symbol} ({lot:.2f} Lot)\n"
            f"🎯 *Harga Close:* `{price:.2f}`\n"
            f"--------------------------------------------------\n"
            f"🤖 _Sentinel Trading Auto-Manager_"
        )
    return send_whatsapp(WA_TARGET_EA, pesan)
