//+------------------------------------------------------------------+
//|                                     Discord_Sentinel_EA_MT5.mq5  |
//| Multi-Timeframe Scalper EA • Bulletproof Edition (v2.35)         |
//| (Live HUD Dashboard • Max Spread Guard • Daily Guard • OTA Sync) |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "2.35"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#define CLOUD_CONFIG_URL "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/ea_cloud_config.json"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== PENGATURAN DISCORD WEBHOOK ==="
input string   InpDiscordWebhookURL = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // URL Webhook Discord Pribadi
input bool     InpEnableDiscord     = true;                                                                                                                            // Aktifkan Notifikasi Discord
input string   InpDiscordMention    = "";                                                                                                                              // Tag Mention (Kosongkan untuk channel pribadi)
input string   InpBotName           = "EA Scalper Cloud Sentinel MT5";                                                                                                 // Nama Bot Discord

input group "=== OTA CLOUD AUTO-SYNC (1x PASANG = AUTO UPDATE) ==="
input bool     InpEnableCloudSync   = true;      // Aktifkan Sinkronisasi Parameter Otomatis dari GitHub
input int      InpSyncIntervalMin   = 5;         // Interval Cek Update Cloud (Menit)

input group "=== PROTEKSI SPREAD & NEWS GUARD ==="
input int      InpMaxSpreadPoints   = 75;        // Maksimum Spread Diizinkan (Points) - Tolak Entry saat News/Rollover

input group "=== FILTER SESI TRADING (JAM LIKUIDITAS TINGGI) ==="
input bool     InpUseTimeFilter     = false;     // Batasi Trading Hanya Jam Aktif (Default False = 24 Jam)
input int      InpStartHour         = 0;         // Jam Mulai Trading (Server Time)
input int      InpEndHour           = 24;        // Jam Selesai Trading (Server Time)

input group "=== DAILY PROFIT TARGET & MAX LOSS GUARD ==="
input bool     InpUseDailyGuard     = true;      // Aktifkan Pengaman Target Harian
input double   InpDailyTargetProfit = 100.0;     // Kunci Profit Harian ($) - Berhenti jika tercapai
input double   InpDailyMaxLoss      = 50.0;      // Batas Rem Rugi Harian ($) - Berhenti jika tersentuh

input group "=== AUTO-LOT & MONEY MANAGEMENT ==="
input bool     InpUseAutoLot        = true;      // Gunakan Auto-Lot Berdasarkan Saldo
input double   InpBalancePerStep    = 100.0;     // Kelipatan Saldo ($100)
input double   InpLotPerStep        = 0.01;      // Lot per Kelipatan Saldo (0.01 Lot per $100)
input double   InpFixedLotSize      = 0.01;      // Lot Tetap (Jika Auto-Lot Dimatikan)
input int      InpStopLossPips      = 15;        // Stop Loss Scalping (Pips)
input int      InpTakeProfitPips    = 30;        // Take Profit Scalping (Pips)
input ulong    InpMagicNumber       = 778899;    // Magic Number EA
input ulong    InpSlippage          = 10;        // Maksimum Slippage (Points)

input group "=== BIAS TREN (M15) & ENTRY (M1) ==="
input int      InpM15FastEMA        = 20;        // M15 Fast EMA Period
input int      InpM15SlowEMA        = 50;        // M15 Slow EMA Period
input int      InpM1FastEMA         = 7;         // M1 Fast EMA Period
input int      InpM1SlowEMA         = 14;        // M1 Slow EMA Period
input int      InpM1RSIPeriod       = 14;        // M1 RSI Period
input double   InpRSIOverbought     = 80.0;      // M1 RSI Overbought Level
input double   InpRSIOversold       = 20.0;      // M1 RSI Oversold Level

input group "=== SCALPING TRAILING STOP ==="
input bool     InpUseTrailingStop   = true;      // Gunakan Trailing Stop Cepat
input int      InpTrailingStartPips = 10;        // Trailing Dimulai Setelah Profit (Pips)
input int      InpTrailingStepPips  = 5;         // Jarak Trailing Step (Pips)

//--- Dynamic Runtime Cloud Variables
string         g_current_version    = "2.35";
bool           g_auto_lot           = true;
double         g_balance_step       = 100.0;
double         g_lot_step           = 0.01;
int            g_sl_pips            = 15;
int            g_tp_pips            = 30;
bool           g_use_trailing       = true;
int            g_trailing_start     = 10;
int            g_trailing_step      = 5;
int            g_max_spread         = 75;
bool           g_use_time_filter    = false;
int            g_start_hour         = 0;
int            g_end_hour           = 24;
bool           g_use_daily_guard    = true;
double         g_daily_target_usd   = 100.0;
double         g_daily_max_loss_usd = 50.0;
int            g_m15_fast_ema       = 20;
int            g_m15_slow_ema       = 50;
int            g_m1_fast_ema        = 7;
int            g_m1_slow_ema        = 14;

//--- Global Handles & Timers
CTrade         m_trade;
CPositionInfo  m_position;
int            m_h_m15_fast_ema;
int            m_h_m15_slow_ema;
int            m_h_m1_fast_ema;
int            m_h_m1_slow_ema;
int            m_h_m1_rsi;
datetime       m_last_bar_time;
datetime       m_last_cloud_sync_time;

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
      content_header = "\"content\": \"🚨 " + InpDiscordMention + " — **[SCALPING ALERT]**\", ";
   }

   string payload = "{" + content_header +
                    "\"username\": \"" + InpBotName + "\"," +
                    "\"embeds\": [{" +
                    "\"title\": \"" + title + "\"," +
                    "\"description\": \"" + description + "\"," +
                    "\"color\": " + IntegerToString(color_hex) + "," +
                    "\"fields\": [" + fields_json + "]," +
                    "\"footer\": {\"text\": \"EA Scalper Sentinel MT5 • " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
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
   string headers = "User-Agent: MetaTrader5-EA\r\n";

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
         g_auto_lot           = ExtractJsonBool(json, "auto_lot", InpUseAutoLot);
         g_balance_step       = ExtractJsonNumber(json, "balance_per_step", InpBalancePerStep);
         g_lot_step           = ExtractJsonNumber(json, "lot_per_step", InpLotPerStep);
         g_sl_pips            = (int)ExtractJsonNumber(json, "stop_loss_pips", InpStopLossPips);
         g_tp_pips            = (int)ExtractJsonNumber(json, "take_profit_pips", InpTakeProfitPips);
         g_use_trailing       = ExtractJsonBool(json, "use_trailing_stop", InpUseTrailingStop);
         g_trailing_start     = (int)ExtractJsonNumber(json, "trailing_start_pips", InpTrailingStartPips);
         g_trailing_step      = (int)ExtractJsonNumber(json, "trailing_step_pips", InpTrailingStepPips);
         g_max_spread         = (int)ExtractJsonNumber(json, "max_spread_points", InpMaxSpreadPoints);
         g_use_time_filter    = ExtractJsonBool(json, "use_time_filter", InpUseTimeFilter);
         g_start_hour         = (int)ExtractJsonNumber(json, "start_hour_server", InpStartHour);
         g_end_hour           = (int)ExtractJsonNumber(json, "end_hour_server", InpEndHour);
         g_use_daily_guard    = ExtractJsonBool(json, "use_daily_guard", InpUseDailyGuard);
         g_daily_target_usd   = ExtractJsonNumber(json, "daily_target_profit_usd", InpDailyTargetProfit);
         g_daily_max_loss_usd = ExtractJsonNumber(json, "daily_max_loss_usd", InpDailyMaxLoss);
         g_m1_fast_ema        = (int)ExtractJsonNumber(json, "m1_fast_ema", InpM1FastEMA);
         g_m1_slow_ema        = (int)ExtractJsonNumber(json, "m1_slow_ema", InpM1SlowEMA);

         if(is_new_version && !is_initial)
         {
            string update_fields = "{\"name\": \"🚀 Versi Terbaru\", \"value\": \"`v" + g_current_version + " (Cloud Synchronized)`\", \"inline\": true}," +
                                   "{\"name\": \"🛡️ Max Spread Guard\", \"value\": \"`" + IntegerToString(g_max_spread) + " Points`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target Baru\", \"value\": \"`SL: " + IntegerToString(g_sl_pips) + " Pips | TP: " + IntegerToString(g_tp_pips) + " Pips`\", \"inline\": true}";
            
            SendDiscordEmbed("🔄 OTA CLOUD UPDATE DIAPLIKASIKAN!", 
                             "EA di MetaTrader kamu berhasil menyinkronkan strategi & parameter terbaru secara otomatis langsung dari GitHub tanpa perlu re-install!", 
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
double CalculateLotSize()
{
   if(!g_auto_lot) return InpFixedLotSize;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) balance = AccountInfoDouble(ACCOUNT_EQUITY);

   double calculated_lot = (balance / g_balance_step) * g_lot_step;

   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(step_lot > 0)
   {
      calculated_lot = MathFloor(calculated_lot / step_lot) * step_lot;
   }

   if(calculated_lot < min_lot) calculated_lot = min_lot;
   if(calculated_lot > max_lot) calculated_lot = max_lot;

   return NormalizeDouble(calculated_lot, 2);
}

//+------------------------------------------------------------------+
//| LIVE HUD DASHBOARD ON-CHART WINDOW                               |
//+------------------------------------------------------------------+
void UpdateOnChartDashboard(string bias_str, double rsi_val, int spread_val, string status_str)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double lot     = CalculateLotSize();
   double daily_pl = GetDailyProfitLoss();

   string spread_status = (spread_val <= g_max_spread) ? "[AMAN ✅]" : "[TERLALU TINGGI 🚫]";
   int total_pos = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber) total_pos++;
      }
   }

   string hud = "=========================================================\n" +
                "  ⚡ EA SCALPER CLOUD SENTINEL (BULLETPROOF v" + g_current_version + ") ⚡\n" +
                "=========================================================\n" +
                "  💰 Saldo Akun       : $" + DoubleToString(balance, 2) + " | Equity: $" + DoubleToString(equity, 2) + "\n" +
                "  📈 Auto-Lot Mode    : " + DoubleToString(lot, 2) + " Lot ($" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot)\n" +
                "  🛡️ Spread Saat Ini  : " + IntegerToString(spread_val) + " Pts (Max: " + IntegerToString(g_max_spread) + " Pts) " + spread_status + "\n" +
                "  🧭 Bias Tren M15    : " + bias_str + "\n" +
                "  🎯 Momentum RSI M1  : " + DoubleToString(rsi_val, 1) + " (Zone 45-75)\n" +
                "  🏆 Profit Hari Ini  : " + ((daily_pl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_pl), 2) + " (Target: +$" + DoubleToString(g_daily_target_usd, 0) + ")\n" +
                "  📦 Posisi Aktif     : " + IntegerToString(total_pos) + " Order\n" +
                "  ☁️ OTA Cloud Status : AKTIF (Auto-Sync tiap " + IntegerToString(InpSyncIntervalMin) + " Menit)\n" +
                "  📡 Discord Webhook  : TERHUBUNG ✅\n" +
                "=========================================================\n" +
                "  🎯 STATUS RADAR     : " + status_str + "\n" +
                "=========================================================";

   Comment(hud);
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI ORDER DISCORD                                  |
//+------------------------------------------------------------------+
void NotifyOpenTrade(string type, double price, double lot_used, double sl, double tp, ulong ticket, string bias_text, int spread_used)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Scalp M1)**\", \"inline\": true}," +
                   "{\"name\": \"🧭 Bias Tren M15\", \"value\": \"`" + bias_text + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (**" + DoubleToString(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(g_sl_pips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(g_tp_pips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Spread Saat Entry\", \"value\": \"`" + IntegerToString(spread_used) + " Points` (Aman)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("⚡ EKSEKUSI SCALPING BARU (" + type + ")", 
                    "Order scalping dieksekusi berdasarkan keselarasan Bias M15 & Trigger M1 dengan proteksi Max Spread Guard.", 
                    embed_color, 
                    fields, false);
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   g_auto_lot           = InpUseAutoLot;
   g_balance_step       = InpBalancePerStep;
   g_lot_step           = InpLotPerStep;
   g_sl_pips            = InpStopLossPips;
   g_tp_pips            = InpTakeProfitPips;
   g_use_trailing       = InpUseTrailingStop;
   g_trailing_start     = InpTrailingStartPips;
   g_trailing_step      = InpTrailingStepPips;
   g_max_spread         = InpMaxSpreadPoints;
   g_use_time_filter    = InpUseTimeFilter;
   g_start_hour         = InpStartHour;
   g_end_hour           = InpEndHour;
   g_use_daily_guard    = InpUseDailyGuard;
   g_daily_target_usd   = InpDailyTargetProfit;
   g_daily_max_loss_usd = InpDailyMaxLoss;
   g_m1_fast_ema        = InpM1FastEMA;
   g_m1_slow_ema        = InpM1SlowEMA;

   FetchAndApplyCloudConfig(true);
   m_last_cloud_sync_time = TimeCurrent();

   m_h_m15_fast_ema = iMA(_Symbol, PERIOD_M15, InpM15FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m15_slow_ema = iMA(_Symbol, PERIOD_M15, InpM15SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   m_h_m1_fast_ema  = iMA(_Symbol, PERIOD_M1, InpM1FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m1_slow_ema  = iMA(_Symbol, PERIOD_M1, InpM1SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m1_rsi       = iRSI(_Symbol, PERIOD_M1, InpM1RSIPeriod, PRICE_CLOSE);

   if(m_h_m15_fast_ema == INVALID_HANDLE || m_h_m15_slow_ema == INVALID_HANDLE ||
      m_h_m1_fast_ema == INVALID_HANDLE || m_h_m1_slow_ema == INVALID_HANDLE || m_h_m1_rsi == INVALID_HANDLE)
   {
      Print("❌ Gagal membuat handle indikator.");
      return INIT_FAILED;
   }

   UpdateOnChartDashboard("MEMUAT...", 50.0, 0, "MENYIAPKAN RADAR SCALPING...");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   IndicatorRelease(m_h_m15_fast_ema);
   IndicatorRelease(m_h_m15_slow_ema);
   IndicatorRelease(m_h_m1_fast_ema);
   IndicatorRelease(m_h_m1_slow_ema);
   IndicatorRelease(m_h_m1_rsi);
}

//+------------------------------------------------------------------+
//| FUNGSI TRAILING STOP                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   if(!g_use_trailing) return;

   double point = _Point;
   double trailing_start = g_trailing_start * 10 * point;
   double trailing_step  = g_trailing_step * 10 * point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(bid - m_position.PriceOpen() > trailing_start)
               {
                  double new_sl = bid - trailing_step;
                  if(new_sl > m_position.StopLoss() + point)
                  {
                     m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
                  }
               }
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if(m_position.PriceOpen() - ask > trailing_start)
               {
                  double new_sl = ask + trailing_step;
                  if(new_sl < m_position.StopLoss() - point || m_position.StopLoss() == 0)
                  {
                     m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ON TICK EXECUTION                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Sinkronisasi berkala dari Cloud GitHub setiap 5 menit
   if(TimeCurrent() - m_last_cloud_sync_time >= InpSyncIntervalMin * 60)
   {
      FetchAndApplyCloudConfig(false);
      m_last_cloud_sync_time = TimeCurrent();
   }

   ApplyTrailingStop();

   int current_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   // Ambil Data Indikator BIAS M15
   double m15_fast[], m15_slow[];
   ArraySetAsSeries(m15_fast, true);
   ArraySetAsSeries(m15_slow, true);
   CopyBuffer(m_h_m15_fast_ema, 0, 0, 2, m15_fast);
   CopyBuffer(m_h_m15_slow_ema, 0, 0, 2, m15_slow);

   bool m15_bullish_bias = (m15_fast[0] > m15_slow[0]);
   bool m15_bearish_bias = (m15_fast[0] < m15_slow[0]);
   string bias_text = m15_bullish_bias ? "🟢 BULLISH (EMA 20 > EMA 50)" : (m15_bearish_bias ? "🔴 BEARISH (EMA 20 < EMA 50)" : "⚪ NETRAL");

   // Ambil Data Indikator ENTRY M1
   double m1_fast[], m1_slow[], m1_rsi[];
   ArraySetAsSeries(m1_fast, true);
   ArraySetAsSeries(m1_slow, true);
   ArraySetAsSeries(m1_rsi, true);
   CopyBuffer(m_h_m1_fast_ema, 0, 1, 2, m1_fast);
   CopyBuffer(m_h_m1_slow_ema, 0, 1, 2, m1_slow);
   CopyBuffer(m_h_m1_rsi, 0, 1, 2, m1_rsi);

   double current_rsi = (ArraySize(m1_rsi) > 0) ? m1_rsi[0] : 50.0;

   string current_status = "SIAGA 1: MEMANTAU CANDLE M1 UNTUK PERSILANGAN BARU...";

   // Cek Proteksi Daily Profit Target & Max Loss
   if(g_use_daily_guard)
   {
      double daily_pl = GetDailyProfitLoss();
      if(daily_pl >= g_daily_target_usd)
      {
         current_status = "🎉 TARGET HARIAN TERPENUHI (+$" + DoubleToString(daily_pl, 2) + ") - LIBUR TRADING!";
         UpdateOnChartDashboard(bias_text, current_rsi, current_spread, current_status);
         return;
      }
      if(daily_pl <= -g_daily_max_loss_usd)
      {
         current_status = "🛡️ REM HARIAN AKTIF (-$" + DoubleToString(MathAbs(daily_pl), 2) + ") - LIBUR TRADING!";
         UpdateOnChartDashboard(bias_text, current_rsi, current_spread, current_status);
         return;
      }
   }

   // Cek Filter Sesi Jam Trading
   if(g_use_time_filter)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour < g_start_hour || dt.hour >= g_end_hour)
      {
         current_status = "⏳ DI LUAR JAM SESI TRADING AKTIF (" + IntegerToString(g_start_hour) + ":00 - " + IntegerToString(g_end_hour) + ":00)";
         UpdateOnChartDashboard(bias_text, current_rsi, current_spread, current_status);
         return;
      }
   }

   // Update HUD Dashboard Real-Time
   UpdateOnChartDashboard(bias_text, current_rsi, current_spread, current_status);

   // Cek Bar Baru di Timeframe M1
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);
   if(current_bar_time == m_last_bar_time) return;
   m_last_bar_time = current_bar_time;

   // Hanya 1 posisi scalping aktif per waktu
   int total_orders = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            total_orders++;
         }
      }
   }

   if(total_orders > 0) return;

   // MAX SPREAD GUARD
   if(current_spread > g_max_spread)
   {
      return;
   }

   // Hitung Lot Sesuai Saldo Terkini ($100 = 0.01 Lot)
   double lot_to_trade = CalculateLotSize();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;

   // SINYAL BUY SCALPING:
   if(m15_bullish_bias && (m1_fast[1] <= m1_slow[1] && m1_fast[0] > m1_slow[0]) && (m1_rsi[0] > 45.0 && m1_rsi[0] < InpRSIOverbought))
   {
      double sl = ask - (g_sl_pips * 10 * point);
      double tp = ask + (g_tp_pips * 10 * point);
      if(m_trade.Buy(lot_to_trade, _Symbol, ask, sl, tp, "Scalp BUY M1"))
      {
         NotifyOpenTrade("BUY", ask, lot_to_trade, sl, tp, m_trade.ResultOrder(), "Bullish (EMA 20 > EMA 50)", current_spread);
      }
   }
   // SINYAL SELL SCALPING:
   else if(m15_bearish_bias && (m1_fast[1] >= m1_slow[1] && m1_fast[0] < m1_slow[0]) && (m1_rsi[0] < 55.0 && m1_rsi[0] > InpRSIOversold))
   {
      double sl = bid + (g_sl_pips * 10 * point);
      double tp = bid - (g_tp_pips * 10 * point);
      if(m_trade.Sell(lot_to_trade, _Symbol, bid, sl, tp, "Scalp SELL M1"))
      {
         NotifyOpenTrade("SELL", bid, lot_to_trade, sl, tp, m_trade.ResultOrder(), "Bearish (EMA 20 < EMA 50)", current_spread);
      }
   }
}
