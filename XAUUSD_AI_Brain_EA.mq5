//+------------------------------------------------------------------+
//|                                     XAUUSD_AI_Brain_EA.mq5       |
//|  APEX HYBRID SOVEREIGN EDITION (SCALP M1 + SWING H4) - v6.00     |
//|  (Dual-Engine • Account Fleet ID • Zero-Bottleneck • All-in-One)  |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX & AI Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "6.00"
#property description "Unified Master Brain EA: Menggabungkan Scalping M1 (Tri-Layer Grid) & Swing H4 Macro Rider dalam 1 EA dengan pemisahan Magic Number, Zero-Bottleneck, dan Fleet Account Tag."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#define CLOUD_CONFIG_URL "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/ea_cloud_config.json"

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

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== 1. IDENTITAS AKUN & FLEET MONITORING ==="
input string              InpAccountTag            = "ACC-01";              // Tag / Nama Unik Akun (misal: ACC-01-PRIMARY, ACC-02-VIP)
input bool                InpEnableHeartbeat       = true;                  // Aktifkan Notifikasi Detak Jantung (Heartbeat Pulse)
input int                 InpHeartbeatIntervalHours= 2;                     // Interval Heartbeat ke Discord (Jam)

input group "=== 2. DISCORD NOTIFICATION WEBHOOK ==="
input string              InpDiscordWebhookURL     = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // Webhook URL Pribadi
input bool                InpEnableDiscord         = true;                  // Aktifkan Notifikasi Discord
input string              InpDiscordMention        = "";                    // Mention Role/User
input string              InpBotName               = "XAUUSD Apex Brain Master"; // Nama Bot

input group "=== 3. OTA CLOUD AUTO-SYNC (1x PASANG = AUTO UPDATE) ==="
input bool                InpEnableCloudSync       = true;                  // Aktifkan Sinkronisasi Cloud dari GitHub
input int                 InpSyncIntervalMin       = 5;                     // Interval Cek Update Cloud (Menit)

input group "=== 4. ENGINE 1: SCALPING M1 (FAST SNIPER) ==="
input bool                InpEnableScalpingEngine  = true;                  // Aktifkan Mesin Scalping M1
input ulong               InpMagicScalp            = 202611;                // Magic Number Scalping
input string              InpCommentScalp          = "Apex_Scalp";          // Label Order Scalping
input bool                InpUseRegimeSwitching    = true;                  // Auto-Switch Strategi (Pullback vs Mean Reversion)
input bool                InpUseSessionVWAP        = true;                  // Session VWAP Institutional Bands (+/- 1.2 SD)
input bool                InpUseAsianSweepTrap     = true;                  // Perangkap Asian Liquidity Sweep (Sesi London)
input bool                InpUseTripleScreen       = false;                 // Triple-Screen Filter M15 (False = Bebas Scalp Cepat)
input int                 InpMaxOpenScalp          = 3;                     // Max Posisi Scalping Aktif (Tri-Layer Sweet Spot)
input int                 InpMinLayerDistancePts   = 30;                    // Jarak Minimal Antar Layer (Points, 30 pts = 3 pips)
input int                 InpScalpBaseSLPoints     = 120;                   // Base SL Scalping (Points, 120 pts = 12 pips)
input int                 InpScalpBaseTPPoints     = 200;                   // Base TP Scalping (Points, 200 pts = 20 pips)
input bool                InpScalpUseBE            = true;                  // Break-Even Cepat Scalping
input int                 InpScalpBETriggerPoints  = 80;                    // Trigger BE Scalping (Points, 80 pts = 8 pips)
input int                 InpScalpBEProfitPoints   = 15;                    // Kunci Profit BE Scalping (Points, 15 pts = 1.5 pips)
input bool                InpScalpUseTrailing      = true;                  // Trailing Stop Cepat Scalping
input int                 InpScalpTrailingStart    = 100;                   // Trailing Start Scalp (Points, 100 pts = 10 pips)
input int                 InpScalpTrailingDist     = 60;                    // Jarak Trailing Scalp (Points, 60 pts = 6 pips)
input int                 InpScalpTrailingStep     = 15;                    // Step Trailing Scalp (Points)

input group "=== 5. ENGINE 2: SWING RUNNER H4 (SENTINEL MACRO RIDER) ==="
input bool                InpEnableSwingEngine     = true;                  // Aktifkan Mesin Swing H4
input ulong               InpMagicSwing            = 202622;                // Magic Number Swing
input string              InpCommentSwing          = "Apex_Swing";          // Label Order Swing
input int                 InpMaxOpenSwing          = 1;                     // Max Posisi Swing Aktif (1 Runner Kokoh)
input double              InpSwingFixedLot         = 0.01;                  // Fixed Lot Size Swing Runner
input int                 InpSwingSLPoints         = 250;                   // SL Swing (Points, 250 pts = 25 pips)
input int                 InpSwingTPPoints         = 500;                   // TP Swing (Points, 500 pts = 50 pips / RR 1:2)
input bool                InpSwingUseBE            = true;                  // Break-Even Swing Runner
input int                 InpSwingBETriggerPoints  = 180;                   // Trigger BE Swing (+18 pips)
input int                 InpSwingBEProfitPoints   = 30;                    // Kunci Profit BE Swing (+3 pips)
input bool                InpSwingUseTrailing      = true;                  // Trailing Stop Jarak Jauh Swing
input int                 InpSwingTrailingStart    = 250;                   // Trailing Start Swing (+25 pips)
input int                 InpSwingTrailingDist     = 150;                   // Jarak Trailing Swing (15 pips)
input int                 InpSwingTrailingStep     = 30;                    // Step Trailing Swing (3 pips)

input group "=== 6. PERISAI PENGAMAN & RISK MANAGEMENT ==="
input ENUM_LOT_TYPE       InpLotType               = LOT_PER_BALANCE;       // Mode Lot Sizing Scalping
input double              InpFixedLot              = 0.01;                  // Base Lot per Kelipatan
input double              InpBalanceStep           = 500.0;                 // Saldo per Kelipatan Lot ($500 = 0.01 Lot)
input double              InpRiskPercent           = 1.0;                   // Risk % per Trade Scalping
input int                 InpMaxSpreadPoints       = 80;                    // Max Spread Filter (Points)
input bool                InpUseDefendTheBag       = true;                  // Defend-The-Bag (Kunci Cuan Harian >= 8%)
input double              InpDefendBagProfitPct    = 8.0;                   // Ambang Defend-The-Bag (% Wallet Pangkas 50% Lot)
input bool                InpUseRedNewsGuard       = true;                  // Perisai Berita Merah AS (CPI, NFP, FOMC)
input int                 InpNewsBufferMin         = 15;                    // Jeda Menit Sebelum & Sesudah Berita Merah
input bool                InpUseFridayAutoClean    = true;                  // Bersihkan Semua Posisi Scalp Jumat Malam (21:00)
input bool                InpUseLossCircuitBreaker = true;                  // Rem Pengaman Rugi Beruntun (2x SL = Cooldown 30 Mnt)
input bool                InpUseDirectionalLock    = true;                  // Kunci 1 Arah Scalp (Haram Hedging saat Layer Aktif)
input bool                InpUseRolloverGuard      = true;                  // Pelindung Jam Rollover Broker (23:50-01:10)
input bool                InpUseDailyGuard         = false;                 // Aktifkan Pengaman Target Harian
input double              InpDailyTargetPercent    = 15.0;                  // Target Profit Harian (15% dari Total Wallet)
input double              InpDailyMaxLossPercent   = 15.0;                  // Batas Rem Rugi Harian (15% dari Total Wallet)

//--- Dynamic Runtime Cloud Variables
string                    g_current_version        = "6.00";
double                    g_balance_step           = 500.0;
double                    g_lot_step               = 0.01;
int                       g_sl_points              = 120;
int                       g_tp_points              = 200;
int                       g_max_spread             = 80;
int                       g_max_open_pos           = 3;
int                       g_min_layer_dist         = 30;
bool                      g_use_trailing           = true;
int                       g_trailing_start         = 100;
int                       g_trailing_dist          = 60;
int                       g_trailing_step          = 15;
bool                      g_use_daily_guard        = false;
double                    g_daily_target_pct       = 15.0;
double                    g_daily_max_loss_pct     = 15.0;

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

//--- Indicator Handles H4/H1 (Swing Sentinel)
int handle_ema50_h4   = INVALID_HANDLE;
int handle_ema200_h4  = INVALID_HANDLE;
int handle_rsi_h4     = INVALID_HANDLE;
int handle_ema21_h1   = INVALID_HANDLE;
int handle_atr_h4     = INVALID_HANDLE;

datetime last_scalp_time = 0;
datetime last_swing_time = 0;
datetime m_last_cloud_sync_time = 0;
datetime g_last_heartbeat_time = 0;
datetime g_cooldown_until = 0;
int      g_consecutive_losses = 0;

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

STrackedPos g_tracked_positions[];
ulong g_notified_deals[];

//--- Account Metadata Cache
string g_account_display_id = "";
string g_account_company    = "";
string g_account_server     = "";
long   g_account_login      = 0;
string g_account_trade_mode = "";

//+------------------------------------------------------------------+
//| HELPER: GENERATE ACCOUNT IDENTIFIER STRING                       |
//+------------------------------------------------------------------+
void InitAccountMetadata()
{
   g_account_login      = AccountInfoInteger(ACCOUNT_LOGIN);
   g_account_company    = AccountInfoString(ACCOUNT_COMPANY);
   g_account_server     = AccountInfoString(ACCOUNT_SERVER);
   g_account_trade_mode = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL) ? "REAL" : "DEMO";

   g_account_display_id = StringFormat("%s [#%d • %s (%s)]", InpAccountTag, g_account_login, g_account_company, g_account_trade_mode);
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
//| FUNGSI PENGIRIM DISCORD WEBHOOK                                  |
//+------------------------------------------------------------------+
void SendDiscordEmbed(string title, string description, int color_hex, string fields_json, bool is_critical=false)
{
   if(!InpEnableDiscord || InpDiscordWebhookURL == "") return;

   string content_header = "";
   if(is_critical && InpDiscordMention != "")
   {
      content_header = "\"content\": \"🚨 " + InpDiscordMention + " — **[APEX BRAIN HYBRID ALERT - " + InpAccountTag + "]**\", ";
   }

   string bot_name_with_tag = InpBotName + " [" + InpAccountTag + "]";

   string payload = "{" + content_header +
                    "\"username\": \"" + bot_name_with_tag + "\"," +
                    "\"embeds\": [{" +
                    "\"title\": \"" + title + "\"," +
                    "\"description\": \"" + description + "\"," +
                    "\"color\": " + IntegerToString(color_hex) + "," +
                    "\"fields\": [" + fields_json + "]," +
                    "\"footer\": {\"text\": \"Akun: " + InpAccountTag + " (#" + IntegerToString(g_account_login) + ") • v" + g_current_version + " • " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
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
//| FUNGSI SINKRONISASI CLOUD DARI GITHUB (OTA AUTO-UPDATE)          |
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
      
      if(cloud_version != "")
      {
         bool is_new_version = (cloud_version != g_current_version);
         g_current_version    = cloud_version;
         g_balance_step       = ExtractJsonNumber(json, "balance_per_step", InpBalanceStep);
         g_lot_step           = ExtractJsonNumber(json, "lot_per_step", InpFixedLot);
         g_sl_points          = (int)ExtractJsonNumber(json, "stop_loss_points", InpScalpBaseSLPoints);
         g_tp_points          = (int)ExtractJsonNumber(json, "take_profit_points", InpScalpBaseTPPoints);
         g_max_spread         = (int)ExtractJsonNumber(json, "max_spread_points", InpMaxSpreadPoints);
         g_max_open_pos       = (int)ExtractJsonNumber(json, "max_open_positions", InpMaxOpenScalp);
         g_min_layer_dist     = (int)ExtractJsonNumber(json, "min_layer_distance_points", InpMinLayerDistancePts);
         g_use_trailing       = ExtractJsonBool(json, "use_trailing_stop", InpScalpUseTrailing);
         g_use_daily_guard    = ExtractJsonBool(json, "use_daily_guard", InpUseDailyGuard);
         g_daily_target_pct   = ExtractJsonNumber(json, "daily_target_profit_percent", InpDailyTargetPercent);
         g_daily_max_loss_pct = ExtractJsonNumber(json, "daily_max_loss_percent", InpDailyMaxLossPercent);

         if(is_new_version && !is_initial)
         {
            double cur_bal = m_account.Balance();
            double target_usd = cur_bal * (g_daily_target_pct / 100.0);

            string update_fields = "{\"name\": \"🏷️ Account Tag\", \"value\": \"`" + InpAccountTag + "` (#" + IntegerToString(g_account_login) + ")\", \"inline\": true}," +
                                   "{\"name\": \"🧠 Brain Engine\", \"value\": \"`v" + g_current_version + " (Hybrid Scalp + Swing)`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target Harian\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (" + DoubleToString(g_daily_target_pct, 0) + "% Wallet)`\", \"inline\": true}," +
                                   "{\"name\": \"⚡ Mesin 1 (Scalp M1)\", \"value\": \"`Tri-Layer Grid + Session VWAP`\", \"inline\": true}," +
                                   "{\"name\": \"🌊 Mesin 2 (Swing H4)\", \"value\": \"`H4 Trend Rider + Value Pullback`\", \"inline\": true}," +
                                   "{\"name\": \"📊 Sinkronisasi PnL\", \"value\": \"`100% Persis Tab History MT5`\", \"inline\": true}";
            
            SendDiscordEmbed("🔄 OTA CLOUD UPDATE DIAPLIKASIKAN (v" + g_current_version + ")!", 
                             "Pembaruan konfigurasi cloud diterapkan otomatis ke akun " + InpAccountTag + "!", 
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
   double free_margin = m_account.MarginFree();
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

   string position_status = StringFormat("`⚡ %d Scalp M1 | 🌊 %d Swing H4`", scalp_count, swing_count);

   string ea_state = "🟢 DUAL-ENGINE AKTIF (Scalp + Swing)";
   if(TimeCurrent() < g_cooldown_until) ea_state = "⏳ COOLDOWN PAUSE (30 Mnt)";
   else if(g_cached_is_news_time) ea_state = "🚨 RED NEWS PAUSE";

   string heartbeat_fields = "{\"name\": \"🏷️ Account Tag & ID\", \"value\": \"**`" + InpAccountTag + "`** (`#" + IntegerToString(g_account_login) + " - " + g_account_company + "`)\", \"inline\": false}," +
                             "{\"name\": \"🏦 Saldo / Equity\", \"value\": \"`$" + DoubleToString(balance, 2) + " / $" + DoubleToString(equity, 2) + "`\", \"inline\": true}," +
                             "{\"name\": \"🏆 PnL Hari Ini (History)\", \"value\": \"`" + ((daily_pnl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_pnl), 2) + "`\", \"inline\": true}," +
                             "{\"name\": \"🛡️ Margin Level\", \"value\": \"`" + DoubleToString(margin_level, 1) + "%` (Free: $" + DoubleToString(free_margin, 2) + ")\", \"inline\": true}," +
                             "{\"name\": \"⚡ Posisi Berjalan\", \"value\": \"" + position_status + "\", \"inline\": true}," +
                             "{\"name\": \"🧠 Status Engine\", \"value\": \"`" + ea_state + "`\", \"inline\": true}," +
                             "{\"name\": \"📶 Versi & Mode\", \"value\": \"`v" + g_current_version + " • " + g_account_trade_mode + "`\", \"inline\": true}";

   SendDiscordEmbed("💓 FLEET HEARTBEAT MONITOR PULSE (" + InpAccountTag + ")", 
                    "Laporan status kesehatan dual-engine & performa akun real-time berjalan normal 100%.", 
                    0x2ECC71, heartbeat_fields, false);
}

//+------------------------------------------------------------------+
//| HITUNG SESSION VWAP (ZERO-BOTTLENECK CACHE)                      |
//+------------------------------------------------------------------+
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
         upper_band = vwap + 1.2 * std_dev;
         lower_band = vwap - 1.2 * std_dev;
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
//| KALKULASI LOT SCALPING (DEFEND-THE-BAG)                          |
//+------------------------------------------------------------------+
double CalculateScalpLotSize(double sl_points)
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
//| DETEKSI PENUTUPAN JUMAT MALAM & ROLLOVER                         |
//+------------------------------------------------------------------+
bool IsFridayWeekendCleanTime()
{
   if(!InpUseFridayAutoClean) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5 && dt.hour >= 14);
}

bool IsRolloverTime()
{
   if(!InpUseRolloverGuard) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return ((dt.hour == 23 && dt.min >= 50) || (dt.hour == 0) || (dt.hour == 1 && dt.min <= 10));
}

void CloseAllPositionsForWeekend()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && (m_position.Magic() == InpMagicScalp || m_position.Magic() == InpMagicSwing))
         {
            m_trade.PositionClose(m_position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| KALKULASI ADAPTIF ATR SL & TP SCALPING                           |
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
      calc_tp = (int)MathMax(150, MathMin(280, atr_points * 2.5));
   }
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI OPEN TRADE DISCORD (HYBRID SCALP / SWING)      |
//+------------------------------------------------------------------+
void NotifyAITrade(string engine, string type, double price, double lot_used, double sl, double tp, ulong ticket, string trigger_source, int spread_used, int current_layers, int sl_pts, int tp_pts)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";
   string engine_badge = (engine == "SWING") ? "🌊 **[SWING RUNNER H4]**" : "⚡ **[SCALP M1 FAST]**";

   if(engine == "SWING") embed_color = (type == "BUY") ? 0x9B59B6 : 0xE67E22;

   string fields = "{\"name\": \"🏷️ Account Tag\", \"value\": \"**`" + InpAccountTag + "`** (`#" + IntegerToString(g_account_login) + " • " + g_account_company + "`)\", \"inline\": false}," +
                   "{\"name\": \"🏛️ Mesin Eksekusi\", \"value\": \"" + engine_badge + "\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Layer " + IntegerToString(current_layers) + ")**\", \"inline\": true}," +
                   "{\"name\": \"⚡ Pemicu Sinyal\", \"value\": \"`" + trigger_source + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (**" + DoubleToString(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(sl_pts / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(tp_pts / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Spread Saat Entry\", \"value\": \"`" + IntegerToString(spread_used) + " Points` (Aman)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed(engine_badge + " " + type + " EXECUTED!", 
                    "Eksekusi posisi pada akun " + InpAccountTag + " (" + engine + " Engine).", 
                    embed_color, 
                    fields, false);
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI CLOSE TRADE DISCORD (HYBRID SCALP / SWING)     |
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
         g_cooldown_until = TimeCurrent() + 30 * 60;
         string cooldown_fields = "{\"name\": \"🏷️ Account Tag\", \"value\": \"`" + InpAccountTag + "` (#" + IntegerToString(g_account_login) + ")\", \"inline\": true}," +
                                  "{\"name\": \"⚠️ Rem Pengaman\", \"value\": \"`2x Loss Beruntun Terdeteksi`\", \"inline\": true}," +
                                  "{\"name\": \"⏳ Durasi Cooldown\", \"value\": \"`30 Menit (Hingga " + TimeToString(g_cooldown_until, TIME_MINUTES) + ")`\", \"inline\": true}," +
                                  "{\"name\": \"🏦 Saldo Diamankan\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}";
         SendDiscordEmbed("🛡️ CONSECUTIVE LOSS CIRCUIT BREAKER AKTIF (" + InpAccountTag + ")!", 
                          "Mesin Scalping istirahat 30 menit untuk mendinginkan akun " + InpAccountTag + ".", 
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
   string engine_label = (engine == "SWING") ? "🌊 SWING RUNNER H4" : "⚡ SCALP M1";

   string fields = "{\"name\": \"🏷️ Account Tag\", \"value\": \"**`" + InpAccountTag + "`** (`#" + IntegerToString(g_account_login) + " • " + g_account_company + "`)\", \"inline\": false}," +
                   "{\"name\": \"🏛️ Mesin Eksekusi\", \"value\": \"`" + engine_label + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Hasil Transaksi\", \"value\": \"" + result_emoji + "\", \"inline\": true}," +
                   "{\"name\": \"💵 Realized PnL\", \"value\": \"**" + pnl_sign + DoubleToString(abs_profit, 2) + "**\", \"inline\": true}," +
                   "{\"name\": \"🏦 Saldo Akun Terkini\", \"value\": \"**`$" + DoubleToString(current_balance, 2) + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Posisi Ditutup\", \"value\": \"`" + type + " " + _Symbol + " (" + DoubleToString(volume, 2) + " Lot)`\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Close\", \"value\": \"`" + DoubleToString(close_price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🏆 Total PnL Hari Ini\", \"value\": \"`" + ((daily_total_pl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_total_pl), 2) + "` (Sama persis Tab History)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Deal Ticket\", \"value\": \"`#" + IntegerToString(deal_ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("🏁 POSISI " + engine + " DITUTUP (" + ((profit >= 0) ? "PROFIT" : "LOSS") + ")", 
                    "Posisi " + engine + " pada akun " + InpAccountTag + " telah resmi ditutup.", 
                    embed_color, 
                    fields, (profit < -30.0));
}

//+------------------------------------------------------------------+
//| EVENT ON TRADE TRANSACTION                                       |
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
   m_trade.SetDeviationInPoints(30);

   InitAccountMetadata();

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

   // Handle Swing H4 / H1
   handle_ema50_h4   = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema200_h4  = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   handle_rsi_h4     = iRSI(_Symbol, PERIOD_H4, 14, PRICE_CLOSE);
   handle_ema21_h1   = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   handle_atr_h4     = iATR(_Symbol, PERIOD_H4, 14);

   if(handle_ema5_m1 == INVALID_HANDLE || handle_ema13_m1 == INVALID_HANDLE ||
      handle_stoch_m1 == INVALID_HANDLE || handle_bb_m1 == INVALID_HANDLE ||
      handle_atr_m1 == INVALID_HANDLE || handle_ema50_m15 == INVALID_HANDLE ||
      handle_ema50_h4 == INVALID_HANDLE || handle_ema200_h4 == INVALID_HANDLE ||
      handle_rsi_h4 == INVALID_HANDLE || handle_ema21_h1 == INVALID_HANDLE ||
      handle_atr_h4 == INVALID_HANDLE)
   {
      Print("[ERROR] Gagal inisialisasi indikator Hybrid Brain EA!");
      return INIT_FAILED;
   }

   EventSetTimer(1);

   double current_bal = m_account.Balance();
   double target_usd = current_bal * (g_daily_target_pct / 100.0);
   double current_lot = CalculateScalpLotSize(g_sl_points);
   double current_daily_pnl = GetDailyProfitLoss(true);

   string startup_fields = "{\"name\": \"🏷️ Account Tag & Login\", \"value\": \"**`" + InpAccountTag + "`** (`#" + IntegerToString(g_account_login) + " - " + g_account_company + "`)\", \"inline\": false}," +
                           "{\"name\": \"🧠 Unified Brain Engine\", \"value\": \"`v" + g_current_version + " (Dual-Engine Hybrid)`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Cuan Harian\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (15% Wallet)`\", \"inline\": true}," +
                           "{\"name\": \"🏆 PnL Hari Ini (History)\", \"value\": \"`" + ((current_daily_pnl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(current_daily_pnl), 2) + "`\", \"inline\": true}," +
                           "{\"name\": \"⚡ Mesin 1: Scalp M1\", \"value\": \"`Tri-Layer Grid + Dynamic ATR`\", \"inline\": true}," +
                           "{\"name\": \"🌊 Mesin 2: Swing H4\", \"value\": \"`Macro Trend Rider + 1:2 RR`\", \"inline\": true}," +
                           "{\"name\": \"📈 Auto-Lot Mode\", \"value\": \"`$" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot` (Scalp: **" + DoubleToString(current_lot, 2) + "**)\", \"inline\": true}";

   SendDiscordEmbed("🧠 XAUUSD AI Brain Master Aktif (v6.00 Hybrid Sovereign)! 🚀", 
                    "Mesin Dual-Engine (M1 Fast Scalp + H4 Macro Swing) pada akun [" + InpAccountTag + "] siap memanen market!", 
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
   IndicatorRelease(handle_ema21_h1);
   IndicatorRelease(handle_atr_h4);
   Comment("");
}

//+------------------------------------------------------------------+
//| EVENT ON TIMER                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   datetime now = TimeCurrent();

   if(now - m_last_cloud_sync_time >= InpSyncIntervalMin * 60)
   {
      FetchAndApplyCloudConfig(false);
      m_last_cloud_sync_time = now;
   }

   if(InpEnableHeartbeat && (now - g_last_heartbeat_time >= InpHeartbeatIntervalHours * 3600))
   {
      SendFleetHeartbeatPulse();
      g_last_heartbeat_time = now;
   }

   static datetime last_fallback_close = 0;
   if(now - last_fallback_close >= 5)
   {
      CheckPositionClosures();
      last_fallback_close = now;
   }
}

//+------------------------------------------------------------------+
//| ON-CHART DASHBOARD APEX HYBRID MASTER                            |
//+------------------------------------------------------------------+
void DisplayAIDashboard(double ema5, double ema13, double stoch_k, double stoch_d, double vwap, double vwap_up, double vwap_low, string regime_label, string scalp_status, string swing_status, int dyn_sl, int dyn_tp, int scalp_total, int scalp_buy, int scalp_sell, int swing_total, int swing_buy, int swing_sell)
{
   long current_spread = m_symbol.Spread();
   string spread_status = (current_spread <= g_max_spread) ? "[AMAN ✅]" : "[TERLALU TINGGI 🚫]";
   
   if(IsHighImpactNewsTime()) spread_status = "[🚨 RED NEWS SHIELD PAUSE]";
   else if(IsFridayWeekendCleanTime()) spread_status = "[📅 FRIDAY WEEKEND PAUSE]";
   else if(IsRolloverTime()) spread_status = "[⏸️ ROLLOVER PAUSE]";
   else if(TimeCurrent() < g_cooldown_until) spread_status = "[⏳ LOSS COOLDOWN PAUSE]";
   
   double cur_bal = m_account.Balance();
   if(cur_bal <= 0) cur_bal = m_account.Equity();

   double dynamic_target_usd = cur_bal * (g_daily_target_pct / 100.0);
   double daily_pl = GetDailyProfitLoss();
   double lot = CalculateScalpLotSize(dyn_sl);

   string info = "=========================================================\n";
   info += "     🧠 XAUUSD APEX BRAIN MASTER (HYBRID DUAL-ENGINE) v" + g_current_version + "\n";
   info += "=========================================================\n";
   info += StringFormat(" 🏷️ Account ID       : %s\n", g_account_display_id);
   info += StringFormat(" 💰 Balance / Equity : $%.2f / $%.2f\n", m_account.Balance(), m_account.Equity());
   info += StringFormat(" 🏆 Profit Hari Ini  : %s$%.2f (Tab History MT5)\n", (daily_pl >= 0) ? "+" : "-", MathAbs(daily_pl));
   info += StringFormat(" 🎯 Target 15%% Cuan  : +$%.2f (Kunci Profit)\n", dynamic_target_usd);
   info += "---------------------------------------------------------\n";
   info += " [⚡ ENGINE 1: SCALPING M1 FAST SNIPER]\n";
   info += StringFormat("  ⚡ Posisi Scalp     : %d/%d Posisi (%d BUY, %d SELL)\n", scalp_total, InpMaxOpenScalp, scalp_buy, scalp_sell);
   info += StringFormat("  📈 M1 Momentum     : EMA5 (%.2f) vs EMA13 (%.2f) -> %s\n", ema5, ema13, (ema5 > ema13) ? "BULLISH 🟢" : "BEARISH 🔴");
   info += StringFormat("  ⚡ Fast Stoch (5,3): K=%.1f | D=%.1f (%s)\n", stoch_k, stoch_d, (stoch_k < 35) ? "OVERSOLD 🟢" : (stoch_k > 65) ? "OVERBOUGHT 🔴" : "NEUTRAL ⚪");
   info += StringFormat("  📊 Session VWAP    : %.2f (Diskon: <%.2f | Premium: >%.2f)\n", vwap, vwap_low, vwap_up);
   info += StringFormat("  🎯 Status Scalp    : %s\n", scalp_status);
   info += "---------------------------------------------------------\n";
   info += " [🌊 ENGINE 2: SWING RUNNER H4 SENTINEL]\n";
   info += StringFormat("  🌊 Posisi Swing    : %d/%d Posisi (%d BUY, %d SELL)\n", swing_total, InpMaxOpenSwing, swing_buy, swing_sell);
   info += StringFormat("  🎯 Status Swing    : %s\n", swing_status);
   info += "---------------------------------------------------------\n";
   info += StringFormat(" 🛡️ Spread Gold      : %d pts (Max: %d pts) %s\n", current_spread, g_max_spread, spread_status);
   info += " 📡 Discord Sentinel : TERHUBUNG (Hybrid Fleet Alerts) ✅\n";
   info += "=========================================================\n";

   Comment(info);
}

//+------------------------------------------------------------------+
//| MANAJEMEN POSISI SCALPING & SWING (FAST BE & TRAILING)           |
//+------------------------------------------------------------------+
void ManageOpenPositions(int active_scalp_buy, int active_scalp_sell)
{
   double point = m_symbol.Point();

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

      // 1. MANAJEMEN POSISI SCALPING (Magic: InpMagicScalp)
      if(magic == InpMagicScalp)
      {
         if(m_position.PositionType() == POSITION_TYPE_BUY)
         {
            double profit_points = (current_bid - open_price) / point;

            // Multi-Stage TP Layer 2/3 di +12 pips
            if(active_scalp_buy >= 2 && profit_points >= 120)
            {
               if(StringFind(m_position.Comment(), "Layer_2") != -1 || StringFind(m_position.Comment(), "Layer_3") != -1)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionClose(ticket);
                  continue;
               }
            }

            // Fast BE Scalping
            if(InpScalpUseBE && profit_points >= InpScalpBETriggerPoints)
            {
               double be_sl = m_symbol.NormalizePrice(open_price + InpScalpBEProfitPoints * point);
               if(current_sl < be_sl)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionModify(ticket, be_sl, current_tp);
               }
            }

            // Fast Trailing Scalping
            if(g_use_trailing && profit_points >= g_trailing_start)
            {
               double new_sl = m_symbol.NormalizePrice(current_bid - g_trailing_dist * point);
               if(new_sl > current_sl + g_trailing_step * point)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL)
         {
            double profit_points = (open_price - current_ask) / point;

            // Multi-Stage TP Layer 2/3 di +12 pips
            if(active_scalp_sell >= 2 && profit_points >= 120)
            {
               if(StringFind(m_position.Comment(), "Layer_2") != -1 || StringFind(m_position.Comment(), "Layer_3") != -1)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionClose(ticket);
                  continue;
               }
            }

            // Fast BE Scalping
            if(InpScalpUseBE && profit_points >= InpScalpBETriggerPoints)
            {
               double be_sl = m_symbol.NormalizePrice(open_price - InpScalpBEProfitPoints * point);
               if(current_sl == 0 || current_sl > be_sl)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionModify(ticket, be_sl, current_tp);
               }
            }

            // Fast Trailing Scalping
            if(g_use_trailing && profit_points >= g_trailing_start)
            {
               double new_sl = m_symbol.NormalizePrice(current_ask + g_trailing_dist * point);
               if(current_sl == 0 || new_sl < current_sl - g_trailing_step * point)
               {
                  m_trade.SetExpertMagicNumber(InpMagicScalp);
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
      }
      // 2. MANAJEMEN POSISI SWING RUNNER (Magic: InpMagicSwing)
      else if(magic == InpMagicSwing)
      {
         if(m_position.PositionType() == POSITION_TYPE_BUY)
         {
            double profit_points = (current_bid - open_price) / point;

            // BE Swing (+18 pips -> SL dipindah ke +3 pips)
            if(InpSwingUseBE && profit_points >= InpSwingBETriggerPoints)
            {
               double be_sl = m_symbol.NormalizePrice(open_price + InpSwingBEProfitPoints * point);
               if(current_sl < be_sl)
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, be_sl, current_tp);
               }
            }

            // Trailing Stop Jarak Jauh Swing (+25 pips start, 15 pips trailing distance)
            if(InpSwingUseTrailing && profit_points >= InpSwingTrailingStart)
            {
               double new_sl = m_symbol.NormalizePrice(current_bid - InpSwingTrailingDist * point);
               if(new_sl > current_sl + InpSwingTrailingStep * point)
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, new_sl, current_tp);
               }
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL)
         {
            double profit_points = (open_price - current_ask) / point;

            // BE Swing (+18 pips -> SL dipindah ke +3 pips)
            if(InpSwingUseBE && profit_points >= InpSwingBETriggerPoints)
            {
               double be_sl = m_symbol.NormalizePrice(open_price - InpSwingBEProfitPoints * point);
               if(current_sl == 0 || current_sl > be_sl)
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, be_sl, current_tp);
               }
            }

            // Trailing Stop Jarak Jauh Swing (+25 pips start, 15 pips trailing distance)
            if(InpSwingUseTrailing && profit_points >= InpSwingTrailingStart)
            {
               double new_sl = m_symbol.NormalizePrice(current_ask + InpSwingTrailingDist * point);
               if(current_sl == 0 || new_sl < current_sl - InpSwingTrailingStep * point)
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
//| VALIDASI JARAK MINIMAL ANTAR LAYER SCALPING                      |
//+------------------------------------------------------------------+
bool IsScalpLayerDistanceValid(ENUM_ORDER_TYPE order_type, double entry_price)
{
   double point = m_symbol.Point();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicScalp)
         {
            double pos_price = m_position.PriceOpen();
            double dist_pts  = MathAbs(entry_price - pos_price) / point;

            if(dist_pts < g_min_layer_dist) return false;
         }
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| EKSEKUSI ORDER SCALPING M1                                       |
//+------------------------------------------------------------------+
void ExecuteScalpOrder(ENUM_ORDER_TYPE order_type, string trigger_source, int current_active_count, int dyn_sl_pts, int dyn_tp_pts)
{
   double point = m_symbol.Point();
   double lot   = CalculateScalpLotSize(dyn_sl_pts);
   if(lot <= 0) return;

   int current_spread = (int)m_symbol.Spread();
   string comment_label = StringFormat("%s_L%d", InpCommentScalp, current_active_count + 1);

   m_trade.SetExpertMagicNumber(InpMagicScalp);

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      if(!IsScalpLayerDistanceValid(ORDER_TYPE_BUY, ask)) return;

      double sl  = (dyn_sl_pts > 0) ? (ask - dyn_sl_pts * point) : 0;
      double tp  = (dyn_tp_pts > 0) ? (ask + dyn_tp_pts * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, comment_label))
      {
         Print("🚀 [SCALP BUY EXECUTED - Layer ", current_active_count + 1, "/3] Akun: ", InpAccountTag, " | Trigger: ", trigger_source, " | Lot: ", lot);
         NotifyAITrade("SCALP", "BUY", ask, lot, sl, tp, m_trade.ResultOrder(), trigger_source, current_spread, current_active_count + 1, dyn_sl_pts, dyn_tp_pts);
         last_scalp_time = TimeCurrent();
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      if(!IsScalpLayerDistanceValid(ORDER_TYPE_SELL, bid)) return;

      double sl  = (dyn_sl_pts > 0) ? (bid - dyn_sl_pts * point) : 0;
      double tp  = (dyn_tp_pts > 0) ? (bid - dyn_tp_pts * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, comment_label))
      {
         Print("🚀 [SCALP SELL EXECUTED - Layer ", current_active_count + 1, "/3] Akun: ", InpAccountTag, " | Trigger: ", trigger_source, " | Lot: ", lot);
         NotifyAITrade("SCALP", "SELL", bid, lot, sl, tp, m_trade.ResultOrder(), trigger_source, current_spread, current_active_count + 1, dyn_sl_pts, dyn_tp_pts);
         last_scalp_time = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| EKSEKUSI ORDER SWING H4                                          |
//+------------------------------------------------------------------+
void ExecuteSwingOrder(ENUM_ORDER_TYPE order_type, string trigger_source)
{
   double point = m_symbol.Point();
   double lot   = InpSwingFixedLot;
   if(lot <= 0) lot = 0.01;

   int current_spread = (int)m_symbol.Spread();
   string comment_label = InpCommentSwing;

   m_trade.SetExpertMagicNumber(InpMagicSwing);

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      double sl  = (InpSwingSLPoints > 0) ? (ask - InpSwingSLPoints * point) : 0;
      double tp  = (InpSwingTPPoints > 0) ? (ask + InpSwingTPPoints * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, comment_label))
      {
         Print("🌊 [SWING BUY EXECUTED] Akun: ", InpAccountTag, " | Trigger: ", trigger_source, " | Lot: ", lot);
         NotifyAITrade("SWING", "BUY", ask, lot, sl, tp, m_trade.ResultOrder(), trigger_source, current_spread, 1, InpSwingSLPoints, InpSwingTPPoints);
         last_swing_time = TimeCurrent();
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      double sl  = (InpSwingSLPoints > 0) ? (bid + InpSwingSLPoints * point) : 0;
      double tp  = (InpSwingTPPoints > 0) ? (bid - InpSwingTPPoints * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, comment_label))
      {
         Print("🌊 [SWING SELL EXECUTED] Akun: ", InpAccountTag, " | Trigger: ", trigger_source, " | Lot: ", lot);
         NotifyAITrade("SWING", "SELL", bid, lot, sl, tp, m_trade.ResultOrder(), trigger_source, current_spread, 1, InpSwingSLPoints, InpSwingTPPoints);
         last_swing_time = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| ON TICK EXECUTION (UNIFIED DUAL-ENGINE)                          |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!m_symbol.RefreshRates()) return;

   // 1. Perisai Jumat Malam
   if(IsFridayWeekendCleanTime())
   {
      CloseAllPositionsForWeekend();
   }

   // 2. SCAN TUNGGAL POSISI AKTIF (Zero-Bottleneck)
   int scalp_total = 0, scalp_buy = 0, scalp_sell = 0;
   int swing_total = 0, swing_buy = 0, swing_sell = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            if(m_position.Magic() == InpMagicScalp)
            {
               scalp_total++;
               if(m_position.PositionType() == POSITION_TYPE_BUY) scalp_buy++;
               else if(m_position.PositionType() == POSITION_TYPE_SELL) scalp_sell++;
            }
            else if(m_position.Magic() == InpMagicSwing)
            {
               swing_total++;
               if(m_position.PositionType() == POSITION_TYPE_BUY) swing_buy++;
               else if(m_position.PositionType() == POSITION_TYPE_SELL) swing_sell++;
            }
         }
      }
   }

   // 3. Eksekusi Proteksi Posisi (Scalp & Swing)
   if(scalp_total > 0 || swing_total > 0)
   {
      ManageOpenPositions(scalp_buy, scalp_sell);
   }

   // 4. Update Asian Range & Hitung Session VWAP Bands
   UpdateAsianRange();
   double vwap = 0.0, vwap_up = 0.0, vwap_low = 0.0;
   CalculateSessionVWAP(vwap, vwap_up, vwap_low);

   // 5. Hitung Dynamic ATR SL & TP Scalping
   int dyn_sl_pts = g_sl_points;
   int dyn_tp_pts = g_tp_points;
   CalculateDynamicSLTP(dyn_sl_pts, dyn_tp_pts);

   // 6. Ambil Data Candlestick M1 Terkini
   MqlRates rates_m1[];
   ArraySetAsSeries(rates_m1, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates_m1) < 5) return;

   // 7. Ambil Buffer Indikator M1 Fast
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

   // 8. Analisis Anatomi Bar 1
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
   // 9. EVALUASI MESIN 1: SCALPING M1 FAST SNIPER
   // =================================================================
   bool scalp_buy_sig = false;
   bool scalp_sell_sig = false;
   string scalp_reason = "";

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool is_london_session = (dt.hour >= 7 && dt.hour <= 12);

   // Pemicu Scalp 1: Asian Sweep
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

   // Pemicu Scalp 2: Session VWAP Bands
   if(!scalp_buy_sig && !scalp_sell_sig && InpUseSessionVWAP)
   {
      if(rates_m1[0].close <= vwap_low && (is_bullish_pinbar || is_bullish_engulf || stoch_k < 25))
      {
         scalp_buy_sig = true; scalp_reason = "Session VWAP Discount (< -1.2 SD)";
      }
      else if(rates_m1[0].close >= vwap_up && (is_bearish_pinbar || is_bearish_engulf || stoch_k > 75))
      {
         scalp_sell_sig = true; scalp_reason = "Session VWAP Premium (> +1.2 SD)";
      }
   }

   // Pemicu Scalp 3: Micro-Pullback Sniper (EMA 5/13 Dip)
   if(!scalp_buy_sig && !scalp_sell_sig)
   {
      if(ema5_curr > ema13_curr && (rates_m1[0].low <= ema13_curr || rates_m1[1].low <= ema13_curr) && rates_m1[0].close >= ema5_curr && (stoch_k > stoch_d || is_bullish_pinbar))
      {
         if(!InpUseTripleScreen || rates_m1[0].close >= macro_ema50)
         {
            scalp_buy_sig = true; scalp_reason = "M1 Micro-Pullback Dip to EMA13";
         }
      }
      else if(ema5_curr < ema13_curr && (rates_m1[0].high >= ema13_curr || rates_m1[1].high >= ema13_curr) && rates_m1[0].close <= ema5_curr && (stoch_k < stoch_d || is_bearish_pinbar))
      {
         if(!InpUseTripleScreen || rates_m1[0].close <= macro_ema50)
         {
            scalp_sell_sig = true; scalp_reason = "M1 Micro-Pullback Rally to EMA13";
         }
      }
   }

   // Pemicu Scalp 4: Fast Stoch Hook
   if(!scalp_buy_sig && !scalp_sell_sig)
   {
      if((prev_stoch_k <= 30 && stoch_k > prev_stoch_k && stoch_k > stoch_d) && (bar1_low <= bb_low || rates_m1[0].low <= bb_low || is_bullish_pinbar))
      {
         scalp_buy_sig = true; scalp_reason = "Fast Stoch Hook Oversold (< 30)";
      }
      else if((prev_stoch_k >= 70 && stoch_k < prev_stoch_k && stoch_k < stoch_d) && (bar1_high >= bb_up || rates_m1[0].high >= bb_up || is_bearish_pinbar))
      {
         scalp_sell_sig = true; scalp_reason = "Fast Stoch Hook Overbought (> 70)";
      }
   }

   // =================================================================
   // 10. EVALUASI MESIN 2: SWING RUNNER H4 (SENTINEL MACRO RIDER)
   // =================================================================
   bool swing_buy_sig = false;
   bool swing_sell_sig = false;
   string swing_reason = "";

   if(InpEnableSwingEngine && (TimeCurrent() - g_last_swing_eval_time >= 60))
   {
      double ema50_h4_buf[], ema200_h4_buf[], rsi_h4_buf[], ema21_h1_buf[];
      ArraySetAsSeries(ema50_h4_buf, true);
      ArraySetAsSeries(ema200_h4_buf, true);
      ArraySetAsSeries(rsi_h4_buf, true);
      ArraySetAsSeries(ema21_h1_buf, true);

      if(CopyBuffer(handle_ema50_h4, 0, 0, 2, ema50_h4_buf) > 0 &&
         CopyBuffer(handle_ema200_h4, 0, 0, 2, ema200_h4_buf) > 0 &&
         CopyBuffer(handle_rsi_h4, 0, 0, 2, rsi_h4_buf) > 0 &&
         CopyBuffer(handle_ema21_h1, 0, 0, 2, ema21_h1_buf) > 0)
      {
         double ema50_h4  = ema50_h4_buf[0];
         double ema200_h4 = ema200_h4_buf[0];
         double rsi_h4    = rsi_h4_buf[0];
         double ema21_h1  = ema21_h1_buf[0];
         double ask_price = m_symbol.Ask();
         double bid_price = m_symbol.Bid();

         // SWING BUY: H4 Bullish Golden Cross (EMA50 > EMA200) + RSI Pullback (40 - 58) + Harga memantul di EMA 21 H1
         if(ema50_h4 > ema200_h4 && rsi_h4 >= 40.0 && rsi_h4 <= 58.0 && ask_price >= ema21_h1)
         {
            if(swing_total < InpMaxOpenSwing && swing_buy == 0)
            {
               swing_buy_sig = true;
               swing_reason = "H4 Bullish Macro Trend + H1 EMA21 Value Pullback";
            }
         }
         // SWING SELL: H4 Bearish Death Cross (EMA50 < EMA200) + RSI Pullback (42 - 60) + Harga tertolak di EMA 21 H1
         else if(ema50_h4 < ema200_h4 && rsi_h4 >= 42.0 && rsi_h4 <= 60.0 && bid_price <= ema21_h1)
         {
            if(swing_total < InpMaxOpenSwing && swing_sell == 0)
            {
               swing_sell_sig = true;
               swing_reason = "H4 Bearish Macro Trend + H1 EMA21 Value Pullback";
            }
         }
      }
      g_last_swing_eval_time = TimeCurrent();
   }

   // 11. Update Dashboard On-Chart
   string scalp_status = "STANDBY HUNTING M1...";
   if(IsHighImpactNewsTime()) scalp_status = "🚨 RED NEWS PAUSE (CPI/NFP/FOMC)";
   else if(IsFridayWeekendCleanTime()) scalp_status = "📅 FRIDAY WEEKEND PAUSE (21:00+)";
   else if(IsRolloverTime()) scalp_status = "⏸️ ROLLOVER TIME PAUSE (23:50-01:10)";
   else if(TimeCurrent() < g_cooldown_until) scalp_status = "⏳ LOSS COOLDOWN (30 Mnt Pause)";
   else if(scalp_buy_sig) scalp_status = "🟢 APEX BUY DETECTED! (" + scalp_reason + ")";
   else if(scalp_sell_sig) scalp_status = "🔴 APEX SELL DETECTED! (" + scalp_reason + ")";

   string swing_status = "STANDBY MONITORING H4...";
   if(swing_buy_sig) swing_status = "🟢 SWING BUY DETECTED! (" + swing_reason + ")";
   else if(swing_sell_sig) swing_status = "🔴 SWING SELL DETECTED! (" + swing_reason + ")";
   else if(swing_total > 0) swing_status = StringFormat("🌊 RUNNING SWING (%d Posisi Aktif)", swing_total);

   DisplayAIDashboard(ema5_curr, ema13_curr, stoch_k, stoch_d, vwap, vwap_up, vwap_low, regime_str, scalp_status, swing_status, dyn_sl_pts, dyn_tp_pts, scalp_total, scalp_buy, scalp_sell, swing_total, swing_buy, swing_sell);

   // 12. Cek Proteksi Daily Target & Max Loss
   if(g_use_daily_guard)
   {
      double cur_bal = m_account.Balance();
      if(cur_bal <= 0) cur_bal = m_account.Equity();

      double dynamic_target_usd = cur_bal * (g_daily_target_pct / 100.0);
      double dynamic_max_loss_usd = cur_bal * (g_daily_max_loss_pct / 100.0);
      double daily_pl = GetDailyProfitLoss();

      if(daily_pl >= dynamic_target_usd || daily_pl <= -dynamic_max_loss_usd) return;
   }

   // 13. Perisai Filter Eksekusi Umum
   if(IsHighImpactNewsTime()) return;
   if(IsFridayWeekendCleanTime()) return;
   if(IsRolloverTime()) return;
   if(m_symbol.Spread() > g_max_spread) return;

   // 14. EKSEKUSI MESIN 2: SWING RUNNER H4 (Jika Sinyal Terbentuk)
   if(InpEnableSwingEngine && (TimeCurrent() - last_swing_time >= 300))
   {
      if(swing_buy_sig && swing_total < InpMaxOpenSwing)
      {
         ExecuteSwingOrder(ORDER_TYPE_BUY, swing_reason);
      }
      else if(swing_sell_sig && swing_total < InpMaxOpenSwing)
      {
         ExecuteSwingOrder(ORDER_TYPE_SELL, swing_reason);
      }
   }

   // 15. EKSEKUSI MESIN 1: SCALPING M1 FAST SNIPER
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
         ExecuteScalpOrder(ORDER_TYPE_BUY, scalp_reason, scalp_total, dyn_sl_pts, dyn_tp_pts);
      }
      else if(scalp_sell_sig)
      {
         ExecuteScalpOrder(ORDER_TYPE_SELL, scalp_reason, scalp_total, dyn_sl_pts, dyn_tp_pts);
      }
   }
}
