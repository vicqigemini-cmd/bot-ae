//+------------------------------------------------------------------+
//|                                     Discord_Sentinel_EA_MT5.mq5  |
//|    Multi-Timeframe Scalper EA • OTA Cloud Auto-Sync Edition      |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "2.20"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

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
input int      InpSyncIntervalMin   = 5;         // Interval Cek Update Cloud (Menit) - Setiap 5 Menit

input group "=== DEFAULT SETTINGS (OTOMATIS TERSINKRON DARI CLOUD) ==="
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
input int      InpM1FastEMA         = 9;         // M1 Fast EMA Period
input int      InpM1SlowEMA         = 21;        // M1 Slow EMA Period
input int      InpM1RSIPeriod       = 14;        // M1 RSI Period
input double   InpRSIOverbought     = 75.0;      // M1 RSI Overbought Level
input double   InpRSIOversold       = 25.0;      // M1 RSI Oversold Level

input group "=== SCALPING TRAILING STOP ==="
input bool     InpUseTrailingStop   = true;      // Gunakan Trailing Stop Cepat
input int      InpTrailingStartPips = 10;        // Trailing Dimulai Setelah Profit (Pips)
input int      InpTrailingStepPips  = 5;         // Jarak Trailing Step (Pips)

//--- Dynamic Runtime Cloud Variables
string         g_current_version    = "2.20";
bool           g_auto_lot           = true;
double         g_balance_step       = 100.0;
double         g_lot_step           = 0.01;
int            g_sl_pips            = 15;
int            g_tp_pips            = 30;
bool           g_use_trailing       = true;
int            g_trailing_start     = 10;
int            g_trailing_step      = 5;
int            g_m15_fast_ema       = 20;
int            g_m15_slow_ema       = 50;
int            g_m1_fast_ema        = 9;
int            g_m1_slow_ema        = 21;
double         g_rsi_ob             = 75.0;
double         g_rsi_os             = 25.0;

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
//| HELPER PARSER JSON SEDERHANA & CEPAT                             |
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
   int res = WebRequest("POST", InpDiscordWebhookURL, headers, 5000, post_data, result_data, result_headers);
   if(res == -1)
   {
      int err = GetLastError();
      if(err == 4060)
      {
         Print("⚠️ PERHATIAN: Tambahkan https://discord.com dan https://raw.githubusercontent.com di Tools -> Options -> Expert Advisors -> WebRequest");
      }
   }
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
         g_current_version  = cloud_version;
         g_auto_lot         = ExtractJsonBool(json, "auto_lot", InpUseAutoLot);
         g_balance_step     = ExtractJsonNumber(json, "balance_per_step", InpBalancePerStep);
         g_lot_step         = ExtractJsonNumber(json, "lot_per_step", InpLotPerStep);
         g_sl_pips          = (int)ExtractJsonNumber(json, "stop_loss_pips", InpStopLossPips);
         g_tp_pips          = (int)ExtractJsonNumber(json, "take_profit_pips", InpTakeProfitPips);
         g_use_trailing     = ExtractJsonBool(json, "use_trailing_stop", InpUseTrailingStop);
         g_trailing_start   = (int)ExtractJsonNumber(json, "trailing_start_pips", InpTrailingStartPips);
         g_trailing_step    = (int)ExtractJsonNumber(json, "trailing_step_pips", InpTrailingStepPips);
         g_rsi_ob           = ExtractJsonNumber(json, "rsi_overbought", InpRSIOverbought);
         g_rsi_os           = ExtractJsonNumber(json, "rsi_oversold", InpRSIOversold);

         Print("✅ OTA Cloud Config Berhasil Disinkronkan! Versi: ", g_current_version);

         if(is_new_version && !is_initial)
         {
            string update_fields = "{\"name\": \"🚀 Versi Terbaru\", \"value\": \"`v" + g_current_version + " (Cloud Synchronized)`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target Baru\", \"value\": \"`SL: " + IntegerToString(g_sl_pips) + " Pips | TP: " + IntegerToString(g_tp_pips) + " Pips`\", \"inline\": true}," +
                                   "{\"name\": \"💰 Auto-Lot Status\", \"value\": \"`$" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot`\", \"inline\": true}";
            
            SendDiscordEmbed("🔄 OTA CLOUD UPDATE DIAPLIKASIKAN!", 
                             "EA di MetaTrader kamu berhasil menyinkronkan strategi & parameter terbaru secara otomatis langsung dari GitHub tanpa perlu re-install!", 
                             0x9B59B6, update_fields, false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FUNGSI KALKULASI AUTO-LOT ($100 = 0.01 LOT)                      |
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
//| FORMAT NOTIFIKASI ORDER DISCORD                                  |
//+------------------------------------------------------------------+
void NotifyOpenTrade(string type, double price, double lot_used, double sl, double tp, ulong ticket, string bias_text)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Scalp M1)**\", \"inline\": true}," +
                   "{\"name\": \"🧭 Bias Tren M15\", \"value\": \"`" + bias_text + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (**" + DoubleToString(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(g_sl_pips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(g_tp_pips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "` (Auto-Lot Proporsional)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("⚡ EKSEKUSI SCALPING BARU (" + type + ")", 
                    "Order scalping dieksekusi berdasarkan keselarasan Bias M15 dan Crossover Momentum M1 (Cloud Sync Engine).", 
                    embed_color, 
                    fields, false);
}

void NotifyCloseTrade(string type, double open_price, double close_price, double profit, ulong ticket)
{
   int embed_color = (profit >= 0) ? 0x2ECC71 : 0xE74C3C;
   string emoji = (profit >= 0) ? "💰 PROFIT" : "🔻 LOSS";

   string fields = "{\"name\": \"📊 Hasil Scalping\", \"value\": \"**" + emoji + ": $" + DoubleToString(profit, 2) + "**\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Posisi\", \"value\": \"`" + type + " " + _Symbol + "`\", \"inline\": true}," +
                   "{\"name\": \"🎯 Open / Close\", \"value\": \"`" + DoubleToString(open_price, _Digits) + " ➜ " + DoubleToString(close_price, _Digits) + "`\", \"inline\": false}";

   SendDiscordEmbed("🏁 POSISI SCALPING DITUTUP (TICKET #" + IntegerToString(ticket) + ")", 
                    "Order scalping telah selesai ditutup oleh EA / menyentuh TP/SL/Trailing Stop.", 
                    embed_color, fields, (profit < -30.0));
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   // Inisialisasi variabel dinamis dari input default
   g_auto_lot       = InpUseAutoLot;
   g_balance_step   = InpBalancePerStep;
   g_lot_step       = InpLotPerStep;
   g_sl_pips        = InpStopLossPips;
   g_tp_pips        = InpTakeProfitPips;
   g_use_trailing   = InpUseTrailingStop;
   g_trailing_start = InpTrailingStartPips;
   g_trailing_step  = InpTrailingStepPips;
   g_m15_fast_ema   = InpM15FastEMA;
   g_m15_slow_ema   = InpM15SlowEMA;
   g_m1_fast_ema    = InpM1FastEMA;
   g_m1_slow_ema    = InpM1SlowEMA;
   g_rsi_ob         = InpRSIOverbought;
   g_rsi_os         = InpRSIOversold;

   // Cek dan aplikasikan konfigurasi cloud dari GitHub saat startup
   FetchAndApplyCloudConfig(true);
   m_last_cloud_sync_time = TimeCurrent();

   m_h_m15_fast_ema = iMA(_Symbol, PERIOD_M15, g_m15_fast_ema, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m15_slow_ema = iMA(_Symbol, PERIOD_M15, g_m15_slow_ema, 0, MODE_EMA, PRICE_CLOSE);

   m_h_m1_fast_ema  = iMA(_Symbol, PERIOD_M1, g_m1_fast_ema, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m1_slow_ema  = iMA(_Symbol, PERIOD_M1, g_m1_slow_ema, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m1_rsi       = iRSI(_Symbol, PERIOD_M1, InpM1RSIPeriod, PRICE_CLOSE);

   if(m_h_m15_fast_ema == INVALID_HANDLE || m_h_m15_slow_ema == INVALID_HANDLE ||
      m_h_m1_fast_ema == INVALID_HANDLE || m_h_m1_slow_ema == INVALID_HANDLE || m_h_m1_rsi == INVALID_HANDLE)
   {
      Print("❌ Gagal membuat handle indikator multi-timeframe.");
      return INIT_FAILED;
   }

   double current_lot = CalculateLotSize();
   string startup_fields = "{\"name\": \"🧭 Engine Mode\", \"value\": \"`Bias: M15 • Entry: M1`\", \"inline\": true}," +
                           "{\"name\": \"☁️ OTA Cloud Sync\", \"value\": \"`v" + g_current_version + " (Active)`\", \"inline\": true}," +
                           "{\"name\": \"📈 Auto-Lot Mode\", \"value\": \"`$" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot` (Lot: **" + DoubleToString(current_lot, 2) + "**)\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Scalping\", \"value\": \"`SL: " + IntegerToString(g_sl_pips) + " Pips | TP: " + IntegerToString(g_tp_pips) + " Pips`\", \"inline\": true}," +
                           "{\"name\": \"💰 Balance / Equity\", \"value\": \"`$" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " / $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "`\", \"inline\": true}";

   SendDiscordEmbed("🤖 EA Scalper Cloud Sentinel MT5 Aktif!", 
                    "Expert Advisor siap bekerja 24/7 di RDP dengan sistem OTA Cloud Auto-Sync (1x Pasang = Auto Update Selamanya).", 
                    0x3498DB, startup_fields, false);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
   // Sinkronisasi berkala dari Cloud GitHub setiap X menit
   if(TimeCurrent() - m_last_cloud_sync_time >= InpSyncIntervalMin * 60)
   {
      FetchAndApplyCloudConfig(false);
      m_last_cloud_sync_time = TimeCurrent();
   }

   ApplyTrailingStop();

   // Cek Bar Baru di Timeframe M1 (Trigger Scalping)
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);
   if(current_bar_time == m_last_bar_time) return;
   m_last_bar_time = current_bar_time;

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

   // 1. Hitung Lot Sesuai Saldo Terkini ($100 = 0.01 Lot)
   double lot_to_trade = CalculateLotSize();

   // 2. Ambil Data Indikator BIAS M15
   double m15_fast[], m15_slow[];
   ArraySetAsSeries(m15_fast, true);
   ArraySetAsSeries(m15_slow, true);
   if(CopyBuffer(m_h_m15_fast_ema, 0, 0, 2, m15_fast) < 2) return;
   if(CopyBuffer(m_h_m15_slow_ema, 0, 0, 2, m15_slow) < 2) return;

   bool m15_bullish_bias = (m15_fast[0] > m15_slow[0]);
   bool m15_bearish_bias = (m15_fast[0] < m15_slow[0]);

   // 3. Ambil Data Indikator ENTRY M1
   double m1_fast[], m1_slow[], m1_rsi[];
   ArraySetAsSeries(m1_fast, true);
   ArraySetAsSeries(m1_slow, true);
   ArraySetAsSeries(m1_rsi, true);
   if(CopyBuffer(m_h_m1_fast_ema, 0, 1, 2, m1_fast) < 2) return;
   if(CopyBuffer(m_h_m1_slow_ema, 0, 1, 2, m1_slow) < 2) return;
   if(CopyBuffer(m_h_m1_rsi, 0, 1, 2, m1_rsi) < 2) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;

   // 4. SINYAL BUY SCALPING:
   if(m15_bullish_bias && (m1_fast[1] <= m1_slow[1] && m1_fast[0] > m1_slow[0]) && (m1_rsi[0] > 45.0 && m1_rsi[0] < g_rsi_ob))
   {
      double sl = ask - (g_sl_pips * 10 * point);
      double tp = ask + (g_tp_pips * 10 * point);
      if(m_trade.Buy(lot_to_trade, _Symbol, ask, sl, tp, "Scalp BUY M1"))
      {
         NotifyOpenTrade("BUY", ask, lot_to_trade, sl, tp, m_trade.ResultOrder(), "Bullish (EMA 20 > EMA 50)");
      }
   }
   // 5. SINYAL SELL SCALPING:
   else if(m15_bearish_bias && (m1_fast[1] >= m1_slow[1] && m1_fast[0] < m1_slow[0]) && (m1_rsi[0] < 55.0 && m1_rsi[0] > g_rsi_os))
   {
      double sl = bid + (g_sl_pips * 10 * point);
      double tp = bid - (g_tp_pips * 10 * point);
      if(m_trade.Sell(lot_to_trade, _Symbol, bid, sl, tp, "Scalp SELL M1"))
      {
         NotifyOpenTrade("SELL", bid, lot_to_trade, sl, tp, m_trade.ResultOrder(), "Bearish (EMA 20 < EMA 50)");
      }
   }
}
