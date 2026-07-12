#ifndef ICT_SHADOW_TRADES_MQH
#define ICT_SHADOW_TRADES_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"

#define SHADOW_MAX_TRADES 500

enum ENUM_SHADOW_CLOSE_REASON
{
   SHADOW_OPEN = 0,
   SHADOW_SL = 1,
   SHADOW_TP1 = 2,
   SHADOW_TIMEOUT = 3
};

struct SShadowTrade
{
   bool active;
   datetime openTime;
   datetime closeTime;
   ENUM_TRADE_DIRECTION dir;
   ENUM_SIGNAL_TRIGGER trigger;
   int chainId;
   int causalTag;

   double entry;
   double sl;
   double tp1;
   double tp2;

   bool closed;
   bool win;
   double pnlPoints;
   double rMultiple;
   ENUM_SHADOW_CLOSE_REASON closeReason;

   void Reset()
   {
      active = false;
      openTime = 0;
      closeTime = 0;
      dir = DIR_NONE;
      trigger = TRIGGER_NONE;
      chainId = -1;
      causalTag = -1;
      entry = 0.0;
      sl = 0.0;
      tp1 = 0.0;
      tp2 = 0.0;
      closed = false;
      win = false;
      pnlPoints = 0.0;
      rMultiple = 0.0;
      closeReason = SHADOW_OPEN;
   }
};

SShadowTrade g_shadowTrades[SHADOW_MAX_TRADES];
int g_shadowCount = 0;
int g_shadowWins = 0;
int g_shadowLosses = 0;
double g_shadowNetR = 0.0;

void Shadow_Init()
{
   for(int i = 0; i < SHADOW_MAX_TRADES; i++)
      g_shadowTrades[i].Reset();

   g_shadowCount = 0;
   g_shadowWins = 0;
   g_shadowLosses = 0;
   g_shadowNetR = 0.0;
}

int Shadow_AllocIndex()
{
   for(int i = 0; i < SHADOW_MAX_TRADES; i++)
      if(!g_shadowTrades[i].active) return i;
   return -1;
}

void Shadow_RecordCandidate(const STradeSignal &sig, int chainId, int causalTag)
{
   if(!sig.isValid) return;

   int idx = Shadow_AllocIndex();
   if(idx < 0) return;

   g_shadowTrades[idx].Reset();
   g_shadowTrades[idx].active = true;
   g_shadowTrades[idx].openTime = TimeCurrent();
   g_shadowTrades[idx].dir = (sig.type == SIGNAL_BUY) ? DIR_BULLISH : DIR_BEARISH;
   g_shadowTrades[idx].trigger = sig.trigger;
   g_shadowTrades[idx].chainId = chainId;
   g_shadowTrades[idx].causalTag = causalTag;
   g_shadowTrades[idx].entry = sig.entryPrice;
   g_shadowTrades[idx].sl = sig.slPrice;
   g_shadowTrades[idx].tp1 = sig.tp1Price;
   g_shadowTrades[idx].tp2 = sig.tp2Price;
}

void Shadow_Close(int i, bool win, ENUM_SHADOW_CLOSE_REASON reason, double exitPrice)
{
   if(i < 0 || i >= SHADOW_MAX_TRADES) return;
   if(!g_shadowTrades[i].active || g_shadowTrades[i].closed) return;

   g_shadowTrades[i].closed = true;
   g_shadowTrades[i].active = false;
   g_shadowTrades[i].win = win;
   g_shadowTrades[i].closeReason = reason;
   g_shadowTrades[i].closeTime = TimeCurrent();

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double riskPts = MathAbs(g_shadowTrades[i].entry - g_shadowTrades[i].sl) / point;
   double pnlPts = MathAbs(exitPrice - g_shadowTrades[i].entry) / point;

   if(g_shadowTrades[i].dir == DIR_BEARISH)
      pnlPts = MathAbs(g_shadowTrades[i].entry - exitPrice) / point;

   if(!win) pnlPts = -riskPts;

   g_shadowTrades[i].pnlPoints = pnlPts;
   g_shadowTrades[i].rMultiple = (riskPts > 0.0) ? (pnlPts / riskPts) : 0.0;

   g_shadowCount++;
   g_shadowNetR += g_shadowTrades[i].rMultiple;
   if(win) g_shadowWins++;
   else g_shadowLosses++;
}

void Shadow_Update()
{
   double hi = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double lo = iLow(_Symbol, PERIOD_CURRENT, 1);
   datetime nowBar = iTime(_Symbol, PERIOD_CURRENT, 1);

   int timeoutBars = MathMax(20, InpSM_GlobalTimeout);
   for(int i = 0; i < SHADOW_MAX_TRADES; i++)
   {
      if(!g_shadowTrades[i].active || g_shadowTrades[i].closed) continue;

      bool isBuy = (g_shadowTrades[i].dir == DIR_BULLISH);

      if(isBuy)
      {
         bool slHit = (lo <= g_shadowTrades[i].sl);
         bool tpHit = (hi >= g_shadowTrades[i].tp1);

         if(slHit)
         {
            Shadow_Close(i, false, SHADOW_SL, g_shadowTrades[i].sl);
            continue;
         }
         if(tpHit)
         {
            Shadow_Close(i, true, SHADOW_TP1, g_shadowTrades[i].tp1);
            continue;
         }
      }
      else
      {
         bool slHit = (hi >= g_shadowTrades[i].sl);
         bool tpHit = (lo <= g_shadowTrades[i].tp1);

         if(slHit)
         {
            Shadow_Close(i, false, SHADOW_SL, g_shadowTrades[i].sl);
            continue;
         }
         if(tpHit)
         {
            Shadow_Close(i, true, SHADOW_TP1, g_shadowTrades[i].tp1);
            continue;
         }
      }

      int age = iBarShift(_Symbol, PERIOD_CURRENT, g_shadowTrades[i].openTime, false);
      if(age > timeoutBars)
      {
         Shadow_Close(i, false, SHADOW_TIMEOUT, iClose(_Symbol, PERIOD_CURRENT, 1));
      }
   }
}

double Shadow_WinRate()
{
   int total = g_shadowWins + g_shadowLosses;
   if(total <= 0) return 0.0;
   return 100.0 * (double)g_shadowWins / (double)total;
}

string Shadow_Summary()
{
   string s = "Shadow N=" + IntegerToString(g_shadowWins + g_shadowLosses);
   s += " WR=" + DoubleToString(Shadow_WinRate(), 1) + "%";
   s += " NetR=" + DoubleToString(g_shadowNetR, 2);
   return s;
}

#endif