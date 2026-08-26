//+------------------------------------------------------------------+
//|                                     Discord_Sentinel_EA_MT4.mq4  |
//| Multi-Timeframe Scalper EA • Bulletproof Edition (v2.30)         |
//| (Max Spread Guard • Session Filter • Daily Target Guard • OTA)   |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "2.30"
#property strict

#define CLOUD_CONFIG_URL "https://raw.githubusercontent.com/vicqigemini-cmd/bot-ae/main/ea_cloud_config.json"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input string   s0 = "=== PENGATURAN DISCORD WEBHOOK ==="; // ---
input string   InpDiscordWebhookURL = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // Webhook URL Pribadi
input bool     InpEnableDiscord     = true;                                                                                                                            // Aktifkan Notifikasi Discord
input string   InpDiscordMention    = "";                                                                                                                              // Tag Mention (Kosongkan untuk channel pribadi)
input string   InpBotName           = "EA Scalper Cloud Sentinel MT4";                                                                                                 // Nama Bot

input string   s1 = "=== OTA CLOUD AUTO-SYNC (1x PASANG = AUTO UPDATE) ==="; // ---
input bool     InpEnableCloudSync   = true;      // Aktifkan Sinkronisasi Parameter Otomatis dari GitHub
input int      InpSyncIntervalMin   = 5;         // Interval Cek Update Cloud (Menit)

input string   s2 = "=== PROTEKSI SPREAD & NEWS GUARD ==="; // ---
input int      InpMaxSpreadPoints   = 35;        // Maksimum Spread Diizinkan (Points) - Tolak Entry saat News/Rollover

input string   s3 = "=== FILTER SESI TRADING ==="; // ---
input bool     InpUseTimeFilter     = true;      // Batasi Trading Hanya Jam Aktif
input int      InpStartHour         = 8;         // Jam Mulai Trading (Server Time)
input int      InpEndHour           = 22;        // Jam Selesai Trading (Server Time)

input string   s4 = "=== DAILY TARGET & MAX LOSS GUARD ==="; // ---
input bool     InpUseDailyGuard     = true;      // Aktifkan Pengaman Target Harian
input double   InpDailyTargetProfit = 50.0;      // Kunci Profit Harian ($)
input double   InpDailyMaxLoss      = 25.0;      // Batas Rem Rugi Harian ($)

input string   s5 = "=== AUTO-LOT & MONEY MANAGEMENT ==="; // ---
input bool     InpUseAutoLot        = true;      // Gunakan Auto-Lot Berdasarkan Saldo
input double   InpBalancePerStep    = 100.0;     // Kelipatan Saldo ($100)
input double   InpLotPerStep        = 0.01;      // Lot per Kelipatan Saldo (0.01 Lot per $100)
input double   InpFixedLotSize      = 0.01;      // Lot Tetap (Jika Auto-Lot Dimatikan)
input int      InpStopLossPips      = 15;        // Stop Loss Scalping (Pips)
input int      InpTakeProfitPips    = 30;        // Take Profit Scalping (Pips)
input int      InpMagicNumber       = 778899;    // Magic Number EA
input int      InpSlippage          = 10;        // Maksimum Slippage (Points)

input string   s6 = "=== BIAS TREN (M15) & ENTRY (M1) ==="; // ---
input int      InpM15FastEMA        = 20;        // M15 Fast EMA Period
input int      InpM15SlowEMA        = 50;        // M15 Slow EMA Period
input int      InpM1FastEMA         = 9;         // M1 Fast EMA Period
input int      InpM1SlowEMA         = 21;        // M1 Slow EMA Period
input int      InpM1RSIPeriod       = 14;        // M1 RSI Period
input double   InpRSIOverbought     = 75.0;      // M1 RSI Overbought Level
input double   InpRSIOversold       = 25.0;      // M1 RSI Oversold Level

input string   s7 = "=== SCALPING TRAILING STOP ==="; // ---
input bool     InpUseTrailingStop   = true;      // Gunakan Trailing Stop Cepat
input int      InpTrailingStartPips = 10;        // Trailing Dimulai Setelah Profit (Pips)
input int      InpTrailingStepPips  = 5;         // Jarak Trailing Step (Pips)

//--- Dynamic Runtime Cloud Variables
string         g_current_version    = "2.30";
bool           g_auto_lot           = true;
double         g_balance_step       = 100.0;
double         g_lot_step           = 0.01;
int            g_sl_pips            = 15;
int            g_tp_pips            = 30;
bool           g_use_trailing       = true;
int            g_trailing_start     = 10;
int            g_trailing_step      = 5;
int            g_max_spread         = 35;
bool           g_use_time_filter    = true;
int            g_start_hour         = 8;
int            g_end_hour           = 22;
bool           g_use_daily_guard    = true;
double         g_daily_target_usd   = 50.0;
double         g_daily_max_loss_usd = 25.0;

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
   return StrToDouble(val_str);
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
                    "\"footer\": {\"text\": \"EA Scalper Sentinel MT4 • " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
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
   string headers = "User-Agent: MetaTrader4-EA\r\n";

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

         if(is_new_version && !is_initial)
         {
            string update_fields = "{\"name\": \"🚀 Versi Terbaru\", \"value\": \"`v" + g_current_version + " (Cloud Synchronized)`\", \"inline\": true}," +
                                   "{\"name\": \"🛡️ Max Spread Guard\", \"value\": \"`" + IntegerToString(g_max_spread) + " Points`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target Baru\", \"value\": \"`SL: " + IntegerToString(g_sl_pips) + " Pips | TP: " + IntegerToString(g_tp_pips) + " Pips`\", \"inline\": true}";
            
            SendDiscordEmbed("🔄 OTA CLOUD UPDATE DIAPLIKASIKAN!", 
                             "EA MT4 kamu berhasil menyinkronkan strategi & parameter terbaru secara otomatis langsung dari GitHub tanpa perlu re-install!", 
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
   datetime start_of_day = StrToTime(TimeToStr(TimeCurrent(), TIME_DATE) + " 00:00");
   double total_profit = 0.0;
   
   int history_total = OrdersHistoryTotal();
   for(int i = 0; i < history_total; i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber && OrderCloseTime() >= start_of_day)
         {
            total_profit += OrderProfit() + OrderSwap() + OrderCommission();
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

   double balance = AccountBalance();
   if(balance <= 0) balance = AccountEquity();

   double calculated_lot = (balance / g_balance_step) * g_lot_step;

   double min_lot = MarketInfo(Symbol(), MODE_MINLOT);
   double max_lot = MarketInfo(Symbol(), MODE_MAXLOT);
   double step_lot = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(step_lot > 0)
   {
      calculated_lot = MathFloor(calculated_lot / step_lot) * step_lot;
   }

   if(calculated_lot < min_lot) calculated_lot = min_lot;
   if(calculated_lot > max_lot) calculated_lot = max_lot;

   return NormalizeDouble(calculated_lot, 2);
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI ORDER DISCORD                                  |
//+------------------------------------------------------------------+
void NotifyOpenTrade(string type, double price, double lot_used, double sl, double tp, int ticket, string bias_text, int spread_used)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Scalp M1)**\", \"inline\": true}," +
                   "{\"name\": \"🧭 Bias Tren M15\", \"value\": \"`" + bias_text + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + Symbol() + "` (**" + DoubleToStr(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToStr(price, Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToStr(sl, Digits) + "` (-" + IntegerToString(g_sl_pips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToStr(tp, Digits) + "` (+" + IntegerToString(g_tp_pips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Spread Saat Entry\", \"value\": \"`" + IntegerToString(spread_used) + " Points` (Aman)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToStr(AccountBalance(), 2) + "`\", \"inline\": true}," +
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

   FetchAndApplyCloudConfig(true);
   m_last_cloud_sync_time = TimeCurrent();

   double current_lot = CalculateLotSize();
   string startup_fields = "{\"name\": \"🧭 Engine Mode\", \"value\": \"`Bias: M15 • Entry: M1`\", \"inline\": true}," +
                           "{\"name\": \"🛡️ Max Spread Guard\", \"value\": \"`Max " + IntegerToString(g_max_spread) + " Points` (Anti-News Spread)\", \"inline\": true}," +
                           "{\"name\": \"⏰ Jam Trading\", \"value\": \"`" + IntegerToString(g_start_hour) + ":00 - " + IntegerToString(g_end_hour) + ":00 Server`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Harian\", \"value\": \"`Target: +$" + DoubleToStr(g_daily_target_usd, 0) + " | Max Loss: -$" + DoubleToStr(g_daily_max_loss_usd, 0) + "`\", \"inline\": true}," +
                           "{\"name\": \"📈 Auto-Lot Mode\", \"value\": \"`$" + DoubleToStr(g_balance_step, 0) + " = " + DoubleToStr(g_lot_step, 2) + " Lot` (Lot: **" + DoubleToStr(current_lot, 2) + "**)\", \"inline\": true}," +
                           "{\"name\": \"💰 Balance / Equity\", \"value\": \"`$" + DoubleToStr(AccountBalance(), 2) + " / $" + DoubleToStr(AccountEquity(), 2) + "`\", \"inline\": true}";

   SendDiscordEmbed("🤖 EA Scalper Bulletproof MT4 Aktif!", 
                    "Expert Advisor siap bekerja 24/7 di RDP dengan proteksi Max Spread Guard saat News dan Daily Target Guard.", 
                    0x3498DB, startup_fields, false);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| FUNGSI TRAILING STOP                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   if(!g_use_trailing) return;

   double point = Point;
   double trailing_start = g_trailing_start * 10 * point;
   double trailing_step  = g_trailing_step * 10 * point;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber)
         {
            if(OrderType() == OP_BUY)
            {
               if(Bid - OrderOpenPrice() > trailing_start)
               {
                  double new_sl = Bid - trailing_step;
                  if(new_sl > OrderStopLoss() + point)
                  {
                     bool res = OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrGreen);
                  }
               }
            }
            else if(OrderType() == OP_SELL)
            {
               if(OrderOpenPrice() - Ask > trailing_start)
               {
                  double new_sl = Ask + trailing_step;
                  if(new_sl < OrderStopLoss() - point || OrderStopLoss() == 0)
                  {
                     bool res = OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrRed);
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
   if(TimeCurrent() - m_last_cloud_sync_time >= InpSyncIntervalMin * 60)
   {
      FetchAndApplyCloudConfig(false);
      m_last_cloud_sync_time = TimeCurrent();
   }

   ApplyTrailingStop();

   // 1. Cek Proteksi Daily Profit Target & Max Loss
   if(g_use_daily_guard)
   {
      double daily_pl = GetDailyProfitLoss();
      if(daily_pl >= g_daily_target_usd || daily_pl <= -g_daily_max_loss_usd)
      {
         return; // Target tercapai atau rem harian aktif
      }
   }

   // 2. Cek Filter Sesi Jam Trading
   if(g_use_time_filter)
   {
      if(Hour() < g_start_hour || Hour() >= g_end_hour)
      {
         return;
      }
   }

   // 3. Cek Bar Baru di Timeframe M1
   datetime current_bar_time = iTime(Symbol(), PERIOD_M1, 0);
   if(current_bar_time == m_last_bar_time) return;
   m_last_bar_time = current_bar_time;

   int total_orders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber)
         {
            total_orders++;
         }
      }
   }

   if(total_orders > 0) return;

   // 4. MAX SPREAD GUARD (Tolak Entry saat Spread Melebar Karena News / Rollover)
   int current_spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   if(current_spread > g_max_spread)
   {
      Print("⚠️ Entry Ditolak oleh Max Spread Guard: Spread saat ini (", current_spread, " pts) > Batas (", g_max_spread, " pts)");
      return;
   }

   // 5. Hitung Lot Sesuai Saldo Terkini ($100 = 0.01 Lot)
   double lot_to_trade = CalculateLotSize();

   // 6. Ambil Data Indikator BIAS M15
   double m15_fast = iMA(Symbol(), PERIOD_M15, g_m15_fast_ema, 0, MODE_EMA, PRICE_CLOSE, 0);
   double m15_slow = iMA(Symbol(), PERIOD_M15, g_m15_slow_ema, 0, MODE_EMA, PRICE_CLOSE, 0);

   bool m15_bullish_bias = (m15_fast > m15_slow);
   bool m15_bearish_bias = (m15_fast < m15_slow);

   // 7. Ambil Data Indikator ENTRY M1
   double m1_fast_prev = iMA(Symbol(), PERIOD_M1, g_m1_fast_ema, 0, MODE_EMA, PRICE_CLOSE, 2);
   double m1_fast_curr = iMA(Symbol(), PERIOD_M1, g_m1_fast_ema, 0, MODE_EMA, PRICE_CLOSE, 1);
   double m1_slow_prev = iMA(Symbol(), PERIOD_M1, g_m1_slow_ema, 0, MODE_EMA, PRICE_CLOSE, 2);
   double m1_slow_curr = iMA(Symbol(), PERIOD_M1, g_m1_slow_ema, 0, MODE_EMA, PRICE_CLOSE, 1);
   double m1_rsi       = iRSI(Symbol(), PERIOD_M1, InpM1RSIPeriod, PRICE_CLOSE, 1);

   double point = Point;

   // 8. SINYAL BUY SCALPING:
   if(m15_bullish_bias && (m1_fast_prev <= m1_slow_prev && m1_fast_curr > m1_slow_curr) && (m1_rsi > 45.0 && m1_rsi < InpRSIOverbought))
   {
      double ask = Ask;
      double sl = ask - (g_sl_pips * 10 * point);
      double tp = ask + (g_tp_pips * 10 * point);
      int ticket = OrderSend(Symbol(), OP_BUY, lot_to_trade, ask, InpSlippage, sl, tp, "Scalp BUY M1", InpMagicNumber, 0, clrGreen);
      if(ticket > 0)
      {
         NotifyOpenTrade("BUY", ask, lot_to_trade, sl, tp, ticket, "Bullish (EMA 20 > EMA 50)", current_spread);
      }
   }
   // 9. SINYAL SELL SCALPING:
   else if(m15_bearish_bias && (m1_fast_prev >= m1_slow_prev && m1_fast_curr < m1_slow_curr) && (m1_rsi < 55.0 && m1_rsi > InpRSIOversold))
   {
      double bid = Bid;
      double sl = bid + (g_sl_pips * 10 * point);
      double tp = bid - (g_tp_pips * 10 * point);
      int ticket = OrderSend(Symbol(), OP_SELL, lot_to_trade, bid, InpSlippage, sl, tp, "Scalp SELL M1", InpMagicNumber, 0, clrRed);
      if(ticket > 0)
      {
         NotifyOpenTrade("SELL", bid, lot_to_trade, sl, tp, ticket, "Bearish (EMA 20 < EMA 50)", current_spread);
      }
   }
}
