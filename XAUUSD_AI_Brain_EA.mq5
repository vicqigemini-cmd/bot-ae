//+------------------------------------------------------------------+
//|                                     XAUUSD_AI_Brain_EA.mq5       |
//|  APEX SOVEREIGN CITADEL v23.00 (INSTITUTIONAL M15 SNIPER MODEL)  |
//|  (SMC FVG • Golden Pocket 50-61.8% • 1:2.5 RR • Anti-Rungkad)    |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX & AI Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "23.00"
#property description "Unified Master Brain EA v23.00 Institutional M15 Single-Entry Sniper Model: Structure-Based SL/TP (1:2.5 RR), M15 Smart Money Concepts (FVG & Liquidity Sweep), Golden Pocket 50-61.8% Fibonacci, True Zero-Loss Commission-Aware BE, Prop Firm 4% Trailing DD Guard, In-EA Autonomous Self-Updater, Global Nuclear Kill-Switch, Prominent Fleet ID."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#define CLOUD_CONFIG_URL "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/ea_cloud_config.json"
#define CLOUD_EX5_URL    "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/XAUUSD_AI_Brain_EA.ex5"

#import "kernel32.dll"
int CopyFileW(string lpExistingFileName, string lpNewFileName, int bFailIfExists);
#import

//--- Enums

enum ENUM_ASSET_CLASS
{
   ASSET_GOLD   = 0, // XAUUSD / GOLD (Logam Mulia)
   ASSET_FOREX  = 1, // EURUSD, GBPUSD, USDJPY, dll (Forex)
   ASSET_INDEX  = 2  // US30, NAS100, SP500, GER40 (Indeks Saham)
};
enum ENUM_LOT_TYPE
{
   LOT_RISK_PERCENT = 0, // Auto-Lot Berdasarkan % Risk Equity (Standar Institusional 1%)
   LOT_PER_BALANCE  = 1, // Auto-Lot Proporsional ($500 = 0.01 Lot)
   LOT_FIXED        = 2  // Fixed Lot Size (Lot Tetap)
};

struct STrackedPos
{
   ulong    ticket;
   string   engine_type;
   string   order_type;
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

struct SFairValueGap
{
   bool     exists;
   bool     is_bullish;
   double   upper_level;
   double   lower_level;
   datetime time_created;
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

input group "=== 3. OTA CLOUD AUTO-SYNC & AUTONOMOUS UPDATER ==="
input bool                InpEnableCloudSync       = true;                  // Aktifkan Sinkronisasi Cloud dari GitHub
input int                 InpSyncIntervalMin       = 5;                     // Interval Cek Update Cloud (Menit)
input bool                InpEnableAutoSelfUpdate  = true;                  // Aktifkan Autonomous In-EA Binary Self-Updater

input group "=== 4. ENGINE UTAMA: M15 INSTITUTIONAL SINGLE-ENTRY SNIPER ==="
input bool                InpEnableM15Sniper       = true;                  // Aktifkan Mesin Utama M15 Sniper (Anti-Rungkad)
input ulong               InpMagicSniper           = 202615;                // Magic Number M15 Sniper
input string              InpCommentSniper         = "Apex_M15_Sniper";     // Label Order Sniper
input ENUM_LOT_TYPE       InpLotType               = LOT_RISK_PERCENT;      // Metode Perhitungan Lot (Standar Institusi = 1% Risk)
input double              InpRiskPercent           = 1.0;                   // Risiko Maksimal per Trade (% Equity)
input double              InpFixedLot              = 0.01;                  // Fixed Lot jika Mode Lot Fixed
input double              InpBalanceStep           = 500.0;                 // Saldo per 0.01 Lot jika Mode Per Balance
input double              InpRiskRewardRatio       = 2.5;                   // Rasio Minimum Risk-to-Reward (1:2.5)
input int                 InpMinSLPoints           = 300;                   // SL Minimal Gold (Points, 300 pts = 30 pips / $3.00 Gold)
input int                 InpMaxSLPoints           = 600;                   // SL Maksimal Gold (Points, 600 pts = 60 pips / $6.00 Gold)
input bool                InpUseStructuralSL       = true;                  // SL Otomatis Berdasarkan Swing High/Low M15 Terdekat
input bool                InpUseGoldenFibPocket    = true;                  // Golden Pocket 50.0%-61.8% Retracement Filter
input bool                InpUseFVGFilter          = true;                  // Smart Money Concepts Fair Value Gap (FVG) Confluence
input bool                InpUseTrueZeroLossBE     = true;                  // True Zero-Loss Commission & Swap-Aware Breakeven
input int                 InpTrueBEExtraBufferPts  = 5;                     // Buffer Ekstra True-BE (Points)
input bool                InpUseM15Trailing        = true;                  // Trailing Stop M15 saat Profit Melampaui 1.5x Risk
input double              InpTrailingStartR        = 1.5;                   // Trailing Start (Kelipatan R, misal 1.5x SL)
input int                 InpTrailingDistPts       = 200;                   // Jarak Trailing (Points, 200 pts = 20 pips)
input int                 InpTrailingStepPts       = 50;                    // Step Trailing (Points, 50 pts = 5 pips)

input group "=== 5. ENGINE 2: SWING RUNNER H4 (GOLDEN POCKET 1:3 RR) ==="
input bool                InpEnableSwingEngine     = true;                  // Aktifkan Mesin Swing H4
input ulong               InpMagicSwing            = 202622;                // Magic Number Swing
input string              InpCommentSwing          = "Apex_H4_Swing";       // Label Order Swing
input double              InpSwingFixedLot         = 0.01;                  // Fixed Lot Size per Sub-Tiket Swing
input double              InpSwingMinADX           = 20.0;                  // Filter Kekuatan Tren Minimal (ADX H4 >= 20)
input int                 InpSwingMaxChasePts      = 250;                   // Jarak Maksimal dari EMA21 H1 (Anti-Late Chase, 25 pips)
input int                 InpSwingSLPoints         = 800;                   // SL Swing Institusional (800 pts = 80 pips / $8 Gold)
input int                 InpSwingTP1Points        = 800;                   // TP1 Quick Cuan (+80 pips untuk kunci modal)
input int                 InpSwingTP2RunnerPoints  = 2400;                  // TP2 Mega Runner (+240 pips / RR 1:3)
input bool                InpUseMultiTierSwingLock = true;                  // Multi-Tier Profit Lock (+120 pips -> Kunci +50 pips)
input int                 InpSwingBEProfitPoints   = 100;                   // Kunci Profit BE Swing (+10 pips)
input bool                InpSwingHoldWeekendIfBE  = true;                  // Izinkan Swing Menginap Weekend jika SL sudah BE
input bool                InpUseTripleSwapGuard    = true;                  // Proteksi Triple-Swap Rabu Malam (23:00 Server)

input group "=== 6. BENTENG PERISAI, PROP FIRM GUARD & FLEET DEFENSE ==="
input bool                InpUsePropFirmGuard      = true;                  // Prop Firm High-Watermark Drawdown Guard
input double              InpPropFirmMaxDailyDDPct = 4.0;                   // Max Daily Trailing Drawdown dari Peak Equity (%)
input bool                InpUseLossCircuitBreaker = true;                  // Rem Pengaman Rugi Beruntun (2x SL = Cooldown 5 Menit)
input int                 InpLossCooldownMinutes   = 5;                     // Durasi Rem Cooldown (HANYA 5 MENIT CEPAT)
input int                 InpMaxSpreadPoints       = 70;                    // Max Spread Filter (Points, 70 pts = 7 pips)
input bool                InpUseManualTradeGuard   = true;                  // Manual Entry Guard (Jeda Otomatis EA jika Ada Trade Manual)
input bool                InpEnableWeekendDigest   = true;                  // Kirim Laporan Rekapitulasi Mingguan Setiap Sabtu Pagi
input bool                InpUseDefendTheBag       = true;                  // Defend-The-Bag (Kunci Cuan Harian >= 8% Wallet)
input double              InpDefendBagProfitPct    = 8.0;                   // Ambang Defend-The-Bag Pangkas 50% Lot
input bool                InpUseWeeklyBagDefender  = true;                  // Weekly Bag Defender (Kunci Cuan Mingguan >= 20% Wallet)
input double              InpWeeklyBagProfitPct    = 20.0;                  // Ambang Cuan Mingguan Pangkas 50% Lot
input bool                InpUseRedNewsGuard       = true;                  // Perisai Berita Merah AS (CPI, NFP, FOMC)
input int                 InpNewsBufferMin         = 15;                    // Jeda Menit Sebelum & Sesudah Berita Merah
input bool                InpUseFridayAutoClean    = true;                  // Bersihkan Posisi Scalp Jumat Malam (21:00 Server)
input bool                InpUseRolloverGuard      = true;                  // Pelindung Jam Rollover Broker (23:50-01:10)


input group "=== 8. INSTITUTIONAL KILL-ZONES TIME ENGINE ==="
input bool                InpUseKillZonesOnly      = true;                  // Hanya Berburu di Jam Likuiditas Institusi (London & NY)
input bool                InpTradeLondonKZ         = true;                  // Aktifkan London Open Kill-Zone (07:00 - 11:00 Server)
input int                 InpLondonKZStartHour     = 7;                     // London KZ Start Hour (Server Time)
input int                 InpLondonKZEndHour       = 11;                    // London KZ End Hour (Server Time)
input bool                InpTradeNYKZ             = true;                  // Aktifkan New York Kill-Zone (13:00 - 17:00 Server)
input int                 InpNYKZStartHour         = 13;                    // NY KZ Start Hour (Server Time)
input int                 InpNYKZEndHour           = 17;                    // NY KZ End Hour (Server Time)
input bool                InpTradeAsianSession     = false;                 // Izinkan Trading di Sesi Asia (False = Standby Hindari Chop)


input group "=== 9. MULTI-PAIR PORTFOLIO & SHARED RISK MATRIX ==="
input bool                InpEnableMultiPairMode   = true;                  // Izinkan EA Beroperasi di Semua Pair (XAU, Forex, Index)
input double              InpMaxPortfolioRiskPct   = 2.0;                   // Batas Maksimal Total Risiko Terbuka Seluruh Portofolio (% Equity)
input int                 InpMaxTotalOpenTradesAll = 3;                     // Batas Maksimal Total Posisi Terbuka Seluruh Portofolio

//--- Dynamic Runtime Cloud Variables
string                    g_current_version        = "23.00";
string                    g_last_self_updated_ver  = "23.00";
double                    g_balance_step           = 500.0;
double                    g_lot_step               = 0.01;
int                       g_max_spread             = 70;
int                       g_loss_cooldown_min      = 5;
bool                      g_use_daily_guard        = false;
double                    g_daily_target_pct       = 15.0;
double                    g_daily_max_loss_pct     = 15.0;

//--- Global Variables
CTrade                    m_trade;
CPositionInfo             m_position;
CSymbolInfo               m_symbol;
CAccountInfo              m_account;
CHistoryOrderInfo         m_history;

// Handles Indikator M15, H1, H4
int                       handle_ema50_m15         = INVALID_HANDLE;
int                       handle_rsi_m15           = INVALID_HANDLE;
int                       handle_atr_m15           = INVALID_HANDLE;
int                       handle_ema50_h1          = INVALID_HANDLE;
int                       handle_ema21_h1          = INVALID_HANDLE;
int                       handle_ema50_h4          = INVALID_HANDLE;
int                       handle_ema200_h4         = INVALID_HANDLE;
int                       handle_rsi_h4            = INVALID_HANDLE;
int                       handle_adx_h4            = INVALID_HANDLE;
int                       handle_atr_h4            = INVALID_HANDLE;

// State Variables
datetime                  last_sniper_time         = 0;
datetime                  last_swing_time          = 0;
datetime                  g_last_m15_eval_bar      = 0;
datetime                  g_last_swing_eval_time   = 0;
datetime                  m_last_cloud_sync_time   = 0;
datetime                  g_last_heartbeat_time    = 0;
datetime                  g_cooldown_until         = 0;
int                       g_consecutive_losses     = 0;
bool                      g_emergency_kill_active  = false;
bool                      g_manual_trade_pause     = false;
ulong                     g_detected_manual_ticket = 0;
datetime                  g_last_weekend_digest_date = 0;

// Prop Firm Tracking
double                    g_daily_peak_equity      = 0.0;
datetime                  g_last_peak_day          = 0;
bool                      g_prop_firm_locked       = false;

// Caches & Structures
SFibLevels                g_cached_m15_fib;
datetime                  g_last_m15_fib_time      = 0;
SFibLevels                g_cached_h4_fib;
datetime                  g_last_h4_fib_time       = 0;
SFairValueGap             g_cached_m15_fvg;
datetime                  g_last_fvg_time          = 0;

// Unique Account ID & Arrays
string                    g_account_tag            = "";
ulong                     g_notified_deals[];
STrackedPos               g_tracked_positions[];

//+------------------------------------------------------------------+
//| HELPER: GENERATE CLEAN SHORT BROKER CODE                         |
//+------------------------------------------------------------------+
string GetCleanBrokerCode()
{
   string comp = m_account.Company();
   StringToUpper(comp);
   
   if(StringFind(comp, "EXNESS") >= 0) return "EXNESS";
   if(StringFind(comp, "XM") >= 0) return "XM";
   if(StringFind(comp, "OCTA") >= 0) return "OCTA";
   if(StringFind(comp, "IC MARKETS") >= 0 || StringFind(comp, "ICMARKETS") >= 0) return "ICM";
   if(StringFind(comp, "PEPPERSTONE") >= 0) return "PEPPER";
   if(StringFind(comp, "FBS") >= 0) return "FBS";
   if(StringFind(comp, "VANTAGE") >= 0) return "VANTAGE";
   if(StringFind(comp, "HFM") >= 0 || StringFind(comp, "HOTFOREX") >= 0) return "HFM";
   if(StringFind(comp, "FOREX4YOU") >= 0) return "F4U";
   if(StringFind(comp, "TICKMILL") >= 0) return "TICKMILL";
   if(StringFind(comp, "DERIV") >= 0) return "DERIV";
   if(StringFind(comp, "FTMO") >= 0) return "FTMO";
   if(StringFind(comp, "FUNDED") >= 0) return "FUNDED";
   
   string clean = "";
   for(int i = 0; i < StringLen(comp); i++)
   {
      ushort ch = StringGetCharacter(comp, i);
      if((ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'))
      {
         StringAdd(clean, ShortToString(ch));
         if(StringLen(clean) >= 6) break;
      }
   }
   if(StringLen(clean) == 0) clean = "BROKER";
   return clean;
}

//+------------------------------------------------------------------+
//| HELPER: INITIALIZE UNIQUE FINGERPRINT ID                         |
//+------------------------------------------------------------------+
void InitAccountMetadata()
{
   if(InpAccountTag == "AUTO" || InpAccountTag == "")
   {
      long login = m_account.Login();
      string broker = GetCleanBrokerCode();
      g_account_tag = StringFormat("ACC-%d-%s", login, broker);
   }
   else
   {
      g_account_tag = InpAccountTag;
   }
   Print("🏷️ [ACCOUNT IDENTITY] Unique Fleet Fingerprint ID: ", g_account_tag);
}

//+------------------------------------------------------------------+
//| RECOVER CONSECUTIVE LOSS STATE                                   |
//+------------------------------------------------------------------+
void RecoverConsecutiveLossesFromHistory()
{
   HistorySelect(TimeCurrent() - 86400, TimeCurrent() + 60);
   int total_deals = HistoryDealsTotal();
   g_consecutive_losses = 0;

   for(int i = total_deals - 1; i >= 0; i--)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket > 0)
      {
         long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

         string deal_sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_sym == _Symbol && (deal_magic == InpMagicSniper || deal_magic == InpMagicSwing) &&
            (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         {
            double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                            HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                            HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

            if(profit < 0)
            {
               g_consecutive_losses++;
            }
            else if(profit > 0)
            {
               break;
            }
         }
      }
   }

   if(g_consecutive_losses >= 2 && InpUseLossCircuitBreaker)
   {
      if(g_cooldown_until < TimeCurrent())
      {
         g_cooldown_until = TimeCurrent() + g_loss_cooldown_min * 60;
         Print("🛡️ [CIRCUIT BREAKER RECOVERED] Akun: ", g_account_tag, " | Cooldown aktif hingga: ", TimeToString(g_cooldown_until, TIME_MINUTES));
      }
   }
}

//+------------------------------------------------------------------+
//| HITUNG PROFIT / LOSS MINGGUAN                                    |
//+------------------------------------------------------------------+
double GetWeeklyProfitLoss()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int days_since_monday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   datetime monday_start = StringToTime(TimeToString(TimeCurrent() - days_since_monday * 86400, TIME_DATE) + " 00:00");

   HistorySelect(monday_start, TimeCurrent() + 60);
   int total_deals = HistoryDealsTotal();
   double total_profit = 0.0;

   for(int i = 0; i < total_deals; i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket > 0)
      {
         long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

         string deal_sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_sym == _Symbol && (deal_magic == InpMagicSniper || deal_magic == InpMagicSwing || deal_magic == 0) &&
            (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         {
            total_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                            HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                            HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         }
      }
   }
   return total_profit;
}

//+------------------------------------------------------------------+
//| HELPER PARSER JSON                                               |
//+------------------------------------------------------------------+
string ExtractJsonString(string json, string key, string default_val="")
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return default_val;
   pos += StringLen(search);

   while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\t')) pos++;

   if(pos < StringLen(json) && StringGetCharacter(json, pos) == '\"')
   {
      pos++;
      int end_pos = StringFind(json, "\"", pos);
      if(end_pos > pos) return StringSubstr(json, pos, end_pos - pos);
   }
   return default_val;
}

double ExtractJsonNumber(string json, string key, double default_val=0.0)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return default_val;
   pos += StringLen(search);

   while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\t')) pos++;

   string num_str = "";
   while(pos < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, pos);
      if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-')
      {
         StringAdd(num_str, ShortToString(ch));
         pos++;
      }
      else break;
   }
   if(StringLen(num_str) > 0) return StringToDouble(num_str);
   return default_val;
}

bool ExtractJsonBool(string json, string key, bool default_val=false)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return default_val;
   pos += StringLen(search);

   while(pos < StringLen(json) && (StringGetCharacter(json, pos) == ' ' || StringGetCharacter(json, pos) == '\t')) pos++;

   if(StringFind(json, "true", pos) == pos) return true;
   if(StringFind(json, "false", pos) == pos) return false;
   return default_val;
}

//+------------------------------------------------------------------+
//| FUNGSI PENGIRIM DISCORD WEBHOOK & MOBILE PUSH                    |
//+------------------------------------------------------------------+
bool SendDiscordEmbed(string title, string description, int color_hex, string fields_json, bool is_alert=false)
{
   if(!InpEnableDiscord || InpDiscordWebhookURL == "") return false;

   string mention_str = (is_alert && InpDiscordMention != "") ? InpDiscordMention + " " : "";
   string time_iso = TimeToString(TimeCurrent(), TIME_DATE) + "T" + TimeToString(TimeCurrent(), TIME_SECONDS) + "Z";

   string payload = "{" +
      "\"username\": \"" + InpBotName + "\"," +
      "\"content\": \"" + mention_str + "\"," +
      "\"embeds\": [{" +
         "\"title\": \"" + title + "\"," +
         "\"description\": \"" + description + "\"," +
         "\"color\": " + IntegerToString(color_hex) + "," +
         "\"fields\": [" + fields_json + "]," +
         "\"footer\": {\"text\": \"ID: " + g_account_tag + " • v" + g_current_version + " • M15 Institutional Sniper\"}," +
         "\"timestamp\": \"" + time_iso + "\"" +
      "}]" +
   "}";

   char post_data[];
   StringToCharArray(payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);
   int data_len = ArraySize(post_data);
   if(data_len > 0 && post_data[data_len - 1] == 0) ArrayResize(post_data, data_len - 1);

   char result_data[];
   string result_headers;
   string headers = "Content-Type: application/json\r\nUser-Agent: MetaTrader5-Apex-Sniper\r\n";

   ResetLastError();
   int res = WebRequest("POST", InpDiscordWebhookURL, headers, 3000, post_data, result_data, result_headers);
   return (res == 200 || res == 204);
}

//+------------------------------------------------------------------+
//| GLOBAL NUCLEAR KILL-SWITCH                                       |
//+------------------------------------------------------------------+
void ExecuteGlobalEmergencyKillSwitch()
{
   Print("🚨 [GLOBAL NUCLEAR KILL-SWITCH ACTIVATED] Menutup seluruh posisi terbuka...");
   int closed_count = 0;
   double closed_pnl = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol)
         {
            closed_pnl += m_position.Profit() + m_position.Swap();
            m_trade.PositionClose(m_position.Ticket());
            closed_count++;
         }
      }
   }

   string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                   "{\"name\": \"🚨 Perintah Cloud\", \"value\": \"`GLOBAL EMERGENCY KILL-SWITCH`\", \"inline\": true}," +
                   "{\"name\": \"📊 Total Posisi Ditutup\", \"value\": \"`" + IntegerToString(closed_count) + " Posisi`\", \"inline\": true}," +
                   "{\"name\": \"💵 Realized Emergency PnL\", \"value\": \"`$" + DoubleToString(closed_pnl, 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🏦 Saldo Akun Terkini\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🔒 Status Sistem\", \"value\": \"`STANDBY FREEZE (Menunggu Rilis Cloud)`\", \"inline\": true}";

   SendDiscordEmbed("[" + g_account_tag + "] 🚨 GLOBAL NUCLEAR KILL-SWITCH DIEKSEKUSI!", 
                    "Seluruh posisi terbuka pada akun **[" + g_account_tag + "]** telah ditutup paksa atas perintah Cloud Config!", 
                    0xE74C3C, fields, true);

   if(InpEnableMobilePush)
   {
      SendNotification(StringFormat("[%s] 🚨 GLOBAL KILL-SWITCH: %d Posisi Ditutup Darurat!", g_account_tag, closed_count));
   }
}

//+------------------------------------------------------------------+
//| AUTONOMOUS IN-EA BINARY SELF-UPDATER                             |
//+------------------------------------------------------------------+
bool PerformAutonomousSelfUpdate(string new_version)
{
   if(!InpEnableAutoSelfUpdate) return false;
   if(new_version == g_last_self_updated_ver || new_version == "" || new_version == g_current_version) return false;

   Print("🚀 [SELF-UPDATER] Memulai proses autonomous self-update ke v", new_version, "...");

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

         if(TerminalInfoInteger(TERMINAL_DLLS_ALLOWED))
         {
            CopyFileW(src_path, dst_path, 0);
         }

         g_last_self_updated_ver = new_version;
         Print("✅ [SELF-UPDATER] Binary EX5 v", new_version, " berhasil diunduh & dipasang!");

         string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                         "{\"name\": \"📦 Versi Baru\", \"value\": \"`v" + new_version + " (Institutional M15 Sniper)`\", \"inline\": true}," +
                         "{\"name\": \"💾 Binary Size\", \"value\": \"`" + IntegerToString(ArraySize(result_data) / 1024) + " KB`\", \"inline\": true}," +
                         "{\"name\": \"⚡ Metode Update\", \"value\": \"`100% In-EA Zero-Touch (Tanpa PowerShell)`\", \"inline\": true}," +
                         "{\"name\": \"📂 Lokasi Terpasang\", \"value\": \"`MQL5\\Experts\\XAUUSD_AI_Brain_EA.ex5`\", \"inline\": true}," +
                         "{\"name\": \"🏛️ Status Terminal\", \"value\": \"`Aktif & Terproteksi Penuh`\", \"inline\": true}";

         SendDiscordEmbed("[" + g_account_tag + "] 🚀 AUTONOMOUS SELF-UPDATE SUKSES (v" + new_version + ")!", 
                          "EA telah berhasil memperbarui file biner dirinya sendiri ke versi **v" + new_version + "** secara mandiri.", 
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
//| HITUNG PROFIT / LOSS HARIAN (EVENT-DRIVEN ZERO-LAG CACHE)        |
//+------------------------------------------------------------------+
datetime g_last_daily_pnl_calc = 0;
double   g_cached_daily_pnl    = 0.0;

double GetDailyProfitLoss(bool force_recalc=false)
{
   datetime now = TimeCurrent();
   if(!force_recalc && (now - g_last_daily_pnl_calc < 10) && g_last_daily_pnl_calc > 0)
   {
      return g_cached_daily_pnl;
   }

   datetime today_start = StringToTime(TimeToString(now, TIME_DATE) + " 00:00");
   HistorySelect(today_start, now + 60);
   int total_deals = HistoryDealsTotal();
   double total_profit = 0.0;

   for(int i = 0; i < total_deals; i++)
   {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket > 0)
      {
         long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

         string deal_sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_sym == _Symbol && (deal_magic == InpMagicSniper || deal_magic == InpMagicSwing || deal_magic == 0) &&
            (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         {
            total_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) +
                            HistoryDealGetDouble(deal_ticket, DEAL_SWAP) +
                            HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         }
      }
   }
   g_cached_daily_pnl = NormalizeDouble(total_profit, 2);
   g_last_daily_pnl_calc = now;
   return g_cached_daily_pnl;
}

//+------------------------------------------------------------------+
//| FUNGSI SINKRONISASI CLOUD DARI GITHUB                            |
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
         Print("🟢 [GLOBAL KILL-SWITCH RELEASED] Mode darurat dinonaktifkan.");
      }

      if(cloud_version != "")
      {
         bool is_new_version = (cloud_version != g_current_version);
         if(is_new_version)
         {
            PerformAutonomousSelfUpdate(cloud_version);
         }

         g_current_version    = cloud_version;
         g_balance_step       = ExtractJsonNumber(json, "balance_per_step", InpBalanceStep);
         g_lot_step           = ExtractJsonNumber(json, "lot_per_step", InpFixedLot);
         g_max_spread         = (int)ExtractJsonNumber(json, "max_spread_points", InpMaxSpreadPoints);
         g_use_daily_guard    = ExtractJsonBool(json, "use_daily_guard", false);
         g_daily_target_pct   = ExtractJsonNumber(json, "daily_target_profit_percent", 15.0);
         g_daily_max_loss_pct = ExtractJsonNumber(json, "daily_max_loss_percent", 15.0);
         g_loss_cooldown_min  = (int)ExtractJsonNumber(json, "loss_cooldown_minutes", InpLossCooldownMinutes);

         if(is_new_version && !is_initial)
         {
            double cur_bal = m_account.Balance();
            double target_usd = cur_bal * (g_daily_target_pct / 100.0);

            string update_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                                   "{\"name\": \"🧠 Brain Engine\", \"value\": \"`v" + g_current_version + " (Institutional M15 Sniper)`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target Harian\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (" + DoubleToString(g_daily_target_pct, 0) + "% Wallet)`\", \"inline\": true}," +
                                   "{\"name\": \"📐 RR Model\", \"value\": \"`1:2.5 Mathematical Expectancy`\", \"inline\": true}," +
                                   "{\"name\": \"🚨 Cloud Kill-Switch\", \"value\": \"`Citadel Redundancy OK`\", \"inline\": true}," +
                                   "{\"name\": \"📊 Sinkronisasi PnL\", \"value\": \"`100% Persis Tab History MT5`\", \"inline\": true}";

            SendDiscordEmbed("[" + g_account_tag + "] 🔄 OTA CLOUD UPDATE DIAPLIKASIKAN (v" + g_current_version + ")!", 
                             "Pembaruan v" + g_current_version + " diterapkan otomatis ke akun **" + g_account_tag + "** (M15 Sniper Active)!", 
                             0x9B59B6, update_fields, false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DETAK JANTUNG FLEET MONITOR                                      |
//+------------------------------------------------------------------+
void SendFleetHeartbeatPulse()
{
   double balance = m_account.Balance();
   double equity  = m_account.Equity();
   double margin_level = (m_account.Margin() > 0) ? (equity / m_account.Margin() * 100.0) : 1000.0;
   double daily_pnl = GetDailyProfitLoss();
   double weekly_pnl = GetWeeklyProfitLoss();

   int active_sniper = 0, active_swing = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol)
      {
         if(m_position.Magic() == InpMagicSniper) active_sniper++;
         else if(m_position.Magic() == InpMagicSwing) active_swing++;
      }
   }

   string status_emoji = (daily_pnl >= 0) ? "🟢" : "🟡";
   string title = StringFormat("[%s] 💓 FLEET MONITOR HEARTBEAT (v%s)", g_account_tag, g_current_version);

   string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏦 Saldo / Equity\", \"value\": \"`$" + DoubleToString(balance, 2) + " / $" + DoubleToString(equity, 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Margin Level\", \"value\": \"`" + DoubleToString(margin_level, 1) + "%`\", \"inline\": true}," +
                   "{\"name\": \"🏆 Profit Hari Ini\", \"value\": \"`" + ((daily_pnl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_pnl), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"📅 Profit Minggu Ini\", \"value\": \"`" + ((weekly_pnl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(weekly_pnl), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Posisi Aktif\", \"value\": \"`Sniper: " + IntegerToString(active_sniper) + " | Swing: " + IntegerToString(active_swing) + "`\", \"inline\": true}," +
                   "{\"name\": \"⚡ Server Ping\", \"value\": \"`" + IntegerToString(TerminalInfoInteger(TERMINAL_PING_LAST) / 1000) + " ms`\", \"inline\": true}," +
                   "{\"name\": \"🧠 Versi Engine\", \"value\": \"`v" + g_current_version + " (Institutional M15 Sniper)`\", \"inline\": true}," +
                   "{\"name\": \"🟢 Status EA\", \"value\": \"`Beroperasi Normal 24/7`\", \"inline\": true}";

   SendDiscordEmbed(title, "Laporan detak jantung berkala armada akun **[" + g_account_tag + "]**.", 0x3498DB, fields, false);
}

//+------------------------------------------------------------------+
//| LAPORAN REKAPITULASI MINGGUAN                                    |
//+------------------------------------------------------------------+
void SendWeeklyFinancialDigest()
{
   double weekly_profit = GetWeeklyProfitLoss();
   double cur_bal = m_account.Balance();
   double starting_bal = cur_bal - weekly_profit;
   if(starting_bal <= 0) starting_bal = cur_bal;
   double weekly_roi_pct = (weekly_profit / starting_bal) * 100.0;

   string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                   "{\"name\": \"💵 Realized Weekly PnL\", \"value\": \"**" + ((weekly_profit >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(weekly_profit), 2) + "**\", \"inline\": true}," +
                   "{\"name\": \"📈 Weekly ROI Growth\", \"value\": \"**" + ((weekly_roi_pct >= 0) ? "+" : "") + DoubleToString(weekly_roi_pct, 2) + "%**\", \"inline\": true}," +
                   "{\"name\": \"🏦 Saldo Akun Penutupan\", \"value\": \"`$" + DoubleToString(cur_bal, 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🏆 Status Finansial\", \"value\": \"`" + ((weekly_profit >= 0) ? "PROFIT MINGGUAN HIJAU 🟢" : "LOSS TERKENDALI 🔴") + "`\", \"inline\": true}";

   SendDiscordEmbed("[" + g_account_tag + "] 📊 REKAPITULASI MINGGUAN PASAR (WEEKEND DIGEST)", 
                    "Evaluasi performa trading akun **[" + g_account_tag + "]** pekan ini.", 
                    (weekly_profit >= 0 ? 0x2ECC71 : 0xE67E22), fields, false);
}

//+------------------------------------------------------------------+
//| MESIN KALKULASI FIBONACCI M15 & H4                               |
//+------------------------------------------------------------------+
void CalculateM15FibonacciLevels(SFibLevels &out_fib, int lookback_bars=24)
{
   datetime now = TimeCurrent();
   if(now - g_last_m15_fib_time < 60 && g_last_m15_fib_time > 0)
   {
      out_fib = g_cached_m15_fib;
      return;
   }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, lookback_bars + 1, rates) < lookback_bars + 1) return;

   double highest = -1e9, lowest = 1e9;
   int high_idx = 0, low_idx = 0;

   for(int i = 1; i <= lookback_bars; i++)
   {
      if(rates[i].high > highest) { highest = rates[i].high; high_idx = i; }
      if(rates[i].low < lowest)   { lowest = rates[i].low;   low_idx  = i; }
   }

   out_fib.swing_high = highest;
   out_fib.swing_low  = lowest;
   double range = highest - lowest;

   ENUM_ASSET_CLASS asset = GetAssetClass(_Symbol);
   double min_range_pts = (asset == ASSET_GOLD) ? 250.0 : (asset == ASSET_INDEX) ? 400.0 : 150.0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.001;

   if(range / point < min_range_pts)
   {
      out_fib.fib_500 = 0.0;
      out_fib.fib_618 = 0.0;
      out_fib.fib_786 = 0.0;
      out_fib.fib_1618_ext = 0.0;
      return;
   }

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

   g_cached_m15_fib = out_fib;
   g_last_m15_fib_time = now;
}

void CalculateH4FibonacciLevels(SFibLevels &out_fib, int lookback_bars=24)
{
   datetime now = TimeCurrent();
   if(now - g_last_h4_fib_time < 300 && g_last_h4_fib_time > 0)
   {
      out_fib = g_cached_h4_fib;
      return;
   }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H4, 0, lookback_bars + 1, rates) < lookback_bars + 1) return;

   double highest = -1e9, lowest = 1e9;
   int high_idx = 0, low_idx = 0;

   for(int i = 1; i <= lookback_bars; i++)
   {
      if(rates[i].high > highest) { highest = rates[i].high; high_idx = i; }
      if(rates[i].low < lowest)   { lowest = rates[i].low;   low_idx  = i; }
   }

   out_fib.swing_high = highest;
   out_fib.swing_low  = lowest;
   double range = highest - lowest;

   ENUM_ASSET_CLASS asset = GetAssetClass(_Symbol);
   double min_range_pts = (asset == ASSET_GOLD) ? 250.0 : (asset == ASSET_INDEX) ? 400.0 : 150.0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.001;

   if(range / point < min_range_pts)
   {
      out_fib.fib_500 = 0.0;
      out_fib.fib_618 = 0.0;
      out_fib.fib_786 = 0.0;
      out_fib.fib_1618_ext = 0.0;
      return;
   }

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
   g_last_h4_fib_time = now;
}

//+------------------------------------------------------------------+
//| PEMILIHAN TIPE FILLING ORDER OTOMATIS ANTI-REJECTION             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| PEMILIHAN TIPE FILLING & DEVIASI ADAPTIF                         |
//+------------------------------------------------------------------+
void SetAssetAdaptiveDeviation()
{
   ENUM_ASSET_CLASS asset = GetAssetClass(_Symbol);
   ulong dev = (asset == ASSET_GOLD) ? 50 : (asset == ASSET_INDEX) ? 100 : 30;
   m_trade.SetDeviationInPoints(dev);
}

void PreWarmIndicatorHistory()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, PERIOD_M15, 0, 500, rates);
   CopyRates(_Symbol, PERIOD_H1, 0, 500, rates);
   CopyRates(_Symbol, PERIOD_H4, 0, 500, rates);
}

void SetOptimalFillingMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_IOC) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((filling & SYMBOL_FILLING_FOK) != 0)
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//+------------------------------------------------------------------+
//| KALIBRASI PARAMETER SWING ADAPTIF (FOREX SWING PLAYBOOK)         |
//+------------------------------------------------------------------+
void GetAdaptiveSwingParameters(string symbol, int &out_sl_pts, int &out_tp1_pts, int &out_tp2_pts)
{
   string sym = symbol;
   StringToUpper(sym);

   // 1. GBPJPY & JPY High Volatility Crosses (The Dragon)
   if(StringFind(sym, "GBPJPY") >= 0 || StringFind(sym, "EURJPY") >= 0 || StringFind(sym, "CADJPY") >= 0)
   {
      out_sl_pts  = 800;  // 80 pips
      out_tp1_pts = 1000; // 100 pips
      out_tp2_pts = 2500; // 250 pips (RR 1:3.1)
      return;
   }

   // 2. Stable Major Forex (EURUSD, AUDUSD, NZDUSD, USDCAD)
   if(StringFind(sym, "EURUSD") >= 0 || StringFind(sym, "AUDUSD") >= 0 || StringFind(sym, "NZDUSD") >= 0 || StringFind(sym, "USDCAD") >= 0)
   {
      out_sl_pts  = 400;  // 40 pips
      out_tp1_pts = 500;  // 50 pips
      out_tp2_pts = 1500; // 150 pips (RR 1:3.75)
      return;
   }

   // 3. Volatile Major Forex (GBPUSD, USDJPY, USDCHF)
   if(StringFind(sym, "GBPUSD") >= 0 || StringFind(sym, "USDJPY") >= 0 || StringFind(sym, "USDCHF") >= 0)
   {
      out_sl_pts  = 600;  // 60 pips
      out_tp1_pts = 700;  // 70 pips
      out_tp2_pts = 2000; // 200 pips (RR 1:3.3)
      return;
   }

   // 4. Global Equity Indices (US30, NAS100, SP500, DAX)
   if(StringFind(sym, "30") >= 0 || StringFind(sym, "100") >= 0 || StringFind(sym, "500") >= 0 || StringFind(sym, "DAX") >= 0 || StringFind(sym, "NAS") >= 0 || StringFind(sym, "DOW") >= 0)
   {
      out_sl_pts  = 1000; // 100 pts index
      out_tp1_pts = 1200; // 120 pts index
      out_tp2_pts = 3500; // 350 pts index (RR 1:3.5)
      return;
   }

   // 5. Default / XAUUSD Gold
   out_sl_pts  = InpSwingSLPoints;        // 800 pts
   out_tp1_pts = InpSwingTP1Points;       // 800 pts
   out_tp2_pts = InpSwingTP2RunnerPoints; // 2400 pts
}

//+------------------------------------------------------------------+
//| DETEKSI KELAS ASET (GOLD / FOREX / INDEX)                        |
//+------------------------------------------------------------------+
ENUM_ASSET_CLASS GetAssetClass(string symbol)
{
   string sym = symbol;
   StringToUpper(sym);
   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0 || StringFind(sym, "SILVER") >= 0 || StringFind(sym, "XAG") >= 0)
      return ASSET_GOLD;
   if(StringFind(sym, "30") >= 0 || StringFind(sym, "100") >= 0 || StringFind(sym, "500") >= 0 || StringFind(sym, "DAX") >= 0 || StringFind(sym, "NAS") >= 0 || StringFind(sym, "DOW") >= 0)
      return ASSET_INDEX;
   return ASSET_FOREX;
}

//+------------------------------------------------------------------+
//| HITUNG TOTAL RISIKO TERBUKA SELURUH PORTOFOLIO (% EQUITY)        |
//+------------------------------------------------------------------+
double CalculateTotalPortfolioOpenRiskPct()
{
   double equity = m_account.Equity();
   if(equity <= 0) return 0.0;

   double total_risk_usd = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         double pos_sl = m_position.StopLoss();
         double open_p = m_position.PriceOpen();
         double vol    = m_position.Volume();
         string sym    = m_position.Symbol();

         bool is_buy = (m_position.PositionType() == POSITION_TYPE_BUY);
         bool is_risk_free = (is_buy && pos_sl >= open_p) || (!is_buy && pos_sl > 0 && pos_sl <= open_p);

         if(!is_risk_free)
         {
            CSymbolInfo pos_sym;
            pos_sym.Name(sym);
            pos_sym.Refresh();
            double tick_v = pos_sym.TickValue();
            if(tick_v <= 0) tick_v = 1.0;
            double pt = (pos_sym.Point() > 0 ? pos_sym.Point() : 0.001);
            double ts = (pos_sym.TickSize() > 0 ? pos_sym.TickSize() : pt);
            double point_v = (tick_v / ts) * pt;

            if(pos_sl > 0)
            {
               double dist_pts = is_buy ? (open_p - pos_sl) : (pos_sl - open_p);
               dist_pts = dist_pts / pt;
               if(dist_pts > 0) total_risk_usd += dist_pts * point_v * vol;
            }
            else
            {
               total_risk_usd += (equity * (InpRiskPercent / 100.0));
            }
         }
      }
   }
   return NormalizeDouble((total_risk_usd / equity) * 100.0, 2);
}

//+------------------------------------------------------------------+
//| DETEKSI INSTITUTIONAL KILL-ZONES TIME WINDOW                     |
//+------------------------------------------------------------------+
bool IsInsideInstitutionalKillZone(string &out_session_name)
{
   if(!InpUseKillZonesOnly)
   {
      out_session_name = "ALL SESSIONS (24H ACTIVE)";
      return true;
   }

   datetime gmt_time = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt_time, dt);
   int gmt_hour = dt.hour;
   int gmt_min  = dt.min;
   double gmt_dec = gmt_hour + (gmt_min / 60.0);

   // London Open Kill-Zone: 07:00 - 11:00 UTC (14:00 - 18:00 WIB)
   if(InpTradeLondonKZ && (gmt_dec >= 7.0 && gmt_dec <= 11.0))
   {
      out_session_name = "LONDON KILL-ZONE 🏛️ (07:00-11:00 UTC)";
      return true;
   }

   // New York Open Kill-Zone: 12:30 - 16:30 UTC (19:30 - 23:30 WIB)
   if(InpTradeNYKZ && (gmt_dec >= 12.5 && gmt_dec <= 16.5))
   {
      out_session_name = "NEW YORK KILL-ZONE ⚡ (12:30-16:30 UTC)";
      return true;
   }

   // Asian Session: 00:00 - 06:30 UTC (07:00 - 13:30 WIB)
   if(InpTradeAsianSession && (gmt_dec >= 0.0 && gmt_dec < 7.0))
   {
      out_session_name = "ASIAN SESSION 🌏 (Low Volatility)";
      return true;
   }

   out_session_name = "STANDBY (OUTSIDE KILL-ZONES ⏳)";
   return false;
}

//+------------------------------------------------------------------+
//| DETEKSI INSTITUTIONAL FAIR VALUE GAP (FVG M15)                   |
//+------------------------------------------------------------------+
void DetectM15FairValueGap(SFairValueGap &out_fvg)
{
   datetime now = TimeCurrent();
   if(now - g_last_fvg_time < 30 && g_last_fvg_time > 0)
   {
      out_fvg = g_cached_m15_fvg;
      return;
   }

   out_fvg.exists = false;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 8, rates) < 8) return;

   // 8-Bar Multi-Imbalance Scanner
   for(int i = 1; i <= 5; i++)
   {
      if(rates[i+2].high < rates[i].low)
      {
         out_fvg.exists = true;
         out_fvg.is_bullish = true;
         out_fvg.upper_level = rates[i].low;
         out_fvg.lower_level = rates[i+2].high;
         out_fvg.time_created = rates[i+1].time;
         break;
      }
      else if(rates[i+2].low > rates[i].high)
      {
         out_fvg.exists = true;
         out_fvg.is_bullish = false;
         out_fvg.upper_level = rates[i+2].low;
         out_fvg.lower_level = rates[i].high;
         out_fvg.time_created = rates[i+1].time;
         break;
      }
   }

   g_cached_m15_fvg = out_fvg;
   g_last_fvg_time = now;
}

//+------------------------------------------------------------------+
//| HITUNG NILAI 1 POINT PER 1.00 LOT DALAM MATA UANG AKUN           |
//+------------------------------------------------------------------+
double CalculatePointValueInDepositCurrency()
{
   double tick_val  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tick_val <= 0) tick_val = 1.0;
   if(tick_size <= 0) tick_size = (point > 0 ? point : 0.001);
   if(point <= 0) point = 0.001;

   double point_val = (tick_val / tick_size) * point;
   if(point_val <= 0) point_val = 1.0;
   return point_val;
}

//+------------------------------------------------------------------+
//| TRUE ZERO-LOSS COMMISSION-AWARE BREAKEVEN CALCULATOR             |
//+------------------------------------------------------------------+
double CalculateCommissionAwareBE(bool is_buy, double open_price, double volume, double extra_buffer_pts=5.0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.001;
   double point_val = CalculatePointValueInDepositCurrency();
   if(point_val <= 0) point_val = 1.0;

   double est_comm_per_lot = 7.0; // ~$7/lot standard round turn
   double comm_pts = (est_comm_per_lot / point_val) + extra_buffer_pts;
   if(comm_pts < 5.0) comm_pts = 5.0;

   if(is_buy)
      return m_symbol.NormalizePrice(open_price + comm_pts * point);
   else
      return m_symbol.NormalizePrice(open_price - comm_pts * point);
}

//+------------------------------------------------------------------+
//| PROP FIRM & CHALLENGE HIGH-WATERMARK DRAWDOWN GUARD              |
//+------------------------------------------------------------------+
void CheckPropFirmDailyWatermark()
{
   if(!InpUsePropFirmGuard) return;

   datetime now = TimeCurrent();
   datetime today_start = StringToTime(TimeToString(now, TIME_DATE) + " 00:00");
   string gv_key = "APEX_DAY_START_" + IntegerToString(m_account.Login());

   if(g_last_peak_day != today_start || g_daily_peak_equity <= 0)
   {
      g_last_peak_day = today_start;
      g_daily_peak_equity = m_account.Balance();
      if(GlobalVariableCheck(gv_key))
      {
         g_daily_peak_equity = GlobalVariableGet(gv_key);
      }
      else
      {
         GlobalVariableSet(gv_key, g_daily_peak_equity);
      }
      g_prop_firm_locked = false;
   }

   double cur_eq = m_account.Equity();
   if(g_daily_peak_equity > 0 && !g_prop_firm_locked)
   {
      if(cur_eq < g_daily_peak_equity)
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
                            "{\"name\": \"💰 Equity Terkunci\", \"value\": \"`$" + DoubleToString(cur_eq, 2) + "`\", \"inline\": true}," +
                            "{\"name\": \"🔒 Status Trading\", \"value\": \"`TUTUP SEMUA POSISI & KUNCI HINGGA BESOK`\", \"inline\": true}";

            SendDiscordEmbed("[" + g_account_tag + "] 🏆 PROP FIRM HIGH-WATERMARK DRAWDOWN GUARD AKTIF!", 
                             "Akun **[" + g_account_tag + "]** dilindungi dari batas Max Daily Drawdown. Semua posisi ditutup & modal aman 100%!", 
                             0xE74C3C, fields, true);

            if(InpEnableMobilePush)
            {
               SendNotification(StringFormat("[%s] 🏆 Prop Firm DD Guard Aktif! Modal Diamankan.", g_account_tag));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MATEMATIKA KALKULASI LOT SWING ADAPTIF (MULTI-ASET)              |
//+------------------------------------------------------------------+
double CalculateSwingLotSize(int swing_sl_points)
{
   double equity = m_account.Equity();
   if(equity <= 0) equity = m_account.Balance();
   if(equity <= 0) return 0.01;

   double lot = InpSwingFixedLot;

   // Dalam mode % Risk, masing-masing sub-tiket mengambil 0.5% risiko (Total 1.0% per setup Swing)
   if(InpLotType == LOT_RISK_PERCENT)
   {
      double sub_ticket_risk_usd = equity * ((InpRiskPercent * 0.5) / 100.0);
      double point_val = CalculatePointValueInDepositCurrency();

      if(swing_sl_points > 0 && point_val > 0)
      {
         lot = sub_ticket_risk_usd / (swing_sl_points * point_val);
      }
   }
   else if(InpLotType == LOT_PER_BALANCE)
   {
      ENUM_ASSET_CLASS asset = GetAssetClass(_Symbol);
      double asset_step = g_balance_step;
      if(asset == ASSET_FOREX) asset_step = g_balance_step * 0.5; // Forex margin lebih ringan
      lot = (equity / (asset_step * 2.0)) * g_lot_step;
   }

   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lot_step <= 0) lot_step = 0.01;
   if(min_lot <= 0) min_lot = 0.01;
   if(max_lot <= 0) max_lot = 100.0;

   lot = MathFloor(lot / lot_step) * lot_step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| MATEMATIKA KALKULASI LOT SNIPER (EXACT 1% RISK EQUITY)           |
//+------------------------------------------------------------------+
double CalculateSniperLotSize(int sl_points)
{
   double lot = 0.01;
   double equity = m_account.Equity();
   if(equity <= 0) equity = m_account.Balance();
   if(equity <= 0) return 0.01;

   if(InpLotType == LOT_RISK_PERCENT)
   {
      double risk_usd = equity * (InpRiskPercent / 100.0);
      double point_val = CalculatePointValueInDepositCurrency();

      if(sl_points > 0 && point_val > 0)
      {
         lot = risk_usd / (sl_points * point_val);
      }
   }
   else if(InpLotType == LOT_PER_BALANCE)
   {
      ENUM_ASSET_CLASS asset = GetAssetClass(_Symbol);
      double asset_step = g_balance_step;
      if(asset == ASSET_FOREX) asset_step = g_balance_step * 0.5; // Forex margin lebih bersahabat ($250/0.01)
      lot = (equity / asset_step) * g_lot_step;
   }
   else
   {
      lot = InpFixedLot;
   }

   // Defend the Bag Protections
   if(InpUseDefendTheBag)
   {
      double daily_pl = GetDailyProfitLoss();
      if(daily_pl >= (equity * (InpDefendBagProfitPct / 100.0)))
      {
         lot = lot * 0.5;
         Print("🛡️ [DEFEND-THE-BAG] Target harian tercapai! Lot dipangkas 50% untuk mengamankan cuan.");
      }
   }

   double min_lot  = m_symbol.LotsMin();
   double max_lot  = m_symbol.LotsMax();
   double lot_step = m_symbol.LotsStep();

   lot = MathFloor(lot / lot_step) * lot_step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| KALKULASI SL & TP STRUKTUR M15 (MINIMAL 1:2.5 RR)                |
//+------------------------------------------------------------------+
void CalculateM15StructuralSLTP(bool is_buy, double &out_sl_pts, double &out_tp_pts)
{
   double point = m_symbol.Point();
   out_sl_pts = InpMinSLPoints;

   if(InpUseStructuralSL)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_M15, 0, 6, rates) >= 6)
      {
         if(is_buy)
         {
            double lowest = 1e9;
            for(int i = 1; i <= 5; i++)
            {
               if(rates[i].low < lowest) lowest = rates[i].low;
            }
            double cur_ask = m_symbol.Ask();
            double dist_pts = (cur_ask - lowest) / point + 50.0; // +50 pts buffer
            out_sl_pts = dist_pts;
         }
         else
         {
            double highest = -1e9;
            for(int i = 1; i <= 5; i++)
            {
               if(rates[i].high > highest) highest = rates[i].high;
            }
            double cur_bid = m_symbol.Bid();
            double dist_pts = (highest - cur_bid) / point + 50.0; // +50 pts buffer
            out_sl_pts = dist_pts;
         }
      }
   }

   // Asset-Adaptive SL Bounds
   ENUM_ASSET_CLASS asset = GetAssetClass(_Symbol);
   int min_sl = InpMinSLPoints;
   int max_sl = InpMaxSLPoints;
   if(asset == ASSET_FOREX)
   {
      min_sl = 150; // 15 pips
      max_sl = 350; // 35 pips
   }
   else if(asset == ASSET_INDEX)
   {
      min_sl = 500;
      max_sl = 1500;
   }

   // Constrain SL between Min and Max points
   if(out_sl_pts < min_sl) out_sl_pts = min_sl;
   if(out_sl_pts > max_sl) out_sl_pts = max_sl;

   out_tp_pts = NormalizeDouble(out_sl_pts * InpRiskRewardRatio, 0);
}

//+------------------------------------------------------------------+
//| PERISAI BERITA & JAM TRADING                                     |
//+------------------------------------------------------------------+
bool IsHighImpactNewsTime()
{
   if(!InpUseRedNewsGuard) return false;
   datetime gmt_now = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt_now, dt);
   if(dt.day_of_week >= 1 && dt.day_of_week <= 5)
   {
      double gmt_dec = dt.hour + (dt.min / 60.0);
      // US High-Impact Data (NFP, CPI, PPI, Retail Sales): 12:15 - 13:45 UTC
      if(gmt_dec >= 12.25 && gmt_dec <= 13.75) return true;
      // US FOMC Interest Rate & Fed Press Conf: 17:45 - 19:15 UTC
      if(gmt_dec >= 17.75 && gmt_dec <= 19.25) return true;
   }
   return false;
}

bool IsRolloverTime()
{
   if(!InpUseRolloverGuard) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.hour == 23 && dt.min >= 50) || (dt.hour == 0) || (dt.hour == 1 && dt.min <= 10)) return true;
   return false;
}

bool IsFridayWeekendCleanTime()
{
   if(!InpUseFridayAutoClean) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= 21) return true;
   return false;
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI OPEN TRADE DISCORD & MOBILE PUSH               |
//+------------------------------------------------------------------+
void NotifyAITrade(string engine, string type, double price, double lot_used, double sl, double tp, ulong ticket, string trigger_source, int spread_used, int sl_pts, int tp_pts)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";
   string engine_badge = (engine == "SWING") ? "🌊 **[SWING RUNNER H4]**" : "🎯 **[M15 INSTITUTIONAL SNIPER]**";

   string title = StringFormat("[%s] %s %s EXECUTED! (RR 1:%.1f)", g_account_tag, engine, type, (double)tp_pts / (sl_pts > 0 ? sl_pts : 1));

   string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏛️ Mesin Eksekusi\", \"value\": \"" + engine_badge + "\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Single Sniper)**\", \"inline\": true}," +
                   "{\"name\": \"⚡ Pemicu Sinyal\", \"value\": \"`" + trigger_source + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (**" + DoubleToString(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Fill\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(sl_pts / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(tp_pts / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Spread Broker\", \"value\": \"`" + IntegerToString(spread_used) + " Points` (Aman)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed(title, "Eksekusi posisi **" + type + "** pada akun **[" + g_account_tag + "]** (" + engine + ").", embed_color, fields, false);

   if(InpEnableMobilePush)
   {
      SendNotification(StringFormat("[%s] %s %s @ %.2f (Lot: %.2f)", g_account_tag, engine, type, price, lot_used));
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

   if(profit < 0 && engine == "SNIPER")
   {
      g_consecutive_losses++;
      if(InpUseLossCircuitBreaker && g_consecutive_losses >= 2)
      {
         g_cooldown_until = TimeCurrent() + g_loss_cooldown_min * 60;
         string cooldown_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                                  "{\"name\": \"⚠️ Rem Pengaman\", \"value\": \"`2x Loss Beruntun Terdeteksi`\", \"inline\": true}," +
                                  "{\"name\": \"⏳ Durasi Cooldown\", \"value\": \"`5 Menit Cepat (Hingga " + TimeToString(g_cooldown_until, TIME_MINUTES) + ")`\", \"inline\": true}," +
                                  "{\"name\": \"🏦 Saldo Diamankan\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "`\", \"inline\": true}";
         SendDiscordEmbed("[" + g_account_tag + "] 🛡️ FAST 5-MIN CIRCUIT BREAKER AKTIF!", 
                          "Mesin Sniper istirahat 5 menit untuk mendinginkan akun **[" + g_account_tag + "]**.", 
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
   string result_text = (profit >= 0) ? "PROFIT" : "LOSS";

   string title = StringFormat("[%s] 🏁 POSISI %s DITUTUP (%s)", g_account_tag, engine, result_text);

   string fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏛️ Mesin Eksekusi\", \"value\": \"`" + engine + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Hasil Transaksi\", \"value\": \"" + result_emoji + "\", \"inline\": true}," +
                   "{\"name\": \"💵 Realized PnL\", \"value\": \"**" + pnl_sign + DoubleToString(abs_profit, 2) + "**\", \"inline\": true}," +
                   "{\"name\": \"🏦 Saldo Akun Terkini\", \"value\": \"**`$" + DoubleToString(current_balance, 2) + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Posisi Ditutup\", \"value\": \"`" + type + " " + _Symbol + " (" + DoubleToString(volume, 2) + " Lot)`\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Close\", \"value\": \"`" + DoubleToString(close_price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🏆 Total PnL Hari Ini\", \"value\": \"`" + ((daily_total_pl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_total_pl), 2) + "` (Tab History)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Deal Ticket\", \"value\": \"`#" + IntegerToString(deal_ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed(title, "Posisi " + engine + " pada akun **[" + g_account_tag + "]** telah resmi ditutup dengan hasil **" + pnl_sign + DoubleToString(abs_profit, 2) + "**.", embed_color, fields, (profit < -30.0));

   if(InpEnableMobilePush)
   {
      SendNotification(StringFormat("[%s] %s Tutup %s %s (PnL: %s%.2f)", g_account_tag, engine, type, (profit >= 0 ? "PROFIT" : "LOSS"), pnl_sign, abs_profit));
   }
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
         string deal_comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);

         string deal_sym = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
         if(deal_sym == _Symbol && (deal_magic == InpMagicSniper || deal_magic == InpMagicSwing || deal_magic == 0) &&
            (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         {
            double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(deal_ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            double close_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            double volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            long deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
            string pos_type = (deal_type == DEAL_TYPE_BUY) ? "BUY (Tutup SELL)" : "SELL (Tutup BUY)";
            string engine = (deal_magic == InpMagicSwing) ? "SWING" : "SNIPER";

            NotifyCloseTrade(engine, pos_type, close_price, profit, deal_ticket, volume);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ENUM_ASSET_CLASS asset_type = GetAssetClass(_Symbol);
   string asset_desc = (asset_type == ASSET_GOLD) ? "GOLD / METALS 🪙" : (asset_type == ASSET_INDEX) ? "EQUITY INDEX 📈" : "MAJOR FOREX 💱";
   Print("🌐 [UNIVERSAL ASSET DETECTED] Symbol: ", _Symbol, " | Kategori: ", asset_desc);

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.Refresh();

   m_trade.SetMarginMode();
   SetOptimalFillingMode();
   SetAssetAdaptiveDeviation();
   PreWarmIndicatorHistory();

   InitAccountMetadata();
   g_loss_cooldown_min = InpLossCooldownMinutes;
   RecoverConsecutiveLossesFromHistory();

   FetchAndApplyCloudConfig(true);
   m_last_cloud_sync_time = TimeCurrent();
   g_last_heartbeat_time  = TimeCurrent();

   // Handle Indikator M15
   handle_ema50_m15 = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_rsi_m15   = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
   handle_atr_m15   = iATR(_Symbol, PERIOD_M15, 14);

   // Handle Indikator H1 & H4
   handle_ema50_h1  = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema21_h1  = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema50_h4  = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema200_h4 = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   handle_rsi_h4    = iRSI(_Symbol, PERIOD_H4, 14, PRICE_CLOSE);
   handle_adx_h4    = iADX(_Symbol, PERIOD_H4, 14);
   handle_atr_h4    = iATR(_Symbol, PERIOD_H4, 14);

   if(handle_ema50_m15 == INVALID_HANDLE || handle_rsi_m15 == INVALID_HANDLE ||
      handle_atr_m15 == INVALID_HANDLE || handle_ema50_h1 == INVALID_HANDLE ||
      handle_ema21_h1 == INVALID_HANDLE || handle_ema50_h4 == INVALID_HANDLE ||
      handle_ema200_h4 == INVALID_HANDLE || handle_rsi_h4 == INVALID_HANDLE ||
      handle_adx_h4 == INVALID_HANDLE || handle_atr_h4 == INVALID_HANDLE)
   {
      Print("[ERROR] Gagal inisialisasi handle indikator M15 Sniper!");
      return INIT_FAILED;
   }

   EventSetTimer(1);

   double current_bal = m_account.Balance();
   double target_usd = current_bal * (g_daily_target_pct / 100.0);
   double current_lot = CalculateSniperLotSize(InpMinSLPoints);
   double current_daily_pnl = GetDailyProfitLoss(true);

   string startup_fields = "{\"name\": \"🏷️ Account ID\", \"value\": \"**`" + g_account_tag + "`**\", \"inline\": true}," +
                           "{\"name\": \"🧠 Brain Engine\", \"value\": \"`v" + g_current_version + " (Institutional M15 Sniper)`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Cuan Harian\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (15% Wallet)`\", \"inline\": true}," +
                           "{\"name\": \"🏆 PnL Hari Ini (History)\", \"value\": \"`" + ((current_daily_pnl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(current_daily_pnl), 2) + "`\", \"inline\": true}," +
                           "{\"name\": \"📐 RR Model\", \"value\": \"`1:2.5 Mathematical Expectancy`\", \"inline\": true}," +
                           "{\"name\": \"📱 Dual Redundancy\", \"value\": \"`Discord + MT5 Mobile Push`\", \"inline\": true}," +
                           "{\"name\": \"📈 Lot Size Model\", \"value\": \"`" + (InpLotType == LOT_RISK_PERCENT ? "1.0% Equity Risk (" + DoubleToString(current_lot, 2) + " Lot)" : "Fixed/Step") + "`\", \"inline\": true}";

   SendDiscordEmbed("[" + g_account_tag + "] 👑 XAUUSD Institutional Sniper Aktif (v23.00 Anti-Rungkad)! 🚀", 
                    "Sistem M15 Single-Entry Sniper siap beroperasi pada akun **[" + g_account_tag + "]** dengan ketahanan benteng kuantitatif mutlak!", 
                    0x3498DB, startup_fields, false);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handle_ema50_m15);
   IndicatorRelease(handle_rsi_m15);
   IndicatorRelease(handle_atr_m15);
   IndicatorRelease(handle_ema50_h1);
   IndicatorRelease(handle_ema21_h1);
   IndicatorRelease(handle_ema50_h4);
   IndicatorRelease(handle_ema200_h4);
   IndicatorRelease(handle_rsi_h4);
   IndicatorRelease(handle_adx_h4);
   IndicatorRelease(handle_atr_h4);
   Comment("");
}

//+------------------------------------------------------------------+
//| EVENT ON TIMER                                                   |
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

   // 3. Automated Weekend Financial Digest
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

   // 4. Garbage Collector
   if(ArraySize(g_notified_deals) > 300)
   {
      ArrayResize(g_notified_deals, 50);
   }
}

//+------------------------------------------------------------------+
//| ON-CHART DASHBOARD M15 SNIPER MASTER                             |
//+------------------------------------------------------------------+
void DisplayAIDashboard(string sniper_status, string swing_status, int dyn_sl, int dyn_tp, int sniper_total, int swing_total, string macro_bias, SFibLevels &fib, string kz_status)
{
   long current_spread = m_symbol.Spread();
   string spread_status = (current_spread <= g_max_spread) ? "[AMAN ✅]" : "[TERLALU TINGGI 🚫]";

   if(g_emergency_kill_active) spread_status = "[🚨 GLOBAL EMERGENCY FREEZE]";
   else if(g_prop_firm_locked) spread_status = "[🏆 PROP FIRM DAILY LOCK]";
   else if(g_manual_trade_pause) spread_status = "[🚨 MANUAL TRADE PAUSE]";
   else if(IsHighImpactNewsTime()) spread_status = "[🚨 RED NEWS SHIELD PAUSE]";
   else if(IsFridayWeekendCleanTime()) spread_status = "[📅 FRIDAY WEEKEND PAUSE]";
   else if(IsRolloverTime()) spread_status = "[⏸️ ROLLOVER PAUSE]";
   else if(TimeCurrent() < g_cooldown_until) spread_status = "[⏳ 5-MIN COOLDOWN PAUSE]";

   double cur_bal = m_account.Balance();
   if(cur_bal <= 0) cur_bal = m_account.Equity();
   double daily_pl = GetDailyProfitLoss();
   double lot = CalculateSniperLotSize(dyn_sl);

   string info = "=========================================================\n";
   info += "     👑 XAUUSD INSTITUTIONAL M15 SNIPER v" + g_current_version + "\n";
   info += "=========================================================\n";
   info += " 🏷️ Unique Fleet ID : " + g_account_tag + "\n";
   info += " 💰 Balance / Equity : $" + DoubleToString(m_account.Balance(), 2) + " / $" + DoubleToString(m_account.Equity(), 2) + "\n";
   info += " 🏆 Profit Hari Ini  : " + ((daily_pl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_pl), 2) + " (Tab History MT5)\n";
   info += " 🌊 Macro H4/H1 Bias : " + macro_bias + "\n";
   info += " 📐 Golden Fib M15   : 50.0% (" + DoubleToString(fib.fib_500, 2) + ") - 61.8% (" + DoubleToString(fib.fib_618, 2) + ")\n";
   info += " ⏰ Institutional KZ : " + kz_status + "\n";
   info += "---------------------------------------------------------\n";
   info += " [🎯 ENGINE 1: M15 INSTITUTIONAL SINGLE-ENTRY SNIPER]\n";
   info += "  🎯 Posisi Sniper    : " + IntegerToString(sniper_total) + "/1 Posisi (Risk: 1.0% = " + DoubleToString(lot, 2) + " Lot)\n";
   info += "  🛡️ Dynamic SL / TP  : " + IntegerToString(dyn_sl / 10) + " Pips / +" + IntegerToString(dyn_tp / 10) + " Pips (RR 1:" + DoubleToString(InpRiskRewardRatio, 1) + ")\n";
   info += "  🎯 Status Sniper    : " + sniper_status + "\n";
   info += "---------------------------------------------------------\n";
   info += " [🌊 ENGINE 2: SWING RUNNER H4 (GOLDEN POCKET 1:3 RR)]\n";
   info += "  🌊 Posisi Swing    : " + IntegerToString(swing_total) + "/2 Posisi\n";
   info += "  🎯 Status Swing    : " + swing_status + "\n";
   info += "---------------------------------------------------------\n";
   info += " 🛡️ Spread Gold      : " + IntegerToString(current_spread) + " pts " + spread_status + "\n";
   info += " 📡 Dual Redundancy  : Discord + MT5 Mobile Push ✅\n";
   info += "=========================================================\n";

   Comment(info);
}

//+------------------------------------------------------------------+
//| MANAJEMEN POSISI TERBUKA (TRUE-BE & TRAILING STOP)               |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   double point = m_symbol.Point();
   double min_stop_dist = (m_symbol.StopsLevel() + m_symbol.Spread() + 10) * point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() != _Symbol) continue;

      ulong  ticket     = m_position.Ticket();
      ulong  magic      = m_position.Magic();
      double open_p     = m_position.PriceOpen();
      double cur_sl     = m_position.StopLoss();
      double cur_tp     = m_position.TakeProfit();
      double cur_bid    = m_symbol.Bid();
      double cur_ask    = m_symbol.Ask();
      double volume     = m_position.Volume();

      if(magic == InpMagicSniper)
      {
         double initial_sl_dist_pts = InpMinSLPoints;
         if(cur_tp > 0 && InpRiskRewardRatio > 0)
         {
            initial_sl_dist_pts = MathAbs(cur_tp - open_p) / (InpRiskRewardRatio * point);
         }
         if(initial_sl_dist_pts < InpMinSLPoints) initial_sl_dist_pts = InpMinSLPoints;

         if(m_position.PositionType() == POSITION_TYPE_BUY)
         {
            double profit_pts = (cur_bid - open_p) / point;

            // 1. Stage 1: Lock Profit & Partial Close 50% when Profit >= 1.5x SL Distance (+0.5R Lock)
            if(profit_pts >= 1.5 * initial_sl_dist_pts)
            {
               double lock_sl = m_symbol.NormalizePrice(open_p + (0.5 * initial_sl_dist_pts) * point);
               if(cur_sl < lock_sl && (cur_bid - lock_sl >= min_stop_dist))
               {
                  double lot_step_sym = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                  double min_lot_sym  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                  if(lot_step_sym <= 0) lot_step_sym = 0.01;
                  if(min_lot_sym <= 0) min_lot_sym = 0.01;

                  if(volume >= min_lot_sym * 2.0)
                  {
                     double close_vol = MathFloor((volume * 0.5) / lot_step_sym) * lot_step_sym;
                     if(close_vol >= min_lot_sym && close_vol < volume)
                     {
                        m_trade.SetExpertMagicNumber(InpMagicSniper);
                        m_trade.PositionClosePartial(ticket, close_vol);
                        Print("💰 [PARTIAL CLOSE 50%] Sniper BUY #", ticket, " amankan ", close_vol, " Lot cuan tunai ke saldo!");
                     }
                  }
                  m_trade.SetExpertMagicNumber(InpMagicSniper);
                  m_trade.PositionModify(ticket, lock_sl, cur_tp);
                  Print("🔒 [PROFIT LOCK +0.5R] Sniper BUY #", ticket, " surplus +", DoubleToString(profit_pts/10.0, 1), " pips! SL dikunci di +0.5R!");
               }
            }
            // 2. Stage 2: Trailing Stop when Profit >= 2.0x SL Distance
            else if(InpUseM15Trailing && profit_pts >= 2.0 * initial_sl_dist_pts)
            {
               double new_sl = m_symbol.NormalizePrice(cur_bid - (0.8 * initial_sl_dist_pts) * point);
               if(new_sl > cur_sl + InpTrailingStepPts * point && (cur_bid - new_sl >= min_stop_dist))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSniper);
                  m_trade.PositionModify(ticket, new_sl, cur_tp);
               }
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL)
         {
            double profit_pts = (open_p - cur_ask) / point;

            // 1. Stage 1: Lock Profit & Partial Close 50% when Profit >= 1.5x SL Distance (+0.5R Lock)
            if(profit_pts >= 1.5 * initial_sl_dist_pts)
            {
               double lock_sl = m_symbol.NormalizePrice(open_p - (0.5 * initial_sl_dist_pts) * point);
               if((cur_sl == 0 || cur_sl > lock_sl) && (lock_sl - cur_ask >= min_stop_dist))
               {
                  double lot_step_sym = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                  double min_lot_sym  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                  if(lot_step_sym <= 0) lot_step_sym = 0.01;
                  if(min_lot_sym <= 0) min_lot_sym = 0.01;

                  if(volume >= min_lot_sym * 2.0)
                  {
                     double close_vol = MathFloor((volume * 0.5) / lot_step_sym) * lot_step_sym;
                     if(close_vol >= min_lot_sym && close_vol < volume)
                     {
                        m_trade.SetExpertMagicNumber(InpMagicSniper);
                        m_trade.PositionClosePartial(ticket, close_vol);
                        Print("💰 [PARTIAL CLOSE 50%] Sniper SELL #", ticket, " amankan ", close_vol, " Lot cuan tunai ke saldo!");
                     }
                  }
                  m_trade.SetExpertMagicNumber(InpMagicSniper);
                  m_trade.PositionModify(ticket, lock_sl, cur_tp);
                  Print("🔒 [PROFIT LOCK +0.5R] Sniper SELL #", ticket, " surplus +", DoubleToString(profit_pts/10.0, 1), " pips! SL dikunci di +0.5R!");
               }
            }
            // 2. Stage 2: Trailing Stop when Profit >= 2.0x SL Distance
            else if(InpUseM15Trailing && profit_pts >= 2.0 * initial_sl_dist_pts)
            {
               double new_sl = m_symbol.NormalizePrice(cur_ask + (0.8 * initial_sl_dist_pts) * point);
               if((cur_sl == 0 || new_sl < cur_sl - InpTrailingStepPts * point) && (new_sl - cur_ask >= min_stop_dist))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSniper);
                  m_trade.PositionModify(ticket, new_sl, cur_tp);
               }
            }
         }
      }
      else if(magic == InpMagicSwing)
      {
         if(m_position.PositionType() == POSITION_TYPE_BUY)
         {
            double profit_points = (cur_bid - open_p) / point;
            if(InpUseMultiTierSwingLock && profit_points >= 1200)
            {
               double tier2_sl = m_symbol.NormalizePrice(open_p + 500 * point);
               if(cur_sl < tier2_sl && (cur_bid - tier2_sl >= min_stop_dist))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, tier2_sl, cur_tp);
               }
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL)
         {
            double profit_points = (open_p - cur_ask) / point;
            if(InpUseMultiTierSwingLock && profit_points >= 1200)
            {
               double tier2_sl = m_symbol.NormalizePrice(open_p - 500 * point);
               if((cur_sl == 0 || cur_sl > tier2_sl) && (tier2_sl - cur_ask >= min_stop_dist))
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(ticket, tier2_sl, cur_tp);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EKSEKUSI ORDER M15 SNIPER                                        |
//+------------------------------------------------------------------+
void ExecuteSniperOrder(ENUM_ORDER_TYPE order_type, string trigger_source, double sl_pts, double tp_pts)
{
   double lot = CalculateSniperLotSize((int)sl_pts);
   if(lot <= 0) return;

   int current_spread = (int)m_symbol.Spread();
   double point = m_symbol.Point();

   m_trade.SetExpertMagicNumber(InpMagicSniper);

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      double sl  = m_symbol.NormalizePrice(ask - sl_pts * point);
      double tp  = m_symbol.NormalizePrice(ask + tp_pts * point);

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, InpCommentSniper))
      {
         ulong ticket = m_trade.ResultOrder();
         Print("🎯 [M15 SNIPER BUY EXECUTED] Lot: ", lot, " | SL: -", sl_pts/10, " pips | TP: +", tp_pts/10, " pips");
         NotifyAITrade("SNIPER", "BUY", ask, lot, sl, tp, ticket, trigger_source, current_spread, (int)sl_pts, (int)tp_pts);
         last_sniper_time = TimeCurrent();
      }
      else
      {
         Print("❌ [SNIPER BUY REJECTED] Broker Retcode: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      double sl  = m_symbol.NormalizePrice(bid + sl_pts * point);
      double tp  = m_symbol.NormalizePrice(bid - tp_pts * point);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, InpCommentSniper))
      {
         ulong ticket = m_trade.ResultOrder();
         Print("🎯 [M15 SNIPER SELL EXECUTED] Lot: ", lot, " | SL: -", sl_pts/10, " pips | TP: +", tp_pts/10, " pips");
         NotifyAITrade("SNIPER", "SELL", bid, lot, sl, tp, ticket, trigger_source, current_spread, (int)sl_pts, (int)tp_pts);
         last_sniper_time = TimeCurrent();
      }
      else
      {
         Print("❌ [SNIPER SELL REJECTED] Broker Retcode: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| EKSEKUSI ORDER SWING RUNNER H4                                   |
//+------------------------------------------------------------------+
void ExecuteSwingOrder(ENUM_ORDER_TYPE order_type, string trigger_source)
{
   double point = m_symbol.Point();
   int swing_sl = InpSwingSLPoints, swing_tp1 = InpSwingTP1Points, swing_tp2 = InpSwingTP2RunnerPoints;
   GetAdaptiveSwingParameters(_Symbol, swing_sl, swing_tp1, swing_tp2);

   double lot = CalculateSwingLotSize(swing_sl);
   if(lot <= 0) lot = 0.01;

   int current_spread = (int)m_symbol.Spread();

   m_trade.SetExpertMagicNumber(InpMagicSwing);

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      double sl  = m_symbol.NormalizePrice(ask - swing_sl * point);
      double tp1 = m_symbol.NormalizePrice(ask + swing_tp1 * point);
      double tp2 = m_symbol.NormalizePrice(ask + swing_tp2 * point);

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp1, StringFormat("%s_TP1", InpCommentSwing)))
      {
         NotifyAITrade("SWING", "BUY (Tiket 1)", ask, lot, sl, tp1, m_trade.ResultOrder(), trigger_source, current_spread, swing_sl, swing_tp1);
      }
      if(m_trade.Buy(lot, _Symbol, ask, sl, tp2, StringFormat("%s_Runner", InpCommentSwing)))
      {
         NotifyAITrade("SWING", "BUY (Tiket 2)", ask, lot, sl, tp2, m_trade.ResultOrder(), trigger_source, current_spread, swing_sl, swing_tp2);
      }
      last_swing_time = TimeCurrent();
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      double sl  = m_symbol.NormalizePrice(bid + swing_sl * point);
      double tp1 = m_symbol.NormalizePrice(bid - swing_tp1 * point);
      double tp2 = m_symbol.NormalizePrice(bid - swing_tp2 * point);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp1, StringFormat("%s_TP1", InpCommentSwing)))
      {
         NotifyAITrade("SWING", "SELL (Tiket 1)", bid, lot, sl, tp1, m_trade.ResultOrder(), trigger_source, current_spread, swing_sl, swing_tp1);
      }
      if(m_trade.Sell(lot, _Symbol, bid, sl, tp2, StringFormat("%s_Runner", InpCommentSwing)))
      {
         NotifyAITrade("SWING", "SELL (Tiket 2)", bid, lot, sl, tp2, m_trade.ResultOrder(), trigger_source, current_spread, swing_sl, swing_tp2);
      }
      last_swing_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| ON TICK EXECUTION (INSTITUTIONAL M15 SNIPER MODEL v23.00)        |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!m_symbol.RefreshRates()) return;

   // 1. Cek Apakah Terkena Global Nuclear Kill-Switch
   if(g_emergency_kill_active) return;

   // 2. Prop Firm High-Watermark Drawdown Guard
   CheckPropFirmDailyWatermark();
   if(g_prop_firm_locked) return;

   // 3. Smart Perisai Jumat Malam (Weekend Gap Protection)
   if(IsFridayWeekendCleanTime())
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol)
         {
            ulong p_magic = m_position.Magic();
            if(p_magic == InpMagicSniper)
            {
               m_trade.SetExpertMagicNumber(InpMagicSniper);
               m_trade.PositionClose(m_position.Ticket());
            }
            else if(p_magic == InpMagicSwing)
            {
               bool is_safe_be = false;
               double p_sl = m_position.StopLoss();
               double p_op = m_position.PriceOpen();
               if(m_position.PositionType() == POSITION_TYPE_BUY && p_sl >= p_op) is_safe_be = true;
               if(m_position.PositionType() == POSITION_TYPE_SELL && p_sl > 0 && p_sl <= p_op) is_safe_be = true;

               if(!InpSwingHoldWeekendIfBE || !is_safe_be)
               {
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionClose(m_position.Ticket());
                  Print("🛡️ [FRIDAY WEEKEND GUARD] Menutup posisi Swing yang belum True-BE sebelum penutupan pasar akhir pekan!");
               }
            }
         }
      }
   }

   // 3.5 PROTEKSI TRIPLE-SWAP RABU MALAM (23:00 SERVER TIME)
   if(InpUseTripleSwapGuard)
   {
      MqlDateTime dt_swap;
      TimeToStruct(TimeCurrent(), dt_swap);
      if(dt_swap.day_of_week == 3 && dt_swap.hour == 23 && dt_swap.min >= 0 && dt_swap.min <= 50)
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicSwing)
            {
               if(m_position.Profit() > 0 && m_position.StopLoss() == 0)
               {
                  double true_be = CalculateCommissionAwareBE(m_position.PositionType() == POSITION_TYPE_BUY, m_position.PriceOpen(), m_position.Volume(), 10.0);
                  m_trade.SetExpertMagicNumber(InpMagicSwing);
                  m_trade.PositionModify(m_position.Ticket(), true_be, m_position.TakeProfit());
                  Print("🛡️ [TRIPLE-SWAP GUARD] Kunci True-BE sebelum rollover 3x Swap Rabu malam!");
               }
            }
         }
      }
   }

   // 4. SCAN LENGKAP POSISI AKTIF & MANUAL TRADE GUARD
   int sniper_total = 0, sniper_buy = 0, sniper_sell = 0;
   int swing_total = 0, swing_buy = 0, swing_sell = 0;
   bool manual_trade_found = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol)
      {
         ulong magic = m_position.Magic();
         if(magic == InpMagicSniper)
         {
            sniper_total++;
            if(m_position.PositionType() == POSITION_TYPE_BUY) sniper_buy++;
            else if(m_position.PositionType() == POSITION_TYPE_SELL) sniper_sell++;
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
         }
      }
   }

   // 5. MANUAL ENTRY GUARD
   if(InpUseManualTradeGuard)
   {
      if(manual_trade_found && !g_manual_trade_pause)
      {
         g_manual_trade_pause = true;
         Print("🚨 [MANUAL TRADE DETECTED] EA dijeda sementara.");
      }
      else if(!manual_trade_found && g_manual_trade_pause)
      {
         g_manual_trade_pause = false;
         Print("🟢 [MANUAL TRADE CLOSED] EA aktif kembali.");
      }
   }

   // 6. Manajemen Posisi Terbuka (True-BE & Trailing Lock)
   if(sniper_total > 0 || swing_total > 0)
   {
      ManageOpenPositions();
   }

   // 7. Hitung Fibonacci M15 & H4
   SFibLevels fib_m15;
   CalculateM15FibonacciLevels(fib_m15, 24);
   SFibLevels fib_h4;
   CalculateH4FibonacciLevels(fib_h4, 24);

   // 8. Hitung SL/TP Dinamis untuk Dashboard
   double dyn_sl_pts = InpMinSLPoints, dyn_tp_pts = InpMinSLPoints * InpRiskRewardRatio;
   CalculateM15StructuralSLTP(true, dyn_sl_pts, dyn_tp_pts);

   // 9. Ambil Data Candlestick M15 Terkini
   MqlRates rates_m15[];
   ArraySetAsSeries(rates_m15, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 5, rates_m15) < 5) return;

   // 10. Ambil Buffer Indikator M15, H1, H4
   double ema50_m15_buf[], rsi_m15_buf[], ema50_h1_buf[], ema21_h1_buf[], ema50_h4_buf[], ema200_h4_buf[], rsi_h4_buf[], adx_h4_buf[];
   ArraySetAsSeries(ema50_m15_buf, true);
   ArraySetAsSeries(rsi_m15_buf, true);
   ArraySetAsSeries(ema50_h1_buf, true);
   ArraySetAsSeries(ema21_h1_buf, true);
   ArraySetAsSeries(ema50_h4_buf, true);
   ArraySetAsSeries(ema200_h4_buf, true);
   ArraySetAsSeries(rsi_h4_buf, true);
   ArraySetAsSeries(adx_h4_buf, true);

   if(CopyBuffer(handle_ema50_m15, 0, 0, 2, ema50_m15_buf) <= 0) return;
   if(CopyBuffer(handle_rsi_m15, 0, 0, 2, rsi_m15_buf) <= 0) return;
   if(CopyBuffer(handle_ema50_h1, 0, 0, 2, ema50_h1_buf) <= 0) return;
   if(CopyBuffer(handle_ema21_h1, 0, 0, 2, ema21_h1_buf) <= 0) return;
   if(CopyBuffer(handle_ema50_h4, 0, 0, 2, ema50_h4_buf) <= 0) return;
   if(CopyBuffer(handle_ema200_h4, 0, 0, 2, ema200_h4_buf) <= 0) return;
   if(CopyBuffer(handle_rsi_h4, 0, 0, 2, rsi_h4_buf) <= 0) return;
   if(CopyBuffer(handle_adx_h4, 0, 0, 2, adx_h4_buf) <= 0) return;

   SetOptimalFillingMode();
   double ema50_m15 = ema50_m15_buf[1];
   double rsi_m15   = rsi_m15_buf[1];
   double ema50_h1  = ema50_h1_buf[1];
   double ema21_h1  = ema21_h1_buf[1];
   double ema50_h4  = ema50_h4_buf[1];
   double ema200_h4 = ema200_h4_buf[1];
   double rsi_h4    = rsi_h4_buf[1];
   double adx_h4    = adx_h4_buf[1];

   bool macro_bullish = (rates_m15[1].close > ema50_h1) && (ema50_h4 > ema200_h4);
   bool macro_bearish = (rates_m15[1].close < ema50_h1) && (ema50_h4 < ema200_h4);
   string macro_bias_str = macro_bullish ? "BULLISH DOMINANCE 🟢" : macro_bearish ? "BEARISH DOMINANCE 🔴" : "NETRAL ⚪";

   // 10.5 DETEKSI STATUS INSTITUTIONAL KILL-ZONE
   string current_kz_name = "";
   bool is_in_killzone = IsInsideInstitutionalKillZone(current_kz_name);

   // 11. ANATOMI REJECTION CANDLE M15 (BAR 1 CONFIRMED CLOSE)
   double bar1_open  = rates_m15[1].open;
   double bar1_high  = rates_m15[1].high;
   double bar1_low   = rates_m15[1].low;
   double bar1_close = rates_m15[1].close;
   double bar1_range = bar1_high - bar1_low;

   double lower_wick = MathMin(bar1_open, bar1_close) - bar1_low;
   double upper_wick = bar1_high - MathMax(bar1_open, bar1_close);

   double bar2_body = MathAbs(rates_m15[2].close - rates_m15[2].open);
   double bar1_body = MathAbs(bar1_close - bar1_open);
   bool is_bullish_engulf = (bar1_close > bar1_open) && (rates_m15[2].close < rates_m15[2].open) && (bar1_close > rates_m15[2].open) && (bar1_open < rates_m15[2].close);
   bool is_bearish_engulf = (bar1_close < bar1_open) && (rates_m15[2].close > rates_m15[2].open) && (bar1_close < rates_m15[2].open) && (bar1_open > rates_m15[2].close);

   bool is_bullish_rejection = (bar1_range > 0) && ((lower_wick >= 0.45 * bar1_range && bar1_close >= bar1_open) || is_bullish_engulf);
   bool is_bearish_rejection = (bar1_range > 0) && ((upper_wick >= 0.45 * bar1_range && bar1_close <= bar1_open) || is_bearish_engulf);

   // =================================================================
   // 12. EVALUASI MESIN 1: M15 INSTITUTIONAL SINGLE-ENTRY SNIPER
   // =================================================================
   bool sniper_buy_sig = false;
   bool sniper_sell_sig = false;
   string sniper_reason = "";

   // Evaluasi Sinyal pada Jendela 90-Detik Pertama Pembukaan Candle M15 (Anti-Spread Spike Miss)
   datetime current_m15_bar_time = rates_m15[0].time;
   bool is_bar_opening_window = (TimeCurrent() - current_m15_bar_time <= 90);
   bool is_new_m15_bar        = (current_m15_bar_time != g_last_m15_eval_bar);

   if((is_new_m15_bar || is_bar_opening_window) && sniper_total == 0)
   {
      double ask_now = m_symbol.Ask();
      double bid_now = m_symbol.Bid();

      // Cek FVG M15 (8-Bar Imbalance Lookback)
      SFairValueGap fvg;
      DetectM15FairValueGap(fvg);

      // BUY CONFLUENCE SETUP (A+ Institutional Quality Only)
      if(macro_bullish && rsi_m15 >= 40.0 && rsi_m15 <= 60.0 && is_bullish_rejection)
      {
         bool in_fib_pocket = (fib_m15.fib_500 > 0 && bar1_low <= fib_m15.fib_500 && bar1_close >= fib_m15.fib_786);
         bool in_fvg_retest = (fvg.exists && fvg.is_bullish && bar1_low <= fvg.upper_level && bar1_close >= fvg.lower_level);

         if(in_fib_pocket || in_fvg_retest)
         {
            sniper_buy_sig = true;
            sniper_reason = in_fib_pocket ? "M15 Golden Fib Pocket (50-61.8%) Rejection" : "M15 FVG Retest Rejection";
         }
      }
      // SELL CONFLUENCE SETUP (A+ Institutional Quality Only)
      else if(macro_bearish && rsi_m15 >= 40.0 && rsi_m15 <= 60.0 && is_bearish_rejection)
      {
         bool in_fib_pocket = (fib_m15.fib_500 > 0 && bar1_high >= fib_m15.fib_500 && bar1_close <= fib_m15.fib_786);
         bool in_fvg_retest = (fvg.exists && !fvg.is_bullish && bar1_high >= fvg.lower_level && bar1_close <= fvg.upper_level);

         if(in_fib_pocket || in_fvg_retest)
         {
            sniper_sell_sig = true;
            sniper_reason = in_fib_pocket ? "M15 Golden Fib Pocket (50-61.8%) Rejection" : "M15 FVG Retest Rejection";
         }
      }
   }

   // =================================================================
   // 13. EVALUASI MESIN 2: SWING RUNNER H4 (GOLDEN FIB POCKET)
   // =================================================================
   bool swing_buy_sig = false;
   bool swing_sell_sig = false;
   string swing_reason = "";

   if(InpEnableSwingEngine && (TimeCurrent() - g_last_swing_eval_time >= 60))
   {
      double ask_now = m_symbol.Ask();
      double bid_now = m_symbol.Bid();
      double point = m_symbol.Point();

      ENUM_ASSET_CLASS asset_for_adx = GetAssetClass(_Symbol);
      double min_adx_threshold = (asset_for_adx == ASSET_GOLD) ? InpSwingMinADX : (asset_for_adx == ASSET_FOREX) ? 16.0 : 18.0;
      bool is_trend_strong = (adx_h4 >= min_adx_threshold);
      bool buy_dist_ok = ((ask_now - ema21_h1) / point <= InpSwingMaxChasePts);
      bool sell_dist_ok = ((ema21_h1 - bid_now) / point <= InpSwingMaxChasePts);

      if(macro_bullish && is_trend_strong && rsi_h4 >= 40.0 && rsi_h4 <= 62.0 && buy_dist_ok && ask_now <= fib_h4.fib_500 && ask_now >= fib_h4.fib_786)
      {
         if(swing_total == 0)
         {
            swing_buy_sig = true;
            swing_reason = "H4 Golden Fib Pocket + Trend Momentum";
         }
      }
      else if(macro_bearish && is_trend_strong && rsi_h4 >= 38.0 && rsi_h4 <= 60.0 && sell_dist_ok && bid_now >= fib_h4.fib_500 && bid_now <= fib_h4.fib_786)
      {
         if(swing_total == 0)
         {
            swing_sell_sig = true;
            swing_reason = "H4 Golden Fib Pocket + Trend Momentum";
         }
      }
      g_last_swing_eval_time = TimeCurrent();
   }

   // 14. Update Dashboard
   string sniper_status = (sniper_total > 0) ? "🎯 RUNNING SNIPER (1 Posisi Aktif)" :
                          sniper_buy_sig ? "🟢 BUY SIGNAL CONFIRMED!" :
                          sniper_sell_sig ? "🔴 SELL SIGNAL CONFIRMED!" : "STANDBY SCANNING M15 STRUCTURE...";

   string swing_status  = (swing_total > 0) ? "🌊 RUNNING SWING (Aktif)" : "STANDBY MONITORING H4...";

   DisplayAIDashboard(sniper_status, swing_status, (int)dyn_sl_pts, (int)dyn_tp_pts, sniper_total, swing_total, macro_bias_str, fib_m15, current_kz_name);

   // 15. Proteksi Filter Umum
   if(g_emergency_kill_active || g_prop_firm_locked || g_manual_trade_pause) return;
   if(IsHighImpactNewsTime()) return;
   if(IsFridayWeekendCleanTime()) return;
   if(IsRolloverTime()) return;
   if(m_symbol.Spread() > g_max_spread) return;
   if(TimeCurrent() < g_cooldown_until) return;

   // 15.3 DIRECTIONAL CONCURRENCY LOCK (ANTI-BENTROKAN DUAL-ENGINE)
   bool sniper_buy_locked_be = false, sniper_sell_locked_be = false;
   bool swing_buy_locked_be  = false, swing_sell_locked_be  = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == _Symbol)
      {
         double p_sl = m_position.StopLoss();
         double p_op = m_position.PriceOpen();
         if(m_position.Magic() == InpMagicSniper)
         {
            if(m_position.PositionType() == POSITION_TYPE_BUY && p_sl >= p_op) sniper_buy_locked_be = true;
            if(m_position.PositionType() == POSITION_TYPE_SELL && p_sl > 0 && p_sl <= p_op) sniper_sell_locked_be = true;
         }
         else if(m_position.Magic() == InpMagicSwing)
         {
            if(m_position.PositionType() == POSITION_TYPE_BUY && p_sl >= p_op) swing_buy_locked_be = true;
            if(m_position.PositionType() == POSITION_TYPE_SELL && p_sl > 0 && p_sl <= p_op) swing_sell_locked_be = true;
         }
      }
   }

   bool can_sniper_buy  = (swing_buy == 0 || swing_buy_locked_be);
   bool can_sniper_sell = (swing_sell == 0 || swing_sell_locked_be);
   bool can_swing_buy   = (sniper_buy == 0 || sniper_buy_locked_be);
   bool can_swing_sell  = (sniper_sell == 0 || sniper_sell_locked_be);

   // 15.5 PROTEKSI SHARED PORTFOLIO RISK MATRIX
   double open_port_risk = CalculateTotalPortfolioOpenRiskPct();
   bool is_portfolio_risk_ok = (open_port_risk + InpRiskPercent <= InpMaxPortfolioRiskPct) && (PositionsTotal() < InpMaxTotalOpenTradesAll);

   // 16. EKSEKUSI MESIN 1: M15 SNIPER (SINGLE SNIPER ENTRY)
   if(InpEnableM15Sniper && sniper_total == 0 && is_in_killzone && is_portfolio_risk_ok)
   {
      if(sniper_buy_sig && can_sniper_buy)
      {
         double sl_pts = 0, tp_pts = 0;
         CalculateM15StructuralSLTP(true, sl_pts, tp_pts);
         ExecuteSniperOrder(ORDER_TYPE_BUY, sniper_reason, sl_pts, tp_pts);
      }
      else if(sniper_sell_sig && can_sniper_sell)
      {
         double sl_pts = 0, tp_pts = 0;
         CalculateM15StructuralSLTP(false, sl_pts, tp_pts);
         ExecuteSniperOrder(ORDER_TYPE_SELL, sniper_reason, sl_pts, tp_pts);
      }
   }

   // 17. EKSEKUSI MESIN 2: SWING H4 RUNNER
   if(InpEnableSwingEngine && swing_total == 0 && is_portfolio_risk_ok && (TimeCurrent() - last_swing_time >= 300))
   {
      if(swing_buy_sig && can_swing_buy)
      {
         ExecuteSwingOrder(ORDER_TYPE_BUY, swing_reason);
      }
      else if(swing_sell_sig && can_swing_sell)
      {
         ExecuteSwingOrder(ORDER_TYPE_SELL, swing_reason);
      }
   }
}
//+------------------------------------------------------------------+
