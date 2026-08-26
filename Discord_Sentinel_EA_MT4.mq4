//+------------------------------------------------------------------+
//|                                     Discord_Sentinel_EA_MT4.mq4  |
//|             Multi-Timeframe Scalper EA (Bias M15 • Entry M1)     |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input string   s0 = "=== PENGATURAN DISCORD WEBHOOK ==="; // ---
input string   InpDiscordWebhookURL = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // Webhook URL Pribadi
input bool     InpEnableDiscord     = true;                                                                                                                            // Aktifkan Notifikasi Discord
input string   InpDiscordMention    = "";                                                                                                                              // Tag Mention (Kosongkan untuk channel pribadi)
input string   InpBotName           = "EA Scalper Sentinel MT4";                                                                                                       // Nama Bot

input string   s1 = "=== PENGATURAN SCALPING & LOT ==="; // ---
input double   InpLotSize           = 0.01;      // Ukuran Lot Scalping
input int      InpStopLossPips      = 15;        // Stop Loss Scalping (Pips)
input int      InpTakeProfitPips    = 30;        // Take Profit Scalping (Pips)
input int      InpMagicNumber       = 778899;    // Magic Number EA
input int      InpSlippage          = 10;        // Maksimum Slippage (Points)

input string   s2 = "=== BIAS TREN BESAR (TIMEFRAME M15) ==="; // ---
input int      InpM15FastEMA        = 20;        // M15 Fast EMA Period
input int      InpM15SlowEMA        = 50;        // M15 Slow EMA Period

input string   s3 = "=== TRIGGER ENTRY PRESISI (TIMEFRAME M1) ==="; // ---
input int      InpM1FastEMA         = 9;         // M1 Fast EMA Period (Scalp Trigger)
input int      InpM1SlowEMA         = 21;        // M1 Slow EMA Period (Scalp Baseline)
input int      InpM1RSIPeriod       = 14;        // M1 RSI Period
input double   InpRSIOverbought     = 75.0;      // M1 RSI Overbought Level
input double   InpRSIOversold       = 25.0;      // M1 RSI Oversold Level

input string   s4 = "=== SCALPING TRAILING STOP ==="; // ---
input bool     InpUseTrailingStop   = true;      // Gunakan Trailing Stop Cepat
input int      InpTrailingStartPips = 10;        // Trailing Dimulai Setelah Profit (Pips)
input int      InpTrailingStepPips  = 5;         // Jarak Trailing Step (Pips)

//--- Global Variables
datetime       m_last_bar_time;

//+------------------------------------------------------------------+
//| FUNGSI PENGIRIM DISCORD WEBHOOK MT4                              |
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
   int res = WebRequest("POST", InpDiscordWebhookURL, headers, 5000, post_data, result_data, result_headers);
   if(res == -1)
   {
      Print("❌ Gagal kirim Webhook Discord. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI ORDER DISCORD                                  |
//+------------------------------------------------------------------+
void NotifyOpenTrade(string type, double price, double sl, double tp, int ticket, string bias_text)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Scalp M1)**\", \"inline\": true}," +
                   "{\"name\": \"🧭 Bias Tren M15\", \"value\": \"`" + bias_text + "`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + Symbol() + "` (" + DoubleToStr(InpLotSize, 2) + " Lot)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToStr(price, Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToStr(sl, Digits) + "` (-" + IntegerToString(InpStopLossPips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToStr(tp, Digits) + "` (+" + IntegerToString(InpTakeProfitPips) + " Pips)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("⚡ EKSEKUSI SCALPING BARU (" + type + ")", 
                    "Order scalping dieksekusi berdasarkan keselarasan Bias M15 dan Crossover Momentum M1.", 
                    embed_color, 
                    fields, false);
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   string startup_fields = "{\"name\": \"🧭 Strategi Multi-Timeframe\", \"value\": \"`Bias: M15 | Entry: M1`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Scalping\", \"value\": \"`SL: " + IntegerToString(InpStopLossPips) + " Pips | TP: " + IntegerToString(InpTakeProfitPips) + " Pips`\", \"inline\": true}," +
                           "{\"name\": \"💰 Balance / Equity\", \"value\": \"`$" + DoubleToStr(AccountBalance(), 2) + " / $" + DoubleToStr(AccountEquity(), 2) + "`\", \"inline\": true}";

   SendDiscordEmbed("🤖 EA Scalper Sentinel MT4 Berhasil Aktif!", 
                    "Expert Advisor siap mengeksekusi Scalping di Timeframe M1 dengan konfirmasi arah tren Timeframe M15.", 
                    0x3498DB, startup_fields, false);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| FUNGSI TRAILING STOP                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   if(!InpUseTrailingStop) return;

   double point = Point;
   double trailing_start = InpTrailingStartPips * 10 * point;
   double trailing_step  = InpTrailingStepPips * 10 * point;

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
   ApplyTrailingStop();

   // Cek Bar Baru di Timeframe M1 (Trigger Scalping)
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

   // 1. Ambil Data Indikator BIAS M15
   double m15_fast = iMA(Symbol(), PERIOD_M15, InpM15FastEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double m15_slow = iMA(Symbol(), PERIOD_M15, InpM15SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 0);

   bool m15_bullish_bias = (m15_fast > m15_slow);
   bool m15_bearish_bias = (m15_fast < m15_slow);

   // 2. Ambil Data Indikator ENTRY M1
   double m1_fast_prev = iMA(Symbol(), PERIOD_M1, InpM1FastEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double m1_fast_curr = iMA(Symbol(), PERIOD_M1, InpM1FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double m1_slow_prev = iMA(Symbol(), PERIOD_M1, InpM1SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double m1_slow_curr = iMA(Symbol(), PERIOD_M1, InpM1SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double m1_rsi       = iRSI(Symbol(), PERIOD_M1, InpM1RSIPeriod, PRICE_CLOSE, 1);

   double point = Point;

   // 3. SINYAL BUY SCALPING:
   if(m15_bullish_bias && (m1_fast_prev <= m1_slow_prev && m1_fast_curr > m1_slow_curr) && (m1_rsi > 45.0 && m1_rsi < InpRSIOverbought))
   {
      double ask = Ask;
      double sl = ask - (InpStopLossPips * 10 * point);
      double tp = ask + (InpTakeProfitPips * 10 * point);
      int ticket = OrderSend(Symbol(), OP_BUY, InpLotSize, ask, InpSlippage, sl, tp, "Scalp BUY M1", InpMagicNumber, 0, clrGreen);
      if(ticket > 0)
      {
         NotifyOpenTrade("BUY", ask, sl, tp, ticket, "Bullish (EMA 20 > EMA 50)");
      }
   }
   // 4. SINYAL SELL SCALPING:
   else if(m15_bearish_bias && (m1_fast_prev >= m1_slow_prev && m1_fast_curr < m1_slow_curr) && (m1_rsi < 55.0 && m1_rsi > InpRSIOversold))
   {
      double bid = Bid;
      double sl = bid + (InpStopLossPips * 10 * point);
      double tp = bid - (InpTakeProfitPips * 10 * point);
      int ticket = OrderSend(Symbol(), OP_SELL, InpLotSize, bid, InpSlippage, sl, tp, "Scalp SELL M1", InpMagicNumber, 0, clrRed);
      if(ticket > 0)
      {
         NotifyOpenTrade("SELL", bid, sl, tp, ticket, "Bearish (EMA 20 < EMA 50)");
      }
   }
}
