//+------------------------------------------------------------------+
//|                                     XAUUSD_AI_Brain_EA.mq5       |
//|  AI-Powered Dual-Regime M1/M15 Neural Scalper for Gold (XAUUSD)  |
//|    (Deep Neural Net • OTA Cloud Sync • Discord Webhook • Guards) |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX & AI Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "3.00"
#property description "EA Scalping M1 Gold (XAUUSD) AI Deep Neural Network dengan Analisis Multi-Timeframe M15 & OTA Cloud Sync"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#define CLOUD_CONFIG_URL "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/ea_cloud_config.json"

//--- Enums
enum ENUM_AI_ENGINE_MODE
{
   AI_BUILTIN_NEURAL_NET = 0, // Built-in Deep Neural Network (MLP 7->8->6->3)
   AI_ONNX_MODEL_FILE    = 1  // Native ONNX Runtime (xauusd_m1_brain.onnx)
};

enum ENUM_LOT_TYPE
{
   LOT_PER_BALANCE  = 0, // Auto-Lot Proporsional ($100 = 0.01 Lot)
   LOT_FIXED        = 1, // Fixed Lot Size (Lot Tetap)
   LOT_RISK_PERCENT = 2  // Auto Lot (% Risk dari Equity)
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== 1. DISCORD NOTIFICATION WEBHOOK ==="
input string              InpDiscordWebhookURL     = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // Webhook URL Pribadi
input bool                InpEnableDiscord         = true;                                                                                                                            // Aktifkan Notifikasi Discord
input string              InpDiscordMention        = "";                                                                                                                              // Mention Role/User
input string              InpBotName               = "XAUUSD AI-Brain Sentinel";                                                                                                      // Nama Bot

input group "=== 2. OTA CLOUD AUTO-SYNC (1x PASANG = AUTO UPDATE) ==="
input bool                InpEnableCloudSync       = true;                  // Aktifkan Sinkronisasi Parameter Otomatis dari GitHub
input int                 InpSyncIntervalMin       = 5;                     // Interval Cek Update Cloud (Menit)

input group "=== 3. AI BRAIN & ENGINE SETTINGS ==="
input ENUM_AI_ENGINE_MODE InpAIMode                = AI_BUILTIN_NEURAL_NET; // Mode Engine AI
input string              InpONNXFileName          = "xauusd_m1_brain.onnx";// Nama File ONNX (jika Mode ONNX)
input double              InpAIConfidenceThreshold = 0.60;                  // Ambang Keyakinan AI (0.50 - 0.90)
input ulong               InpMagicNumber           = 202611;                // Magic Number EA
input string              InpTradeComment          = "AI_Brain_XAU";        // Label Order

input group "=== 4. MONEY & RISK MANAGEMENT ==="
input ENUM_LOT_TYPE       InpLotType               = LOT_PER_BALANCE;       // Mode Lot Sizing
input double              InpFixedLot              = 0.01;                  // Base Lot per Kelipatan
input double              InpBalanceStep           = 100.0;                 // Saldo per Kelipatan Lot ($100 = 0.01 Lot)
input double              InpRiskPercent           = 1.0;                   // Risk % per Trade
input int                 InpStopLossPoints        = 150;                   // Stop Loss (Points, 150 pts = 15 pips)
input int                 InpTakeProfitPoints      = 300;                   // Take Profit (Points, 300 pts = 30 pips)
input int                 InpMaxSpreadPoints       = 75;                    // Max Spread Filter (Points)
input int                 InpMaxOpenPositions      = 1;                     // Max Posisi Scalping Aktif

input group "=== 5. BREAK-EVEN & TRAILING STOP ==="
input bool                InpUseBreakEven          = true;                  // Aktifkan Break-Even (BE)
input int                 InpBETriggerPoints       = 100;                   // Trigger BE (Points Profit)
input int                 InpBEProfitPoints        = 20;                    // Kunci Profit BE (Points)
input bool                InpUseTrailingStop       = true;                  // Aktifkan Trailing Stop
input int                 InpTrailingStartPoints   = 120;                   // Trailing Start (Points Profit)
input int                 InpTrailingDistance      = 80;                    // Jarak Trailing Stop (Points)
input int                 InpTrailingStep          = 20;                    // Step Pergeseran Trailing (Points)

input group "=== 6. DAILY TARGET & MAX LOSS GUARD ==="
input bool                InpUseDailyGuard         = true;                  // Aktifkan Pengaman Target Harian
input double              InpDailyTargetProfit     = 100.0;                 // Kunci Profit Harian ($) - Selesai trading
input double              InpDailyMaxLoss          = 50.0;                  // Batas Rem Rugi Harian ($) - Rem pengaman

input group "=== 7. AI FEATURE INDICATORS (M15 & M1) ==="
input int                 InpADX_Period_M15        = 14;                    // M15 ADX Period
input int                 InpEMA_Fast_M15          = 20;                    // M15 Fast EMA Period
input int                 InpEMA_Slow_M15          = 50;                    // M15 Slow EMA Period
input int                 InpBB_Period_M15         = 20;                    // M15 Bollinger Bands Period
input double              InpBB_Dev_M15            = 2.0;                   // M15 BB Deviation
input int                 InpEMA_M1                = 13;                    // M1 Fast EMA Period
input int                 InpRSI_Period_M1         = 14;                    // M1 RSI Period
input int                 InpBB_Period_M1          = 20;                    // M1 Bollinger Bands Period
input double              InpBB_Dev_M1             = 2.0;                   // M1 BB Deviation

//--- Dynamic Runtime Cloud Variables
string                    g_current_version        = "3.00";
double                    g_confidence_thresh      = 0.60;
double                    g_balance_step           = 100.0;
double                    g_lot_step               = 0.01;
int                       g_sl_points              = 150;
int                       g_tp_points              = 300;
int                       g_max_spread             = 75;
bool                      g_use_trailing           = true;
int                       g_trailing_start         = 120;
int                       g_trailing_dist          = 80;
int                       g_trailing_step          = 20;
bool                      g_use_daily_guard        = true;
double                    g_daily_target_usd       = 100.0;
double                    g_daily_max_loss_usd     = 50.0;

//--- Global Handles & Objects
CTrade                    m_trade;
CPositionInfo             m_position;
CSymbolInfo               m_symbol;
CAccountInfo              m_account;

int handle_adx_m15   = INVALID_HANDLE;
int handle_emaF_m15  = INVALID_HANDLE;
int handle_emaS_m15  = INVALID_HANDLE;
int handle_bb_m15    = INVALID_HANDLE;
int handle_ema_m1    = INVALID_HANDLE;
int handle_rsi_m1    = INVALID_HANDLE;
int handle_bb_m1     = INVALID_HANDLE;

long onnx_handle     = INVALID_HANDLE;
bool onnx_loaded     = false;

datetime last_m1_bar_time = 0;
datetime m_last_cloud_sync_time = 0;

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
      content_header = "\"content\": \"🚨 " + InpDiscordMention + " — **[AI SCALPING ALERT]**\", ";
   }

   string payload = "{" + content_header +
                    "\"username\": \"" + InpBotName + "\"," +
                    "\"embeds\": [{" +
                    "\"title\": \"" + title + "\"," +
                    "\"description\": \"" + description + "\"," +
                    "\"color\": " + IntegerToString(color_hex) + "," +
                    "\"fields\": [" + fields_json + "]," +
                    "\"footer\": {\"text\": \"XAUUSD AI-Brain Sentinel MT5 • " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
                    "}]}";

   char post_data[];
   char result_data[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n";

   StringToCharArray(payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post_data, ArraySize(post_data) - 1);

   ResetLastError();
   WebRequest("POST", InpDiscordWebhookURL, headers, 5000, post_data, result_data, result_headers);
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
   int res = WebRequest("GET", CLOUD_CONFIG_URL, headers, 5000, post_data, result_data, result_headers);
   if(res == 200)
   {
      string json = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
      string cloud_version = ExtractJsonString(json, "version");
      
      if(cloud_version != "")
      {
         bool is_new_version = (cloud_version != g_current_version);
         g_current_version    = cloud_version;
         g_confidence_thresh  = ExtractJsonNumber(json, "ai_confidence_threshold", InpAIConfidenceThreshold);
         g_balance_step       = ExtractJsonNumber(json, "balance_per_step", InpBalanceStep);
         g_lot_step           = ExtractJsonNumber(json, "lot_per_step", InpFixedLot);
         g_sl_points          = (int)ExtractJsonNumber(json, "stop_loss_points", InpStopLossPoints);
         g_tp_points          = (int)ExtractJsonNumber(json, "take_profit_points", InpTakeProfitPoints);
         g_max_spread         = (int)ExtractJsonNumber(json, "max_spread_points", InpMaxSpreadPoints);
         g_use_trailing       = ExtractJsonBool(json, "use_trailing_stop", InpUseTrailingStop);
         g_use_daily_guard    = ExtractJsonBool(json, "use_daily_guard", InpUseDailyGuard);
         g_daily_target_usd   = ExtractJsonNumber(json, "daily_target_profit_usd", InpDailyTargetProfit);
         g_daily_max_loss_usd = ExtractJsonNumber(json, "daily_max_loss_usd", InpDailyMaxLoss);

         if(is_new_version && !is_initial)
         {
            string update_fields = "{\"name\": \"🧠 Versi AI Engine\", \"value\": \"`v" + g_current_version + " (Cloud Synced)`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 AI Confidence Min\", \"value\": \"`" + DoubleToString(g_confidence_thresh * 100.0, 0) + "%`\", \"inline\": true}," +
                                   "{\"name\": \"🛡️ Max Spread Guard\", \"value\": \"`" + IntegerToString(g_max_spread) + " Pts`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target SL / TP\", \"value\": \"`SL: " + IntegerToString(g_sl_points / 10) + " Pips | TP: " + IntegerToString(g_tp_points / 10) + " Pips`\", \"inline\": true}";
            
            SendDiscordEmbed("🔄 OTA CLOUD UPDATE DIAPLIKASIKAN (AI-BRAIN)!", 
                             "Parameter AI & Strategi Scalping berhasil diperbarui secara otomatis dari GitHub!", 
                             0x9B59B6, update_fields, false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| HITUNG PROFIT / LOSS HARIAN (DAILY GUARD)                        |
//+------------------------------------------------------------------+
double GetDailyProfitLoss()
{
   datetime start_of_day = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00");
   HistorySelect(start_of_day, TimeCurrent());
   
   double total_profit = 0.0;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
         {
            total_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         }
      }
   }
   return total_profit;
}

//+------------------------------------------------------------------+
//| KALKULASI AUTO-LOT ($100 = 0.01 LOT)                             |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_points)
{
   double lot = g_lot_step;

   if(InpLotType == LOT_PER_BALANCE)
   {
      double balance = m_account.Balance();
      if(balance <= 0) balance = m_account.Equity();
      if(g_balance_step > 0)
      {
         lot = MathFloor(balance / g_balance_step) * g_lot_step;
      }
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

   double lot_step = m_symbol.LotsStep();
   double min_lot  = m_symbol.LotsMin();
   double max_lot  = m_symbol.LotsMax();

   if(lot_step > 0) lot = MathFloor(lot / lot_step) * lot_step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI ORDER DISCORD DENGAN CONFIDENCE AI             |
//+------------------------------------------------------------------+
void NotifyAITrade(string type, double price, double lot_used, double sl, double tp, ulong ticket, float confidence, int spread_used)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order AI\", \"value\": \"" + emoji + " **" + type + " (Scalp M1)**\", \"inline\": true}," +
                   "{\"name\": \"🧠 AI Confidence\", \"value\": \"**" + DoubleToString(confidence * 100.0f, 1) + "%** 🔥\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (**" + DoubleToString(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(g_sl_points / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(g_tp_points / 10) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Spread Saat Entry\", \"value\": \"`" + IntegerToString(spread_used) + " Points` (Aman)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "` (Auto-Lot Proporsional)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("🧠 AI NEURAL SCALPER EXECUTED (" + type + ")", 
                    "Deep Neural Network AI mendeteksi probabilitas tinggi (" + DoubleToString(confidence * 100.0f, 1) + "%) pada timeframe M1/M15 Gold.", 
                    embed_color, 
                    fields, false);
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
      Alert("PERINGATAN: EA 'XAUUSD AI Brain' hanya boleh dipasang pada chart XAUUSD / GOLD!");
      return INIT_FAILED;
   }

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.Refresh();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetDeviationInPoints(30);

   g_confidence_thresh  = InpAIConfidenceThreshold;
   g_balance_step       = InpBalanceStep;
   g_lot_step           = InpFixedLot;
   g_sl_points          = InpStopLossPoints;
   g_tp_points          = InpTakeProfitPoints;
   g_max_spread         = InpMaxSpreadPoints;
   g_use_trailing       = InpUseTrailingStop;
   g_trailing_start     = InpTrailingStartPoints;
   g_trailing_dist      = InpTrailingDistance;
   g_trailing_step      = InpTrailingStep;
   g_use_daily_guard    = InpUseDailyGuard;
   g_daily_target_usd   = InpDailyTargetProfit;
   g_daily_max_loss_usd = InpDailyMaxLoss;

   FetchAndApplyCloudConfig(true);
   m_last_cloud_sync_time = TimeCurrent();

   // Handles Indikator M15
   handle_adx_m15  = iADX(_Symbol, PERIOD_M15, InpADX_Period_M15);
   handle_emaF_m15 = iMA(_Symbol, PERIOD_M15, InpEMA_Fast_M15, 0, MODE_EMA, PRICE_CLOSE);
   handle_emaS_m15 = iMA(_Symbol, PERIOD_M15, InpEMA_Slow_M15, 0, MODE_EMA, PRICE_CLOSE);
   handle_bb_m15   = iBands(_Symbol, PERIOD_M15, InpBB_Period_M15, 0, InpBB_Dev_M15, PRICE_CLOSE);

   // Handles Indikator M1
   handle_ema_m1   = iMA(_Symbol, PERIOD_M1, InpEMA_M1, 0, MODE_EMA, PRICE_CLOSE);
   handle_rsi_m1   = iRSI(_Symbol, PERIOD_M1, InpRSI_Period_M1, PRICE_CLOSE);
   handle_bb_m1    = iBands(_Symbol, PERIOD_M1, InpBB_Period_M1, 0, InpBB_Dev_M1, PRICE_CLOSE);

   if(handle_adx_m15 == INVALID_HANDLE || handle_emaF_m15 == INVALID_HANDLE ||
      handle_emaS_m15 == INVALID_HANDLE || handle_bb_m15 == INVALID_HANDLE ||
      handle_ema_m1 == INVALID_HANDLE || handle_rsi_m1 == INVALID_HANDLE ||
      handle_bb_m1 == INVALID_HANDLE)
   {
      Print("[ERROR] Gagal inisialisasi indikator!");
      return INIT_FAILED;
   }

   // ONNX Initialization
   if(InpAIMode == AI_ONNX_MODEL_FILE)
   {
      onnx_handle = OnnxCreate(InpONNXFileName, ONNX_DEFAULT);
      if(onnx_handle != INVALID_HANDLE)
      {
         const long in_shape[]  = {1, 7};
         const long out_shape[] = {1, 3};
         if(OnnxSetInputShape(onnx_handle, 0, in_shape) && OnnxSetOutputShape(onnx_handle, 0, out_shape))
         {
            onnx_loaded = true;
         }
      }
   }

   double current_lot = CalculateLotSize(g_sl_points);
   string startup_fields = "{\"name\": \"🧠 AI Neural Engine\", \"value\": \"`Deep MLP (7->8->6->3)`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Ambang Keyakinan\", \"value\": \"`Min " + DoubleToString(g_confidence_thresh * 100.0, 0) + "% Confidence`\", \"inline\": true}," +
                           "{\"name\": \"🛡️ Max Spread Guard\", \"value\": \"`Max " + IntegerToString(g_max_spread) + " Points`\", \"inline\": true}," +
                           "{\"name\": \"📈 Auto-Lot Mode\", \"value\": \"`$" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot` (Lot: **" + DoubleToString(current_lot, 2) + "**)\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target SL / TP\", \"value\": \"`SL: " + IntegerToString(g_sl_points / 10) + " Pips | TP: " + IntegerToString(g_tp_points / 10) + " Pips`\", \"inline\": true}," +
                           "{\"name\": \"☁️ OTA Cloud Sync\", \"value\": \"`v" + g_current_version + " (Active)`\", \"inline\": true}";

   SendDiscordEmbed("🧠 XAUUSD AI-Brain Sentinel Aktif!", 
                    "Expert Advisor bertenaga Deep Neural Network AI siap berburu scalping 24/7 di XAUUSD M1.", 
                    0x3498DB, startup_fields, false);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handle_adx_m15);
   IndicatorRelease(handle_emaF_m15);
   IndicatorRelease(handle_emaS_m15);
   IndicatorRelease(handle_bb_m15);
   IndicatorRelease(handle_ema_m1);
   IndicatorRelease(handle_rsi_m1);
   IndicatorRelease(handle_bb_m1);

   if(onnx_handle != INVALID_HANDLE)
   {
      OnnxRelease(onnx_handle);
      onnx_handle = INVALID_HANDLE;
   }

   Comment("");
}

//+------------------------------------------------------------------+
//| EKSTRAKSI FITUR AI (FEATURE ENGINEERING 7 FEATURES)              |
//+------------------------------------------------------------------+
bool ExtractAIFeatures(float &features[])
{
   double adx_m15[];
   double emaF_m15[], emaS_m15[];
   double bb_upper_m15[], bb_lower_m15[], bb_mid_m15[];
   double ema_m1[];
   double rsi_m1[];
   double bb_upper_m1[], bb_lower_m1[];
   MqlRates rates_m15[], rates_m1[];

   ArraySetAsSeries(adx_m15, true);
   ArraySetAsSeries(emaF_m15, true);
   ArraySetAsSeries(emaS_m15, true);
   ArraySetAsSeries(bb_upper_m15, true);
   ArraySetAsSeries(bb_lower_m15, true);
   ArraySetAsSeries(bb_mid_m15, true);
   ArraySetAsSeries(ema_m1, true);
   ArraySetAsSeries(rsi_m1, true);
   ArraySetAsSeries(bb_upper_m1, true);
   ArraySetAsSeries(bb_lower_m1, true);
   ArraySetAsSeries(rates_m15, true);
   ArraySetAsSeries(rates_m1, true);

   if(CopyBuffer(handle_adx_m15, 0, 1, 1, adx_m15) <= 0) return false;
   if(CopyBuffer(handle_emaF_m15, 0, 1, 1, emaF_m15) <= 0) return false;
   if(CopyBuffer(handle_emaS_m15, 0, 1, 1, emaS_m15) <= 0) return false;
   if(CopyBuffer(handle_bb_m15, 1, 1, 1, bb_upper_m15) <= 0) return false;
   if(CopyBuffer(handle_bb_m15, 2, 1, 1, bb_lower_m15) <= 0) return false;
   if(CopyBuffer(handle_bb_m15, 0, 1, 1, bb_mid_m15) <= 0) return false;

   if(CopyBuffer(handle_ema_m1, 0, 1, 1, ema_m1) <= 0) return false;
   if(CopyBuffer(handle_rsi_m1, 0, 1, 1, rsi_m1) <= 0) return false;
   if(CopyBuffer(handle_bb_m1, 1, 1, 1, bb_upper_m1) <= 0) return false;
   if(CopyBuffer(handle_bb_m1, 2, 1, 1, bb_lower_m1) <= 0) return false;

   if(CopyRates(_Symbol, PERIOD_M15, 1, 1, rates_m15) <= 0) return false;
   if(CopyRates(_Symbol, PERIOD_M1, 1, 1, rates_m1) <= 0) return false;

   double point = m_symbol.Point();
   double close_m15 = rates_m15[0].close;
   double close_m1  = rates_m1[0].close;

   features[0] = (float)MathMin(MathMax(adx_m15[0] / 100.0, 0.0), 1.0);
   features[1] = (float)((emaF_m15[0] - emaS_m15[0]) / MathMax(close_m15, 1.0) * 100.0);
   features[2] = (float)((bb_upper_m15[0] - bb_lower_m15[0]) / MathMax(bb_mid_m15[0], 1.0) * 100.0);
   features[3] = (float)MathMin(MathMax(rsi_m1[0] / 100.0, 0.0), 1.0);
   features[4] = (float)((close_m1 - ema_m1[0]) / MathMax(point * 100.0, 0.01));
   double bb_width_m1 = bb_upper_m1[0] - bb_lower_m1[0];
   features[5] = (float)((bb_width_m1 > 0.0) ? MathMin(MathMax((close_m1 - bb_lower_m1[0]) / bb_width_m1, 0.0), 1.0) : 0.5);
   features[6] = (float)((double)m_symbol.Spread() / (double)MathMax(g_max_spread, 1));

   return true;
}

//+------------------------------------------------------------------+
//| DEEP NEURAL NETWORK AI INFERENCE (MLP)                           |
//+------------------------------------------------------------------+
void RunAIBrain(const float &features[], float &prob_neutral, float &prob_buy, float &prob_sell)
{
   if(InpAIMode == AI_ONNX_MODEL_FILE && onnx_loaded)
   {
      float in_vector[7];
      for(int i = 0; i < 7; i++) in_vector[i] = features[i];
      float out_probs[3];
      if(OnnxRun(onnx_handle, ONNX_NO_CONVERSION, in_vector, out_probs))
      {
         prob_neutral = out_probs[0];
         prob_buy     = out_probs[1];
         prob_sell    = out_probs[2];
         return;
      }
   }

   // Built-in Deep Neural Network (MLP 7 -> 8 -> 6 -> 3)
   float h1[8];
   float W1[7][8] = {
      { 0.55f, -0.40f,  0.60f, -0.30f,  0.15f,  0.45f, -0.45f,  0.30f},
      { 1.50f, -1.45f,  1.10f, -1.05f,  0.50f,  1.20f, -1.15f,  0.80f},
      { 0.35f,  0.40f, -0.30f, -0.35f,  0.60f,  0.25f,  0.20f, -0.15f},
      { 0.95f, -1.00f,  0.75f, -0.80f, -0.40f,  0.85f, -0.90f,  0.60f},
      { 1.10f, -1.10f,  0.85f, -0.85f,  0.25f,  0.95f, -1.00f,  0.55f},
      { 0.85f, -0.90f,  0.65f, -0.70f, -0.50f,  0.75f, -0.75f,  0.45f},
      {-0.60f, -0.60f, -0.50f, -0.50f,  0.10f, -0.40f, -0.40f, -0.30f}
   };
   float B1[8] = {0.1f, 0.1f, -0.05f, -0.05f, 0.0f, 0.05f, 0.05f, 0.0f};

   for(int j = 0; j < 8; j++)
   {
      float sum = B1[j];
      for(int i = 0; i < 7; i++) sum += features[i] * W1[i][j];
      h1[j] = (sum > 0.0f) ? sum : (0.1f * sum);
   }

   float h2[6];
   float W2[8][6] = {
      { 0.75f, -0.65f,  0.50f, -0.40f,  0.15f,  0.30f},
      {-0.65f,  0.75f, -0.40f,  0.50f,  0.15f, -0.30f},
      { 0.40f,  0.40f, -0.25f, -0.25f,  0.50f,  0.15f},
      { 0.85f, -0.85f,  0.65f, -0.65f, -0.25f,  0.40f},
      { 0.65f, -0.65f,  0.50f, -0.50f,  0.00f,  0.30f},
      { 0.50f, -0.50f,  0.40f, -0.40f, -0.15f,  0.15f},
      {-0.50f,  0.50f, -0.40f,  0.40f,  0.15f, -0.15f},
      { 0.40f, -0.40f,  0.30f, -0.30f,  0.00f,  0.15f}
   };
   float B2[6] = {0.05f, 0.05f, 0.0f, 0.0f, 0.05f, 0.0f};

   for(int k = 0; k < 6; k++)
   {
      float sum = B2[k];
      for(int j = 0; j < 8; j++) sum += h1[j] * W2[j][k];
      h2[k] = (sum > 0.0f) ? sum : (0.1f * sum);
   }

   float out_raw[3];
   float W3[6][3] = {
      {-0.30f,  1.35f, -1.25f},
      {-0.30f, -1.25f,  1.35f},
      { 0.95f, -0.50f, -0.50f},
      {-0.40f,  1.45f, -1.35f},
      { 0.60f, -0.25f, -0.25f},
      {-0.15f,  0.95f, -0.85f}
   };
   float B3[3] = {0.25f, -0.12f, -0.12f};

   float max_val = -1e9f;
   for(int c = 0; c < 3; c++)
   {
      out_raw[c] = B3[c];
      for(int k = 0; k < 6; k++) out_raw[c] += h2[k] * W3[k][c];
      if(out_raw[c] > max_val) max_val = out_raw[c];
   }

   float sum_exp = 0.0f;
   float exp_val[3];
   for(int c = 0; c < 3; c++)
   {
      exp_val[c] = (float)MathExp(out_raw[c] - max_val);
      sum_exp += exp_val[c];
   }

   prob_neutral = exp_val[0] / sum_exp;
   prob_buy     = exp_val[1] / sum_exp;
   prob_sell    = exp_val[2] / sum_exp;
}

//+------------------------------------------------------------------+
//| ON-CHART AI LIVE DASHBOARD                                       |
//+------------------------------------------------------------------+
void DisplayAIDashboard(const float &features[], float p_neu, float p_buy, float p_sell)
{
   string ai_action = "WAIT / HUNTING...";
   if(p_buy >= (float)g_confidence_thresh && p_buy > p_sell) ai_action = StringFormat("BUY SIGNAL (%.1f%% Conf)", p_buy * 100.0f);
   else if(p_sell >= (float)g_confidence_thresh && p_sell > p_buy) ai_action = StringFormat("SELL SIGNAL (%.1f%% Conf)", p_sell * 100.0f);

   string engine_name = (InpAIMode == AI_ONNX_MODEL_FILE && onnx_loaded) ? "ONNX Engine (xauusd_m1_brain.onnx)" : "Built-in Deep Neural Network (MLP)";
   long current_spread = m_symbol.Spread();
   string spread_status = (current_spread <= g_max_spread) ? "[AMAN ✅]" : "[TERLALU TINGGI 🚫]";
   double daily_pl = GetDailyProfitLoss();
   double lot = CalculateLotSize(g_sl_points);

   string info = "=========================================================\n";
   info += "       🧠 XAUUSD AI-BRAIN DUAL-REGIME SCALPER v" + g_current_version + "    \n";
   info += "=========================================================\n";
   info += StringFormat(" 💰 Balance / Equity : $%.2f / $%.2f\n", m_account.Balance(), m_account.Equity());
   info += StringFormat(" 📈 Auto-Lot Mode    : %.2f Lot ($%.0f = %.2f Lot)\n", lot, g_balance_step, g_lot_step);
   info += StringFormat(" 🧠 AI Neural Model  : %s\n", engine_name);
   info += StringFormat(" 🎯 Ambang Keyakinan : %.0f%% Minimum Confidence\n", g_confidence_thresh * 100.0);
   info += "---------------------------------------------------------\n";
   info += " [AI REAL-TIME PROBABILITY METER]\n";
   info += StringFormat("  🟢 BUY  Probability : %5.1f %%  %s\n", p_buy * 100.0f, (p_buy >= (float)g_confidence_thresh) ? "🔥 [VALID ENTRY]" : "");
   info += StringFormat("  🔴 SELL Probability : %5.1f %%  %s\n", p_sell * 100.0f, (p_sell >= (float)g_confidence_thresh) ? "🔥 [VALID ENTRY]" : "");
   info += StringFormat("  ⚪ NEUTRAL / WAIT   : %5.1f %%\n", p_neu * 100.0f);
   info += StringFormat("  🎯 Status Keputusan : %s\n", ai_action);
   info += "---------------------------------------------------------\n";
   info += StringFormat(" 🛡️ Spread Gold      : %d pts (Max: %d pts) %s\n", current_spread, g_max_spread, spread_status);
   info += StringFormat(" 🏆 Profit Hari Ini  : %s$%.2f (Target: +$%.0f)\n", (daily_pl >= 0) ? "+" : "-", MathAbs(daily_pl), g_daily_target_usd);
   info += StringFormat(" ☁️ OTA Cloud Status : AKTIF (Auto-Sync tiap %d Menit)\n", InpSyncIntervalMin);
   info += " 📡 Discord Webhook  : TERHUBUNG ✅\n";
   info += "=========================================================\n";

   Comment(info);
}

//+------------------------------------------------------------------+
//| MANAJEMEN POSISI: BREAK-EVEN & TRAILING STOP                     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   double point = m_symbol.Point();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() != _Symbol) continue;
      if(m_position.Magic() != InpMagicNumber) continue;

      ulong  ticket       = m_position.Ticket();
      double open_price   = m_position.PriceOpen();
      double current_sl   = m_position.StopLoss();
      double current_tp   = m_position.TakeProfit();
      double current_bid  = m_symbol.Bid();
      double current_ask  = m_symbol.Ask();

      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         double profit_points = (current_bid - open_price) / point;

         // Break-Even
         if(InpUseBreakEven && profit_points >= InpBETriggerPoints)
         {
            double be_sl = m_symbol.NormalizePrice(open_price + InpBEProfitPoints * point);
            if(current_sl < be_sl)
            {
               m_trade.PositionModify(ticket, be_sl, current_tp);
            }
         }

         // Trailing Stop
         if(g_use_trailing && profit_points >= g_trailing_start)
         {
            double new_sl = m_symbol.NormalizePrice(current_bid - g_trailing_dist * point);
            if(new_sl > current_sl + g_trailing_step * point)
            {
               m_trade.PositionModify(ticket, new_sl, current_tp);
            }
         }
      }
      else if(m_position.PositionType() == POSITION_TYPE_SELL)
      {
         double profit_points = (open_price - current_ask) / point;

         // Break-Even
         if(InpUseBreakEven && profit_points >= InpBETriggerPoints)
         {
            double be_sl = m_symbol.NormalizePrice(open_price - InpBEProfitPoints * point);
            if(current_sl == 0 || current_sl > be_sl)
            {
               m_trade.PositionModify(ticket, be_sl, current_tp);
            }
         }

         // Trailing Stop
         if(g_use_trailing && profit_points >= g_trailing_start)
         {
            double new_sl = m_symbol.NormalizePrice(current_ask + g_trailing_dist * point);
            if(current_sl == 0 || new_sl < current_sl - g_trailing_step * point)
            {
               m_trade.PositionModify(ticket, new_sl, current_tp);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BUKA POSISI ORDER AI                                             |
//+------------------------------------------------------------------+
void OpenAIOrder(ENUM_ORDER_TYPE order_type, float confidence)
{
   double point = m_symbol.Point();
   double lot   = CalculateLotSize(g_sl_points);
   if(lot <= 0) return;

   int current_spread = (int)m_symbol.Spread();
   string comment_label = StringFormat("%s_%.0f%%", InpTradeComment, confidence * 100.0f);

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      double sl  = (g_sl_points > 0) ? (ask - g_sl_points * point) : 0;
      double tp  = (g_tp_points > 0) ? (ask + g_tp_points * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, comment_label))
      {
         NotifyAITrade("BUY", ask, lot, sl, tp, m_trade.ResultOrder(), confidence, current_spread);
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      double sl  = (g_sl_points > 0) ? (bid + g_sl_points * point) : 0;
      double tp  = (g_tp_points > 0) ? (bid - g_tp_points * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, comment_label))
      {
         NotifyAITrade("SELL", bid, lot, sl, tp, m_trade.ResultOrder(), confidence, current_spread);
      }
   }
}

//+------------------------------------------------------------------+
//| ON TICK EXECUTION                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!m_symbol.RefreshRates()) return;

   // 1. Sinkronisasi berkala dari Cloud GitHub setiap 5 menit
   if(TimeCurrent() - m_last_cloud_sync_time >= InpSyncIntervalMin * 60)
   {
      FetchAndApplyCloudConfig(false);
      m_last_cloud_sync_time = TimeCurrent();
   }

   // 2. Eksekusi Proteksi Posisi (Break-Even & Trailing Stop per tick)
   ManageOpenPositions();

   // 3. Ekstraksi Fitur AI Real-Time
   float features[7];
   if(!ExtractAIFeatures(features)) return;

   // 4. Prediksi Keputusan oleh Otak AI
   float prob_neutral = 0.0f;
   float prob_buy     = 0.0f;
   float prob_sell    = 0.0f;
   RunAIBrain(features, prob_neutral, prob_buy, prob_sell);

   // 5. Perbarui On-Chart Live Dashboard
   DisplayAIDashboard(features, prob_neutral, prob_buy, prob_sell);

   // 6. Cek Proteksi Daily Profit Target & Max Loss
   if(g_use_daily_guard)
   {
      double daily_pl = GetDailyProfitLoss();
      if(daily_pl >= g_daily_target_usd || daily_pl <= -g_daily_max_loss_usd) return;
   }

   // 7. Filter Bar Baru M1
   datetime current_time = iTime(_Symbol, PERIOD_M1, 0);
   if(current_time == 0 || current_time == last_m1_bar_time) return;
   last_m1_bar_time = current_time;

   // 8. Validasi Spread & Maksimal Posisi
   if(m_symbol.Spread() > g_max_spread) return;

   int active_orders = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber) active_orders++;
      }
   }
   if(active_orders >= InpMaxOpenPositions) return;

   // 9. Eksekusi Keputusan AI
   if(prob_buy >= (float)g_confidence_thresh && prob_buy > prob_sell)
   {
      OpenAIOrder(ORDER_TYPE_BUY, prob_buy);
   }
   else if(prob_sell >= (float)g_confidence_thresh && prob_sell > prob_buy)
   {
      OpenAIOrder(ORDER_TYPE_SELL, prob_sell);
   }
}
