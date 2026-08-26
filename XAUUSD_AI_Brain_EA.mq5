//+------------------------------------------------------------------+
//|                                     XAUUSD_AI_Brain_EA.mq5       |
//|  SOVEREIGN INSTITUTIONAL M1 GOLD SCALPER (XAUUSD) - v4.50        |
//|  (Dynamic ATR • Multi-Stage TP • Anti-Rollover • Direction Lock)  |
//|                                  https://github.com/vicqigemini-cmd |
//+------------------------------------------------------------------+
#property copyright "IDX & AI Sentinel Algorithmic Team"
#property link      "https://github.com/vicqigemini-cmd"
#property version   "4.50"
#property description "EA Scalping M1 Gold (XAUUSD) Sovereign Edition. Dynamic ATR SL/TP, Multi-Stage Profit, Directional Lock, Anti-Rollover Spread Guard."

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

struct STrackedPos
{
   ulong    ticket;
   string   type;
   double   open_price;
   double   volume;
   datetime open_time;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== 1. DISCORD NOTIFICATION WEBHOOK ==="
input string              InpDiscordWebhookURL     = "https://discord.com/api/webhooks/1542059423999197184/KMcjEnHpAkMwoW8cwbQKdxnYYl4E0q2ENkRy-ICu0ssk_w6y3Eyihy5vNGHKkw1Ys61C"; // Webhook URL Pribadi
input bool                InpEnableDiscord         = true;                                                                                                                            // Aktifkan Notifikasi Discord
input string              InpDiscordMention        = "";                                                                                                                              // Mention Role/User
input string              InpBotName               = "XAUUSD Sovereign Scalper";                                                                                                      // Nama Bot

input group "=== 2. OTA CLOUD AUTO-SYNC (1x PASANG = AUTO UPDATE) ==="
input bool                InpEnableCloudSync       = true;                  // Aktifkan Sinkronisasi Cloud dari GitHub
input int                 InpSyncIntervalMin       = 5;                     // Interval Cek Update Cloud (Menit)

input group "=== 3. SOVEREIGN ENGINE & SAFETY GUARDS ==="
input ulong               InpMagicNumber           = 202611;                // Magic Number EA
input string              InpTradeComment          = "Sovereign_XAU";       // Label Order
input bool                InpUseDynamicATR         = true;                  // SL & TP Adaptif Volatilitas (ATR M1)
input int                 InpATR_Period            = 14;                    // ATR Period
input bool                InpUseDirectionalLock    = true;                  // Kunci 1 Arah (Haram Hedging saat Layer Aktif)
input bool                InpUseRolloverGuard      = true;                  // Pelindung Jam Rollover Broker (23:50-01:10)
input int                 InpMinLayerDistancePts   = 30;                    // Jarak Minimal Antar Layer (Points, 30 pts = 3 pips)
input int                 InpMaxOpenPositions      = 3;                     // Max Posisi Scalping Aktif (Tri-Layer Sweet Spot)

input group "=== 4. MONEY & RISK MANAGEMENT ==="
input ENUM_LOT_TYPE       InpLotType               = LOT_PER_BALANCE;       // Mode Lot Sizing
input double              InpFixedLot              = 0.01;                  // Base Lot per Kelipatan
input double              InpBalanceStep           = 500.0;                 // Saldo per Kelipatan Lot ($500 = 0.01 Lot)
input double              InpRiskPercent           = 1.0;                   // Risk % per Trade
input int                 InpBaseSLPoints          = 120;                   // Base Stop Loss (Points, 120 pts = 12 pips)
input int                 InpBaseTPPoints          = 200;                   // Base Take Profit (Points, 200 pts = 20 pips)
input int                 InpMaxSpreadPoints       = 80;                    // Max Spread Filter (Points)

input group "=== 5. FAST BREAK-EVEN & AGGRESSIVE TRAILING ==="
input bool                InpUseBreakEven          = true;                  // Aktifkan Break-Even Cepat
input int                 InpBETriggerPoints       = 80;                    // Trigger BE (Points Profit, 80 pts = 8 pips)
input int                 InpBEProfitPoints        = 15;                    // Kunci Profit BE (Points, 15 pts = 1.5 pips)
input bool                InpUseTrailingStop       = true;                  // Aktifkan Trailing Stop Cepat
input int                 InpTrailingStartPoints   = 100;                   // Trailing Start (Points Profit, 100 pts = 10 pips)
input int                 InpTrailingDistance      = 60;                    // Jarak Trailing Stop (Points, 60 pts = 6 pips)
input int                 InpTrailingStep          = 15;                    // Step Pergeseran Trailing (Points)

input group "=== 6. DAILY TARGET & MAX LOSS GUARD (% WALLET) ==="
input bool                InpUseDailyGuard         = true;                  // Aktifkan Pengaman Target Harian
input double              InpDailyTargetPercent    = 15.0;                  // Target Profit Harian (15% dari Total Wallet)
input double              InpDailyMaxLossPercent   = 7.0;                   // Batas Rem Rugi Harian (7% dari Total Wallet)

input group "=== 7. M1 INDICATOR PARAMETERS (HYPER RESPONSIVE) ==="
input int                 InpEMA_Fast_M1           = 5;                     // M1 Ultra-Fast EMA Period
input int                 InpEMA_Slow_M1           = 13;                    // M1 Momentum EMA Period
input int                 InpStoch_K               = 5;                     // Fast Stochastic %K
input int                 InpStoch_D               = 3;                     // Fast Stochastic %D
input int                 InpStoch_Slowing         = 3;                     // Fast Stochastic Slowing
input int                 InpBB_Period_M1          = 20;                    // M1 Bollinger Bands Period
input double              InpBB_Dev_M1             = 2.0;                   // M1 BB Deviation

//--- Dynamic Runtime Cloud Variables
string                    g_current_version        = "4.50";
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
bool                      g_use_daily_guard        = true;
double                    g_daily_target_pct       = 15.0;
double                    g_daily_max_loss_pct     = 7.0;

//--- Global Handles & Objects
CTrade                    m_trade;
CPositionInfo             m_position;
CSymbolInfo               m_symbol;
CAccountInfo              m_account;

int handle_ema5_m1   = INVALID_HANDLE;
int handle_ema13_m1  = INVALID_HANDLE;
int handle_stoch_m1  = INVALID_HANDLE;
int handle_bb_m1     = INVALID_HANDLE;
int handle_atr_m1    = INVALID_HANDLE;

datetime last_trade_time = 0;
datetime m_last_cloud_sync_time = 0;

STrackedPos g_tracked_positions[];
ulong g_notified_deals[];

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
      content_header = "\"content\": \"🚨 " + InpDiscordMention + " — **[SOVEREIGN SCALPER ALERT]**\", ";
   }

   string payload = "{" + content_header +
                    "\"username\": \"" + InpBotName + "\"," +
                    "\"embeds\": [{" +
                    "\"title\": \"" + title + "\"," +
                    "\"description\": \"" + description + "\"," +
                    "\"color\": " + IntegerToString(color_hex) + "," +
                    "\"fields\": [" + fields_json + "]," +
                    "\"footer\": {\"text\": \"XAUUSD Sovereign Scalper Sentinel MT5 v" + g_current_version + " • " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}" +
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
         g_balance_step       = ExtractJsonNumber(json, "balance_per_step", InpBalanceStep);
         g_lot_step           = ExtractJsonNumber(json, "lot_per_step", InpFixedLot);
         g_sl_points          = (int)ExtractJsonNumber(json, "stop_loss_points", InpBaseSLPoints);
         g_tp_points          = (int)ExtractJsonNumber(json, "take_profit_points", InpBaseTPPoints);
         g_max_spread         = (int)ExtractJsonNumber(json, "max_spread_points", InpMaxSpreadPoints);
         g_max_open_pos       = (int)ExtractJsonNumber(json, "max_open_positions", InpMaxOpenPositions);
         g_min_layer_dist     = (int)ExtractJsonNumber(json, "min_layer_distance_points", InpMinLayerDistancePts);
         g_use_trailing       = ExtractJsonBool(json, "use_trailing_stop", InpUseTrailingStop);
         g_use_daily_guard    = ExtractJsonBool(json, "use_daily_guard", InpUseDailyGuard);
         g_daily_target_pct   = ExtractJsonNumber(json, "daily_target_profit_percent", InpDailyTargetPercent);
         g_daily_max_loss_pct = ExtractJsonNumber(json, "daily_max_loss_percent", InpDailyMaxLossPercent);

         if(is_new_version && !is_initial)
         {
            double cur_bal = m_account.Balance();
            double target_usd = cur_bal * (g_daily_target_pct / 100.0);
            double loss_usd = cur_bal * (g_daily_max_loss_pct / 100.0);

            string update_fields = "{\"name\": \"⚡ Sovereign Engine\", \"value\": \"`v" + g_current_version + " (Sovereign Edition)`\", \"inline\": true}," +
                                   "{\"name\": \"🎯 Target Harian (15%)\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (" + DoubleToString(g_daily_target_pct, 0) + "% Wallet)`\", \"inline\": true}," +
                                   "{\"name\": \"🛡️ Max Loss Harian (7%)\", \"value\": \"`-$" + DoubleToString(loss_usd, 2) + " (" + DoubleToString(g_daily_max_loss_pct, 0) + "% Wallet)`\", \"inline\": true}," +
                                   "{\"name\": \"⚡ Tri-Layer Sweet Spot\", \"value\": \"`Max " + IntegerToString(g_max_open_pos) + " Posisi (Min " + IntegerToString(g_min_layer_dist / 10) + " Pips)`\", \"inline\": true}," +
                                   "{\"name\": \"📈 Auto-Lot Mode\", \"value\": \"`$" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot`\", \"inline\": true}";
            
            SendDiscordEmbed("🔄 OTA CLOUD UPDATE DIAPLIKASIKAN (SOVEREIGN v" + g_current_version + ")!", 
                             "5 Pilar Optimalisasi Institusional (Dynamic ATR, Multi-Stage TP, Directional Lock) resmi aktif!", 
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
//| CEK JAM ROLLOVER SPREAD SPIKE (23:50 - 01:10)                    |
//+------------------------------------------------------------------+
bool IsRolloverTime()
{
   if(!InpUseRolloverGuard) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Server rollover spread spike biasa terjadi antara 23:50 s/d 01:10
   if((dt.hour == 23 && dt.min >= 50) || (dt.hour == 0) || (dt.hour == 1 && dt.min <= 10))
   {
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| KALKULASI ADAPTIF ATR SL & TP                                    |
//+------------------------------------------------------------------+
void CalculateDynamicSLTP(int &calc_sl, int &calc_tp)
{
   calc_sl = g_sl_points;
   calc_tp = g_tp_points;

   if(!InpUseDynamicATR || handle_atr_m1 == INVALID_HANDLE) return;

   double atr_buf[];
   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(handle_atr_m1, 0, 0, 1, atr_buf) > 0)
   {
      double point = m_symbol.Point();
      double atr_points = atr_buf[0] / point;

      // Dynamic SL = 1.5x ATR M1 (Batas: 100 s/d 160 points / 10-16 pips)
      calc_sl = (int)MathMax(100, MathMin(160, atr_points * 1.5));

      // Dynamic TP = 2.5x ATR M1 (Batas: 150 s/d 280 points / 15-28 pips)
      calc_tp = (int)MathMax(150, MathMin(280, atr_points * 2.5));
   }
}

//+------------------------------------------------------------------+
//| KALKULASI AUTO-LOT ($500 = 0.01 LOT)                             |
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
//| FORMAT NOTIFIKASI OPEN TRADE DISCORD                             |
//+------------------------------------------------------------------+
void NotifyAITrade(string type, double price, double lot_used, double sl, double tp, ulong ticket, string trigger_source, int spread_used, int current_layers, int sl_pts, int tp_pts)
{
   int embed_color = (type == "BUY") ? 0x2ECC71 : 0xE74C3C;
   string emoji = (type == "BUY") ? "🟢" : "🔴";

   string fields = "{\"name\": \"🏷️ Tipe Order\", \"value\": \"" + emoji + " **" + type + " (Layer " + IntegerToString(current_layers) + "/" + IntegerToString(g_max_open_pos) + ")**\", \"inline\": true}," +
                   "{\"name\": \"⚡ Pemicu Sniper\", \"value\": \"`" + trigger_source + "`\", \"inline\": true}," +
                   "{\"name\": \"🧠 Versi Engine\", \"value\": \"`v" + g_current_version + " (Sovereign)`\", \"inline\": true}," +
                   "{\"name\": \"📊 Simbol & Lot\", \"value\": \"`" + _Symbol + "` (**" + DoubleToString(lot_used, 2) + " Lot**)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Open\", \"value\": \"`" + DoubleToString(price, _Digits) + "` (Sniper Execution)\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Dynamic SL\", \"value\": \"`" + DoubleToString(sl, _Digits) + "` (-" + IntegerToString(sl_pts / 10) + " Pips ATR)\", \"inline\": true}," +
                   "{\"name\": \"🎯 Dynamic TP\", \"value\": \"`" + DoubleToString(tp, _Digits) + "` (+" + IntegerToString(tp_pts / 10) + " Pips ATR)\", \"inline\": true}," +
                   "{\"name\": \"🛡️ Spread Saat Entry\", \"value\": \"`" + IntegerToString(spread_used) + " Points` (Aman)\", \"inline\": true}," +
                   "{\"name\": \"💰 Saldo Akun\", \"value\": \"`$" + DoubleToString(m_account.Balance(), 2) + "` ($500 = 0.01)\", \"inline\": true}," +
                   "{\"name\": \"🎫 Ticket ID\", \"value\": \"`#" + IntegerToString(ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("⚡ SOVEREIGN FAST SNIPER (" + type + " - Layer " + IntegerToString(current_layers) + ")", 
                    "Eksekusi Instan M1: Terkonfirmasi Rejection Wick + Volatilitas Adaptif ATR.", 
                    embed_color, 
                    fields, false);
}

//+------------------------------------------------------------------+
//| FORMAT NOTIFIKASI CLOSE TRADE DISCORD                            |
//+------------------------------------------------------------------+
void NotifyCloseTrade(string type, double close_price, double profit, ulong deal_ticket, double volume)
{
   for(int i = 0; i < ArraySize(g_notified_deals); i++)
   {
      if(g_notified_deals[i] == deal_ticket) return;
   }
   int sz = ArraySize(g_notified_deals);
   ArrayResize(g_notified_deals, sz + 1);
   g_notified_deals[sz] = deal_ticket;

   int embed_color = (profit >= 0) ? 0x2ECC71 : 0xE74C3C;
   string result_emoji = (profit >= 0) ? "🟢 **PROFIT CUAN**" : "🔴 **LOSS TERKENDALI**";
   string pnl_sign = (profit >= 0) ? "+$" : "-$";
   double abs_profit = MathAbs(profit);
   double current_balance = m_account.Balance();
   double daily_total_pl = GetDailyProfitLoss();

   string fields = "{\"name\": \"📊 Hasil Transaksi\", \"value\": \"" + result_emoji + "\", \"inline\": true}," +
                   "{\"name\": \"🧠 Versi Engine\", \"value\": \"`v" + g_current_version + " (Sovereign)`\", \"inline\": true}," +
                   "{\"name\": \"💵 Realized PnL\", \"value\": \"**" + pnl_sign + DoubleToString(abs_profit, 2) + "**\", \"inline\": true}," +
                   "{\"name\": \"🏦 Saldo Akun Terkini\", \"value\": \"**`$" + DoubleToString(current_balance, 2) + "`**\", \"inline\": true}," +
                   "{\"name\": \"🏷️ Posisi Ditutup\", \"value\": \"`" + type + " " + _Symbol + " (" + DoubleToString(volume, 2) + " Lot)`\", \"inline\": true}," +
                   "{\"name\": \"🎯 Harga Close\", \"value\": \"`" + DoubleToString(close_price, _Digits) + "`\", \"inline\": true}," +
                   "{\"name\": \"🏆 Total PnL Hari Ini\", \"value\": \"`" + ((daily_total_pl >= 0) ? "+$" : "-$") + DoubleToString(MathAbs(daily_total_pl), 2) + "`\", \"inline\": true}," +
                   "{\"name\": \"🎫 Deal Ticket\", \"value\": \"`#" + IntegerToString(deal_ticket) + "`\", \"inline\": true}";

   SendDiscordEmbed("🏁 POSISI SCALPING SELESAI DITUTUP (" + ((profit >= 0) ? "PROFIT" : "LOSS") + ")", 
                    "Posisi scalping telah resmi ditutup (Take Profit / Stop Loss / Trailing Stop) dan saldo akun berhasil diperbarui.", 
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
         
         if((deal_magic == InpMagicNumber || deal_magic == 0) && (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT || deal_entry == DEAL_ENTRY_OUT_BY))
         {
            double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(deal_ticket, DEAL_SWAP) + 
                            HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            double close_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            double volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            long deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
            string pos_type = (deal_type == DEAL_TYPE_BUY) ? "BUY (Tutup SELL)" : "SELL (Tutup BUY)";
            
            NotifyCloseTrade(pos_type, close_price, profit, deal_ticket, volume);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DOUBLE-CHECK POSITION CLOSE TRACKER                              |
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
               NotifyCloseTrade(g_tracked_positions[i].type, close_price, profit, deal, g_tracked_positions[i].volume);
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
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
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
               g_tracked_positions[sz].type = (m_position.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
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
      Alert("PERINGATAN: EA 'XAUUSD Sovereign Scalper' hanya boleh dipasang pada chart XAUUSD / GOLD!");
      return INIT_FAILED;
   }

   if(!m_symbol.Name(_Symbol)) return INIT_FAILED;
   m_symbol.Refresh();

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetDeviationInPoints(30);

   g_balance_step       = InpBalanceStep;
   g_lot_step           = InpFixedLot;
   g_sl_points          = InpBaseSLPoints;
   g_tp_points          = InpBaseTPPoints;
   g_max_spread         = InpMaxSpreadPoints;
   g_max_open_pos       = InpMaxOpenPositions;
   g_min_layer_dist     = InpMinLayerDistancePts;
   g_use_trailing       = InpUseTrailingStop;
   g_trailing_start     = InpTrailingStartPoints;
   g_trailing_dist      = InpTrailingDistance;
   g_trailing_step      = InpTrailingStep;
   g_use_daily_guard    = InpUseDailyGuard;
   g_daily_target_pct   = InpDailyTargetPercent;
   g_daily_max_loss_pct = InpDailyMaxLossPercent;

   FetchAndApplyCloudConfig(true);
   m_last_cloud_sync_time = TimeCurrent();

   // Inisialisasi Indikator M1 Ultra-Fast & Dynamic ATR
   handle_ema5_m1  = iMA(_Symbol, PERIOD_M1, InpEMA_Fast_M1, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema13_m1 = iMA(_Symbol, PERIOD_M1, InpEMA_Slow_M1, 0, MODE_EMA, PRICE_CLOSE);
   handle_stoch_m1 = iStochastic(_Symbol, PERIOD_M1, InpStoch_K, InpStoch_D, InpStoch_Slowing, MODE_SMA, STO_LOWHIGH);
   handle_bb_m1    = iBands(_Symbol, PERIOD_M1, InpBB_Period_M1, 0, InpBB_Dev_M1, PRICE_CLOSE);
   handle_atr_m1   = iATR(_Symbol, PERIOD_M1, InpATR_Period);

   if(handle_ema5_m1 == INVALID_HANDLE || handle_ema13_m1 == INVALID_HANDLE ||
      handle_stoch_m1 == INVALID_HANDLE || handle_bb_m1 == INVALID_HANDLE ||
      handle_atr_m1 == INVALID_HANDLE)
   {
      Print("[ERROR] Gagal inisialisasi indikator Sovereign M1!");
      return INIT_FAILED;
   }

   double current_bal = m_account.Balance();
   double target_usd = current_bal * (g_daily_target_pct / 100.0);
   double loss_usd = current_bal * (g_daily_max_loss_pct / 100.0);
   double current_lot = CalculateLotSize(g_sl_points);

   string startup_fields = "{\"name\": \"⚡ Sovereign Engine\", \"value\": \"`v" + g_current_version + " (5 Pilar Institusional)`\", \"inline\": true}," +
                           "{\"name\": \"🎯 Target Cuan Harian\", \"value\": \"`+$" + DoubleToString(target_usd, 2) + " (15% Wallet)`\", \"inline\": true}," +
                           "{\"name\": \"🛡️ Max Loss Harian\", \"value\": \"`-$" + DoubleToString(loss_usd, 2) + " (7% Wallet)`\", \"inline\": true}," +
                           "{\"name\": \"⚡ Tri-Layer Sweet Spot\", \"value\": \"`Max 3 Posisi (Kunci 1 Arah Aktif)`\", \"inline\": true}," +
                           "{\"name\": \"📈 Auto-Lot Mode\", \"value\": \"`$" + DoubleToString(g_balance_step, 0) + " = " + DoubleToString(g_lot_step, 2) + " Lot` (Lot: **" + DoubleToString(current_lot, 2) + "**)\", \"inline\": true}," +
                           "{\"name\": \"🛡️ Dynamic ATR Guard\", \"value\": \"`SL/TP Adaptif + Anti-Rollover 23:50-01:10`\", \"inline\": true}";

   SendDiscordEmbed("⚡ XAUUSD Sovereign Scalper Aktif (v4.50)! 🚀", 
                    "5 Pilar Institusional Aktif: Dynamic ATR Volatility, Multi-Stage TP, Directional Lock, Anti-Rollover Guard!", 
                    0x3498DB, startup_fields, false);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handle_ema5_m1);
   IndicatorRelease(handle_ema13_m1);
   IndicatorRelease(handle_stoch_m1);
   IndicatorRelease(handle_bb_m1);
   IndicatorRelease(handle_atr_m1);
   Comment("");
}

//+------------------------------------------------------------------+
//| ON-CHART DASHBOARD SOVEREIGN SCALPER                             |
//+------------------------------------------------------------------+
void DisplayAIDashboard(double ema5, double ema13, double stoch_k, double stoch_d, double bb_up, double bb_low, string signal_status, int dyn_sl, int dyn_tp)
{
   long current_spread = m_symbol.Spread();
   string spread_status = (current_spread <= g_max_spread) ? "[AMAN ✅]" : "[TERLALU TINGGI 🚫]";
   if(IsRolloverTime()) spread_status = "[ROLLOVER PAUSE ⏸️]";
   
   double cur_bal = m_account.Balance();
   if(cur_bal <= 0) cur_bal = m_account.Equity();

   double dynamic_target_usd = cur_bal * (g_daily_target_pct / 100.0);
   double dynamic_max_loss_usd = cur_bal * (g_daily_max_loss_pct / 100.0);
   double daily_pl = GetDailyProfitLoss();
   double lot = CalculateLotSize(dyn_sl);

   int active_orders = 0;
   int buy_orders = 0;
   int sell_orders = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            active_orders++;
            if(m_position.PositionType() == POSITION_TYPE_BUY) buy_orders++;
            else if(m_position.PositionType() == POSITION_TYPE_SELL) sell_orders++;
         }
      }
   }

   string dir_status = "NETRAL (Siap BUY / SELL)";
   if(buy_orders > 0) dir_status = StringFormat("BUY ONLY LOCKED 🟢 (%d/3 Layer)", buy_orders);
   else if(sell_orders > 0) dir_status = StringFormat("SELL ONLY LOCKED 🔴 (%d/3 Layer)", sell_orders);

   string info = "=========================================================\n";
   info += "       ⚡ XAUUSD SOVEREIGN SCALPER v" + g_current_version + " (INSTITUSIONAL)    \n";
   info += "=========================================================\n";
   info += StringFormat(" 💰 Balance / Equity : $%.2f / $%.2f\n", m_account.Balance(), m_account.Equity());
   info += StringFormat(" 📈 Auto-Lot Mode    : %.2f Lot ($%.0f = %.2f Lot)\n", lot, g_balance_step, g_lot_step);
   info += StringFormat(" ⚡ Posisi Aktif     : %d / %d Posisi (Sweet Spot)\n", active_orders, g_max_open_pos);
   info += StringFormat(" 🔒 Direction Lock   : %s\n", dir_status);
   info += "---------------------------------------------------------\n";
   info += " [M1 DYNAMIC VOLATILITY & PRICE ACTION]\n";
   info += StringFormat("  📈 M1 Momentum     : EMA5 (%.2f) vs EMA13 (%.2f) -> %s\n", ema5, ema13, (ema5 > ema13) ? "BULLISH 🟢" : "BEARISH 🔴");
   info += StringFormat("  ⚡ Fast Stoch (5,3): K=%.1f | D=%.1f (%s)\n", stoch_k, stoch_d, (stoch_k < 25) ? "OVERSOLD 🟢" : (stoch_k > 75) ? "OVERBOUGHT 🔴" : "NEUTRAL ⚪");
   info += StringFormat("  🛡️ Dynamic ATR SL/TP: SL -%d Pips | TP +%d Pips\n", dyn_sl / 10, dyn_tp / 10);
   info += StringFormat("  🎯 Status Radar    : %s\n", signal_status);
   info += "---------------------------------------------------------\n";
   info += StringFormat(" 🛡️ Spread Gold      : %d pts (Max: %d pts) %s\n", current_spread, g_max_spread, spread_status);
   info += StringFormat(" 🏆 Profit Hari Ini  : %s$%.2f\n", (daily_pl >= 0) ? "+" : "-", MathAbs(daily_pl));
   info += StringFormat(" 🎯 Target 15%% Cuan  : +$%.2f (Kunci Profit)\n", dynamic_target_usd);
   info += StringFormat(" 🛡️ Max Loss 7%% Rugi : -$%.2f (Rem Pengaman)\n", dynamic_max_loss_usd);
   info += " 📡 Discord Webhook  : TERHUBUNG (Multi-Stage Notifications) ✅\n";
   info += "=========================================================\n";

   Comment(info);
}

//+------------------------------------------------------------------+
//| MANAJEMEN POSISI: MULTI-STAGE TP, FAST BE & TRAILING             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   double point = m_symbol.Point();

   int active_buy_count = 0;
   int active_sell_count = 0;
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      if(m_position.SelectByIndex(p))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            if(m_position.PositionType() == POSITION_TYPE_BUY) active_buy_count++;
            else if(m_position.PositionType() == POSITION_TYPE_SELL) active_sell_count++;
         }
      }
   }

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

         // Multi-Stage TP: Jika ada 3 posisi, tutup layer kedua/ketiga di +12 pips (120 pts)
         if(active_buy_count >= 2 && profit_points >= 120)
         {
            // Amankan cuan cepat layer 2 & 3
            if(StringFind(m_position.Comment(), "Layer_2") != -1 || StringFind(m_position.Comment(), "Layer_3") != -1)
            {
               m_trade.PositionClose(ticket);
               continue;
            }
         }

         // Fast Break-Even (+1.5 pips saat profit +8 pips)
         if(InpUseBreakEven && profit_points >= InpBETriggerPoints)
         {
            double be_sl = m_symbol.NormalizePrice(open_price + InpBEProfitPoints * point);
            if(current_sl < be_sl)
            {
               m_trade.PositionModify(ticket, be_sl, current_tp);
            }
         }

         // Aggressive Scalping Trailing Stop
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

         // Multi-Stage TP: Jika ada 3 posisi, tutup layer kedua/ketiga di +12 pips (120 pts)
         if(active_sell_count >= 2 && profit_points >= 120)
         {
            if(StringFind(m_position.Comment(), "Layer_2") != -1 || StringFind(m_position.Comment(), "Layer_3") != -1)
            {
               m_trade.PositionClose(ticket);
               continue;
            }
         }

         // Fast Break-Even (+1.5 pips saat profit +8 pips)
         if(InpUseBreakEven && profit_points >= InpBETriggerPoints)
         {
            double be_sl = m_symbol.NormalizePrice(open_price - InpBEProfitPoints * point);
            if(current_sl == 0 || current_sl > be_sl)
            {
               m_trade.PositionModify(ticket, be_sl, current_tp);
            }
         }

         // Aggressive Scalping Trailing Stop
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
//| VALIDASI JARAK MINIMAL ANTAR LAYER                               |
//+------------------------------------------------------------------+
bool IsLayerDistanceValid(ENUM_ORDER_TYPE order_type, double entry_price)
{
   double point = m_symbol.Point();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
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
//| BUKA POSISI SOVEREIGN SNIPER                                     |
//+------------------------------------------------------------------+
void ExecuteSovereignScalp(ENUM_ORDER_TYPE order_type, string trigger_source, int current_active_count, int dyn_sl_pts, int dyn_tp_pts)
{
   double point = m_symbol.Point();
   double lot   = CalculateLotSize(dyn_sl_pts);
   if(lot <= 0) return;

   int current_spread = (int)m_symbol.Spread();
   string comment_label = StringFormat("%s_Layer_%d", InpTradeComment, current_active_count + 1);

   if(order_type == ORDER_TYPE_BUY)
   {
      double ask = m_symbol.Ask();
      if(!IsLayerDistanceValid(ORDER_TYPE_BUY, ask)) return;

      double sl  = (dyn_sl_pts > 0) ? (ask - dyn_sl_pts * point) : 0;
      double tp  = (dyn_tp_pts > 0) ? (ask + dyn_tp_pts * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Buy(lot, _Symbol, ask, sl, tp, comment_label))
      {
         Print("🚀 [SOVEREIGN BUY EXECUTED - Layer ", current_active_count + 1, "/3] Trigger: ", trigger_source, " | Lot: ", lot, " | Price: ", ask);
         NotifyAITrade("BUY", ask, lot, sl, tp, m_trade.ResultOrder(), trigger_source, current_spread, current_active_count + 1, dyn_sl_pts, dyn_tp_pts);
         last_trade_time = TimeCurrent();
      }
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      double bid = m_symbol.Bid();
      if(!IsLayerDistanceValid(ORDER_TYPE_SELL, bid)) return;

      double sl  = (dyn_sl_pts > 0) ? (bid + dyn_sl_pts * point) : 0;
      double tp  = (dyn_tp_pts > 0) ? (bid - dyn_tp_pts * point) : 0;
      sl = m_symbol.NormalizePrice(sl);
      tp = m_symbol.NormalizePrice(tp);

      if(m_trade.Sell(lot, _Symbol, bid, sl, tp, comment_label))
      {
         Print("🚀 [SOVEREIGN SELL EXECUTED - Layer ", current_active_count + 1, "/3] Trigger: ", trigger_source, " | Lot: ", lot, " | Price: ", bid);
         NotifyAITrade("SELL", bid, lot, sl, tp, m_trade.ResultOrder(), trigger_source, current_spread, current_active_count + 1, dyn_sl_pts, dyn_tp_pts);
         last_trade_time = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| ON TICK EXECUTION (SOVEREIGN INSTITUTIONAL ENGINE)               |
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

   // 2. Eksekusi Proteksi Posisi (Multi-Stage TP, Fast BE, Trailing Stop)
   ManageOpenPositions();

   // 3. Double-Check Deteksi Posisi Tertutup
   CheckPositionClosures();

   // 4. Hitung Dynamic ATR SL & TP
   int dyn_sl_pts = g_sl_points;
   int dyn_tp_pts = g_tp_points;
   CalculateDynamicSLTP(dyn_sl_pts, dyn_tp_pts);

   // 5. Ambil Data Candlestick M1 Terkini (Anatomi Price Action)
   MqlRates rates_m1[];
   ArraySetAsSeries(rates_m1, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates_m1) < 5) return;

   // 6. Ambil Buffer Indikator M1 Fast
   double ema5_buf[], ema13_buf[], stoch_k_buf[], stoch_d_buf[], bb_up_buf[], bb_low_buf[];
   ArraySetAsSeries(ema5_buf, true);
   ArraySetAsSeries(ema13_buf, true);
   ArraySetAsSeries(stoch_k_buf, true);
   ArraySetAsSeries(stoch_d_buf, true);
   ArraySetAsSeries(bb_up_buf, true);
   ArraySetAsSeries(bb_low_buf, true);

   if(CopyBuffer(handle_ema5_m1, 0, 0, 3, ema5_buf) <= 0) return;
   if(CopyBuffer(handle_ema13_m1, 0, 0, 3, ema13_buf) <= 0) return;
   if(CopyBuffer(handle_stoch_m1, 0, 0, 3, stoch_k_buf) <= 0) return;
   if(CopyBuffer(handle_stoch_m1, 1, 0, 3, stoch_d_buf) <= 0) return;
   if(CopyBuffer(handle_bb_m1, 1, 0, 3, bb_up_buf) <= 0) return;
   if(CopyBuffer(handle_bb_m1, 2, 0, 3, bb_low_buf) <= 0) return;

   double ema5_curr    = ema5_buf[0];
   double ema13_curr   = ema13_buf[0];
   double stoch_k      = stoch_k_buf[0];
   double stoch_d      = stoch_d_buf[0];
   double prev_stoch_k = stoch_k_buf[1];
   double prev_stoch_d = stoch_d_buf[1];
   double bb_up        = bb_up_buf[0];
   double bb_low       = bb_low_buf[0];

   // 7. Analisis Anatomi Bar 1 yang Resmi Tertutup (Confirmed Anti-Repaint Wick)
   double bar1_open  = rates_m1[1].open;
   double bar1_high  = rates_m1[1].high;
   double bar1_low   = rates_m1[1].low;
   double bar1_close = rates_m1[1].close;
   double bar1_range = bar1_high - bar1_low;

   double lower_wick = MathMin(bar1_open, bar1_close) - bar1_low;
   double upper_wick = bar1_high - MathMax(bar1_open, bar1_close);

   bool is_bullish_pinbar = (bar1_range > 0) && (lower_wick >= 0.45 * bar1_range) && (bar1_close > bar1_low);
   bool is_bearish_pinbar = (bar1_range > 0) && (upper_wick >= 0.45 * bar1_range) && (bar1_close < bar1_high);
   bool is_bullish_engulf = (bar1_close > rates_m1[2].high) && (bar1_close > bar1_open);
   bool is_bearish_engulf = (bar1_close < rates_m1[2].low) && (bar1_close < bar1_open);

   // 8. Cek Posisi Aktif & Directional Lock
   int active_orders = 0;
   int active_buy_count = 0;
   int active_sell_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
         {
            active_orders++;
            if(m_position.PositionType() == POSITION_TYPE_BUY) active_buy_count++;
            else if(m_position.PositionType() == POSITION_TYPE_SELL) active_sell_count++;
         }
      }
   }

   // 9. Sinyal Price Action & Micro BOS Instan
   bool buy_signal = false;
   bool sell_signal = false;
   string trigger_reason = "";

   // --- SKENARIO A: WICK REJECTION SNIPER ---
   if((bar1_low <= bb_low || rates_m1[0].low <= bb_low) && (is_bullish_pinbar || is_bullish_engulf) && (stoch_k < 35 || (prev_stoch_k < 25 && stoch_k > prev_stoch_k)))
   {
      buy_signal = true;
      trigger_reason = "M1 Wick Rejection di Lower BB (Bottom Sniper)";
   }
   else if((bar1_high >= bb_up || rates_m1[0].high >= bb_up) && (is_bearish_pinbar || is_bearish_engulf) && (stoch_k > 65 || (prev_stoch_k > 75 && stoch_k < prev_stoch_k)))
   {
      sell_signal = true;
      trigger_reason = "M1 Wick Rejection di Upper BB (Top Sniper)";
   }

   // --- SKENARIO B: MOMENTUM IMPULSE BREAKOUT ---
   if(!buy_signal && !sell_signal)
   {
      double highest_3bars = MathMax(rates_m1[1].high, MathMax(rates_m1[2].high, rates_m1[3].high));
      if(ema5_curr > ema13_curr && ema5_buf[1] <= ema13_buf[1] && rates_m1[0].close >= highest_3bars && stoch_k > stoch_d)
      {
         buy_signal = true;
         trigger_reason = "M1 EMA 5/13 Golden Cross + Momentum Breakout";
      }

      double lowest_3bars = MathMin(rates_m1[1].low, MathMin(rates_m1[2].low, rates_m1[3].low));
      if(ema5_curr < ema13_curr && ema5_buf[1] >= ema13_buf[1] && rates_m1[0].close <= lowest_3bars && stoch_k < stoch_d)
      {
         sell_signal = true;
         trigger_reason = "M1 EMA 5/13 Death Cross + Momentum Breakdown";
      }
   }

   // 10. Update Dashboard On-Chart
   string dashboard_status = "STANDBY HUNTING M1...";
   if(IsRolloverTime()) dashboard_status = "⏸️ ROLLOVER TIME PAUSE (23:50-01:10)";
   else if(buy_signal) dashboard_status = "🟢 SOVEREIGN BUY DETECTED! (" + trigger_reason + ")";
   else if(sell_signal) dashboard_status = "🔴 SOVEREIGN SELL DETECTED! (" + trigger_reason + ")";
   DisplayAIDashboard(ema5_curr, ema13_curr, stoch_k, stoch_d, bb_up, bb_low, dashboard_status, dyn_sl_pts, dyn_tp_pts);

   // 11. Cek Proteksi Daily Target (15%) & Max Loss (7%) dari Wallet
   if(g_use_daily_guard)
   {
      double cur_bal = m_account.Balance();
      if(cur_bal <= 0) cur_bal = m_account.Equity();

      double dynamic_target_usd = cur_bal * (g_daily_target_pct / 100.0);
      double dynamic_max_loss_usd = cur_bal * (g_daily_max_loss_pct / 100.0);
      double daily_pl = GetDailyProfitLoss();

      if(daily_pl >= dynamic_target_usd || daily_pl <= -dynamic_max_loss_usd) return;
   }

   // 12. Validasi Rollover Pause, Spread & Maksimal 3 Posisi
   if(IsRolloverTime()) return;
   if(m_symbol.Spread() > g_max_spread) return;
   if(active_orders >= g_max_open_pos) return;

   // 13. Directional Hegemony Guard (Haram Hedging saat Layer Berjalan)
   if(InpUseDirectionalLock)
   {
      if(active_buy_count > 0 && sell_signal) return; // Dilarang SELL jika ada BUY aktif
      if(active_sell_count > 0 && buy_signal) return; // Dilarang BUY jika ada SELL aktif
   }

   // 14. Cooldown Minimal 5 Detik Antar Order
   if(TimeCurrent() - last_trade_time < 5) return;

   // 15. EKSEKUSI SOVEREIGN SNIPER ORDER (Maksimal 3 Layer)
   if(buy_signal)
   {
      ExecuteSovereignScalp(ORDER_TYPE_BUY, trigger_reason, active_orders, dyn_sl_pts, dyn_tp_pts);
   }
   else if(sell_signal)
   {
      ExecuteSovereignScalp(ORDER_TYPE_SELL, trigger_reason, active_orders, dyn_sl_pts, dyn_tp_pts);
   }
}
