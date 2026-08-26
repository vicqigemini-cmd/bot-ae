//+------------------------------------------------------------------+
//|                                     XAUUSD_AI_Brain_EA.mq5       |
//|  APEX SOVEREIGN CITADEL & GOLDEN FIBONACCI MASTER - v12.00       |
//|  (Golden Fib Pocket • Global Kill-Switch • Mobile Push • Citadel)|
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX & AI Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "12.00"
#property description "Unified Master Brain EA v12.00 Apex Sovereign Citadel & Golden Fibonacci Edition: Golden Pocket 50-61.8% Retracement & 161.8% Extension Engine, Global Cloud Nuclear Kill-Switch, Native MT5 Mobile Push Notification, 24/7 VPS Garbage Collector & Ping Watchdog, Multi-Tier Swing Lock, Slippage Radar, Weekend Digest, Manual Guard, Prominent Fleet ID."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#define CLOUD_CONFIG_URL "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/ea_cloud_config.json"
#define CLOUD_EX5_URL "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/XAUUSD_AI_Brain_EA.ex5"

#import "kernel32.dll"
int CopyFileW(string lpExistingFileName, string lpNewFileName, int bFailIfExists);
#import


//--- Enums
enum ENUM_LOT_TYPE
{
   LOT_PER_BALANCE  = 0, // Auto-Lot Proporsional ($500 = 0.01 Lot)
   LOT_FIXED        = 1, // Fixed Lot Size (Lot Tetap)
   LOT_RISK_PERCENT = 2  // Auto Lot (% Risk dari Equity)
};

enum ENUM_MARKET_REGIME
{
   REGIME_SIDEWAYS_RANGE = 0, // Pasar Ranging / Sideways (Mean-Reversion Mode)
   REGIME_STRONG_TREND   = 1, // Pasar Trending Kuat (Momentum Breakout & Pullback Mode)
   REGIME_CHAOTIC_NOISE  = 2  // Pasar Noise Ekstrem (Standby)
};

struct STrackedPos
{
   ulong    ticket;
   string   engine_type; // "SCALP" atau "SWING"
   string   order_type;  // "BUY" atau "SELL"
   double   open_price;
   double   volume;
   datetime open_time;
};

struct SFibLevels
{
   double swing_high;
   double swing_low;
   double fib_500;
   double fib_618;      // The Golden Pocket
   double fib_786;
   double fib_1618_ext; // Institutional Extension Target
   bool   is_uptrend;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== 1. IDENTITAS AKUN & UNIQUE FINGERPRINT ID ==="
input string              InpAccountTag            = "AUTO";                // Tag Akun ("AUTO" = Otomatis ACC-[Login]-[BrokerCode], atau isi nama kustom)
input bool                InpEnableHeartbeat       = true;                  // Aktifkan Notifikasi Detak Jantung (Heartbeat Pulse)
input int                 InpHeartbeatIntervalHours= 2;                     // Interval Heartbeat ke Discord (Jam)

input group "=== 2. NOTIFIKASI DUAL-REDUNDANCY (DISCORD + MT5 HP) ==="
input string              InpDiscordWebhookURL     = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // Webhook URL Pribadi
input bool                InpEnableDiscord         = true;                  // Aktifkan Notifikasi Discord
input bool                InpEnableMobilePush      = true;                  // Kirim Push Notification ke Aplikasi MT5 HP (iPhone/Android)
input string              InpDiscordMention        = "";                    // Mention Role/User
input string              InpBotName               = "XAUUSD Apex Brain Master"; // Nama Bot

input group "=== 3. OTA CLOUD AUTO-SYNC & CITADEL DEFENSE ==="
input bool                InpEnableCloudSync       = true;                  // Aktifkan Sinkronisasi Cloud dari GitHub
input int                 InpSyncIntervalMin       = 5;                     // Interval Cek Update Cloud (Menit)

input group "=== 4. ENGINE 1: SCALPING M1 (MICRO-FIBONACCI SNIPER) ==="
input bool                InpEnableScalpingEngine  = true;                  // Aktifkan Mesin Scalping M1
input ulong               InpMagicScalp            = 202611;                // Magic Number Scalping
input string              InpCommentScalp          = "Apex_Scalp";          // Label Order Scalping
input bool                InpUseMicroFibScalp      = true;                  // Micro-Fibonacci Retracement 50-61.8% Filter M1
input bool                InpScalpUseBE            = false;                 // Break-Even Cepat (False = Pure Target TP Bebas Nafas)
input int                 InpScalpBaseSLPoints     = 120;                   // Base SL Scalping (Points, 120 pts = 12 pips)
input int                 InpScalpBaseTPPoints     = 220;                   // Base TP Scalping (Points, 220 pts = 22 pips / RR 1:1.83)
input bool                InpScalpUseTrailing      = true;                  // Trailing Stop Tebal Scalping
input int                 InpScalpTrailingStart    = 150;                   // Trailing Start Scalp (+15 pips baru jalan)
input int                 InpScalpTrailingDist     = 70;                    // Jarak Trailing Scalp (Points, 70 pts = 7 pips)
input int                 InpScalpTrailingStep     = 15;                    // Step Trailing Scalp (Points)
input bool                InpUseBasketTakeProfit   = true;                  // Basket TP (Tutup Seluruh Layer Serentak saat Total Surplus)
input double              InpBasketProfitUSD       = 5.0;                   // Target Cuan Basket TP ($5.00 Bersih)
input bool                InpUseMacroBiasBooster   = true;                  // Macro-Confluence Bias Booster (Sinergi H4 ke M1)
input bool                InpUseTickVelocityGuard  = true;                  // Tick Velocity Speedometer (Anti-Flash Crash)
input bool                InpUseAdaptiveVWAP       = true;                  // Session-Adaptive VWAP Bands (Asia/London/NY)
input bool                InpUseRegimeSwitching    = true;                  // Auto-Switch Strategi (Pullback vs Mean Reversion)
input bool                InpUseAsianSweepTrap     = true;                  // Perangkap Asian Liquidity Sweep (Sesi London)
input bool                InpUseTripleScreen       = false;                 // Triple-Screen Filter M15 (False = Bebas Scalp Cepat)
input int                 InpMaxOpenScalp          = 3;                     // Max Posisi Scalping Aktif (Tri-Layer Sweet Spot)
input int                 InpMinLayerDistancePts   = 30;                    // Jarak Minimal Dasar Antar Layer (Points, 30 pts = 3 pips)
input bool                InpUseAdaptiveGrid       = true;                  // Volatility-Adaptive Grid Spacing (Melebar Otomatis saat Badai)
input double              InpMinMarginLevelForGrid = 400.0;                 // Proteksi Margin Level Minimal untuk Layer 2 & 3 (%)

input group "=== 5. ENGINE 2: SWING RUNNER H4 (GOLDEN FIBONACCI POCKET) ==="
input bool                InpEnableSwingEngine     = true;                  // Aktifkan Mesin Swing H4
input ulong               InpMagicSwing            = 202622;                // Magic Number Swing
input string              InpCommentSwing          = "Apex_Swing";          // Label Order Swing
input bool                InpUseGoldenFibPocket    = true;                  // Golden Pocket 50.0%-61.8% Fibonacci Swing Entry
input bool                InpUseDualTicketSwing    = true;                  // Dual-Ticket Scaling Out (TP1 Lock + TP2 Runner)
input double              InpSwingFixedLot         = 0.01;                  // Fixed Lot Size per Sub-Tiket Swing
input double              InpSwingMinADX           = 20.0;                  // Filter Kekuatan Tren Minimal (ADX H4 >= 20)
input int                 InpSwingMaxChasePts      = 250;                   // Jarak Maksimal dari EMA21 H1 (Anti-Late Chase, 25 pips)
input int                 InpSwingSLPoints         = 800;                   // SL Swing Institusional (800 pts = 80 pips / $8 Gold)
input int                 InpSwingTP1Points        = 800;                   // TP1 Quick Cuan (+80 pips untuk kunci modal)
input int                 InpSwingTP2RunnerPoints  = 2400;                  // TP2 Mega Runner (+240 pips / RR 1:3)
input bool                InpUseMultiTierSwingLock = true;                  // Multi-Tier Profit Lock (+120 pips -> Kunci +50 pips)
input int                 InpSwingBEProfitPoints   = 100;                   // Kunci Profit BE Swing (+10 pips)
input bool                InpSwingUseTrailing      = true;                  // Trailing Stop Jarak Jauh Swing
input int                 InpSwingTrailingStart    = 1500;                  // Trailing Start Swing (+150 pips)
input int                 InpSwingTrailingDist     = 700;                   // Jarak Trailing Swing (70 pips)
input int                 InpSwingTrailingStep     = 200;                   // Step Trailing Swing (20 pips)
input bool                InpSwingHoldWeekendIfBE  = true;                  // Izinkan Swing Menginap Weekend jika SL sudah BE (Risk-Free)
input bool                InpUseTripleSwapGuard    = true;                  // Proteksi Triple-Swap Rabu Malam (23:00 Server)

input group "=== 6. PERISAI PENGAMAN, MANUAL GUARD & WEEKEND DIGEST ==="
input bool                InpUseManualTradeGuard   = true;                  // Manual Entry Guard (Jeda Otomatis EA jika Ada Trade Manual)
input bool                InpEnableWeekendDigest   = true;                  // Kirim Laporan Rekapitulasi Mingguan Setiap Sabtu Pagi
input ENUM_LOT_TYPE       InpLotType               = LOT_PER_BALANCE;       // Mode Lot Sizing Scalping
input double              InpFixedLot              = 0.01;                  // Base Lot per Kelipatan
input double              InpBalanceStep           = 500.0;                 // Saldo per Kelipatan Lot ($500 = 0.01 Lot)
input double              InpRiskPercent           = 1.0;                   // Risk % per Trade Scalping
input int                 InpMaxSpreadPoints       = 80;                    // Max Spread Filter (Points)
input bool                InpUseDefendTheBag       = true;                  // Defend-The-Bag (Kunci Cuan Harian >= 8%)
input double              InpDefendBagProfitPct    = 8.0;                   // Ambang Defend-The-Bag (% Wallet Pangkas 50% Lot)
input bool                InpUseWeeklyBagDefender  = true;                  // Weekly Bag Defender (Kunci Cuan Mingguan >= 20%)
input double              InpWeeklyBagProfitPct    = 20.0;                  // Ambang Cuan Mingguan Pangkas 50% Lot (% Wallet)
input bool                InpUseRedNewsGuard       = true;                  // Perisai Berita Merah AS (CPI, NFP, FOMC)
input int                 InpNewsBufferMin         = 15;                    // Jeda Menit Sebelum & Sesudah Berita Merah
input bool                InpUseFridayAutoClean    = true;                  // Bersihkan Posisi Scalp Jumat Malam (21:00 Server)
input bool                InpUseLossCircuitBreaker = true;                  // Rem Pengaman Rugi Beruntun (2x SL = Cooldown Cepat)
input int                 InpLossCooldownMinutes   = 5;                     // Durasi Rem Cooldown (HANYA 5 MENIT CEPAT)
input bool                InpUseDirectionalLock    = true;                  // Kunci 1 Arah Scalp (Haram Hedging saat Layer Aktif)
input bool                InpUseRolloverGuard      = true;                  // Pelindung Jam Rollover Broker (23:50-01:10)
input bool                InpUseDailyGuard         = false;                 // Aktifkan Pengaman Target Harian
input double              InpDailyTargetPercent    = 15.0;                  // Target Profit Harian (15% dari Total Wallet)
input double              InpDailyMaxLossPercent   = 15.0;                  // Batas Rem Rugi Harian (15% dari Total Wallet)


input group "=== 7. INSTITUTIONAL SMC, TRUE-BE & PROP FIRM ALPHA ==="
input bool                InpUseFVGFilter          = true;                  // Institutional Fair Value Gap (FVG M15/H1 Retest)
input bool                InpUseTrueZeroLossBE     = true;                  // True Zero-Loss Commission & Swap-Aware Breakeven
input int                 InpTrueBEExtraBufferPts  = 5;                     // Buffer Tambahan True-BE (Points)
input bool                InpUseScalpPartialClose  = true;                  // 2-Stage Scalp Partial Close (Ambil 50% Lot di +12 pips)
input int                 InpScalpPartialPoints    = 120;                   // Titik Partial Close Scalping (+12 pips)
input bool                InpUsePropFirmGuard      = true;                  // Prop Firm High-Watermark Drawdown Guard
input double              InpPropFirmMaxDailyDDPct = 4.0;                   // Max Daily Trailing Drawdown dari Peak Equity (%)
input bool                InpUseMTFConfluenceScore = true;                  // Multi-Timeframe Confluence Score Matrix (M1/M15/H1/H4)
input int                 InpMinConfluenceScore    = 80;                    // Minimum Skor Konfluensi untuk Eksekusi (0-100)

//--- High-Watermark & Prop Firm Variables
double g_daily_peak_equity    = 0.0;
datetime g_last_peak_day      = 0;
bool g_prop_firm_locked       = false;

struct SFairValueGap
{
   bool   exists;
   bool   is_bullish;
   double upper_level;
   double lower_level;
   datetime time_created;
};
SFairValueGap g_cached_m15_fvg;
datetime g_last_fvg_calc_time = 0;

//--- Dynamic Runtime Cloud Variables
string                    g_current_version        = "12.00";
double                    g_balance_step           = 500.0;
double                    g_lot_step               = 0.01;
int                       g_sl_points              = 120;
int                       g_tp_points              = 220;
int                       g_max_spread             = 80;
int                       g_max_open_pos           = 3;
int                       g_min_layer_dist         = 30;
bool                      g_use_trailing           = true;
int                       g_trailing_start         = 150;
int                       g_trailing_dist          = 70;
int                       g_trailing_step          = 15;
bool                      g_use_daily_guard        = false;
double                    g_daily_target_pct       = 15.0;
double                    g_daily_max_loss_pct     = 15.0;
int                       g_loss_cooldown_min      = 5;
bool                      g_emergency_kill_active  = false;

//--- Global Handles & Objects
CTrade                    m_trade;
CPositionInfo             m_position;
CSymbolInfo               m_symbol;
CAccountInfo              m_account;

//--- Indicator Handles M1 (Scalping)
int handle_ema5_m1    = INVALID_HANDLE;
int handle_ema13_m1   = INVALID_HANDLE;
int handle_stoch_m1   = INVALID_HANDLE;
int handle_bb_m1      = INVALID_HANDLE;
int handle_atr_m1     = INVALID_HANDLE;
int handle_ema50_m15  = INVALID_HANDLE;

//--- Indicator Handles H4/H1 (Swing Mastery)
int handle_ema50_h4   = INVALID_HANDLE;
int handle_ema200_h4  = INVALID_HANDLE;
int handle_rsi_h4     = INVALID_HANDLE;
int handle_adx_h4     = INVALID_HANDLE;
int handle_ema21_h1   = INVALID_HANDLE;
int handle_atr_h4     = INVALID_HANDLE;

datetime last_scalp_time = 0;
datetime last_swing_time = 0;
datetime m_last_cloud_sync_time = 0;
datetime g_last_heartbeat_time = 0;
datetime g_cooldown_until = 0;
datetime g_last_weekend_digest_date = 0;
int      g_consecutive_losses = 0;

//--- MANUAL ENTRY INTERVENTION GUARD STATE
bool     g_manual_trade_pause = false;
ulong    g_detected_manual_ticket = 0;

//--- ZERO-BOTTLENECK CACHE ENGINE
datetime g_last_vwap_calc_time = 0;
double   g_cached_vwap = 0.0;
double   g_cached_vwap_up = 0.0;
double   g_cached_vwap_low = 0.0;

datetime g_last_pnl_calc_time = 0;
double   g_cached_daily_pnl = 0.0;

datetime g_last_news_check_time = 0;
bool     g_cached_is_news_time = false;

double   g_asian_high = 0.0;
double   g_asian_low  = 0.0;
datetime g_asian_date = 0;
datetime g_last_asian_calc_time = 0;

datetime g_last_swing_eval_time = 0;

//--- FIBONACCI RUNTIME CACHE
datetime g_last_fib_calc_time = 0;
SFibLevels g_cached_h4_fib;

//--- TICK VELOCITY SPEEDOMETER
datetime g_velocity_pause_until = 0;
datetime g_last_tick_time = 0;
double   g_last_tick_bid = 0.0;

STrackedPos g_tracked_positions[];
ulong g_notified_deals[];

//--- Account Metadata Cache (Unique Fingerprint ID)
string g_account_tag    = "";
long   g_account_login  = 0;

//+------------------------------------------------------------------+
//| HELPER: GENERATE CLEAN SHORT BROKER CODE                         |
//+------------------------------------------------------------------+
string GetCleanBrokerCode()
{
   string company = AccountInfoString(ACCOUNT_COMPANY);
   string server  = AccountInfoString(ACCOUNT_SERVER);
   StringToUpper(company);
   StringToUpper(server);

   if(StringFind(company, "IC MARKETS") != -1 || StringFind(server, "ICMARKETS") != -1) return "ICM";
   if(StringFind(company, "EXNESS") != -1 || StringFind(server, "EXNESS") != -1) return "EXN";
   if(StringFind(company, "XM") != -1 || StringFind(server, "XMGLOBAL") != -1) return "XM";
   if(StringFind(company, "OCTA") != -1 || StringFind(server, "OCTAFX") != -1) return "OCTA";
   if(StringFind(company, "FBS") != -1 || StringFind(server, "FBS") != -1) return "FBS";
   if(StringFind(company, "VANTAGE") != -1 || StringFind(server, "VANTAGE") != -1) return "VTG";
   if(StringFind(company, "PEPPERSTONE") != -1 || StringFind(server, "PEPPERSTONE") != -1) return "PEP";
   if(StringFind(company, "FOREX.COM") != -1 || StringFind(server, "FOREX") != -1) return "FXC";
   if(StringFind(company, "HFM") != -1 || StringFind(company, "HOTFOREX") != -1) return "HFM";
   if(StringFind(company, "PU PRIME") != -1 || StringFind(server, "PUPRIME") != -1) return "PUP";

   string clean = "";
   for(int i = 0; i < StringLen(company); i++)
   {
      ushort ch = StringGetCharacter(company, i);
      if((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'))
      {
         StringAdd(clean, ShortToString(ch));
         if(StringLen(clean) >= 3) break;
      }
   }
   if(clean == "") clean = "MT5";
   return clean;
}

//+------------------------------------------------------------------+
//| HELPER: GENERATE UNIQUE FINGERPRINT ID (ACC-[LOGIN]-[BROKER])    |
//+------------------------------------------------------------------+
void InitAccountMetadata()
{
   g_account_login = AccountInfoInteger(ACCOUNT_LOGIN);

   string tag = InpAccountTag;
   StringTrimLeft(tag);
   StringTrimRight(tag);

   if(tag == "" || tag == "AUTO" || tag == "ACC-01")
   {
      string broker_code = GetCleanBrokerCode();
      g_account_tag = StringFormat("ACC-%d-%s", g_account_login, broker_code);
   }
   else
   {
      g_account_tag = tag;
   }
}

//+------------------------------------------------------------------+
//| RECOVER CONSECUTIVE LOSS STATE (5-MINUTE COOLDOWN)               |
//+------------------------------------------------------------------+
void RecoverConsecutiveLossesFromHistory()
{
   datetime start_of_day = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00");
   HistorySelect(start_of_day, TimeCurrent() + 60);

   int total_deals = HistoryDealsTotal();
   int consecutive = 0;

   for(int i = total_deals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         long deal_entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);

         if((deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY) &&
            (deal_magic == InpMagicScalp || deal_magic == 0))
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            if(profit < 0)
            {
               consecutive++;
            }
            else
            {
               break;
            }
         }
      }
   }
   g_consecutive_losses = consecutive;
   if(g_consecutive_losses >= 2 && InpUseLossCircuitBreaker)
   {
      if(g_cooldown_until < TimeCurrent())
      {
         g_cooldown_until = TimeCurrent() + g_loss_cooldown_min * 60;
      }
   }
}

//+------------------------------------------------------------------+
//| HITUNG PROFIT / LOSS MINGGUAN (UNTUK WEEKLY BAG DEFENDER)        |
//+------------------------------------------------------------------+
double GetWeeklyProfitLoss()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int days_from_monday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   datetime start_of_week = StringToTime(TimeToString(now - days_from_monday * 86400, TIME_DATE) + " 00:00");
   HistorySelect(start_of_week, now + 60);

   double total_profit = 0.0;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         long deal_entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         long deal_type  = HistoryDealGetInteger(ticket, DEAL_TYPE);

         if((deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY) &&
            (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL))
         {
            total_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         }
      }
   }
   return total_profit;
}

//+------------------------------------------------------------------+
//| HELPER PARSER JSON                                               |
//+------------------------------------------------------------------+
string ExtractJsonString(string json, string key)
{
   int key_pos = StringFind(json, "\"" + key + "\"");
   if(key_pos == -1) return "";
   int colon_pos = StringFind(json, ":", key_pos);
   if(colon_pos == -1) return "";
   int quote_start = StringFind(json, "\"", colon_pos);
   if(quote_start == -1) return "";
   int quote_end = StringFind(json, "\"", quote_start + 1);
   if(quote_end == -1) return "";
   return StringSubstr(json, quote_start + 1, quote_end - quote_start - 1);
}

double ExtractJsonNumber(string json, string key, double default_val)
{
   int key_pos = StringFind(json, "\"" + key + "\"");
   if(key_pos == -1) return default_val;
   int colon_pos = StringFind(json, ":", key_pos);
   if(colon_pos == -1) return default_val;
   int comma_pos = StringFind(json, ",", colon_pos);
   int close_brace = StringFind(json, "}", colon_pos);
   int end_pos = (comma_pos != -1 && (close_brace == -1 || comma_pos < close_brace)) ? comma_pos : close_brace;
   if(end_pos == -1) end_pos = StringLen(json);
   string val_str = StringSubstr(json, colon_pos + 1, end_pos - colon_pos - 1);
   StringTrimLeft(val_str);
   StringTrimRight(val_str);
   return StringToDouble(val_str);
}

bool ExtractJsonBool(string json, string key, bool default_val)
{
   int key_pos = StringFind(json, "\"" + key + "\"");
   if(key_pos == -1) return default_val;
   int colon_pos = StringFind(json, ":", key_pos);
   if(colon_pos == -1) return default_val;
   string sub = StringSubstr(json, colon_pos + 1, 10);
   if(StringFind(sub, "true") != -1) return true;
   if(StringFind(sub, "false") != -1) return false;
   return default_val;
}

//+------------------------------------------------------------------+
//| FUNGSI PENGIRIM DISCORD WEBHOOK & MOBILE PUSH                    |
//+------------------------------------------------------------------+
void SendDiscordEmbed(string title, string description, int color_hex, string fields_json, bool is_critical=false)
{
   if(!InpEnableDiscord || InpDiscordWebhookURL == "") return;

   string content_header = "";
   if(is_critical && InpDiscordMention != "")
   {
      content_header = "\"content\": \"🚨 " + InpDiscordMention + " — **[" + g_account_tag + " ALERT]**\", ";
   }

   string bot_name_with_tag = InpBotName + " [" + g_account_tag + "]";

   string payload = "{" + content_header +
                    "\"username\": \"" + bot_name_with_tag + "\"," +
                    "\"embeds\": [{" +
                    "\"title\": \"" + title + "\"," +
                    "\"description\": \"" + description + "\"," +
                    "\"color\": " + IntegerToString(color_hex) + "," +
                    "\"fields\": [" + fields_json + "]," +
                    "\"footer\": {\"text\": \"ID: " + g_account_tag + " • v" + g_current_version + " • " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
                    "}]}";

   char post_data[];
   char result_data[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n";

   StringToCharArray(payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post_data, ArraySize(post_data) - 1);

   ResetLastError();
   WebRequest("POST", InpDiscordWebhookURL, headers, 3000, post_data, result_data, result_headers);
}

//+------------------------------------------------------------------+
//| GLOBAL NUCLEAR KILL-SWITCH (TUTUP SEMUA POSISI DARURAT)          |
//+------------------------------------------------------------------+
void ExecuteGlobalEmergencyKillSwitch()
{
   Print("🚨 [GLOBAL NUCLEAR KILL-SWITCH] Perintah darurat diterima dari Cloud! Menutup seluruh posisi terbuka...");
   
   int closed_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            m_trade.PositionClose(m_position.Ticket());
            closed_count++;
         }
      }
   }

   string kill_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                        "{\"name\": \"🚨 Tindakan Darurat\", \"value\": \"`Global Cloud Kill-Switch Ditekan`\", \"inline\": true}," +
                        "{\"name\": \"📊 Posisi Ditutup\", \"value\": \"`" + IntegerToString(closed_count) + " Posisi Dinolkan`\", \"inline\": true}," +
                        "{\"name\": \"🏦 Saldo Diamankan\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}," +
                        "{\"name\": \"⏸️ Status Mesin\", \"value\": \"`FREEZE STANDBY (Aman Parkir)`\", \"inline\": true}";

   SendDiscordEmbed("[" + g_account_tag + "] 🚨 GLOBAL NUCLEAR KILL-SWITCH DIAKTIFKAN!", 
                    "Semua transaksi pada akun **[" + g_account_tag + "]** telah ditutup paksa secara serentak demi keamanan aset!", 
                    0xE74C3C, kill_fields, true);

   if(InpEnableMobilePush)
   {
      SendNotification(StringFormat("[%s] 🚨 GLOBAL KILL-SWITCH DIAKTIFKAN! Seluruh %d posisi ditutup aman.", g_account_tag, closed_count));
   }
}

//+------------------------------------------------------------------+
//| HITUNG PROFIT / LOSS HARIAN (100% PERSIS TAB HISTORY MT5)        |
//+------------------------------------------------------------------+
double GetDailyProfitLoss(bool force_recalc=false)
{
   datetime now = TimeCurrent();
   if(!force_recalc && (now - g_last_pnl_calc_time < 3))
   {
      return g_cached_daily_pnl;
   }

   datetime start_of_day = StringToTime(TimeToString(now, TIME_DATE) + " 00:00");
   HistorySelect(start_of_day, now + 60);
   
   double total_profit = 0.0;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         long deal_entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         long deal_type  = HistoryDealGetInteger(ticket, DEAL_TYPE);

         if((deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY) &&
            (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL))
         {
            total_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         }
      }
   }

   g_cached_daily_pnl = NormalizeDouble(total_profit, 2);
   g_last_pnl_calc_time = now;
   return g_cached_daily_pnl;
}

//+------------------------------------------------------------------+
//| MESIN AUTONOMOUS INTERNAL SELF-UPDATER (ZERO POWERSHELL)         |
//+------------------------------------------------------------------+
string g_last_self_updated_ver = "12.00";

bool PerformAutonomousSelfUpdate(string new_version)
{
   if(new_version == g_last_self_updated_ver || new_version == "" || new_version == "11.10") return false;
   
   Print("🚀 [SELF-UPDATER] Memulai proses autonomous self-update ke v" + new_version + "...");

   char post_data[];
   char result_data[];
   string result_headers;
   string headers = "User-Agent: MetaTrader5-AI-SelfUpdater\r\n";

   ResetLastError();
   int res = WebRequest("GET", CLOUD_EX5_URL, headers, 10000, post_data, result_data, result_headers);
   if(res == 200 && ArraySize(result_data) > 50000)
   {
      string temp_file_name = "XAUUSD_AI_Brain_EA_update.ex5";
      int file_handle = FileOpen(temp_file_name, FILE_WRITE|FILE_BIN);
      if(file_handle != INVALID_HANDLE)
      {
         FileWriteArray(file_handle, result_data, 0, ArraySize(result_data));
         FileClose(file_handle);
         
         string data_path = TerminalInfoString(TERMINAL_DATA_PATH);
         string src_path  = data_path + "\\MQL5\\Files\\" + temp_file_name;
         string dst_path  = data_path + "\\MQL5\\Experts\\XAUUSD_AI_Brain_EA.ex5";

         bool copy_ok = false;
         if(TerminalInfoInteger(TERMINAL_DLLS_ALLOWED))
         {
            int r = CopyFileW(src_path, dst_path, 0);
            if(r != 0) copy_ok = true;
         }

         g_last_self_updated_ver = new_version;
         Print("✅ [SELF-UPDATER] Binary EX5 v" + new_version + " berhasil diunduh & dipasang! (" + IntegerToString(ArraySize(result_data)) + " bytes)");

         string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                         "{\"name\": \"📦 Versi Baru\", \"value\": \"`v" + new_version + " (Autonomous Updated)`\", \"inline\": true}," +
                         "{\"name\": \"💾 Binary Size\", \"value\": \"`" + IntegerToString(ArraySize(result_data) / 1024) + " KB`\", \"inline\": true}," +
                         "{\"name\": \"⚡ Metode Update\", \"value\": \"`100% In-EA Zero-Touch (Tanpa PowerShell)`\", \"inline\": true}," +
                         "{\"name\": \"📂 Lokasi Terpasang\", \"value\": \"`MQL5\\\\Experts\\\\XAUUSD_AI_Brain_EA.ex5`\", \"inline\": true}," +
                         "{\"name\": \"🏛️ Status Terminal\", \"value\": \"`Aktif & Terproteksi Penuh`\", \"inline\": true}";

         SendDiscordEmbed("[" + g_account_tag + "] 🚀 AUTONOMOUS SELF-UPDATE SUKSES (v" + new_version + ")!", 
                          "EA telah berhasil mengunduh dan memperbarui file biner dirinya sendiri secara mandiri tanpa bantuan PowerShell atau aplikasi eksternal.", 
                          0x2ECC71, fields, false);

         if(InpEnableMobilePush)
         {
            SendNotification(StringFormat("[%s] 🚀 Autonomous Self-Update Berhasil ke v%s!", g_account_tag, new_version));
         }
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| FUNGSI SINKRONISASI CLOUD DARI GITHUB (CONTINUOUS SYNC)          |
//+------------------------------------------------------------------+
void FetchAndApplyCloudConfig(bool is_initial=false)
{
   if(!InpEnableCloudSync) return;

   char post_data[];
   char result_data[];
   string result_headers;
   string headers = "User-Agent: MetaTrader5-AI-EA\r\n";

   ResetLastError();
   int res = WebRequest("GET", CLOUD_CONFIG_URL, headers, 3000, post_data, result_data, result_headers);
   if(res == 200)
   {
      string json = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
      string cloud_version = ExtractJsonString(json, "version");

      bool cloud_kill = ExtractJsonBool(json, "emergency_close_all", false);
      if(cloud_kill && !g_emergency_kill_active)
      {
         g_emergency_kill_active = true;
         ExecuteGlobalEmergencyKillSwitch();
      }
      else if(!cloud_kill && g_emergency_kill_active)
      {
         g_emergency_kill_active = false;
         Print("🟢 [GLOBAL KILL-SWITCH RELEASED] Mode darurat dinonaktifkan. EA kembali berburu normal.");
      }
      
      if(cloud_version != "")
      {
         bool is_new_version = (cloud_version != g_current_version);
         bool enable_self_update = ExtractJsonBool(json, "enable_auto_self_update", true);
         if(is_new_version && enable_self_update)
         {
            PerformAutonomousSelfUpdate(cloud_version);
         }
         g_current_version    = cloud_version;
         g_balance_step       = ExtractJsonNumber(json, "balance_per_step", InpBalanceStep);
         g_lot_step           = ExtractJsonNumber(json, "lot_per_step", InpFixedLot);
         g_sl_points          = (int)ExtractJsonNumber(json, "stop_loss_points", InpScalpBaseSLPoints);
         g_tp_points          = (int)ExtractJsonNumber(json, "take_profit_points", InpScalpBaseTPPoints);
         g_max_spread         = (int)ExtractJsonNumber(json, "max_spread_points", InpMaxSpreadPoints);
         g_max_open_pos       = (int)ExtractJsonNumber(json, "max_open_positions", InpMaxOpenScalp);
         g_min_layer_dist     = (int)ExtractJsonNumber(json, "min_layer_distance_points", InpMinLayerDistancePts);
         g_use_trailing       = ExtractJsonBool(json, "use_trailing_stop", InpScalpUseTrailing);
         g_trailing_start     = (int)ExtractJsonNumber(json, "trailing_start_points", InpScalpTrailingStart);
         g_trailing_dist      = (int)ExtractJsonNumber(json, "trailing_distance_points", InpScalpTrailingDist);
         g_trailing_step      = (int)ExtractJsonNumber(json, "trailing_step_points", InpScalpTrailingStep);
         g_use_daily_guard    = ExtractJsonBool(json, "use_daily_guard", InpUseDailyGuard);
         g_daily_target_pct   = ExtractJsonNumber(json, "daily_target_profit_percent", InpDailyTargetPercent);
         g_daily_max_loss_pct = ExtractJsonNumber(json, "daily_max_loss_percent", InpDailyMaxLossPercent);
         g_loss_cooldown_min  = (int)ExtractJsonNumber(json, "loss_cooldown_minutes", InpLossCooldownMinutes);

         if(is_new_version && !is_initial)
         {
            double cur_bal = m_account.Balance();
            double target_usd = cur_bal * (g_daily_target_pct / 100.0);

            string update_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                                   "{\"name\": \"🧠 Brain Engine\", \"value\": \"`v" + g_current_version + " (Golden Fibonacci)`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target Harian\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (" + DoubleToString(g_daily_target_pct, 0) + "% Wallet)`\", \"inline\": true}," +
                                   "{\"name\": \"📐 Golden Pocket\", \"value\": \"`50.0% - 61.8% Fib Active`\", \"inline\": true}," +
                                   "{\"name\": \"🚨 Cloud Kill-Switch\", \"value\": \"`Citadel Redundancy OK`\", \"inline\": true}," +
                                   "{\"name\": \"📊 Sinkronisasi PnL\", \"value\": \"`100% Persis Tab History MT5`\", \"inline\": true}";
            
            SendDiscordEmbed("[" + g_account_tag + "] 🔄 OTA CLOUD UPDATE DIAPLIKASIKAN (v" + g_current_version + ")!", 
                             "Pembaruan v" + g_current_version + " diterapkan otomatis ke akun **" + g_account_tag + "** (Golden Fibonacci Engine Aktif)!", 
                             0x9B59B6, update_fields, false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DETAK JANTUNG FLEET MONITOR (PERIODIC HEARTBEAT PULSE)           |
//+------------------------------------------------------------------+
void SendFleetHeartbeatPulse()
{
   if(!InpEnableHeartbeat || !InpEnableDiscord) return;

   double balance = m_account.Balance();
   double equity  = m_account.Equity();
   double margin  = m_account.Margin();
   double free_margin = m_account.FreeMargin();
   double margin_level = (margin > 0) ? (equity / margin * 100.0) : 1000.0;
   double daily_pnl = GetDailyProfitLoss(true);

   int scalp_count = 0;
   int swing_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            if(m_position.Magic() == InpMagicScalp) scalp_count++;
            else if(m_position.Magic() == InpMagicSwing) swing_count++;
         }
      }
   }

   string position_status = "`⚡ " + IntegerToString(scalp_count) + " Scalp M1 | 🌊 " + IntegerToString(swing_count) + " Swing H4`";

   string ea_state = "🟢 APEX CITADEL AKTIF";
   if(g_emergency_kill_active) ea_state = "🚨 EMERGENCY KILL FREEZE";
   else if(g_manual_trade_pause) ea_state = "🚨 MANUAL TRADE ACTIVE (EA PAUSED)";
   else if(TimeCurrent() < g_cooldown_until) ea_state = "⏳ 5-MIN COOLDOWN (OTA SYNC RUNNING)";
   else if(g_cached_is_news_time) ea_state = "🚨 RED NEWS PAUSE";
   else if(TimeCurrent() < g_velocity_pause_until) ea_state = "⚡ TICK VELOCITY SURGE PAUSE";

   string heartbeat_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                             "{\"name\": \"🏦 Saldo / Equity\", \"value\": \"`$" + DoubleToString(balance, 2) + " / $" + DoubleToString(equity, 2) + "`\", \"inline\": true}," +
                             "{\"name\": \"🏆 PnL Hari Ini (History)\", \"value\": \"`" + ((daily_pnl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_pnl), 2) + "`\", \"inline\": true}," +
                             "{\"name\": \"🛡️ Margin Level\", \"value\": \"`" + DoubleToString(margin_level, 1) + "%` (Free: $" + DoubleToString(free_margin, 2) + ")\", \"inline\": true}," +
                             "{\"name\": \"⚡ Posisi Berjalan\", \"value\": \"" + position_status + "\", \"inline\": true}," +
                             "{\"name\": \"🧠 Status Engine\", \"value\": \"`" + ea_state + "`\", \"inline\": true}," +
                             "{\"name\": \"📶 Versi Engine\", \"value\": \"`v" + g_current_version + "`\", \"inline\": true}";

   SendDiscordEmbed("[" + g_account_tag + "] 💓 FLEET HEARTBEAT MONITOR PULSE", 
                    "Laporan status kesehatan dual-engine pada akun **" + g_account_tag + "** berjalan normal 100%.", 
                    0x2ECC71, heartbeat_fields, false);
}

//+------------------------------------------------------------------+
//| LAPORAN REKAPITULASI MINGGUAN (WEEKEND FINANCIAL DIGEST)         |
//+------------------------------------------------------------------+
void SendWeeklyFinancialDigest()
{
   if(!InpEnableWeekendDigest || !InpEnableDiscord) return;

   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int days_from_monday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   datetime start_of_week = StringToTime(TimeToString(now - days_from_monday * 86400, TIME_DATE) + " 00:00");
   HistorySelect(start_of_week, now + 60);

   int total_deals = HistoryDealsTotal();
   int win_count = 0;
   int loss_count = 0;
   double total_profit_usd = 0.0;
   double total_loss_usd = 0.0;
   int scalp_deals = 0;
   int swing_deals = 0;

   for(int i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         long deal_entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);

         if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY)
         {
            double net_pnl = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                             HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                             HistoryDealGetDouble(ticket, DEAL_COMMISSION);

            if(deal_magic == InpMagicScalp) scalp_deals++;
            else if(deal_magic == InpMagicSwing) swing_deals++;

            if(net_pnl >= 0)
            {
               win_count++;
               total_profit_usd += net_pnl;
            }
            else
            {
               loss_count++;
               total_loss_usd += MathAbs(net_pnl);
            }
         }
      }
   }

   int closed_trades = win_count + loss_count;
   double winrate = (closed_trades > 0) ? ((double)win_count / (double)closed_trades * 100.0) : 0.0;
   double net_weekly_pl = total_profit_usd - total_loss_usd;
   double current_balance = m_account.Balance();
   double initial_approx_bal = (current_balance - net_weekly_pl > 0) ? (current_balance - net_weekly_pl) : current_balance;
   double weekly_growth_pct = (initial_approx_bal > 0) ? (net_weekly_pl / initial_approx_bal * 100.0) : 0.0;
   double profit_factor = (total_loss_usd > 0) ? (total_profit_usd / total_loss_usd) : ((total_profit_usd > 0) ? 99.9 : 0.0);

   string growth_sign = (net_weekly_pl >= 0) ? "+$" : "-$";
   string pct_sign = (weekly_growth_pct >= 0) ? "+" : "";

   string digest_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                          "{\"name\": \"🏆 Net Panen Mingguan\", \"value\": \"**`" + growth_sign + DoubleToString(MathAbs(net_weekly_pl), 2) + " (" + pct_sign + DoubleToString(weekly_growth_pct, 1) + "%)`**\", \"inline\": true}," +
                          "{\"name\": \"🏦 Saldo Wallet Terkini\", \"value\": \"`$" + DoubleToString(current_balance, 2) + "`\", \"inline\": true}," +
                          "{\"name\": \"🎯 Winrate Mingguan\", \"value\": \"`" + DoubleToString(winrate, 1) + "%` (" + IntegerToString(win_count) + "W / " + IntegerToString(loss_count) + "L)\", \"inline\": true}," +
                          "{\"name\": \"⚖️ Profit Factor\", \"value\": \"`" + DoubleToString(profit_factor, 2) + "`\", \"inline\": true}," +
                          "{\"name\": \"📊 Total Transaksi\", \"value\": \"`" + IntegerToString(closed_trades) + " Trade` (⚡ " + IntegerToString(scalp_deals) + " Scalp, 🌊 " + IntegerToString(swing_deals) + " Swing)\", \"inline\": true}," +
                          "{\"name\": \"🛡️ Status Weekend\", \"value\": \"`Semua Posisi Aman Terkendali ✅`\", \"inline\": true}";

   SendDiscordEmbed("[" + g_account_tag + "] 📜 WEEKEND FINANCIAL DIGEST (LAPORAN REKAP MINGGUAN) 🌟", 
                    "Selamat berakhir pekan! Berikut adalah rangkuman performa trading sepekan untuk akun **" + g_account_tag + "**.", 
                    0xF1C40F, digest_fields, false);
}

//+------------------------------------------------------------------+
//| DETEKSI INSTITUTIONAL FAIR VALUE GAP (FVG M15/H1)                |
//+------------------------------------------------------------------+
void DetectM15FairValueGap(SFairValueGap &out_fvg)
{
   datetime now = TimeCurrent();
   if(now - g_last_fvg_calc_time < 30 && g_last_fvg_calc_time > 0)
   {
      out_fvg = g_cached_m15_fvg;
      return;
   }

   out_fvg.exists = false;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 5, rates) < 5) return;

   // 3-Bar FVG Check (Bar 1, Bar 2, Bar 3)
   // Bullish FVG: Bar 3 High < Bar 1 Low (Imbalance on Bar 2)
   if(rates[3].high < rates[1].low)
   {
      out_fvg.exists = true;
      out_fvg.is_bullish = true;
      out_fvg.upper_level = rates[1].low;
      out_fvg.lower_level = rates[3].high;
      out_fvg.time_created = rates[2].time;
   }
   // Bearish FVG: Bar 3 Low > Bar 1 High
   else if(rates[3].low > rates[1].high)
   {
      out_fvg.exists = true;
      out_fvg.is_bullish = false;
      out_fvg.upper_level = rates[3].low;
      out_fvg.lower_level = rates[1].high;
      out_fvg.time_created = rates[2].time;
   }

   g_cached_m15_fvg = out_fvg;
   g_last_fvg_calc_time = now;
}

//+------------------------------------------------------------------+
//| TRUE ZERO-LOSS COMMISSION & SWAP-AWARE BREAKEVEN CALCULATOR      |
//+------------------------------------------------------------------+
double CalculateCommissionAwareBE(bool is_buy, double open_price, double volume, double extra_buffer_pts=5.0)
{
   double point = m_symbol.Point();
   double tick_val = m_symbol.TickValue();
   if(tick_val <= 0) tick_val = 1.0;

   // Standard ECN commission buffer (~$7/lot round turn)
   double est_comm = 7.0 * volume;
   double be_offset_points = (est_comm / (tick_val * (volume > 0 ? volume : 0.01))) + extra_buffer_pts;
   if(be_offset_points < 10.0) be_offset_points = 10.0;

   double be_price = 0.0;
   if(is_buy)
      be_price = m_symbol.NormalizePrice(open_price + be_offset_points * point);
   else
      be_price = m_symbol.NormalizePrice(open_price - be_offset_points * point);

   return be_price;
}

//+------------------------------------------------------------------+
//| MULTI-TIMEFRAME CONFLUENCE SCORE MATRIX (0 - 100 SKOR)           |
//+------------------------------------------------------------------+
int CalculateMTFConfluenceScore(bool is_buy, double cur_bid, double cur_ask, double vwap, double ema50_h4, double ema200_h4, double rsi_h4, double adx_h4)
{
   int score = 0;

   // 1. M1 Momentum & VWAP (25 Pts)
   if(is_buy)
   {
      if(cur_ask > vwap) score += 15;
      else if(cur_ask < vwap - 80 * m_symbol.Point()) score += 10; // Deep Discount
      score += 10; // M1 Trigger Ready
   }
   else
   {
      if(cur_bid < vwap) score += 15;
      else if(cur_bid > vwap + 80 * m_symbol.Point()) score += 10; // Premium
      score += 10;
   }

   // 2. M15 FVG Confluence (25 Pts)
   SFairValueGap fvg;
   DetectM15FairValueGap(fvg);
   if(fvg.exists)
   {
      if(is_buy && fvg.is_bullish && cur_ask >= fvg.lower_level && cur_ask <= fvg.upper_level) score += 25;
      else if(!is_buy && !fvg.is_bullish && cur_bid >= fvg.lower_level && cur_bid <= fvg.upper_level) score += 25;
      else score += 15; // Trend alignment
   }
   else score += 20;

   // 3. H1 Trend & Pullback Health (25 Pts)
   double ema21_h1_val[];
   ArraySetAsSeries(ema21_h1_val, true);
   if(CopyBuffer(handle_ema21_h1, 0, 0, 2, ema21_h1_val) >= 2)
   {
      if(is_buy && cur_ask >= ema21_h1_val[0] - 150 * m_symbol.Point()) score += 25;
      else if(!is_buy && cur_bid <= ema21_h1_val[0] + 150 * m_symbol.Point()) score += 25;
      else score += 10;
   }
   else score += 20;

   // 4. H4 Macro Trend & Golden Pocket (25 Pts)
   if(is_buy && ema50_h4 > ema200_h4 && rsi_h4 >= 40.0 && rsi_h4 <= 65.0 && adx_h4 >= 18.0) score += 25;
   else if(!is_buy && ema50_h4 < ema200_h4 && rsi_h4 >= 35.0 && rsi_h4 <= 60.0 && adx_h4 >= 18.0) score += 25;
   else score += 15;

   return score;
}

//+------------------------------------------------------------------+
//| PROP FIRM & CHALLENGE HIGH-WATERMARK DRAWDOWN GUARD              |
//+------------------------------------------------------------------+
void CheckPropFirmDailyWatermark()
{
   if(!InpUsePropFirmGuard) return;

   datetime now = TimeCurrent();
   datetime today_start = StringToTime(TimeToString(now, TIME_DATE) + " 00:00");
   if(g_last_peak_day != today_start)
   {
      g_last_peak_day = today_start;
      g_daily_peak_equity = m_account.Equity();
      g_prop_firm_locked = false;
   }

   double cur_eq = m_account.Equity();
   if(cur_eq > g_daily_peak_equity) g_daily_peak_equity = cur_eq;

   if(g_daily_peak_equity > 0 && !g_prop_firm_locked)
   {
      double dd_pct = (g_daily_peak_equity - cur_eq) / g_daily_peak_equity * 100.0;
      if(dd_pct >= InpPropFirmMaxDailyDDPct)
      {
         g_prop_firm_locked = true;
         ExecuteGlobalEmergencyKillSwitch();

         string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                         "{\"name\": \"🏆 Guard Mode\", \"value\": \"`PROP FIRM HIGH-WATERMARK DEFENSE`\", \"inline\": true}," +
                         "{\"name\": \"📉 Max Trailing DD\", \"value\": \"`" + DoubleToString(dd_pct, 2) + "% (Batas " + DoubleToString(InpPropFirmMaxDailyDDPct, 1) + "%)`\", \"inline\": true}," +
                         "{\"name\": \"🏦 Peak Equity Hari Ini\", \"value\": \"`$" + DoubleToString(g_daily_peak_equity, 2) + "`\", \"inline\": true}," +
                         "{\"name\": \"💰 Equity Saat Kunci\", \"value\": \"`$" + DoubleToString(cur_eq, 2) + "`\", \"inline\": true}," +
                         "{\"name\": \"🔒 Status Trading\", \"value\": \"`TUTUP SEMUA POSISI & KUNCI HINGGA BESOK`\", \"inline\": true}";

         SendDiscordEmbed("[" + g_account_tag + "] 🏆 PROP FIRM HIGH-WATERMARK DRAWDOWN GUARD AKTIF!", 
                          "Akun **[" + g_account_tag + "]** berhasil dilindungi dari pelanggaran batas Daily Drawdown Prop Firm. Semua posisi ditutup & modal aman 100%!", 
                          0xE74C3C, fields, true);

         if(InpEnableMobilePush)
         {
            SendNotification(StringFormat("[%s] 🏆 Prop Firm DD Guard Aktif! Modal Diamankan.", g_account_tag));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 2-STAGE SCALPING PARTIAL PROFIT SCALER (50% CLOSE + TRUE-BE)     |
//+------------------------------------------------------------------+
void ProcessScalpPartialClose()
{
   if(!InpUseScalpPartialClose) return;

   double point = m_symbol.Point();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp)
         {
            double open_p = m_position.PriceOpen();
            double cur_p  = m_position.PriceCurrent();
            double cur_sl = m_position.StopLoss();
            double cur_tp = m_position.TakeProfit();
            double volume = m_position.Volume();
            ulong  ticket = m_position.Ticket();

            // Only partial close if volume >= 0.02 Lot and hasn't partial closed yet
            if(volume >= 0.02)
            {
               if(m_position.PositionType() == POSITION_TYPE_BUY)
               {
                  double profit_pts = (cur_p - open_p) / point;
                  if(profit_pts >= InpScalpPartialPoints)
                  {
                     double half_lot = NormalizeDouble(volume / 2.0, 2);
                     if(half_lot >= 0.01)
                     {
                        m_trade.SetExpertMagicNumber(InpMagicScalp);
                        if(m_trade.PositionClosePartial(ticket, half_lot))
                        {
                           double true_be = CalculateCommissionAwareBE(true, open_p, half_lot, InpTrueBEExtraBufferPts);
                           m_trade.PositionModify(ticket, true_be, cur_tp);
                           Print("🪜 [SCALP PARTIAL TP] Tiket #", ticket, " berhasil ambil profit 50% (", half_lot, " Lot) & SL dikunci di True-BE!");
                        }
                     }
                  }
               }
               else if(m_position.PositionType() == POSITION_TYPE_SELL)
               {
                  double profit_pts = (open_p - cur_p) / point;
                  if(profit_pts >= InpScalpPartialPoints)
                  {
                     double half_lot = NormalizeDouble(volume / 2.0, 2);
                     if(half_lot >= 0.01)
                     {
                        m_trade.SetExpertMagicNumber(InpMagicScalp);
                        if(m_trade.PositionClosePartial(ticket, half_lot))
                        {
                           double true_be = CalculateCommissionAwareBE(false, open_p, half_lot, InpTrueBEExtraBufferPts);
                           m_trade.PositionModify(ticket, true_be, cur_tp);
                           Print("🪜 [SCALP PARTIAL TP] Tiket #", ticket, " berhasil ambil profit 50% (", half_lot, " Lot) & SL dikunci di True-BE!");
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MESIN KALKULASI FIBONACCI H4 (GOLDEN POCKET 50% - 61.8%)         |
//+------------------------------------------------------------------+
void CalculateH4FibonacciLevels(SFibLevels &out_fib, int lookback_bars=24)
{
   datetime now = TimeCurrent();
   if(now - g_last_fib_calc_time < 60 && g_cached_h4_fib.swing_high > 0)
   {
      out_fib = g_cached_h4_fib;
      return;
   }

   ZeroMemory(out_fib);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int count = CopyRates(_Symbol, PERIOD_H4, 0, lookback_bars, rates);
   if(count < lookback_bars) return;

   double highest = -1e9;
   double lowest  = 1e9;
   int high_idx = 0;
   int low_idx  = 0;

   for(int i = 0; i < count; i++)
   {
      if(rates[i].high > highest) { highest = rates[i].high; high_idx = i; }
      if(rates[i].low < lowest)   { lowest  = rates[i].low;  low_idx  = i; }
   }

   out_fib.swing_high = highest;
   out_fib.swing_low  = lowest;
   double range = highest - lowest;

   if(low_idx > high_idx)
   {
      out_fib.is_uptrend = true;
      out_fib.fib_500 = highest - 0.500 * range;
      out_fib.fib_618 = highest - 0.618 * range;
      out_fib.fib_786 = highest - 0.786 * range;
      out_fib.fib_1618_ext = highest + 0.618 * range;
   }
   else
   {
      out_fib.is_uptrend = false;
      out_fib.fib_500 = lowest + 0.500 * range;
      out_fib.fib_618 = lowest + 0.618 * range;
      out_fib.fib_786 = lowest + 0.786 * range;
      out_fib.fib_1618_ext = lowest - 0.618 * range;
   }

   g_cached_h4_fib = out_fib;
   g_last_fib_calc_time = now;
}

//+------------------------------------------------------------------+
//| MESIN MICRO-FIBONACCI M1 SCALPING                                |
//+------------------------------------------------------------------+
void CalculateM1MicroFib(double &fib50, double &fib618, bool is_buy)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 15, rates) < 15) return;

   double highest = -1e9, lowest = 1e9;
   for(int i = 0; i < 15; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest)   lowest  = rates[i].low;
   }
   double range = highest - lowest;
   if(is_buy)
   {
      fib50  = highest - 0.500 * range;
      fib618 = highest - 0.618 * range;
   }
   else
   {
      fib50  = lowest + 0.500 * range;
      fib618 = lowest + 0.618 * range;
   }
}

//+------------------------------------------------------------------+
//| PENGALI ADAPTIF VWAP SESI (ASIA / LONDON / NY)                   |
//+------------------------------------------------------------------+
double GetSessionVWAPMultiplier()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < 7) return 1.0;
   if(dt.hour >= 7 && dt.hour < 13) return 1.3;
   if(dt.hour >= 13 && dt.hour < 22) return 1.6;
   return 1.2;
}

void CalculateSessionVWAP(double &vwap, double &upper_band, double &lower_band)
{
   datetime now = TimeCurrent();

   if(now - g_last_vwap_calc_time < 10 && g_cached_vwap > 0)
   {
      vwap = g_cached_vwap;
      upper_band = g_cached_vwap_up;
      lower_band = g_cached_vwap_low;
      return;
   }

   vwap = m_symbol.Bid();
   upper_band = vwap + 120 * m_symbol.Point();
   lower_band = vwap - 120 * m_symbol.Point();

   datetime start_of_day = StringToTime(TimeToString(now, TIME_DATE) + " 00:00");
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M1, start_of_day, now, rates);
   if(copied > 5)
   {
      double cum_vol_price = 0.0;
      long   cum_volume    = 0;
      for(int i = 0; i < copied; i++)
      {
         double typical_price = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
         long vol = (rates[i].tick_volume > 0) ? rates[i].tick_volume : 1;
         cum_vol_price += typical_price * vol;
         cum_volume += vol;
      }

      if(cum_volume > 0)
      {
         vwap = cum_vol_price / cum_volume;

         double sum_sq_diff = 0.0;
         for(int i = 0; i < copied; i++)
         {
            double tp = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
            sum_sq_diff += MathPow(tp - vwap, 2.0);
         }
         double std_dev = MathSqrt(sum_sq_diff / copied);
         double sd_mult = (InpUseAdaptiveVWAP) ? GetSessionVWAPMultiplier() : 1.2;
         upper_band = vwap + sd_mult * std_dev;
         lower_band = vwap - sd_mult * std_dev;
      }
   }

   g_cached_vwap       = vwap;
   g_cached_vwap_up    = upper_band;
   g_cached_vwap_low   = lower_band;
   g_last_vwap_calc_time = now;
}

//+------------------------------------------------------------------+
//| TRACKING ASIAN RANGE                                             |
//+------------------------------------------------------------------+
void UpdateAsianRange()
{
   datetime now = TimeCurrent();
   datetime today_date = StringToTime(TimeToString(now, TIME_DATE));
   if(g_asian_date != today_date)
   {
      g_asian_high = 0.0;
      g_asian_low  = 0.0;
      g_asian_date = today_date;
   }

   if(now - g_last_asian_calc_time < 60 && g_asian_high > 0) return;

   MqlDateTime dt;
   TimeToStruct(now, dt);

   if(dt.hour < 6)
   {
      datetime asian_start = today_date;
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int count = CopyRates(_Symbol, PERIOD_M5, asian_start, now, rates);
      if(count > 0)
      {
         double highest = -1e9;
         double lowest  = 1e9;
         for(int i = 0; i < count; i++)
         {
            if(rates[i].high > highest) highest = rates[i].high;
            if(rates[i].low < lowest)   lowest  = rates[i].low;
         }
         g_asian_high = highest;
         g_asian_low  = lowest;
      }
   }
   g_last_asian_calc_time = now;
}

//+------------------------------------------------------------------+
//| TICK VELOCITY SPEEDOMETER (ANTI-FLASH CRASH)                     |
//+------------------------------------------------------------------+
void CheckTickVelocity()
{
   if(!InpUseTickVelocityGuard) return;

   datetime now = TimeCurrent();
   double current_bid = m_symbol.Bid();

   if(g_last_tick_bid > 0)
   {
      int time_diff = (int)(now - g_last_tick_time);
      if(time_diff <= 2)
      {
         double pts_diff = MathAbs(current_bid - g_last_tick_bid) / m_symbol.Point();
         if(pts_diff >= 150.0)
         {
            g_velocity_pause_until = now + 15;
            Print("⚠️ [TICK VELOCITY SURGE] Terdeteksi spike liar ", pts_diff, " pts! Bot istirahat 15 detik.");
         }
      }
   }

   g_last_tick_time = now;
   g_last_tick_bid  = current_bid;
}

//+------------------------------------------------------------------+
//| DETEKSI REZIM PASAR M1                                           |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME DetectMarketRegime(double bb_up, double bb_low, double ema5, double ema13)
{
   double point = m_symbol.Point();
   double bb_width_pts = (bb_up - bb_low) / point;

   if(bb_width_pts < 100) return REGIME_SIDEWAYS_RANGE;
   if(MathAbs(ema5 - ema13) / point > 20) return REGIME_STRONG_TREND;
   return REGIME_SIDEWAYS_RANGE;
}

//+------------------------------------------------------------------+
//| KALKULASI LOT SCALPING (DEFEND-THE-BAG + WEEKLY DEFENDER)        |
//+------------------------------------------------------------------+
double CalculateScalpLotSize(double sl_points, bool is_counter_trend=false)
{
   double lot = g_lot_step;
   double balance = m_account.Balance();
   if(balance <= 0) balance = m_account.Equity();

   if(InpLotType == LOT_PER_BALANCE && g_balance_step > 0)
   {
      lot = MathFloor(balance / g_balance_step) * g_lot_step;
   }
   else if(InpLotType == LOT_RISK_PERCENT && sl_points > 0)
   {
      double equity     = m_account.Equity();
      double risk_money = equity * (InpRiskPercent / 100.0);
      double tick_value = m_symbol.TickValue();
      double tick_size  = m_symbol.TickSize();
      double point      = m_symbol.Point();

      if(tick_size > 0 && tick_value > 0)
      {
         double loss_per_lot = (sl_points * point / tick_size) * tick_value;
         if(loss_per_lot > 0) lot = risk_money / loss_per_lot;
      }
   }

   if(InpUseDefendTheBag)
   {
      double daily_pl = GetDailyProfitLoss();
      double defend_threshold_usd = balance * (InpDefendBagProfitPct / 100.0);
      if(daily_pl >= defend_threshold_usd)
      {
         lot = lot * 0.5;
      }
   }

   if(InpUseWeeklyBagDefender)
   {
      MqlDateTime cur_dt;
      TimeToStruct(TimeCurrent(), cur_dt);
      if(cur_dt.day_of_week >= 4)
      {
         double weekly_pl = GetWeeklyProfitLoss();
         double weekly_threshold_usd = balance * (InpWeeklyBagProfitPct / 100.0);
         if(weekly_pl >= weekly_threshold_usd)
         {
            lot = lot * 0.5;
         }
      }
   }

   if(is_counter_trend)
   {
      lot = lot * 0.5;
   }

   double lot_step = m_symbol.LotsStep();
   double min_lot  = m_symbol.LotsMin();
   double max_lot  = m_symbol.LotsMax();

   if(lot_step > 0) lot = MathFloor(lot / lot_step) * lot_step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| DETEKSI BERITA MERAH AS (HIGH-IMPACT NEWS GUARD)                 |
//+------------------------------------------------------------------+
bool IsHighImpactNewsTime()
{
   if(!InpUseRedNewsGuard) return false;

   datetime now = TimeCurrent();
   if(now - g_last_news_check_time < 30)
   {
      return g_cached_is_news_time;
   }

   bool news_active = false;
   MqlCalendarValue values[];
   datetime from_time = now - InpNewsBufferMin * 60;
   datetime to_time   = now + InpNewsBufferMin * 60;

   int total_events = CalendarValueHistory(values, from_time, to_time, "US");
   if(total_events > 0)
   {
      for(int i = 0; i < total_events; i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            if(event.importance == CALENDAR_IMPORTANCE_HIGH) { news_active = true; break; }
         }
      }
   }

   if(!news_active)
   {
      MqlDateTime dt;
      TimeToStruct(now, dt);
      if(dt.hour == 12 && dt.min >= (30 - InpNewsBufferMin) && dt.min <= (30 + InpNewsBufferMin)) news_active = true;
      else if(dt.hour == 14 && dt.min <= InpNewsBufferMin) news_active = true;
      else if(dt.hour == 18 && dt.min <= InpNewsBufferMin) news_active = true;
   }

   g_cached_is_news_time = news_active;
   g_last_news_check_time = now;
   return g_cached_is_news_time;
}

//+------------------------------------------------------------------+
//| DETEKSI PENUTUPAN JUMAT MALAM (21:00 SERVER) & ROLLOVER          |
//+------------------------------------------------------------------+
bool IsFridayWeekendCleanTime()
{
   if(!InpUseFridayAutoClean) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5 && dt.hour >= 21);
}

bool IsRolloverTime()
{
   if(!InpUseRolloverGuard) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return ((dt.hour == 23 && dt.min >= 50) || (dt.hour == 0) || (dt.hour == 1 && dt.min <= 10));
}

//+------------------------------------------------------------------+
//| SMART FRIDAY WEEKEND AUTO-CLEAN                                  |
//+------------------------------------------------------------------+
void CloseAllPositionsForWeekend()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            if(m_position.Magic() == InpMagicScalp)
            {
               m_trade.SetExpertMagicNumber(InpMagicScalp);
               m_trade.PositionClose(m_position.Ticket());
            }
            else if(m_position.Magic() == InpMagicSwing)
            {
               double open_p = m_position.PriceOpen();
               double sl_p   = m_position.StopLoss();
               bool is_risk_free = false;

               if(m_position.PositionType() == POSITION_TYPE_BUY && sl_p >= open_p) is_risk_free = true;
               else if(m_position.PositionType() == POSITION_TYPE_SELL && sl_p > 0 && sl_p <= open_p) is_risk_free = true;

               if(!InpSwingHoldWeekendIfBE || !is_risk_free)
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionClose(m_position.Ticket());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| KALKULASI ADAPTIF ATR SL & TP SCALPING (1:1.83 RATIO)            |
//+------------------------------------------------------------------+
void CalculateDynamicSLTP(int &calc_sl, int &calc_tp)
{
   calc_sl = g_sl_points;
   calc_tp = g_tp_points;

   if(handle_atr_m1 == INVALID_HANDLE) return;

   double atr_buf[];
   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(handle_atr_m1, 0, 0, 1, atr_buf) > 0)
   {
      double point = m_symbol.Point();
      double atr_points = atr_buf[0] / point;

      calc_sl = (int)MathMax(100, MathMin(160, atr_points * 1.5));
      calc_tp = (int)MathMax(180, MathMin(300, atr_points * 2.8));
   }
}

//+------------------------------------------------------------------+
//| VOLATILITY-ADAPTIVE GRID SPACING                                 |
//+------------------------------------------------------------------+
int CalculateAdaptiveLayerDistance()
{
   int required_pts = g_min_layer_dist;

   if(InpUseAdaptiveGrid && handle_atr_m1 != INVALID_HANDLE)
   {
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(handle_atr_m1, 0, 0, 1, atr_buf) > 0)
      {
         double point = m_symbol.Point();
         int dynamic_pts = (int)((atr_buf[0] / point) * 0.6);
         if(dynamic_pts > required_pts) required_pts = dynamic_pts;
      }
   }

   return required_pts;
}

//+------------------------------------------------------------------+
//| SMART EXECUTION RETRY & SLIPPAGE AUDIT TELEMETRY                 |
//+------------------------------------------------------------------+
bool ExecuteBuyWithSmartRetry(double lot, double sl_pts, double tp_pts, string comment_label, ulong &out_ticket, double &out_exec_price, double &out_slippage_pips)
{
   double point = m_symbol.Point();
   int max_retries = 3;

   for(int attempt = 1; attempt <= max_retries; attempt++)
   {
      m_symbol.RefreshRates();
      double ask = m_symbol.Ask();
      double sl  = (sl_pts > 0) ? m_symbol.NormalizePrice(ask - sl_pts * point) : 0;
      double tp  = (tp_pts > 0) ? m_symbol.NormalizePrice(ask + tp_pts * point) : 0;

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, comment_label))
      {
         out_ticket = m_trade.ResultOrder();
         out_exec_price = m_trade.ResultPrice();
         if(out_exec_price <= 0) out_exec_price = ask;
         out_slippage_pips = (out_exec_price - ask) / (10.0 * point);
         return true;
      }
      Sleep(100);
   }
   return false;
}

bool ExecuteSellWithSmartRetry(double lot, double sl_pts, double tp_pts, string comment_label, ulong &out_ticket, double &out_exec_price, double &out_slippage_pips)
{
   double point = m_symbol.Point();
   int max_retries = 3;

   for(int attempt = 1; attempt <= max_retries; attempt++)
   {
      m_symbol.RefreshRates();
      double bid = m_symbol.Bid();
      double sl  = (sl_pts > 0) ? m_symbol.NormalizePrice(bid + sl_pts * point) : 0;
      double tp  = (tp_pts > 0) ? m_symbol.NormalizePrice(bid - tp_pts * point) : 0;

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, comment_label))
      {
         out_ticket = m_trade.ResultOrder();
         out_exec_price = m_trade.ResultPrice();
         if(out_exec_price <= 0) out_exec_price = bid;
         out_slippage_pips = (bid - out_exec_price) / (10.0 * point);
         return true;
      }
      Sleep(100);
   }
   return false;
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI OPEN TRADE DISCORD & MOBILE PUSH               |
//+------------------------------------------------------------------+
void NotifyAITrade(string engine, string type, double price, double lot_used, double sl, double tp, ulong ticket, string trigger_source, int spread_used, int current_layers, int sl_pts, int tp_pts, double slippage_pips=0.0)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";
   string engine_badge = (engine == "SWING") ? "🌊 **[SWING RUNNER H4]**" : "⚡ **[SCALP M1 APEX CITADEL]**";
   string short_engine = (engine == "SWING") ? "🌊 SWING" : "⚡ SCALP";

   if(engine == "SWING") embed_color = (type == "BUY") ? 0x9B59B6 : 0xE67E22;

   string title = StringFormat("[%s] %s %s EXECUTED! (L%d)", g_account_tag, short_engine, type, current_layers);

   string slip_quality = (MathAbs(slippage_pips) <= 0.3) ? "✅ Presisi Sempurna" : (slippage_pips < 0) ? "🟢 Favorable" : "⚠️ Normal";
   string slip_str = StringFormat("%+.1f Pips (%s)", slippage_pips, slip_quality);

   string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏛️ Mesin Eksekusi\", \"value\": \"" + engine_badge + "\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Layer " + IntegerToString(current_layers) + ")**\", \"inline\": true}," +
                   "{\"name\": \"⚡ Pemicu Sinyal\", \"value\": \"`" + trigger_source + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (**" + DoubleToString(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Fill\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(sl_pts / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(tp_pts / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🕵️ Slippage Radar\", \"value\": \"`" + slip_str + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Spread Broker\", \"value\": \"`" + IntegerToString(spread_used) + " Points` (Aman)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed(title, 
                    "Eksekusi posisi **" + type + "** pada akun **[" + g_account_tag + "]** (" + engine + " Engine).", 
                    embed_color, 
                    fields, false);

   if(InpEnableMobilePush)
   {
      SendNotification(StringFormat("[%s] %s %s @ %.2f (Lot: %.2f)", g_account_tag, short_engine, type, price, lot_used));
   }
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI CLOSE TRADE DISCORD & MOBILE PUSH              |
//+------------------------------------------------------------------+
void NotifyCloseTrade(string engine, string type, double close_price, double profit, ulong deal_ticket, double volume)
{
   for(int i = 0; i < ArraySize(g_notified_deals); i++)
   {
      if(g_notified_deals[i] == deal_ticket) return;
   }
   int sz = ArraySize(g_notified_deals);
   ArrayResize(g_notified_deals, sz + 1);
   g_notified_deals[sz] = deal_ticket;

   if(profit < 0 && engine == "SCALP")
   {
      g_consecutive_losses++;
      if(InpUseLossCircuitBreaker && g_consecutive_losses >= 2)
      {
         g_cooldown_until = TimeCurrent() + g_loss_cooldown_min * 60;
         string cooldown_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                                  "{\"name\": \"⚠️ Rem Pengaman\", \"value\": \"`2x Loss Beruntun Terdeteksi`\", \"inline\": true}," +
                                  "{\"name\": \"⏳ Durasi Cooldown\", \"value\": \"`5 Menit Cepat (Hingga " + TimeToString(g_cooldown_until, TIME_MINUTES) + ")`\", \"inline\": true}," +
                                  "{\"name\": \"🔄 Status Cloud\", \"value\": \"`Sync & Heartbeat Tetap Aktif 100%`\", \"inline\": true}," +
                                  "{\"name\": \"🏦 Saldo Diamankan\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}";
         SendDiscordEmbed("[" + g_account_tag + "] 🛡️ FAST 5-MIN CIRCUIT BREAKER AKTIF!", 
                          "Mesin Scalping istirahat 5 menit untuk mendinginkan akun **[" + g_account_tag + "]** (Pembaruan cloud OTA tetap berjalan normal).", 
                          0xE67E22, cooldown_fields, true);
      }
   }
   else if(profit >= 0)
   {
      g_consecutive_losses = 0;
   }

   int embed_color = (profit >= 0) ? 0x2ECC71 : 0xE74C3C;
   string result_emoji = (profit >= 0) ? "🟢 **PROFIT CUAN**" : "🔴 **LOSS TERKENDALI**";
   string pnl_sign = (profit >= 0) ? "+$" : "-$";
   double abs_profit = MathAbs(profit);
   double current_balance = m_account.Balance();
   double daily_total_pl = GetDailyProfitLoss(true);
   string engine_label = (engine == "SWING") ? "🌊 SWING RUNNER H4" : "⚡ SCALP M1 APEX CITADEL";
   string result_text = (profit >= 0) ? "PROFIT" : "LOSS";

   string title = StringFormat("[%s] 🏁 POSISI %s DITUTUP (%s)", g_account_tag, engine, result_text);

   string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏛️ Mesin Eksekusi\", \"value\": \"`" + engine_label + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Hasil Transaksi\", \"value\": \"" + result_emoji + "\", \"inline\": true}," +
                   "{\"name\": \"💵 Realized PnL\", \"value\": \"**" + pnl_sign + DoubleToString(abs_profit, 2) + "**\", \"inline\": true}," +
                   "{\"name\": \"🏦 Saldo Akun Terkini\", \"value\": \"**`$" + DoubleToString(current_balance, 2) + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Posisi Ditutup\", \"value\": \"`" + type + " " + _Symbol + " (" + DoubleToString(volume, 2) + " Lot)`\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Close\", \"value\": \"`" + DoubleToString(close_price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🏆 Total PnL Hari Ini\", \"value\": \"`" + ((daily_total_pl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_total_pl), 2) + "` (Tab History)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Deal Ticket\", \"value\": \"`#" + IntegerToString(deal_ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed(title, 
                    "Posisi " + engine + " pada akun **[" + g_account_tag + "]** telah resmi ditutup dengan hasil **" + pnl_sign + DoubleToString(abs_profit, 2) + "**.", 
                    embed_color, 
                    fields, (profit < -30.0));

   if(InpEnableMobilePush)
   {
      SendNotification(StringFormat("[%s] %s Tutup %s %s (PnL: %s%.2f)", g_account_tag, engine, type, (profit >= 0 ? "PROFIT" : "LOSS"), pnl_sign, abs_profit));
   }
}

//+------------------------------------------------------------------+
//| EVENT ON TRADE TRANSACTION (INSTANT RUNNER BE SYNC)              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong deal_ticket = trans.deal;
      HistorySelect(TimeCurrent() - 3600, TimeCurrent() + 60);
      if(HistoryDealSelect(deal_ticket))
      {
         long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
         
         if((deal_magic == InpMagicScalp || deal_magic == InpMagicSwing || deal_magic == 0) &&
            (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         {
            double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(deal_ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            double close_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            double volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            long deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
            string pos_type = (deal_type == DEAL_TYPE_BUY) ? "BUY (Tutup SELL)" : "SELL (Tutup BUY)";
            string engine = (deal_magic == InpMagicSwing) ? "SWING" : "SCALP";
            
            NotifyCloseTrade(engine, pos_type, close_price, profit, deal_ticket, volume);

            // INSTANT EVENT-TRIGGERED BE SYNC FOR SWING RUNNER
            if(deal_magic == InpMagicSwing && profit > 0 && StringFind(deal_comment, "TP1") != -1)
            {
               double point = m_symbol.Point();
               for(int p = PositionsTotal() - 1; p >= 0; p--)
               {
                  if(m_position.SelectByIndex(p))
                  {
                     if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicSwing)
                     {
                        if(StringFind(m_position.Comment(), "Runner") != -1)
                        {
                           double open_p = m_position.PriceOpen();
                           double cur_sl = m_position.StopLoss();
                           double cur_tp = m_position.TakeProfit();
                           double be_sl = 0;

                           if(m_position.PositionType() == POSITION_TYPE_BUY)
                           {
                              be_sl = m_symbol.NormalizePrice(open_p + InpSwingBEProfitPoints * point);
                              if(cur_sl < be_sl)
                              {
                                 m_trade.SetExpertMagicNumber(InpMagicSwing);
                                 m_trade.PositionModify(m_position.Ticket(), be_sl, cur_tp);
                                 Print("🔒 [INSTANT BE SYNC] Tiket 1 TP1 Profit! Tiket 2 Runner SL berhasil dikunci di BE +10 pips!");
                              }
                           }
                           else if(m_position.PositionType() == POSITION_TYPE_SELL)
                           {
                              be_sl = m_symbol.NormalizePrice(open_p - InpSwingBEProfitPoints * point);
                              if(cur_sl == 0 || cur_sl > be_sl)
                              {
                                 m_trade.SetExpertMagicNumber(InpMagicSwing);
                                 m_trade.PositionModify(m_position.Ticket(), be_sl, cur_tp);
                                 Print("🔒 [INSTANT BE SYNC] Tiket 1 TP1 Profit! Tiket 2 Runner SL berhasil dikunci di BE +10 pips!");
                              }
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PERIODIC POSITION CLOSE FALLBACK TRACKER                         |
//+------------------------------------------------------------------+
void CheckPositionClosures()
{
   HistorySelect(TimeCurrent() - 86400, TimeCurrent() + 60);

   for(int i = ArraySize(g_tracked_positions) - 1; i >= 0; i--)
   {
      ulong tracked_ticket = g_tracked_positions[i].ticket;
      bool is_still_open = false;

      for(int p = PositionsTotal() - 1; p >= 0; p--)
      {
         if(m_position.SelectByIndex(p))
         {
            if(m_position.Ticket() == tracked_ticket)
            {
               is_still_open = true;
               break;
            }
         }
      }

      if(!is_still_open)
      {
         HistorySelectByPosition(tracked_ticket);
         int total_deals = HistoryDealsTotal();
         for(int d = total_deals - 1; d >= 0; d--)
         {
            ulong deal = HistoryDealGetTicket(d);
            if(deal > 0 && HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
               double profit = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION);
               double close_price = HistoryDealGetDouble(deal, DEAL_PRICE);
               NotifyCloseTrade(g_tracked_positions[i].engine_type, g_tracked_positions[i].order_type, close_price, profit, deal, g_tracked_positions[i].volume);
               break;
            }
         }

         for(int k = i; k < ArraySize(g_tracked_positions) - 1; k++)
         {
            g_tracked_positions[k] = g_tracked_positions[k+1];
         }
         ArrayResize(g_tracked_positions, ArraySize(g_tracked_positions) - 1);
      }
   }

   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      if(m_position.SelectByIndex(p))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicScalp || m_position.Magic() == InpMagicSwing))
         {
            ulong cur_ticket = m_position.Ticket();
            bool already_tracked = false;
            for(int k = 0; k < ArraySize(g_tracked_positions); k++)
            {
               if(g_tracked_positions[k].ticket == cur_ticket) { already_tracked = true; break; }
            }
            if(!already_tracked)
            {
               int sz = ArraySize(g_tracked_positions);
               ArrayResize(g_tracked_positions, sz + 1);
               g_tracked_positions[sz].ticket = cur_ticket;
               g_tracked_positions[sz].engine_type = (m_position.Magic() == InpMagicSwing) ? "SWING" : "SCALP";
               g_tracked_positions[sz].order_type = (m_position.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               g_tracked_positions[sz].open_price = m_position.PriceOpen();
               g_tracked_positions[sz].volume = m_position.Volume();
               g_tracked_positions[sz].open_time = (datetime)m_position.Time();
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   string sym = _Symbol;
   StringToUpper(sym);
   if(StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0)
   {
      Alert("PERINGATAN: EA 'XAUUSD Apex Brain Master' hanya boleh dipasang pada chart XAUUSD / GOLD!");
      return INIT_FAILED;
   }

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.Refresh();

   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetDeviationInPoints(40);

   InitAccountMetadata();
   g_loss_cooldown_min  = InpLossCooldownMinutes;
   RecoverConsecutiveLossesFromHistory();

   g_balance_step       = InpBalanceStep;
   g_lot_step           = InpFixedLot;
   g_sl_points          = InpScalpBaseSLPoints;
   g_tp_points          = InpScalpBaseTPPoints;
   g_max_spread         = InpMaxSpreadPoints;
   g_max_open_pos       = InpMaxOpenScalp;
   g_min_layer_dist     = InpMinLayerDistancePts;
   g_use_trailing       = InpScalpUseTrailing;
   g_trailing_start     = InpScalpTrailingStart;
   g_trailing_dist      = InpScalpTrailingDist;
   g_trailing_step      = InpScalpTrailingStep;
   g_use_daily_guard    = InpUseDailyGuard;
   g_daily_target_pct   = InpDailyTargetPercent;
   g_daily_max_loss_pct = InpDailyMaxLossPercent;

   FetchAndApplyCloudConfig(true);
   m_last_cloud_sync_time = TimeCurrent();
   g_last_heartbeat_time  = TimeCurrent();

   // Handle Scalping M1
   handle_ema5_m1    = iMA(_Symbol, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema13_m1   = iMA(_Symbol, PERIOD_M1, 13, 0, MODE_EMA, PRICE_CLOSE);
   handle_stoch_m1   = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   handle_bb_m1      = iBands(_Symbol, PERIOD_M1, 20, 0, 2.0, PRICE_CLOSE);
   handle_atr_m1     = iATR(_Symbol, PERIOD_M1, 14);
   handle_ema50_m15  = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);

   // Handle Swing H4 / H1 Mastery
   handle_ema50_h4   = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema200_h4  = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   handle_rsi_h4     = iRSI(_Symbol, PERIOD_H4, 14, PRICE_CLOSE);
   handle_adx_h4     = iADX(_Symbol, PERIOD_H4, 14);
   handle_ema21_h1   = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   handle_atr_h4     = iATR(_Symbol, PERIOD_H4, 14);

   if(handle_ema5_m1 == INVALID_HANDLE || handle_ema13_m1 == INVALID_HANDLE ||
      handle_stoch_m1 == INVALID_HANDLE || handle_bb_m1 == INVALID_HANDLE ||
      handle_atr_m1 == INVALID_HANDLE || handle_ema50_m15 == INVALID_HANDLE ||
      handle_ema50_h4 == INVALID_HANDLE || handle_ema200_h4 == INVALID_HANDLE ||
      handle_rsi_h4 == INVALID_HANDLE || handle_adx_h4 == INVALID_HANDLE ||
      handle_ema21_h1 == INVALID_HANDLE || handle_atr_h4 == INVALID_HANDLE)
   {
      Print("[ERROR] Gagal inisialisasi indikator Apex Citadel EA!");
      return INIT_FAILED;
   }

   EventSetTimer(1);

   double current_bal = m_account.Balance();
   double target_usd = current_bal * (g_daily_target_pct / 100.0);
   double current_lot = CalculateScalpLotSize(g_sl_points, false);
   double current_daily_pnl = GetDailyProfitLoss(true);

   string startup_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                           "{\"name\": \"🧠 Brain Engine\", \"value\": \"`v" + g_current_version + " (Golden Fibonacci)`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Cuan Harian\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (15% Wallet)`\", \"inline\": true}," +
                           "{\"name\": \"🏆 PnL Hari Ini (History)\", \"value\": \"`" + ((current_daily_pnl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(current_daily_pnl), 2) + "`\", \"inline\": true}," +
                           "{\"name\": \"📐 Golden Pocket\", \"value\": \"`50.0% - 61.8% Retracement`\", \"inline\": true}," +
                           "{\"name\": \"📱 Dual Redundancy\", \"value\": \"`Discord + MT5 Mobile Push`\", \"inline\": true}," +
                           "{\"name\": \"📈 Auto-Lot Mode\", \"value\": \"`$" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot` (Scalp: **" + DoubleToString(current_lot, 2) + "**)\", \"inline\": true}";

   SendDiscordEmbed("[" + g_account_tag + "] 👑 XAUUSD AI Brain Master Aktif (v12.00 Golden Fibonacci)! 🚀", 
                    "Sistem Sovereign Citadel & Golden Fibonacci siap beroperasi pada akun **[" + g_account_tag + "]** dengan ketahanan benteng institusional mutlak!", 
                    0x3498DB, startup_fields, false);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handle_ema5_m1);
   IndicatorRelease(handle_ema13_m1);
   IndicatorRelease(handle_stoch_m1);
   IndicatorRelease(handle_bb_m1);
   IndicatorRelease(handle_atr_m1);
   IndicatorRelease(handle_ema50_m15);
   IndicatorRelease(handle_ema50_h4);
   IndicatorRelease(handle_ema200_h4);
   IndicatorRelease(handle_rsi_h4);
   IndicatorRelease(handle_adx_h4);
   IndicatorRelease(handle_ema21_h1);
   IndicatorRelease(handle_atr_h4);
   Comment("");
}

//+------------------------------------------------------------------+
//| EVENT ON TIMER (CONTINUOUS CLOUD SYNC & GARBAGE COLLECTOR)       |
//+------------------------------------------------------------------+
void OnTimer()
{
   datetime now = TimeCurrent();

   // 1. Sinkronisasi Cloud OTA & Global Kill-Switch Check
   if(now - m_last_cloud_sync_time >= InpSyncIntervalMin * 60)
   {
      FetchAndApplyCloudConfig(false);
      m_last_cloud_sync_time = now;
   }

   // 2. Heartbeat Monitor Pulse
   if(InpEnableHeartbeat && (now - g_last_heartbeat_time >= InpHeartbeatIntervalHours * 3600))
   {
      SendFleetHeartbeatPulse();
      g_last_heartbeat_time = now;
   }

   // 3. Automated Weekend Financial Digest (Setiap Sabtu Pukul 08:00 Pagi)
   if(InpEnableWeekendDigest)
   {
      MqlDateTime dt;
      TimeToStruct(now, dt);
      if(dt.day_of_week == 6 && dt.hour >= 8)
      {
         datetime today_date = StringToTime(TimeToString(now, TIME_DATE));
         if(g_last_weekend_digest_date != today_date)
         {
            g_last_weekend_digest_date = today_date;
            SendWeeklyFinancialDigest();
         }
      }
   }

   // 4. 24/7 VPS Garbage Collector (Pembersih Memori RAM Otomatis)
   if(ArraySize(g_notified_deals) > 300)
   {
      ArrayResize(g_notified_deals, 50);
   }

   // 5. Fallback Closure Tracker
   static datetime last_fallback_close = 0;
   if(now - last_fallback_close >= 5)
   {
      CheckPositionClosures();
      last_fallback_close = now;
   }
}

//+------------------------------------------------------------------+
//| ON-CHART DASHBOARD APEX UNIQUE FINGERPRINT MASTER                |
//+------------------------------------------------------------------+
void DisplayAIDashboard(double ema5, double ema13, double stoch_k, double stoch_d, double vwap, double vwap_up, double vwap_low, string regime_label, string scalp_status, string swing_status, int dyn_sl, int dyn_tp, int scalp_total, int scalp_buy, int scalp_sell, int swing_total, int swing_buy, int swing_sell, string macro_bias, SFibLevels &fib)
{
   long current_spread = m_symbol.Spread();
   string spread_status = (current_spread <= g_max_spread) ? "[AMAN ✅]" : "[TERLALU TINGGI 🚫]";
   
   if(g_emergency_kill_active) spread_status = "[🚨 GLOBAL EMERGENCY FREEZE]";
   else if(g_manual_trade_pause) spread_status = "[🚨 MANUAL TRADE PAUSE]";
   else if(IsHighImpactNewsTime()) spread_status = "[🚨 RED NEWS SHIELD PAUSE]";
   else if(IsFridayWeekendCleanTime()) spread_status = "[📅 FRIDAY WEEKEND PAUSE]";
   else if(IsRolloverTime()) spread_status = "[⏸️ ROLLOVER PAUSE]";
   else if(TimeCurrent() < g_cooldown_until) spread_status = "[⏳ 5-MIN COOLDOWN PAUSE]";
   else if(TimeCurrent() < g_velocity_pause_until) spread_status = "[⚡ VELOCITY SURGE PAUSE]";
   
   double cur_bal = m_account.Balance();
   if(cur_bal <= 0) cur_bal = m_account.Equity();

   double dynamic_target_usd = cur_bal * (g_daily_target_pct / 100.0);
   double daily_pl = GetDailyProfitLoss();
   double lot = CalculateScalpLotSize(dyn_sl, false);

   string info = "=========================================================\n";
   info += "     👑 XAUUSD APEX SOVEREIGN CITADEL v" + g_current_version + "\n";
   info += "=========================================================\n";
   info += " 🏷️ Unique Fleet ID : " + g_account_tag + "\n";
   info += " 💰 Balance / Equity : $" + DoubleToString(m_account.Balance(), 2) + " / $" + DoubleToString(m_account.Equity(), 2) + "\n";
   info += " 🏆 Profit Hari Ini  : " + ((daily_pl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_pl), 2) + " (Tab History MT5)\n";
   info += " 🎯 Target 15% Cuan  : +$" + DoubleToString(dynamic_target_usd, 2) + " (Kunci Profit)\n";
   info += " 🌊 Macro H4 Bias    : " + macro_bias + "\n";
   info += " 📐 Golden Fib Zone  : 50.0% (" + DoubleToString(fib.fib_500, 2) + ") - 61.8% (" + DoubleToString(fib.fib_618, 2) + ")\n";
   info += "---------------------------------------------------------\n";
   info += " [⚡ ENGINE 1: SCALPING M1 (MICRO-FIB + ADAPTIVE VWAP)]\n";
   info += "  ⚡ Posisi Scalp     : " + IntegerToString(scalp_total) + "/" + IntegerToString(InpMaxOpenScalp) + " Posisi (" + IntegerToString(scalp_buy) + " BUY, " + IntegerToString(scalp_sell) + " SELL)\n";
   info += "  📈 M1 Momentum     : EMA5 (" + DoubleToString(ema5, 2) + ") vs EMA13 (" + DoubleToString(ema13, 2) + ") -> " + ((ema5 > ema13) ? "BULLISH 🟢" : "BEARISH 🔴") + "\n";
   info += "  ⚡ Fast Stoch (5,3): K=" + DoubleToString(stoch_k, 1) + " | D=" + DoubleToString(stoch_d, 1) + " (" + ((stoch_k < 35) ? "OVERSOLD 🟢" : (stoch_k > 65) ? "OVERBOUGHT 🔴" : "NEUTRAL ⚪") + ")\n";
   info += "  📊 Adaptive VWAP   : " + DoubleToString(vwap, 2) + " (Diskon: <" + DoubleToString(vwap_low, 2) + " | Premium: >" + DoubleToString(vwap_up, 2) + ")\n";
   info += "  🎯 Status Scalp    : " + scalp_status + "\n";
   info += "---------------------------------------------------------\n";
   info += " [🌊 ENGINE 2: SWING RUNNER H4 (GOLDEN POCKET 1:3 RR)]\n";
   info += "  🌊 Posisi Swing    : " + IntegerToString(swing_total) + "/" + (InpUseDualTicketSwing ? "2" : "1") + " Posisi (" + IntegerToString(swing_buy) + " BUY, " + IntegerToString(swing_sell) + " SELL)\n";
   info += "  🎯 Status Swing    : " + swing_status + "\n";
   info += "---------------------------------------------------------\n";
   info += " 🛡️ Spread Gold      : " + IntegerToString(current_spread) + " pts (Max: " + IntegerToString(g_max_spread) + " pts) " + spread_status + "\n";
   info += " 📡 Dual Redundancy  : Discord + MT5 Mobile Push ✅\n";
   info += "=========================================================\n";

   Comment(info);
}

//+------------------------------------------------------------------+
//| SPREAD-AWARE TRAILING STOP & BASKET TAKE-PROFIT GRID             |
//+------------------------------------------------------------------+
void ManageOpenPositions(int active_scalp_buy, int active_scalp_sell)
{
   double point = m_symbol.Point();
   double min_stop_distance = (m_symbol.StopsLevel() + m_symbol.Spread() + 10) * point;

   // BASKET TAKE-PROFIT
   if(InpUseBasketTakeProfit)
   {
      if(active_scalp_buy >= 2)
      {
         double total_buy_pnl = 0.0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp && m_position.PositionType() == POSITION_TYPE_BUY)
            {
               total_buy_pnl += m_position.Profit() + m_position.Swap();
            }
         }
         if(total_buy_pnl >= InpBasketProfitUSD)
         {
            Print("🧺 [BASKET TP BUY EXECUTED] Menutup seluruh ", active_scalp_buy, " layer Buy serentak dengan total profit: +$", DoubleToString(total_buy_pnl, 2));
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp && m_position.PositionType() == POSITION_TYPE_BUY)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionClose(m_position.Ticket());
               }
            }
            return;
         }
      }

      if(active_scalp_sell >= 2)
      {
         double total_sell_pnl = 0.0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp && m_position.PositionType() == POSITION_TYPE_SELL)
            {
               total_sell_pnl += m_position.Profit() + m_position.Swap();
            }
         }
         if(total_sell_pnl >= InpBasketProfitUSD)
         {
            Print("🧺 [BASKET TP SELL EXECUTED] Menutup seluruh ", active_scalp_sell, " layer Sell serentak dengan total profit: +$", DoubleToString(total_sell_pnl, 2));
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp && m_position.PositionType() == POSITION_TYPE_SELL)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionClose(m_position.Ticket());
               }
            }
            return;
         }
      }
   }

   // Standard Wide Trailing & Multi-Tier Swing Profit Lock
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() != _Symbol) continue;

      ulong  ticket       = m_position.Ticket();
      ulong  magic        = m_position.Magic();
      double open_price   = m_position.PriceOpen();
      double current_sl   = m_position.StopLoss();
      double current_tp   = m_position.TakeProfit();
      double current_bid  = m_symbol.Bid();
      double current_ask  = m_symbol.Ask();

      if(magic == InpMagicScalp)
      {
         if(m_position.PositionType() == POSITION_TYPE_BUY)
         {
            double profit_points = (current_bid - open_price) / point;

            if(g_use_trailing && profit_points >= g_trailing_start)
            {
               double new_sl = m_symbol.NormalizePrice(current_bid - g_trailing_dist * point);
               if(new_sl > current_sl + g_trailing_step * point && (current_bid - new_sl >= min_stop_distance))
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL)
         {
            double profit_points = (open_price - current_ask) / point;

            if(g_use_trailing && profit_points >= g_trailing_start)
            {
               double new_sl = m_symbol.NormalizePrice(current_ask + g_trailing_dist * point);
               if((current_sl == 0 || new_sl < current_sl - g_trailing_step * point) && (new_sl - current_ask >= min_stop_distance))
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
      }
      else if(magic == InpMagicSwing)
      {
         if(m_position.PositionType() == POSITION_TYPE_BUY)
         {
            double profit_points = (current_bid - open_price) / point;

            if(InpUseMultiTierSwingLock && profit_points >= 1200 && profit_points < InpSwingTrailingStart)
            {
               double tier2_sl = m_symbol.NormalizePrice(open_price + 500 * point); // Kunci +50 pips
               if(current_sl < tier2_sl && (current_bid - tier2_sl >= min_stop_distance))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, tier2_sl, current_tp);
                  Print("🔒 [TIER-2 SWING PROFIT LOCK] Runner BUY surplus +", DoubleToString(profit_points/10.0, 1), " pips! SL dinaikkan mengunci +50 pips profit!");
               }
            }
            else if(InpSwingUseTrailing && profit_points >= InpSwingTrailingStart)
            {
               double new_sl = m_symbol.NormalizePrice(current_bid - InpSwingTrailingDist * point);
               if(new_sl > current_sl + InpSwingTrailingStep * point && (current_bid - new_sl >= min_stop_distance))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL)
         {
            double profit_points = (open_price - current_ask) / point;

            if(InpUseMultiTierSwingLock && profit_points >= 1200 && profit_points < InpSwingTrailingStart)
            {
               double tier2_sl = m_symbol.NormalizePrice(open_price - 500 * point); // Kunci +50 pips
               if((current_sl == 0 || current_sl > tier2_sl) && (tier2_sl - current_ask >= min_stop_distance))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, tier2_sl, current_tp);
                  Print("🔒 [TIER-2 SWING PROFIT LOCK] Runner SELL surplus +", DoubleToString(profit_points/10.0, 1), " pips! SL diturunkan mengunci +50 pips profit!");
               }
            }
            else if(InpSwingUseTrailing && profit_points >= InpSwingTrailingStart)
            {
               double new_sl = m_symbol.NormalizePrice(current_ask + InpSwingTrailingDist * point);
               if((current_sl == 0 || new_sl < current_sl - InpSwingTrailingStep * point) && (new_sl - current_ask >= min_stop_distance))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DIRECTIONAL DISCOUNT-ONLY LAYERING VALIDATION (ADAPTIVE GRID)    |
//+------------------------------------------------------------------+
bool IsScalpLayerDistanceValid(ENUM_ORDER_TYPE order_type, double entry_price)
{
   double point = m_symbol.Point();
   int adaptive_dist_pts = CalculateAdaptiveLayerDistance();

   if(order_type == ORDER_TYPE_BUY)
   {
      double lowest_buy_price = 1e9;
      int buy_count = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp && m_position.PositionType() == POSITION_TYPE_BUY)
            {
               double pos_price = m_position.PriceOpen();
               if(pos_price < lowest_buy_price) lowest_buy_price = pos_price;
               buy_count++;
            }
         }
      }

      if(buy_count > 0 && lowest_buy_price < 1e9)
      {
         if(entry_price > lowest_buy_price - adaptive_dist_pts * point) return false;
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double highest_sell_price = -1e9;
      int sell_count = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp && m_position.PositionType() == POSITION_TYPE_SELL)
            {
               double pos_price = m_position.PriceOpen();
               if(pos_price > highest_sell_price) highest_sell_price = pos_price;
               sell_count++;
            }
         }
      }

      if(sell_count > 0 && highest_sell_price > -1e9)
      {
         if(entry_price < highest_sell_price + adaptive_dist_pts * point) return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| EKSEKUSI ORDER SCALPING M1 (SMART RETRY + SLIPPAGE TELEMETRY)    |
//+------------------------------------------------------------------+
void ExecuteScalpOrder(ENUM_ORDER_TYPE order_type, string trigger_source, int current_active_count, int dyn_sl_pts, int dyn_tp_pts, bool is_counter_trend=false)
{
   if(current_active_count >= 1)
   {
      double margin = m_account.Margin();
      double equity = m_account.Equity();
      double margin_level = (margin > 0) ? (equity / margin * 100.0) : 1000.0;
      if(margin_level < InpMinMarginLevelForGrid)
      {
         Print("🛡️ [MARGIN HEALTH GUARD] Margin Level ", DoubleToString(margin_level,1), "% < ", InpMinMarginLevelForGrid, "%! Batalkan penambahan layer scalping.");
         return;
      }
   }

   double lot = CalculateScalpLotSize(dyn_sl_pts, is_counter_trend);
   if(lot <= 0) return;

   int current_spread = (int)m_symbol.Spread();
   string comment_label = StringFormat("%s_L%d", InpCommentScalp, current_active_count + 1);

   m_trade.SetExpertMagicNumber(InpMagicScalp);
   ulong executed_ticket = 0;
   double exec_price = 0.0;
   double slippage_pips = 0.0;

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      if(!IsScalpLayerDistanceValid(ORDER_TYPE_BUY, ask)) return;

      if(ExecuteBuyWithSmartRetry(lot, dyn_sl_pts, dyn_tp_pts, comment_label, executed_ticket, exec_price, slippage_pips))
      {
         Print("🚀 [SCALP BUY EXECUTED - Layer ", current_active_count + 1, "/3] Akun: ", g_account_tag, " | Slip: ", slippage_pips, " pips | Lot: ", lot);
         NotifyAITrade("SCALP", "BUY", exec_price, lot, exec_price - dyn_sl_pts * m_symbol.Point(), exec_price + dyn_tp_pts * m_symbol.Point(), executed_ticket, trigger_source, current_spread, current_active_count + 1, dyn_sl_pts, dyn_tp_pts, slippage_pips);
         last_scalp_time = TimeCurrent();
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      if(!IsScalpLayerDistanceValid(ORDER_TYPE_SELL, bid)) return;

      if(ExecuteSellWithSmartRetry(lot, dyn_sl_pts, dyn_tp_pts, comment_label, executed_ticket, exec_price, slippage_pips))
      {
         Print("🚀 [SCALP SELL EXECUTED - Layer ", current_active_count + 1, "/3] Akun: ", g_account_tag, " | Slip: ", slippage_pips, " pips | Lot: ", lot);
         NotifyAITrade("SCALP", "SELL", exec_price, lot, exec_price + dyn_sl_pts * m_symbol.Point(), exec_price - dyn_tp_pts * m_symbol.Point(), executed_ticket, trigger_source, current_spread, current_active_count + 1, dyn_sl_pts, dyn_tp_pts, slippage_pips);
         last_scalp_time = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| DUAL-TICKET SWING SCALING (TP1 LOCK + TP2 MEGA RUNNER)           |
//+------------------------------------------------------------------+
void ExecuteSwingOrder(ENUM_ORDER_TYPE order_type, string trigger_source)
{
   double point = m_symbol.Point();
   double lot   = InpSwingFixedLot;
   if(lot <= 0) lot = 0.01;

   int current_spread = (int)m_symbol.Spread();

   int swing_sl = InpSwingSLPoints;
   int swing_tp1 = InpSwingTP1Points;
   int swing_tp2 = InpSwingTP2RunnerPoints;

   if(handle_atr_h4 != INVALID_HANDLE)
   {
      double atr_h4_buf[];
      ArraySetAsSeries(atr_h4_buf, true);
      if(CopyBuffer(handle_atr_h4, 0, 0, 1, atr_h4_buf) > 0)
      {
         int dynamic_atr_pts = (int)(atr_h4_buf[0] / point);
         if(dynamic_atr_pts >= 400 && dynamic_atr_pts <= 1500)
         {
            swing_sl  = (int)(dynamic_atr_pts * 1.5);
            swing_tp1 = (int)(dynamic_atr_pts * 1.2);
            swing_tp2 = (int)(swing_sl * 3.0);
         }
      }
   }

   m_trade.SetExpertMagicNumber(InpMagicSwing);

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      double sl  = (swing_sl > 0) ? (ask - swing_sl * point) : 0;
      double tp1 = (swing_tp1 > 0) ? (ask + swing_tp1 * point) : 0;
      double tp2 = (swing_tp2 > 0) ? (ask + swing_tp2 * point) : 0;
      sl  = m_symbol.NormalizePrice(sl);
      tp1 = m_symbol.NormalizePrice(tp1);
      tp2 = m_symbol.NormalizePrice(tp2);

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp1, StringFormat("%s_TP1", InpCommentSwing)))
      {
         Print("🌊 [SWING BUY TIKET 1 - TP1] Lot: ", lot, " | TP1: +", swing_tp1/10, " pips");
         NotifyAITrade("SWING", "BUY (Tiket 1 - TP1 Lock)", ask, lot, sl, tp1, m_trade.ResultOrder(), trigger_source, current_spread, 1, swing_sl, swing_tp1, 0.0);
      }

      if(InpUseDualTicketSwing)
      {
         if(m_trade.Buy(lot, _Symbol, ask, sl, tp2, StringFormat("%s_Runner", InpCommentSwing)))
         {
            Print("🌊 [SWING BUY TIKET 2 - Runner] Lot: ", lot, " | TP2: +", swing_tp2/10, " pips");
            NotifyAITrade("SWING", "BUY (Tiket 2 - Mega Runner)", ask, lot, sl, tp2, m_trade.ResultOrder(), trigger_source, current_spread, 2, swing_sl, swing_tp2, 0.0);
         }
      }
      last_swing_time = TimeCurrent();
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      double sl  = (swing_sl > 0) ? (bid + swing_sl * point) : 0;
      double tp1 = (swing_tp1 > 0) ? (bid - swing_tp1 * point) : 0;
      double tp2 = (swing_tp2 > 0) ? (bid - swing_tp2 * point) : 0;
      sl  = m_symbol.NormalizePrice(sl);
      tp1 = m_symbol.NormalizePrice(tp1);
      tp2 = m_symbol.NormalizePrice(tp2);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp1, StringFormat("%s_TP1", InpCommentSwing)))
      {
         Print("🌊 [SWING SELL TIKET 1 - TP1] Lot: ", lot, " | TP1: +", swing_tp1/10, " pips");
         NotifyAITrade("SWING", "SELL (Tiket 1 - TP1 Lock)", bid, lot, sl, tp1, m_trade.ResultOrder(), trigger_source, current_spread, 1, swing_sl, swing_tp1, 0.0);
      }

      if(InpUseDualTicketSwing)
      {
         if(m_trade.Sell(lot, _Symbol, bid, sl, tp2, StringFormat("%s_Runner", InpCommentSwing)))
         {
            Print("🌊 [SWING SELL TIKET 2 - Runner] Lot: ", lot, " | TP2: +", swing_tp2/10, " pips");
            NotifyAITrade("SWING", "SELL (Tiket 2 - Mega Runner)", bid, lot, sl, tp2, m_trade.ResultOrder(), trigger_source, current_spread, 2, swing_sl, swing_tp2, 0.0);
         }
      }
      last_swing_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| ON TICK EXECUTION (APEX SOVEREIGN CITADEL v12.00)                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!m_symbol.RefreshRates()) return;

   // 1. Cek Apakah Terkena Global Nuclear Kill-Switch
   if(g_emergency_kill_active) return;

   // 2. Tick Velocity Speedometer
   CheckTickVelocity();

   // 3. Smart Perisai Jumat Malam (21:00 Server)
   if(IsFridayWeekendCleanTime())
   {
      CloseAllPositionsForWeekend();
   }

   // 4. SCAN LENGKAP POSISI AKTIF & MANUAL TRADE GUARD DETECTION
   int scalp_total = 0, scalp_buy = 0, scalp_sell = 0;
   int swing_total = 0, swing_buy = 0, swing_sell = 0;
   bool manual_trade_found = false;
   ulong manual_ticket = 0;
   string manual_type = "";
   double manual_vol = 0.0;
   double manual_open = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            ulong magic = m_position.Magic();
            if(magic == InpMagicScalp)
            {
               scalp_total++;
               if(m_position.PositionType() == POSITION_TYPE_BUY) scalp_buy++;
               else if(m_position.PositionType() == POSITION_TYPE_SELL) scalp_sell++;
            }
            else if(magic == InpMagicSwing)
            {
               swing_total++;
               if(m_position.PositionType() == POSITION_TYPE_BUY) swing_buy++;
               else if(m_position.PositionType() == POSITION_TYPE_SELL) swing_sell++;
            }
            else
            {
               manual_trade_found = true;
               manual_ticket = m_position.Ticket();
               manual_type = (m_position.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               manual_vol = m_position.Volume();
               manual_open = m_position.PriceOpen();
            }
         }
      }
   }

   // 5. LOGIKA MANUAL ENTRY GUARD (Jeda EA Saat Ada Trade Manual)
   if(InpUseManualTradeGuard)
   {
      if(manual_trade_found)
      {
         if(!g_manual_trade_pause)
         {
            g_manual_trade_pause = true;
            g_detected_manual_ticket = manual_ticket;

            string manual_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                                   "{\"name\": \"🚨 Intervensi Manual\", \"value\": \"`" + manual_type + " " + _Symbol + " (" + DoubleToString(manual_vol, 2) + " Lot)`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(manual_open, _Digits) + "`\", \"inline\": true}," +
                                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(manual_ticket) + "`\", \"inline\": true}," +
                                   "{\"name\": \"⏸️ Status EA\", \"value\": \"`PAUSED (Menghormati Manual Trade)`\", \"inline\": true}";

            SendDiscordEmbed("[" + g_account_tag + "] 🚨 MANUAL ENTRY DETECTED (EA PAUSED)!", 
                             "Terdeteksi posisi manual pada akun **[" + g_account_tag + "]**. Seluruh mesin EA otomatis dijeda agar tidak mengganggu analisa manual pengguna.", 
                             0xE67E22, manual_fields, true);
         }
      }
      else
      {
         if(g_manual_trade_pause)
         {
            g_manual_trade_pause = false;
            g_detected_manual_ticket = 0;

            string resume_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                                   "{\"name\": \"🟢 Status EA\", \"value\": \"`RESUMED (Kembali Berburu Sinyal)`\", \"inline\": true}," +
                                   "{\"name\": \"🏦 Saldo Akun\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}";

            SendDiscordEmbed("[" + g_account_tag + "] 🟢 MANUAL TRADE SELESAI (EA AKTIF KEMBALI)!", 
                             "Posisi manual telah ditutup. Mesin EA pada akun **[" + g_account_tag + "]** kembali aktif berburu sinyal secara normal.", 
                             0x2ECC71, resume_fields, false);
         }
      }
   }

   // 6. Eksekusi Proteksi Posisi Milik EA & Basket Take-Profit
   if(scalp_total > 0 || swing_total > 0)
   {
      ManageOpenPositions(scalp_buy, scalp_sell);
   }

   // 7. Update Asian Range, Hitung VWAP & Fibonacci H4 Levels
   UpdateAsianRange();
   double vwap = 0.0, vwap_up = 0.0, vwap_low = 0.0;
   CalculateSessionVWAP(vwap, vwap_up, vwap_low);
   SFibLevels fib_h4;
   CalculateH4FibonacciLevels(fib_h4, 24);

   // 8. Hitung Dynamic ATR SL & TP Scalping
   int dyn_sl_pts = g_sl_points;
   int dyn_tp_pts = g_tp_points;
   CalculateDynamicSLTP(dyn_sl_pts, dyn_tp_pts);

   // 9. Ambil Data Candlestick M1 Terkini
   MqlRates rates_m1[];
   ArraySetAsSeries(rates_m1, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates_m1) < 5) return;

   // 10. Ambil Buffer Indikator M1 Fast & Macro
   double ema5_buf[], ema13_buf[], stoch_k_buf[], stoch_d_buf[], bb_up_buf[], bb_low_buf[], ema50_m15_buf[];
   ArraySetAsSeries(ema5_buf, true);
   ArraySetAsSeries(ema13_buf, true);
   ArraySetAsSeries(stoch_k_buf, true);
   ArraySetAsSeries(stoch_d_buf, true);
   ArraySetAsSeries(bb_up_buf, true);
   ArraySetAsSeries(bb_low_buf, true);
   ArraySetAsSeries(ema50_m15_buf, true);

   if(CopyBuffer(handle_ema5_m1, 0, 0, 3, ema5_buf) <= 0) return;
   if(CopyBuffer(handle_ema13_m1, 0, 0, 3, ema13_buf) <= 0) return;
   if(CopyBuffer(handle_stoch_m1, 0, 0, 3, stoch_k_buf) <= 0) return;
   if(CopyBuffer(handle_stoch_m1, 1, 0, 3, stoch_d_buf) <= 0) return;
   if(CopyBuffer(handle_bb_m1, 1, 0, 3, bb_up_buf) <= 0) return;
   if(CopyBuffer(handle_bb_m1, 2, 0, 3, bb_low_buf) <= 0) return;
   if(CopyBuffer(handle_ema50_m15, 0, 0, 1, ema50_m15_buf) <= 0) return;

   double ema5_curr    = ema5_buf[0];
   double ema13_curr   = ema13_buf[0];
   double stoch_k      = stoch_k_buf[0];
   double stoch_d      = stoch_d_buf[0];
   double prev_stoch_k = stoch_k_buf[1];
   double bb_up        = bb_up_buf[0];
   double bb_low       = bb_low_buf[0];
   double macro_ema50  = ema50_m15_buf[0];

   // 11. ANALISIS ANATOMI BAR 1 M1
   double bar1_open  = rates_m1[1].open;
   double bar1_high  = rates_m1[1].high;
   double bar1_low   = rates_m1[1].low;
   double bar1_close = rates_m1[1].close;
   double bar1_range = bar1_high - bar1_low;

   double lower_wick = MathMin(bar1_open, bar1_close) - bar1_low;
   double upper_wick = bar1_high - MathMax(bar1_open, bar1_close);

   bool is_bullish_pinbar = (bar1_range > 0) && (lower_wick >= 0.35 * bar1_range) && (bar1_close > bar1_low);
   bool is_bearish_pinbar = (bar1_range > 0) && (upper_wick >= 0.35 * bar1_range) && (bar1_close < bar1_high);
   bool is_bullish_engulf = (bar1_close > rates_m1[2].high) && (bar1_close > bar1_open);
   bool is_bearish_engulf = (bar1_close < rates_m1[2].low) && (bar1_close < bar1_open);

   ENUM_MARKET_REGIME regime = DetectMarketRegime(bb_up, bb_low, ema5_curr, ema13_curr);
   string regime_str = (regime == REGIME_STRONG_TREND) ? "TRENDING MOMENTUM 🚀" : "RANGING / SIDEWAYS ⚖️";

   // =================================================================
   // 12. EVALUASI MESIN 2: SWING RUNNER H4 (GOLDEN FIB POCKET 50-61.8%)
   // =================================================================
   bool swing_buy_sig = false;
   bool swing_sell_sig = false;
   string swing_reason = "";
   string macro_bias_label = "NETRAL ⚪";
   bool macro_h4_bullish = false;
   bool macro_h4_bearish = false;

   if(InpEnableSwingEngine || InpUseMacroBiasBooster)
   {
      double ema50_h4_buf[], ema200_h4_buf[], rsi_h4_buf[], adx_h4_buf[], ema21_h1_buf[];
      ArraySetAsSeries(ema50_h4_buf, true);
      ArraySetAsSeries(ema200_h4_buf, true);
      ArraySetAsSeries(rsi_h4_buf, true);
      ArraySetAsSeries(adx_h4_buf, true);
      ArraySetAsSeries(ema21_h1_buf, true);

      MqlRates rates_h1[];
      ArraySetAsSeries(rates_h1, true);

      if(CopyBuffer(handle_ema50_h4, 0, 0, 2, ema50_h4_buf) > 0 &&
         CopyBuffer(handle_ema200_h4, 0, 0, 2, ema200_h4_buf) > 0 &&
         CopyBuffer(handle_rsi_h4, 0, 0, 2, rsi_h4_buf) > 0 &&
         CopyBuffer(handle_adx_h4, 0, 0, 2, adx_h4_buf) > 0 &&
         CopyBuffer(handle_ema21_h1, 0, 0, 2, ema21_h1_buf) > 0 &&
         CopyRates(_Symbol, PERIOD_H1, 0, 3, rates_h1) >= 3)
      {
         double ema50_h4   = ema50_h4_buf[0];
         double ema200_h4  = ema200_h4_buf[0];
         double rsi_h4     = rsi_h4_buf[0];
         double adx_h4     = adx_h4_buf[0];
         double ema21_h1   = ema21_h1_buf[0];

         macro_h4_bullish = (ema50_h4 > ema200_h4);
         macro_h4_bearish = (ema50_h4 < ema200_h4);
         macro_bias_label = (macro_h4_bullish) ? "BULLISH DOMINANCE 🟢 (ADX: " + DoubleToString(adx_h4,1) + ")" :
                            (macro_h4_bearish) ? "BEARISH DOMINANCE 🔴 (ADX: " + DoubleToString(adx_h4,1) + ")" : "NETRAL ⚪";

         double h1_bar1_open  = rates_h1[1].open;
         double h1_bar1_high  = rates_h1[1].high;
         double h1_bar1_low   = rates_h1[1].low;
         double h1_bar1_close = rates_h1[1].close;
         double h1_bar1_range = h1_bar1_high - h1_bar1_low;

         double h1_lower_wick = MathMin(h1_bar1_open, h1_bar1_close) - h1_bar1_low;
         double h1_upper_wick = h1_bar1_high - MathMax(h1_bar1_open, h1_bar1_close);

         bool h1_bullish_rejection = (h1_bar1_range > 0) && ((h1_lower_wick >= 0.30 * h1_bar1_range) || (h1_bar1_close > h1_bar1_open));
         bool h1_bearish_rejection = (h1_bar1_range > 0) && ((h1_upper_wick >= 0.30 * h1_bar1_range) || (h1_bar1_close < h1_bar1_open));

         bool is_trend_strong = (adx_h4 >= InpSwingMinADX);
         int max_allowed_swing = (InpUseDualTicketSwing ? 2 : 1);

         if(TimeCurrent() - g_last_swing_eval_time >= 60)
         {
            double point = m_symbol.Point();
            double ask_now = m_symbol.Ask();
            double bid_now = m_symbol.Bid();

            bool buy_dist_ok = ((ask_now - ema21_h1) / point <= InpSwingMaxChasePts);
            bool sell_dist_ok = ((ema21_h1 - bid_now) / point <= InpSwingMaxChasePts);

            bool in_golden_buy_pocket = (!InpUseGoldenFibPocket) || (ask_now <= fib_h4.fib_500 && ask_now >= fib_h4.fib_786);
            bool in_golden_sell_pocket = (!InpUseGoldenFibPocket) || (bid_now >= fib_h4.fib_500 && bid_now <= fib_h4.fib_786);

            if(macro_h4_bullish && is_trend_strong && rsi_h4 >= 38.0 && rsi_h4 <= 60.0 &&
               h1_bar1_low <= ema21_h1 && h1_bar1_close >= ema21_h1 && h1_bullish_rejection && buy_dist_ok && in_golden_buy_pocket)
            {
               if(swing_total < max_allowed_swing && swing_buy == 0)
               {
                  swing_buy_sig = true;
                  swing_reason = StringFormat("Golden Pocket Fib (%.2f) + H1 EMA21 Rejection", fib_h4.fib_618);
               }
            }
            else if(macro_h4_bearish && is_trend_strong && rsi_h4 >= 40.0 && rsi_h4 <= 62.0 &&
                    h1_bar1_high >= ema21_h1 && h1_bar1_close <= ema21_h1 && h1_bearish_rejection && sell_dist_ok && in_golden_sell_pocket)
            {
               if(swing_total < max_allowed_swing && swing_sell == 0)
               {
                  swing_sell_sig = true;
                  swing_reason = StringFormat("Golden Pocket Fib (%.2f) + H1 EMA21 Rejection", fib_h4.fib_618);
               }
            }
            g_last_swing_eval_time = TimeCurrent();
         }
      }
   }

   // =================================================================
   // 13. EVALUASI MESIN 1: SCALPING M1 (MICRO-FIBONACCI SNIPER)
   // =================================================================
   bool scalp_buy_sig = false;
   bool scalp_sell_sig = false;
   string scalp_reason = "";
   bool is_scalp_counter_trend = false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool is_london_session = (dt.hour >= 7 && dt.hour <= 12);

   double micro_fib50_buy = 0, micro_fib618_buy = 0;
   double micro_fib50_sell = 0, micro_fib618_sell = 0;
   if(InpUseMicroFibScalp)
   {
      CalculateM1MicroFib(micro_fib50_buy, micro_fib618_buy, true);
      CalculateM1MicroFib(micro_fib50_sell, micro_fib618_sell, false);
   }

   if(InpUseAsianSweepTrap && is_london_session && g_asian_high > 0 && g_asian_low > 0)
   {
      if(rates_m1[1].low < g_asian_low && bar1_close > g_asian_low && (is_bullish_pinbar || is_bullish_engulf))
      {
         scalp_buy_sig = true; scalp_reason = "Asian Low Sweep Reversal";
      }
      else if(rates_m1[1].high > g_asian_high && bar1_close < g_asian_high && (is_bearish_pinbar || is_bearish_engulf))
      {
         scalp_sell_sig = true; scalp_reason = "Asian High Sweep Reversal";
      }
   }

   if(!scalp_buy_sig && !scalp_sell_sig && InpUseAdaptiveVWAP)
   {
      if(bar1_close <= vwap_low && (is_bullish_pinbar || is_bullish_engulf || stoch_k < 25))
      {
         scalp_buy_sig = true; scalp_reason = "Session VWAP Discount (" + DoubleToString(GetSessionVWAPMultiplier(),1) + " SD)";
      }
      else if(bar1_close >= vwap_up && (is_bearish_pinbar || is_bearish_engulf || stoch_k > 75))
      {
         scalp_sell_sig = true; scalp_reason = "Session VWAP Premium (" + DoubleToString(GetSessionVWAPMultiplier(),1) + " SD)";
      }
   }

   if(!scalp_buy_sig && !scalp_sell_sig && InpUseMicroFibScalp)
   {
      if(ema5_curr > ema13_curr && bar1_low <= micro_fib618_buy && bar1_close >= micro_fib618_buy && (stoch_k > stoch_d || is_bullish_pinbar))
      {
         scalp_buy_sig = true; scalp_reason = "Micro-Fib 61.8% Golden Pullback";
      }
      else if(ema5_curr < ema13_curr && bar1_high >= micro_fib618_sell && bar1_close <= micro_fib618_sell && (stoch_k < stoch_d || is_bearish_pinbar))
      {
         scalp_sell_sig = true; scalp_reason = "Micro-Fib 61.8% Golden Pullback";
      }
   }

   if(!scalp_buy_sig && !scalp_sell_sig)
   {
      if(ema5_curr > ema13_curr && (rates_m1[1].low <= ema13_curr || rates_m1[2].low <= ema13_curr) && bar1_close >= ema5_curr && (stoch_k > stoch_d || is_bullish_pinbar))
      {
         if(!InpUseTripleScreen || bar1_close >= macro_ema50)
         {
            scalp_buy_sig = true; scalp_reason = "M1 Micro-Pullback Dip to EMA13";
         }
      }
      else if(ema5_curr < ema13_curr && (rates_m1[1].high >= ema13_curr || rates_m1[2].high >= ema13_curr) && bar1_close <= ema5_curr && (stoch_k < stoch_d || is_bearish_pinbar))
      {
         if(!InpUseTripleScreen || bar1_close <= macro_ema50)
         {
            scalp_sell_sig = true; scalp_reason = "M1 Micro-Pullback Rally to EMA13";
         }
      }
   }

   if(!scalp_buy_sig && !scalp_sell_sig)
   {
      if((prev_stoch_k <= 30 && stoch_k > prev_stoch_k && stoch_k > stoch_d) && (bar1_low <= bb_low || is_bullish_pinbar))
      {
         scalp_buy_sig = true; scalp_reason = "Fast Stoch Hook Oversold (< 30)";
      }
      else if((prev_stoch_k >= 70 && stoch_k < prev_stoch_k && stoch_k < stoch_d) && (bar1_high >= bb_up || is_bearish_pinbar))
      {
         scalp_sell_sig = true; scalp_reason = "Fast Stoch Hook Overbought (> 70)";
      }
   }

   if(InpUseMacroBiasBooster)
   {
      if(macro_h4_bullish && scalp_sell_sig)
      {
         is_scalp_counter_trend = true;
         if(stoch_k < 78) scalp_sell_sig = false;
      }
      else if(macro_h4_bearish && scalp_buy_sig)
      {
         is_scalp_counter_trend = true;
         if(stoch_k > 22) scalp_buy_sig = false;
      }
   }

   // 14. Update Dashboard On-Chart
   string scalp_status = "STANDBY HUNTING M1...";
   if(g_emergency_kill_active) scalp_status = "🚨 GLOBAL EMERGENCY KILL (FREEZE)";
   else if(g_manual_trade_pause) scalp_status = "⏸️ MANUAL ENTRY ACTIVE (EA PAUSED)";
   else if(IsHighImpactNewsTime()) scalp_status = "🚨 RED NEWS PAUSE (CPI/NFP/FOMC)";
   else if(IsFridayWeekendCleanTime()) scalp_status = "📅 FRIDAY WEEKEND PAUSE (21:00+)";
   else if(IsRolloverTime()) scalp_status = "⏸️ ROLLOVER TIME PAUSE (23:50-01:10)";
   else if(TimeCurrent() < g_cooldown_until) scalp_status = "⏳ 5-MIN COOLDOWN (OTA SYNC RUNNING)";
   else if(TimeCurrent() < g_velocity_pause_until) scalp_status = "⚡ VELOCITY SURGE PAUSE (15 Detik)";
   else if(scalp_buy_sig) scalp_status = "🟢 APEX BUY DETECTED! (" + scalp_reason + ")";
   else if(scalp_sell_sig) scalp_status = "🔴 APEX SELL DETECTED! (" + scalp_reason + ")";

   string swing_status = "STANDBY MONITORING H4...";
   if(g_emergency_kill_active) swing_status = "🚨 GLOBAL EMERGENCY KILL (FREEZE)";
   else if(g_manual_trade_pause) swing_status = "⏸️ MANUAL ENTRY ACTIVE (EA PAUSED)";
   else if(swing_buy_sig) swing_status = "🟢 SWING BUY DETECTED! (" + swing_reason + ")";
   else if(swing_sell_sig) swing_status = "🔴 SWING SELL DETECTED! (" + swing_reason + ")";
   else if(swing_total > 0) swing_status = StringFormat("🌊 RUNNING SWING (%d Posisi Aktif)", swing_total);

   DisplayAIDashboard(ema5_curr, ema13_curr, stoch_k, stoch_d, vwap, vwap_up, vwap_low, regime_str, scalp_status, swing_status, dyn_sl_pts, dyn_tp_pts, scalp_total, scalp_buy, scalp_sell, swing_total, swing_buy, swing_sell, macro_bias_label, fib_h4);

   // 15. Cek Proteksi Manual Trade Guard & Daily Guard
   if(g_emergency_kill_active || g_manual_trade_pause) return;

   if(g_use_daily_guard)
   {
      double cur_bal = m_account.Balance();
      if(cur_bal <= 0) cur_bal = m_account.Equity();

      double dynamic_target_usd = cur_bal * (g_daily_target_pct / 100.0);
      double dynamic_max_loss_usd = cur_bal * (g_daily_max_loss_pct / 100.0);
      double daily_pl = GetDailyProfitLoss();

      if(daily_pl >= dynamic_target_usd || daily_pl <= -dynamic_max_loss_usd) return;
   }

   // 16. Perisai Filter Eksekusi Umum
   if(IsHighImpactNewsTime()) return;
   if(IsFridayWeekendCleanTime()) return;
   if(IsRolloverTime()) return;
   if(m_symbol.Spread() > g_max_spread) return;
   if(TimeCurrent() < g_velocity_pause_until) return;

   // 17. EKSEKUSI MESIN 2: SWING RUNNER H4 (Dual-Ticket Scaling)
   int max_allowed_swing = (InpUseDualTicketSwing ? 2 : 1);
   if(InpEnableSwingEngine && (TimeCurrent() - last_swing_time >= 300))
   {
      if(swing_buy_sig && swing_total < max_allowed_swing)
      {
         ExecuteSwingOrder(ORDER_TYPE_BUY, swing_reason);
      }
      else if(swing_sell_sig && swing_total < max_allowed_swing)
      {
         ExecuteSwingOrder(ORDER_TYPE_SELL, swing_reason);
      }
   }

   // 18. EKSEKUSI MESIN 1: SCALPING M1 FAST SNIPER
   if(InpEnableScalpingEngine)
   {
      if(TimeCurrent() < g_cooldown_until) return;
      if(scalp_total >= InpMaxOpenScalp) return;

      if(InpUseDirectionalLock)
      {
         if(scalp_buy > 0 && scalp_sell_sig) return;
         if(scalp_sell > 0 && scalp_buy_sig) return;
      }

      if(TimeCurrent() - last_scalp_time < 5) return;

      if(scalp_buy_sig)
      {
         ExecuteScalpOrder(ORDER_TYPE_BUY, scalp_reason, scalp_total, dyn_sl_pts, dyn_tp_pts, is_scalp_counter_trend);
      }
      else if(scalp_sell_sig)
      {
         ExecuteScalpOrder(ORDER_TYPE_SELL, scalp_reason, scalp_total, dyn_sl_pts, dyn_tp_pts, is_scalp_counter_trend);
      }
   }
}