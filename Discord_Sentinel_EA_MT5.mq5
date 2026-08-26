//+------------------------------------------------------------------+
//|                                     Discord_Sentinel_EA_MT5.mq5  |
//|             Multi-Timeframe Scalper EA (Bias M15 • Entry M1)     |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== PENGATURAN DISCORD WEBHOOK ==="
input string   InpDiscordWebhookURL = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // URL Webhook Discord Pribadi
input bool     InpEnableDiscord     = true;                                                                                                                            // Aktifkan Notifikasi Discord
input string   InpDiscordMention    = "";                                                                                                                              // Tag Mention (Kosongkan untuk channel pribadi)
input string   InpBotName           = "EA Scalper Sentinel MT5";                                                                                                       // Nama Bot Discord

input group "=== PENGATURAN SCALPING & LOT ==="
input double   InpLotSize           = 0.01;      // Ukuran Lot Scalping
input int      InpStopLossPips      = 15;        // Stop Loss Scalping (Pips)
input int      InpTakeProfitPips    = 30;        // Take Profit Scalping (Pips)
input ulong    InpMagicNumber       = 778899;    // Magic Number EA
input ulong    InpSlippage          = 10;        // Maksimum Slippage (Points)

input group "=== BIAS TREN BESAR (TIMEFRAME M15) ==="
input int      InpM15FastEMA        = 20;        // M15 Fast EMA Period
input int      InpM15SlowEMA        = 50;        // M15 Slow EMA Period

input group "=== TRIGGER ENTRY PRESISI (TIMEFRAME M1) ==="
input int      InpM1FastEMA         = 9;         // M1 Fast EMA Period (Scalp Trigger)
input int      InpM1SlowEMA         = 21;        // M1 Slow EMA Period (Scalp Baseline)
input int      InpM1RSIPeriod       = 14;        // M1 RSI Period
input double   InpRSIOverbought     = 75.0;      // M1 RSI Overbought Level
input double   InpRSIOversold       = 25.0;      // M1 RSI Oversold Level

input group "=== SCALPING TRAILING STOP ==="
input bool     InpUseTrailingStop   = true;      // Gunakan Trailing Stop Cepat
input int      InpTrailingStartPips = 10;        // Trailing Dimulai Setelah Profit (Pips)
input int      InpTrailingStepPips  = 5;         // Jarak Trailing Step (Pips)

//--- Global Variables
CTrade         m_trade;
CPositionInfo  m_position;
int            m_h_m15_fast_ema;
int            m_h_m15_slow_ema;
int            m_h_m1_fast_ema;
int            m_h_m1_slow_ema;
int            m_h_m1_rsi;
datetime       m_last_bar_time;

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
      Print("❌ Gagal kirim Webhook Discord. Error: ", err);
      if(err == 4060)
      {
         Print("⚠️ PERHATIAN: Izinkan WebRequest di MT5: Tools -> Options -> Expert Advisors -> Tambahkan: https://discord.com");
      }
   }
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI ORDER DISCORD                                  |
//+------------------------------------------------------------------+
void NotifyOpenTrade(string type, double price, double sl, double tp, ulong ticket, string bias_text)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Scalp M1)**\", \"inline\": true}," +
                   "{\"name\": \"🧭 Bias Tren M15\", \"value\": \"`" + bias_text + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (" + DoubleToString(InpLotSize, 2) + " Lot)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(InpStopLossPips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(InpTakeProfitPips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("⚡ EKSEKUSI SCALPING BARU (" + type + ")", 
                    "Order scalping dieksekusi berdasarkan keselarasan Bias M15 dan Crossover Momentum M1.", 
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

   // Inisialisasi Indikator Timeframe M15 (Bias Tren)
   m_h_m15_fast_ema = iMA(_Symbol, PERIOD_M15, InpM15FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m15_slow_ema = iMA(_Symbol, PERIOD_M15, InpM15SlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   // Inisialisasi Indikator Timeframe M1 (Entry Scalping Trigger)
   m_h_m1_fast_ema  = iMA(_Symbol, PERIOD_M1, InpM1FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m1_slow_ema  = iMA(_Symbol, PERIOD_M1, InpM1SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_h_m1_rsi       = iRSI(_Symbol, PERIOD_M1, InpM1RSIPeriod, PRICE_CLOSE);

   if(m_h_m15_fast_ema == INVALID_HANDLE || m_h_m15_slow_ema == INVALID_HANDLE ||
      m_h_m1_fast_ema == INVALID_HANDLE || m_h_m1_slow_ema == INVALID_HANDLE || m_h_m1_rsi == INVALID_HANDLE)
   {
      Print("❌ Gagal membuat handle indikator multi-timeframe.");
      return INIT_FAILED;
   }

   string startup_fields = "{\"name\": \"🧭 Strategi Multi-Timeframe\", \"value\": \"`Bias: M15 | Entry: M1`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Scalping\", \"value\": \"`SL: " + IntegerToString(InpStopLossPips) + " Pips | TP: " + IntegerToString(InpTakeProfitPips) + " Pips`\", \"inline\": true}," +
                           "{\"name\": \"💰 Balance / Equity\", \"value\": \"`$" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " / $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "`\", \"inline\": true}";

   SendDiscordEmbed("🤖 EA Scalper Sentinel MT5 Berhasil Aktif!", 
                    "Expert Advisor siap mengeksekusi Scalping di Timeframe M1 dengan konfirmasi arah tren Timeframe M15.", 
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
   if(!InpUseTrailingStop) return;

   double point = _Point;
   double trailing_start = InpTrailingStartPips * 10 * point;
   double trailing_step  = InpTrailingStepPips * 10 * point;

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
   ApplyTrailingStop();

   // Cek Bar Baru di Timeframe M1 (Trigger Scalping)
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);
   if(current_bar_time == m_last_bar_time) return;
   m_last_bar_time = current_bar_time;

   // Hanya 1 posisi scalping aktif per waktu untuk mengontrol risiko
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

   // 1. Ambil Data Indikator BIAS M15
   double m15_fast[], m15_slow[];
   ArraySetAsSeries(m15_fast, true);
   ArraySetAsSeries(m15_slow, true);
   if(CopyBuffer(m_h_m15_fast_ema, 0, 0, 2, m15_fast) < 2) return;
   if(CopyBuffer(m_h_m15_slow_ema, 0, 0, 2, m15_slow) < 2) return;

   bool m15_bullish_bias = (m15_fast[0] > m15_slow[0]);
   bool m15_bearish_bias = (m15_fast[0] < m15_slow[0]);

   // 2. Ambil Data Indikator ENTRY M1
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

   // 3. SINYAL BUY SCALPING:
   // • Bias M15 Bullish (Fast EMA > Slow EMA di M15)
   // • Trigger M1 Golden Cross (Fast EMA 9 melintasi Slow EMA 21 di M1)
   // • RSI M1 > 45 && < Overbought (75)
   if(m15_bullish_bias && (m1_fast[1] <= m1_slow[1] && m1_fast[0] > m1_slow[0]) && (m1_rsi[0] > 45.0 && m1_rsi[0] < InpRSIOverbought))
   {
      double sl = ask - (InpStopLossPips * 10 * point);
      double tp = ask + (InpTakeProfitPips * 10 * point);
      if(m_trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Scalp BUY M1"))
      {
         NotifyOpenTrade("BUY", ask, sl, tp, m_trade.ResultOrder(), "Bullish (EMA 20 > EMA 50)");
      }
   }
   // 4. SINYAL SELL SCALPING:
   // • Bias M15 Bearish (Fast EMA < Slow EMA di M15)
   // • Trigger M1 Death Cross (Fast EMA 9 melintasi Slow EMA 21 di M1)
   // • RSI M1 < 55 && > Oversold (25)
   else if(m15_bearish_bias && (m1_fast[1] >= m1_slow[1] && m1_fast[0] < m1_slow[0]) && (m1_rsi[0] < 55.0 && m1_rsi[0] > InpRSIOversold))
   {
      double sl = bid + (InpStopLossPips * 10 * point);
      double tp = bid - (InpTakeProfitPips * 10 * point);
      if(m_trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Scalp SELL M1"))
      {
         NotifyOpenTrade("SELL", bid, sl, tp, m_trade.ResultOrder(), "Bearish (EMA 20 < EMA 50)");
      }
   }
}
