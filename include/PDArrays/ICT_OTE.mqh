//+------------------------------------------------------------------+
//|                          ICT_OTE.mqh                              |
//|          Optimal Trade Entry Zones & Premium/Discount              |
//|                    ICT Unified Professional EA                     |
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

//+------------------------------------------------------------------+
//| Initialize OTE System                                             |
//+------------------------------------------------------------------+
bool InitializeOTE()
{
   g_oteZone.Reset();
   
   // Initialize range info
   g_rangeInfo.Reset();
   
   Print("OTE System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: OTE CALCULATION                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate OTE Zone                                                |
//+------------------------------------------------------------------+
void CalculateOTEZone()
{
   if(!InpUseOTE)
      return;
   
   // Find swing high and low for OTE calculation
   double swingHigh = 0;
   double swingLow = 0;
   datetime swingHighTime = 0;
   datetime swingLowTime = 0;
   
   // Use external swings if available
   if(g_lastExternalHigh > 0 && g_lastExternalLow > 0)
   {
      swingHigh = g_lastExternalHigh;
      swingLow = g_lastExternalLow;
      swingHighTime = g_lastExternalHighTime;
      swingLowTime = g_lastExternalLowTime;
   }
   else
   {
      // Use recent range
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
   

   
   // Calculate fib levels
   g_oteZone.swingHigh = swingHigh;
   g_oteZone.swingLow = swingLow;
   g_oteZone.time = MathMax(swingHighTime, swingLowTime);
   
   // For bullish OTE: retracement DOWN from high
   // For bearish OTE: retracement UP from low
   
   // We need to determine which direction we're looking for
   // Based on current trend/entry zone direction
   
   if(g_entryZone.isValid)
   {
      g_oteZone.isBullish = (g_entryZone.direction == DIR_BULLISH);
   }
   else
   {
      g_oteZone.isBullish = g_isBullishActive;
   }
   
   if(g_oteZone.isBullish)
   {
      // Bullish OTE: 61.8% - 79% retracement from high
      g_oteZone.fib618 = swingHigh - range * (InpOTE_Fib618 / 100.0);
      g_oteZone.fib70 = swingHigh - range * (InpOTE_Fib705 / 100.0);
      g_oteZone.fib79 = swingHigh - range * (InpOTE_Fib79 / 100.0);
   }
   else
   {
      // Bearish OTE: 61.8% - 79% retracement from low
      g_oteZone.fib618 = swingLow + range * (InpOTE_Fib618 / 100.0);
      g_oteZone.fib70 = swingLow + range * (InpOTE_Fib705 / 100.0);
      g_oteZone.fib79 = swingLow + range * (InpOTE_Fib79 / 100.0);
   }
   
   g_oteZone.isValid = true;
   
   // Draw OTE zone
   if(InpShowOrderBlocks)
      DrawCurrentOTEZone();
}

//+------------------------------------------------------------------+
//| Draw Current OTE Zone                                             |
//+------------------------------------------------------------------+
void DrawCurrentOTEZone()
{
   if(!g_oteZone.isValid) return;
   if(!ShouldDrawPDElement(PD_OTE_ZONE)) return;

   DeleteObject(g_oteZone.objName);
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   DrawOTEZone(g_oteZone.objName,
               g_oteZone.time,
               g_oteZone.fib618,
               g_oteZone.fib70,
               g_oteZone.fib79,
               currentTime,
               g_oteZone.isBullish);

   // Add system-aware label to OTE zone
   string lbl = BuildElementLabel(LAYER_CTF, g_oteZone.isBullish, "OTE Zone");
   string lblName = g_oteZone.objName + "_syslbl";
   DrawText(lblName, g_oteZone.time, g_oteZone.fib70, lbl,
            InpOTEZoneColor, 8, ANCHOR_LEFT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Check if Price in OTE Zone                                        |
//+------------------------------------------------------------------+
bool IsPriceInOTEZone()
{
   if(!g_oteZone.isValid)
      return false;
   
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   double zoneTop = g_oteZone.ZoneTop();
   double zoneBottom = g_oteZone.ZoneBottom();
   
   return (price >= zoneBottom && price <= zoneTop);
}

//+------------------------------------------------------------------+
//| Get Distance to OTE Optimal                                       |
//+------------------------------------------------------------------+
double GetDistanceToOTE_Optimal()
{
   if(!g_oteZone.isValid)
      return DBL_MAX;
   
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double optimal = g_oteZone.OptimalEntry();
   
   return MathAbs(price - optimal);
}

//+------------------------------------------------------------------+
//|              SECTION 3: PREMIUM/DISCOUNT                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Range Info (Premium/Discount)                              |
//+------------------------------------------------------------------+
void UpdateRangeInfo()
{
   if(!InpUsePremiumDiscount)
   {
      g_rangeInfo.currentZone = ZONE_NONE;
      return;
   }
   
   // Find range high and low
   int highBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpPD_RangeLookback, 0);
   int lowBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, InpPD_RangeLookback, 0);
   
   g_rangeInfo.high = iHigh(_Symbol, PERIOD_CURRENT, highBar);
   g_rangeInfo.low = iLow(_Symbol, PERIOD_CURRENT, lowBar);
   
   if(g_rangeInfo.high <= g_rangeInfo.low)
      return;
   
   double range = g_rangeInfo.high - g_rangeInfo.low;
   
   g_rangeInfo.equilibrium = (g_rangeInfo.high + g_rangeInfo.low) / 2.0;
   g_rangeInfo.premiumLevel = g_rangeInfo.low + range * (InpPremiumLevel / 100.0);
   g_rangeInfo.discountLevel = g_rangeInfo.low + range * (InpDiscountLevel / 100.0);
   g_rangeInfo.rangeStart = iTime(_Symbol, PERIOD_CURRENT, MathMax(highBar, lowBar));
   
   // Determine current zone
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   g_rangeInfo.currentZone = CalculateZone(currentPrice, g_rangeInfo.high, g_rangeInfo.low);
}

//+------------------------------------------------------------------+
//| Check Zone Alignment                                              |
//+------------------------------------------------------------------+
bool IsZoneAligned(bool isBuy)
{
   if(!InpUsePremiumDiscount)
      return true;
   
   UpdateRangeInfo();
   
   if(isBuy)
   {
      // Buy in discount zone
      return (g_rangeInfo.currentZone == ZONE_DISCOUNT);
   }
   else
   {
      // Sell in premium zone
      return (g_rangeInfo.currentZone == ZONE_PREMIUM);
   }
}

//+------------------------------------------------------------------+
//| Get Zone Score Bonus                                              |
//+------------------------------------------------------------------+
int GetZoneScoreBonus()
{
   if(!InpUsePremiumDiscount)
      return 0;
   
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

//+------------------------------------------------------------------+
//| Update OTE System                                                 |
//+------------------------------------------------------------------+
void UpdateOTESystem()
{
   UpdateRangeInfo();

   // Recalculate once per new bar or if invalid
   static datetime lastOTECalcBar = 0;
   datetime bar0 = iTime(_Symbol, PERIOD_CURRENT, 0);

   if(!g_oteZone.isValid || bar0 != lastOTECalcBar)
   {
      CalculateOTEZone();
      lastOTECalcBar = bar0;
   }

   if(g_oteZone.isValid && ObjectFind(0, g_oteZone.objName) >= 0)
   {
      ObjectSetInteger(0, g_oteZone.objName, OBJPROP_TIME, 1, bar0);
   }
}

//+------------------------------------------------------------------+
//| Get OTE Entry Price                                               |
//+------------------------------------------------------------------+
double GetOTEEntryPrice()
{
   if(!g_oteZone.isValid)
      return 0;
   
   return g_oteZone.OptimalEntry();
}

//+------------------------------------------------------------------+
//| Check if at Optimal Entry                                         |
//+------------------------------------------------------------------+
bool IsAtOptimalEntry(double tolerance)
{
   if(!g_oteZone.isValid)
      return false;
   
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double optimal = g_oteZone.OptimalEntry();
   
   return (MathAbs(price - optimal) <= tolerance);
}

//+------------------------------------------------------------------+
//| Get Zone Description                                              |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Draw Range Levels                                                 |
//+------------------------------------------------------------------+
void DrawRangeLevels()
{
   if(!InpUsePremiumDiscount)
      return;
   
   UpdateRangeInfo();
   
   if(g_rangeInfo.high <= 0)
      return;
   
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double atr = GetATR();
   
   // Premium line
   string premName = g_prefix + "Range_Premium";
   DrawTrendLine(premName, g_rangeInfo.rangeStart, g_rangeInfo.premiumLevel,
                 currentTime, g_rangeInfo.premiumLevel, g_bearColorDim, 1, STYLE_DOT, false);
   
   // Equilibrium line
   string eqName = g_prefix + "Range_EQ";
   DrawTrendLine(eqName, g_rangeInfo.rangeStart, g_rangeInfo.equilibrium,
                 currentTime, g_rangeInfo.equilibrium, g_neutralColor, 1, STYLE_DOT, false);
   
   // Discount line
   string discName = g_prefix + "Range_Discount";
   DrawTrendLine(discName, g_rangeInfo.rangeStart, g_rangeInfo.discountLevel,
                 currentTime, g_rangeInfo.discountLevel, g_bullColorDim, 1, STYLE_DOT, false);
   
   // Labels
   DrawText(premName + "_lbl", g_rangeInfo.rangeStart, g_rangeInfo.premiumLevel + atr * 0.05,
            "Premium", g_bearColorDim, 7, ANCHOR_LEFT);
   
   DrawText(eqName + "_lbl", g_rangeInfo.rangeStart, g_rangeInfo.equilibrium + atr * 0.05,
            "EQ", g_neutralColor, 7, ANCHOR_LEFT);
   
   DrawText(discName + "_lbl", g_rangeInfo.rangeStart, g_rangeInfo.discountLevel + atr * 0.05,
            "Discount", g_bullColorDim, 7, ANCHOR_LEFT);
}

#endif // ICT_OTE_MQH