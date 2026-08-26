//+------------------------------------------------------------------+
//|                                     Discord_Sentinel_EA_MT4.mq4  |
//|                        IDX Sentinel & Algorithmic Trading EA     |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input string   s0 = "=== PENGATURAN DISCORD WEBHOOK ==="; // ---
input string   InpDiscordWebhookURL = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // Webhook URL Pribadi
input bool     InpEnableDiscord     = true;                                                                                                                            // Aktifkan Notifikasi Discord
input string   InpDiscordMention    = "";                                                                                                                              // Tag Mention (Kosongkan untuk channel pribadi)
input string   InpBotName           = "EA Private Sentinel MT4";                                                                                                       // Nama Bot

input string   s1 = "=== PENGATURAN TRADING ==="; // ---
input double   InpLotSize           = 0.01;      // Lot Size
input int      InpStopLossPips      = 30;        // Stop Loss (Pips)
input int      InpTakeProfitPips    = 60;        // Take Profit (Pips)
input int      InpMagicNumber       = 778899;    // Magic Number
input int      InpSlippage          = 10;        // Slippage

input string   s2 = "=== PENGATURAN INDIKATOR ==="; // ---
input int      InpFastEMA           = 20;        // Fast EMA Period
input int      InpSlowEMA           = 50;        // Slow EMA Period
input int      InpRSIPeriod         = 14;        // RSI Period
input double   InpRSIOverbought     = 70.0;      // RSI Overbought
input double   InpRSIOversold       = 30.0;      // RSI Oversold

input string   s3 = "=== TRAILING STOP ==="; // ---
input bool     InpUseTrailingStop   = true;      // Gunakan Trailing Stop
input int      InpTrailingStartPips = 20;        // Trailing Start (Pips)
input int      InpTrailingStepPips  = 10;        // Trailing Step (Pips)

datetime m_last_bar_time;

//+------------------------------------------------------------------+
//| FUNGSI PENGIRIM DISCORD WEBHOOK MT4                              |
//+------------------------------------------------------------------+
void SendDiscordEmbed(string title, string description, int color_hex, string fields_json, bool is_critical=false)
{
   if(!InpEnableDiscord || InpDiscordWebhookURL == "") return;

   string content_header = "";
   if(is_critical && InpDiscordMention != "")
   {
      content_header = "\"content\": \"🚨 " + InpDiscordMention + " — **[TRADING ALERT]**\", ";
   }

   string payload = "{" + content_header +
                    "\"username\": \"" + InpBotName + "\"," +
                    "\"embeds\": [{" +
                    "\"title\": \"" + title + "\"," +
                    "\"description\": \"" + description + "\"," +
                    "\"color\": " + IntegerToString(color_hex) + "," +
                    "\"fields\": [" + fields_json + "]," +
                    "\"footer\": {\"text\": \"EA Sentinel MT4 • " + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
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
         Print("⚠️ Izinkan WebRequest di MT4: Tools -> Options -> Expert Advisors -> Tambahkan: https://discord.com");
      }
   }
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   string startup_fields = "{\"name\": \"💻 Pair & Timeframe\", \"value\": \"`" + Symbol() + " (" + IntegerToString(Period()) + ")`\", \"inline\": true}," +
                           "{\"name\": \"💰 Balance / Equity\", \"value\": \"`$" + DoubleToString(AccountBalance(), 2) + " / $" + DoubleToString(AccountEquity(), 2) + "`\", \"inline\": true}," +
                           "{\"name\": \"⚙️ Magic Number\", \"value\": \"`" + IntegerToString(InpMagicNumber) + "`\", \"inline\": true}";

   SendDiscordEmbed("🤖 EA IDX Sentinel MT4 Berhasil Aktif!", 
                    "Expert Advisor telah online dan siap memantau pasar.", 
                    0x3498DB, startup_fields, false);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| TRAILING STOP                                                    |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   if(!InpUseTrailingStop) return;

   double point = Point;
   if(Digits == 3 || Digits == 5) point *= 10;

   double trailing_start = InpTrailingStartPips * point;
   double trailing_step  = InpTrailingStepPips * point;

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
                     bool res = OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrNONE);
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
                     bool res = OrderModify(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), 0, clrNONE);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ON TICK                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   ApplyTrailingStop();

   datetime current_bar_time = Time[0];
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

   double fast_ema1 = iMA(Symbol(), 0, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double fast_ema2 = iMA(Symbol(), 0, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double slow_ema1 = iMA(Symbol(), 0, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slow_ema2 = iMA(Symbol(), 0, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double rsi       = iRSI(Symbol(), 0, InpRSIPeriod, PRICE_CLOSE, 1);

   double point = Point;
   if(Digits == 3 || Digits == 5) point *= 10;

   // Sinyal BUY
   if(fast_ema2 <= slow_ema2 && fast_ema1 > slow_ema1 && rsi > 50.0 && rsi < InpRSIOverbought)
   {
      double sl = Ask - (InpStopLossPips * point);
      double tp = Ask + (InpTakeProfitPips * point);
      int ticket = OrderSend(Symbol(), OP_BUY, InpLotSize, Ask, InpSlippage, sl, tp, "EA Sentinel BUY", InpMagicNumber, 0, clrGreen);
      if(ticket > 0)
      {
         string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"🟢 **BUY**\", \"inline\": true}," +
                         "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + Symbol() + "` (" + DoubleToString(InpLotSize, 2) + " Lot)\", \"inline\": true}," +
                         "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(Ask, Digits) + "`\", \"inline\": true}," +
                         "{\"name\": \"🛡️ Stop Loss / TP\", \"value\": \"`SL: " + DoubleToString(sl, Digits) + " | TP: " + DoubleToString(tp, Digits) + "`\", \"inline\": false}";
         SendDiscordEmbed("⚡ OPEN POSISI BUY (" + Symbol() + ")", "Eksekusi otomatis sinyal EMA & RSI.", 0x2ECC71, fields, false);
      }
   }
   // Sinyal SELL
   else if(fast_ema2 >= slow_ema2 && fast_ema1 < slow_ema1 && rsi < 50.0 && rsi > InpRSIOversold)
   {
      double sl = Bid + (InpStopLossPips * point);
      double tp = Bid - (InpTakeProfitPips * point);
      int ticket = OrderSend(Symbol(), OP_SELL, InpLotSize, Bid, InpSlippage, sl, tp, "EA Sentinel SELL", InpMagicNumber, 0, clrRed);
      if(ticket > 0)
      {
         string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"🔴 **SELL**\", \"inline\": true}," +
                         "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + Symbol() + "` (" + DoubleToString(InpLotSize, 2) + " Lot)\", \"inline\": true}," +
                         "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(Bid, Digits) + "`\", \"inline\": true}," +
                         "{\"name\": \"🛡️ Stop Loss / TP\", \"value\": \"`SL: " + DoubleToString(sl, Digits) + " | TP: " + DoubleToString(tp, Digits) + "`\", \"inline\": false}";
         SendDiscordEmbed("⚡ OPEN POSISI SELL (" + Symbol() + ")", "Eksekusi otomatis sinyal EMA & RSI.", 0xE74C3C, fields, false);
      }
   }
}
