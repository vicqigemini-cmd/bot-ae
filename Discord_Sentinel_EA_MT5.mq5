//+------------------------------------------------------------------+
//|                                     Discord_Sentinel_EA_MT5.mq5  |
//|                        IDX Sentinel & Algorithmic Trading EA     |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "1.00"
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
input string   InpBotName           = "EA Private Sentinel";                                                                                                           // Nama Bot Discord

input group "=== PENGATURAN TRADING & LOT ==="
input double   InpLotSize           = 0.01;      // Ukuran Lot Tetap
input int      InpStopLossPips      = 30;        // Stop Loss (Pips)
input int      InpTakeProfitPips    = 60;        // Take Profit (Pips)
input ulong    InpMagicNumber       = 778899;    // Magic Number EA
input ulong    InpSlippage          = 10;        // Maksimum Slippage (Points)

input group "=== PENGATURAN INDIKATOR (TREND + RSI) ==="
input int      InpFastEMA           = 20;        // Fast EMA Period
input int      InpSlowEMA           = 50;        // Slow EMA Period
input int      InpRSIPeriod         = 14;        // RSI Period
input double   InpRSIOverbought     = 70.0;      // RSI Overbought Level
input double   InpRSIOversold       = 30.0;      // RSI Oversold Level

input group "=== TRAILING STOP ==="
input bool     InpUseTrailingStop   = true;      // Gunakan Trailing Stop
input int      InpTrailingStartPips = 20;        // Trailing Dimulai Setelah Profit (Pips)
input int      InpTrailingStepPips  = 10;        // Jarak Trailing Step (Pips)

//--- Global Variables
CTrade         m_trade;
CPositionInfo  m_position;
int            m_handle_fast_ema;
int            m_handle_slow_ema;
int            m_handle_rsi;
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
      content_header = "\"content\": \"🚨 " + InpDiscordMention + " — **[PERHATIAN KREDIT / TRADING ALERT]**\", ";
   }

   string payload = "{" + content_header +
                    "\"username\": \"" + InpBotName + "\"," +
                    "\"embeds\": [{" +
                    "\"title\": \"" + title + "\"," +
                    "\"description\": \"" + description + "\"," +
                    "\"color\": " + IntegerToString(color_hex) + "," +
                    "\"fields\": [" + fields_json + "]," +
                    "\"footer\": {\"text\": \"EA Sentinel MT5 • " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
                    "}]}";

   char post_data[];
   char result_data[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n";

   StringToCharArray(payload, post_data, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(post_data, ArraySize(post_data) - 1); // Hapus null terminator

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
void NotifyOpenTrade(string type, double price, double sl, double tp, ulong ticket)
{
   string color_hex = (type == "BUY") ? "3066993" : "15158332"; // Hijau atau Merah
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + "**\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (" + DoubleToString(InpLotSize, 2) + " Lot)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Stop Loss\", \"value\": \"`" + DoubleToString(sl, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🎯 Take Profit\", \"value\": \"`" + DoubleToString(tp, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("⚡ EKSEKUSI POSISI BARU (" + type + ")", 
                    "EA telah mengeksekusi order otomatis berdasarkan konfirmasi sinyal EMA & RSI.", 
                    (type == "BUY") ? 0x2ECC71 : 0xE74C3C, 
                    fields, false);
}

void NotifyCloseTrade(string type, double open_price, double close_price, double profit, ulong ticket)
{
   int embed_color = (profit >= 0) ? 0x2ECC71 : 0xE74C3C;
   string emoji = (profit >= 0) ? "💰 PROFIT" : "🔻 LOSS";

   string fields = "{\"name\": \"📊 Hasil Trade\", \"value\": \"**" + emoji + ": $" + DoubleToString(profit, 2) + "**\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Posisi\", \"value\": \"`" + type + " " + _Symbol + "`\", \"inline\": true}," +
                   "{\"name\": \"🎯 Open / Close\", \"value\": \"`" + DoubleToString(open_price, _Digits) + " ➜ " + DoubleToString(close_price, _Digits) + "`\", \"inline\": false}";

   SendDiscordEmbed("🏁 POSISI DITUTUP (TICKET #" + IntegerToString(ticket) + ")", 
                    "Order telah selesai ditutup oleh EA / menyentuh target TP/SL.", 
                    embed_color, fields, (profit < -50.0));
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);

   m_handle_fast_ema = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_handle_slow_ema = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_handle_rsi      = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);

   if(m_handle_fast_ema == INVALID_HANDLE || m_handle_slow_ema == INVALID_HANDLE || m_handle_rsi == INVALID_HANDLE)
   {
      Print("❌ Gagal membuat handle indikator.");
      return INIT_FAILED;
   }

   // Kirim pesan salam pembuka ke Discord
   string startup_fields = "{\"name\": \"💻 Pair & Timeframe\", \"value\": \"`" + _Symbol + " (" + EnumToString(_Period) + ")`\", \"inline\": true}," +
                           "{\"name\": \"💰 Balance / Equity\", \"value\": \"`$" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " / $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "`\", \"inline\": true}," +
                           "{\"name\": \"⚙️ Magic Number\", \"value\": \"`" + IntegerToString(InpMagicNumber) + "`\", \"inline\": true}";

   SendDiscordEmbed("🤖 EA IDX Sentinel Berhasil Aktif!", 
                    "Expert Advisor telah online dan siap memantau pasar serta mengeksekusi order otomatis.", 
                    0x3498DB, startup_fields, false);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(m_handle_fast_ema);
   IndicatorRelease(m_handle_slow_ema);
   IndicatorRelease(m_handle_rsi);
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

   // Cek apakah ada bar baru
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(current_bar_time == m_last_bar_time) return;
   m_last_bar_time = current_bar_time;

   // Periksa apakah sudah ada posisi aktif untuk EA ini
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

   if(total_orders > 0) return; // Hanya 1 posisi aktif per waktu

   // Ambil data indikator
   double fast_ema[], slow_ema[], rsi[];
   ArraySetAsSeries(fast_ema, true);
   ArraySetAsSeries(slow_ema, true);
   ArraySetAsSeries(rsi, true);

   if(CopyBuffer(m_handle_fast_ema, 0, 1, 2, fast_ema) < 2) return;
   if(CopyBuffer(m_handle_slow_ema, 0, 1, 2, slow_ema) < 2) return;
   if(CopyBuffer(m_handle_rsi, 0, 1, 2, rsi) < 2) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;

   // Sinyal BUY: Fast EMA melintasi Slow EMA ke atas DAN RSI > 50 (belum Overbought)
   if(fast_ema[1] <= slow_ema[1] && fast_ema[0] > slow_ema[0] && rsi[0] > 50.0 && rsi[0] < InpRSIOverbought)
   {
      double sl = ask - (InpStopLossPips * 10 * point);
      double tp = ask + (InpTakeProfitPips * 10 * point);
      if(m_trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "EA Sentinel BUY"))
      {
         NotifyOpenTrade("BUY", ask, sl, tp, m_trade.ResultOrder());
      }
   }
   // Sinyal SELL: Fast EMA melintasi Slow EMA ke bawah DAN RSI < 50 (belum Oversold)
   else if(fast_ema[1] >= slow_ema[1] && fast_ema[0] < slow_ema[0] && rsi[0] < 50.0 && rsi[0] > InpRSIOversold)
   {
      double sl = bid + (InpStopLossPips * 10 * point);
      double tp = bid - (InpTakeProfitPips * 10 * point);
      if(m_trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "EA Sentinel SELL"))
      {
         NotifyOpenTrade("SELL", bid, sl, tp, m_trade.ResultOrder());
      }
   }
}
