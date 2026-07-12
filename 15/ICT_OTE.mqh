//+------------------------------------------------------------------+
//|                          ICT_OTE.mqh                              |
//|                 OTE Zones and Range Zone Utilities                |
//|                 "ICT Unified Professional EA v15"                 |
//+------------------------------------------------------------------+
#ifndef ICT_OTE_MQH
#define ICT_OTE_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+
bool InitializeOTE()
{
   g_oteZone.Reset();
   g_rangeInfo.Reset();
   Print("OTE System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: OTE CALCULATION                            |
//+------------------------------------------------------------------+
void CalculateOTEZone()
{
   if(!g_needDetectOTE)
      return;

   if(!InpUseOTE)
   {
      g_oteZone.isValid = false;
      return;
   }

   double swingHigh = 0.0;
   double swingLow = 0.0;
   datetime swingHighTime = 0;
   datetime swingLowTime = 0;

   if(g_lastExternalHigh > 0 && g_lastExternalLow > 0)
   {
      swingHigh = g_lastExternalHigh;
      swingLow = g_lastExternalLow;
      swingHighTime = g_lastExternalHighTime;
      swingLowTime = g_lastExternalLowTime;
   }
   else
   {
      int highBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 0);
      int lowBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 0);

      swingHigh = iHigh(_Symbol, PERIOD_CURRENT, highBar);
      swingLow = iLow(_Symbol, PERIOD_CURRENT, lowBar);
      swingHighTime = iTime(_Symbol, PERIOD_CURRENT, highBar);
      swingLowTime = iTime(_Symbol, PERIOD_CURRENT, lowBar);
   }

   if(swingHigh <= 0 || swingLow <= 0 || swingHigh <= swingLow)
   {
      g_oteZone.isValid = false;
      return;
   }

   double range = swingHigh - swingLow;
   double atr = GetATR();
   if(atr > 0 && range < atr * 0.1)
   {
      g_oteZone.isValid = false;
      return;
   }

   g_oteZone.swingHigh = swingHigh;
   g_oteZone.swingLow = swingLow;
   g_oteZone.time = MathMax(swingHighTime, swingLowTime);

   if(g_entryZone.isValid)
      g_oteZone.isBullish = (g_entryZone.direction == DIR_BULLISH);
   else
      g_oteZone.isBullish = g_isBullishActive;

   if(g_oteZone.isBullish)
   {
      g_oteZone.fib618 = swingHigh - range * (InpOTE_Fib618 / 100.0);
      g_oteZone.fib70  = swingHigh - range * (InpOTE_Fib705 / 100.0);
      g_oteZone.fib79  = swingHigh - range * (InpOTE_Fib79 / 100.0);
   }
   else
   {
      g_oteZone.fib618 = swingLow + range * (InpOTE_Fib618 / 100.0);
      g_oteZone.fib70  = swingLow + range * (InpOTE_Fib705 / 100.0);
      g_oteZone.fib79  = swingLow + range * (InpOTE_Fib79 / 100.0);
   }

   g_oteZone.isValid = true;
   DrawCurrentOTEZone();
}

void DrawCurrentOTEZone()
{
   if(!g_oteZone.isValid)
      return;

   if(!ShouldDrawNarrativeElement(NZ_OTE_ZONE))
      return;

   DeleteObject(g_oteZone.objName);

   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   DrawOTEZone(g_oteZone.objName,
               g_oteZone.time,
               g_oteZone.fib618,
               g_oteZone.fib70,
               g_oteZone.fib79,
               currentTime,
               g_oteZone.isBullish);

   string lbl = BuildElementLabel(LAYER_CTF, g_oteZone.isBullish, "OTE Zone");
   string lblName = g_oteZone.objName + "_syslbl";
   DrawText(lblName, g_oteZone.time, g_oteZone.fib70, lbl,
            InpOTEZoneColor, 8, ANCHOR_LEFT, "Arial Bold");
}

bool IsPriceInOTEZone()
{
   if(!g_oteZone.isValid)
      return false;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double zoneTop = g_oteZone.ZoneTop();
   double zoneBottom = g_oteZone.ZoneBottom();

   return (price >= zoneBottom && price <= zoneTop);
}

double GetDistanceToOTE_Optimal()
{
   if(!g_oteZone.isValid)
      return DBL_MAX;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double optimal = g_oteZone.OptimalEntry();
   return MathAbs(price - optimal);
}

//+------------------------------------------------------------------+
//|              SECTION 3: RANGE ZONE CALCULATION                     |
//+------------------------------------------------------------------+
void UpdateRangeInfo()
{
   int rangeLookback = 50;

   int highBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, rangeLookback, 0);
   int lowBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, rangeLookback, 0);

   g_rangeInfo.high = iHigh(_Symbol, PERIOD_CURRENT, highBar);
   g_rangeInfo.low = iLow(_Symbol, PERIOD_CURRENT, lowBar);

   if(g_rangeInfo.high <= g_rangeInfo.low)
   {
      g_rangeInfo.currentZone = ZONE_NONE;
      return;
   }

   double range = g_rangeInfo.high - g_rangeInfo.low;
   double premiumLevelPct = 70.0;
   double discountLevelPct = 30.0;

   g_rangeInfo.equilibrium = (g_rangeInfo.high + g_rangeInfo.low) * 0.5;
   g_rangeInfo.premiumLevel = g_rangeInfo.low + range * (premiumLevelPct / 100.0);
   g_rangeInfo.discountLevel = g_rangeInfo.low + range * (discountLevelPct / 100.0);
   g_rangeInfo.rangeStart = iTime(_Symbol, PERIOD_CURRENT, MathMax(highBar, lowBar));

   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   g_rangeInfo.currentZone = CalculateZone(currentPrice, g_rangeInfo.high, g_rangeInfo.low);
}

bool IsZoneAligned(bool isBuy)
{
   UpdateRangeInfo();

   if(isBuy)
      return (g_rangeInfo.currentZone == ZONE_DISCOUNT);

   return (g_rangeInfo.currentZone == ZONE_PREMIUM);
}

int GetZoneScoreBonus()
{
   UpdateRangeInfo();

   switch(g_rangeInfo.currentZone)
   {
      case ZONE_PREMIUM:
         return (g_currentDirection == DIR_BEARISH) ? 6 : 0;
      case ZONE_DISCOUNT:
         return (g_currentDirection == DIR_BULLISH) ? 6 : 0;
      default:
         return 0;
   }
}

//+------------------------------------------------------------------+
//|              SECTION 4: OTE MANAGEMENT                             |
//+------------------------------------------------------------------+
void UpdateOTESystem()
{
   // Keep range info current for any zone consumers.
   UpdateRangeInfo();

   if(!g_needDetectOTE)
      return;

   static datetime lastOTECalcBar = 0;
   datetime bar0 = iTime(_Symbol, PERIOD_CURRENT, 0);

   if(!g_oteZone.isValid || bar0 != lastOTECalcBar)
   {
      CalculateOTEZone();
      lastOTECalcBar = bar0;
   }

   if(g_oteZone.isValid && ObjectFind(0, g_oteZone.objName) >= 0)
      ObjectSetInteger(0, g_oteZone.objName, OBJPROP_TIME, 1, bar0);
}

double GetOTEEntryPrice()
{
   if(!g_oteZone.isValid)
      return 0.0;
   return g_oteZone.OptimalEntry();
}

bool IsAtOptimalEntry(double tolerance)
{
   if(!g_oteZone.isValid)
      return false;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double optimal = g_oteZone.OptimalEntry();
   return (MathAbs(price - optimal) <= tolerance);
}

string GetZoneDescription()
{
   switch(g_rangeInfo.currentZone)
   {
      case ZONE_PREMIUM:     return "PREMIUM (Sell Zone)";
      case ZONE_DISCOUNT:    return "DISCOUNT (Buy Zone)";
      case ZONE_EQUILIBRIUM: return "EQUILIBRIUM";
      default:               return "Unknown";
   }
}

void DrawRangeLevels()
{
   // Optional helper visualization; not part of narrative element draw gating.
   UpdateRangeInfo();

   if(g_rangeInfo.high <= 0)
      return;

   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double atr = GetATR();
   if(atr <= 0) atr = _Point * 50;

   string premName = g_prefix + "Range_Premium";
   DrawTrendLine(premName, g_rangeInfo.rangeStart, g_rangeInfo.premiumLevel,
                 currentTime, g_rangeInfo.premiumLevel, g_bearColorDim, 1, STYLE_DOT, false);

   string eqName = g_prefix + "Range_EQ";
   DrawTrendLine(eqName, g_rangeInfo.rangeStart, g_rangeInfo.equilibrium,
                 currentTime, g_rangeInfo.equilibrium, g_neutralColor, 1, STYLE_DOT, false);

   string discName = g_prefix + "Range_Discount";
   DrawTrendLine(discName, g_rangeInfo.rangeStart, g_rangeInfo.discountLevel,
                 currentTime, g_rangeInfo.discountLevel, g_bullColorDim, 1, STYLE_DOT, false);

   DrawText(premName + "_lbl", g_rangeInfo.rangeStart, g_rangeInfo.premiumLevel + atr * 0.05,
            "Premium", g_bearColorDim, 7, ANCHOR_LEFT);

   DrawText(eqName + "_lbl", g_rangeInfo.rangeStart, g_rangeInfo.equilibrium + atr * 0.05,
            "EQ", g_neutralColor, 7, ANCHOR_LEFT);

   DrawText(discName + "_lbl", g_rangeInfo.rangeStart, g_rangeInfo.discountLevel + atr * 0.05,
            "Discount", g_bullColorDim, 7, ANCHOR_LEFT);
}

#endif // ICT_OTE_MQH