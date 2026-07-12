//+------------------------------------------------------------------+
//|                        ICT_Utilities.mqh                          |
//|                    Utility and Helper Functions                    |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_UTILITIES_MQH
#define ICT_UTILITIES_MQH

#include "ICT_Types.mqh"
#include "ICT_Config.mqh"
#include "ICT_Globals.mqh"


//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION FUNCTIONS                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Validate Input Parameters                                         |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
// Validate timeframes
   if(InpHTF_Timeframe <= Period())
     {
      Print("Warning: HTF should be higher than current timeframe");
     }

   if(InpLTF_Timeframe >= Period())
     {
      Print("Warning: LTF should be lower than current timeframe");
     }

// Validate risk parameters
   if(InpRiskPercent <= 0 || InpRiskPercent > 10)
     {
      Print("Error: Risk percent must be between 0 and 10");
      return false;
     }

// Validate multipliers
   if(InpDisplacementMultiplier <= 0)
     {
      Print("Error: Displacement multiplier must be positive");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Initialize Core Systems                                           |
//+------------------------------------------------------------------+
bool InitializeCore()
  {
// Reset all globals
   ResetAllGlobals();

// Initialize global arrays
   InitializeGlobalArrays();

// Set score threshold based on entry style
//switch(InpEntryStyle)
// {
// case STYLE_AGGRESSIVE:

//    break;
// case STYLE_MODERATE:

//   break;
// case STYLE_CONSERVATIVE:

//   break;
//  }

   g_isInitialized = true;
   return true;
  }


//+------------------------------------------------------------------+
//| ShouldDrawNarrativeElement                                        |
//+------------------------------------------------------------------+
bool SM_IsElementLoaded(ENUM_SM_ELEMENT e);
bool ShouldDrawNarrativeElement(ENUM_NARRATIVE_ZONE_TYPE zoneType)
{
   if(!InpSM_ShowLoadedElementsOnChart)
      return false;

   ENUM_SM_ELEMENT smElem = NarrativeZoneToSMElement(zoneType);
   if(smElem == SM_ELEM_NONE)
      return false;

   return SM_IsElementLoaded(smElem);
}
//+------------------------------------------------------------------+
//| Initialize Indicators                                             |
//+------------------------------------------------------------------+
bool InitializeIndicators()
  {
// Main ATR
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 50);
   if(g_atrHandle == INVALID_HANDLE)
     {
      Print("Error: Failed to create CTF ATR indicator");
      return false;
     }

// ── ADD THIS BLOCK ──
// Pre-populate ATR buffer for initial drawing
   int maxAttempts = 10;
   for(int attempt = 0; attempt < maxAttempts; attempt++)
     {
      if(CopyBuffer(g_atrHandle, 0, 0, 10, g_atrBuffer) > 0)
         break;
      Sleep(50);
     }
// ── END ADDED BLOCK ──
// HTF ATR
   if(InpEnableHTF)
     {
      g_htfAtrHandle = iATR(_Symbol, InpHTF_Timeframe, 50);
      if(g_htfAtrHandle == INVALID_HANDLE)
        {
         Print("Warning: Failed to create HTF ATR indicator");
        }
     }

// LTF ATR
   if(InpEnableLTF)
     {
      g_ltfAtrHandle = iATR(_Symbol, InpLTF_Timeframe, 50);
      if(g_ltfAtrHandle == INVALID_HANDLE)
        {
         Print("Warning: Failed to create LTF ATR indicator");
        }
     }

// Setup buffers
   ArraySetAsSeries(g_atrBuffer, true);
   ArraySetAsSeries(g_htfAtrBuffer, true);
   ArraySetAsSeries(g_ltfAtrBuffer, true);

   return true;
  }

//+------------------------------------------------------------------+
//| Deinitialize Indicators                                           |
//+------------------------------------------------------------------+
void DeinitializeIndicators()
  {
   if(g_atrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
     }

   if(g_htfAtrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_htfAtrHandle);
      g_htfAtrHandle = INVALID_HANDLE;
     }

   if(g_ltfAtrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_ltfAtrHandle);
      g_ltfAtrHandle = INVALID_HANDLE;
     }

   if(g_smtHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_smtHandle);
      g_smtHandle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//|              SECTION 2: PRICE DATA FUNCTIONS                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Price Data (Any Timeframe)                                    |
//+------------------------------------------------------------------+
double TF_Open(ENUM_TIMEFRAMES tf, int bar)
  { return iOpen(_Symbol, tf, bar); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double TF_High(ENUM_TIMEFRAMES tf, int bar)
  { return iHigh(_Symbol, tf, bar); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double TF_Low(ENUM_TIMEFRAMES tf, int bar)
  { return iLow(_Symbol, tf, bar); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double TF_Close(ENUM_TIMEFRAMES tf, int bar)
  { return iClose(_Symbol, tf, bar); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime TF_Time(ENUM_TIMEFRAMES tf, int bar)
  { return iTime(_Symbol, tf, bar); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TF_Bars(ENUM_TIMEFRAMES tf)
  { return iBars(_Symbol, tf); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TF_BarShift(ENUM_TIMEFRAMES tf, datetime time)
  { return iBarShift(_Symbol, tf, time, false); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TF_Highest(ENUM_TIMEFRAMES tf, int count, int start)
  { return iHighest(_Symbol, tf, MODE_HIGH, count, start); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TF_Lowest(ENUM_TIMEFRAMES tf, int count, int start)
  { return iLowest(_Symbol, tf, MODE_LOW, count, start); }

//+------------------------------------------------------------------+
//| Get Body Top (Max of Open/Close)                                  |
//+------------------------------------------------------------------+
double BodyTop(ENUM_TIMEFRAMES tf, int bar)
  {
   return MathMax(TF_Open(tf, bar), TF_Close(tf, bar));
  }

//+------------------------------------------------------------------+
//| Get Body Bottom (Min of Open/Close)                               |
//+------------------------------------------------------------------+
double BodyBottom(ENUM_TIMEFRAMES tf, int bar)
  {
   return MathMin(TF_Open(tf, bar), TF_Close(tf, bar));
  }

//+------------------------------------------------------------------+
//| Get Body Size                                                     |
//+------------------------------------------------------------------+
double BodySize(ENUM_TIMEFRAMES tf, int bar)
  {
   return MathAbs(TF_Close(tf, bar) - TF_Open(tf, bar));
  }

//+------------------------------------------------------------------+
//| Get Candle Range                                                  |
//+------------------------------------------------------------------+
double CandleRange(ENUM_TIMEFRAMES tf, int bar)
  {
   return TF_High(tf, bar) - TF_Low(tf, bar);
  }

//+------------------------------------------------------------------+
//| Get Upper Wick Size                                               |
//+------------------------------------------------------------------+
double UpperWick(ENUM_TIMEFRAMES tf, int bar)
  {
   return TF_High(tf, bar) - BodyTop(tf, bar);
  }

//+------------------------------------------------------------------+
//| Get Lower Wick Size                                               |
//+------------------------------------------------------------------+
double LowerWick(ENUM_TIMEFRAMES tf, int bar)
  {
   return BodyBottom(tf, bar) - TF_Low(tf, bar);
  }

//+------------------------------------------------------------------+
//| Check if Bullish Candle                                           |
//+------------------------------------------------------------------+
bool IsBullishCandle(ENUM_TIMEFRAMES tf, int bar)
  {
   return TF_Close(tf, bar) > TF_Open(tf, bar);
  }

//+------------------------------------------------------------------+
//| Check if Bearish Candle                                           |
//+------------------------------------------------------------------+
bool IsBearishCandle(ENUM_TIMEFRAMES tf, int bar)
  {
   return TF_Close(tf, bar) < TF_Open(tf, bar);
  }

//+------------------------------------------------------------------+
//| Check if Institutional Candle (Large Range)                       |
//+------------------------------------------------------------------+
bool IsInstitutionalCandle(ENUM_TIMEFRAMES tf, int bar, double atr)
  {
   if(atr <= 0)
      return false;
   return CandleRange(tf, bar) >= atr * InpOB_InstitutionalMultiple;
  }

//+------------------------------------------------------------------+
//| Check if Displacement Candle                                      |
//+------------------------------------------------------------------+
bool IsDisplacementCandle(ENUM_TIMEFRAMES tf, int bar, double atr)
  {
   if(atr <= 0)
      return false;

   double range = CandleRange(tf, bar);
   if(range < atr * InpDisplacementMultiplier)
      return false;

// Body percentage check
   double body = BodySize(tf, bar);
   if(range > 0 && (body / range * 100.0) < InpDisp_MinBodyPercent)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDisplacementMove(ENUM_TIMEFRAMES tf, int startBar, double atr, bool expectBullish)
  {
   if(atr <= 0)
      return false;

   int count = InpDisp_MinConsecutive;
   double totalMove = 0;

   for(int i = 0; i < count && (startBar + i) < iBars(_Symbol, tf); i++)
     {
      int bar = startBar + i;
      double barOpen = TF_Open(tf, bar);
      double barClose = TF_Close(tf, bar);

      if(!IsDisplacementCandle(tf, bar, atr))
         return false;

      // Direction check
      if(expectBullish && barClose <= barOpen)
         return false;
      if(!expectBullish && barClose >= barOpen)
         return false;

      totalMove += MathAbs(barClose - barOpen);
     }

// Check if FVG was created (optional)
   if(InpDisp_RequireFVGCreated)
     {
      // Check for gap between candle before displacement and candle after
      if(startBar >= 2)
        {
         double beforeHigh = TF_High(tf, startBar + 1);
         double afterLow = TF_Low(tf, startBar - 1);

         if(expectBullish && afterLow <= beforeHigh)
            return false; // No bullish FVG created

         double beforeLow = TF_Low(tf, startBar + 1);
         double afterHigh = TF_High(tf, startBar - 1);

         if(!expectBullish && afterHigh >= beforeLow)
            return false; // No bearish FVG created
        }
     }

   return true;
  }
//+------------------------------------------------------------------+
//|              SECTION 3: PIVOT DETECTION FUNCTIONS                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Bar is Pivot High                                        |
//+------------------------------------------------------------------+
bool IsPivotHigh(ENUM_TIMEFRAMES tf, int barIndex, int leftBars, int rightBars)
  {
   int totalBars = TF_Bars(tf);
   if(barIndex + leftBars >= totalBars || barIndex - rightBars < 0)
      return false;

   double high = TF_High(tf, barIndex);

// Check left side
   for(int i = 1; i <= leftBars; i++)
     {
      if(TF_High(tf, barIndex + i) > high)
         return false;
     }

// Check right side
   for(int i = 1; i <= rightBars; i++)
     {
      if(TF_High(tf, barIndex - i) > high)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Check if Bar is Pivot Low                                         |
//+------------------------------------------------------------------+
bool IsPivotLow(ENUM_TIMEFRAMES tf, int barIndex, int leftBars, int rightBars)
  {
   int totalBars = TF_Bars(tf);
   if(barIndex + leftBars >= totalBars || barIndex - rightBars < 0)
      return false;

   double low = TF_Low(tf, barIndex);

// Check left side
   for(int i = 1; i <= leftBars; i++)
     {
      if(TF_Low(tf, barIndex + i) < low)
         return false;
     }

// Check right side
   for(int i = 1; i <= rightBars; i++)
     {
      if(TF_Low(tf, barIndex - i) < low)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate Pivot Score (Multi-Period Validation)                   |
//+------------------------------------------------------------------+
int CalculatePivotScore(ENUM_TIMEFRAMES tf, int barIndex, bool isHigh)
  {
   int score = 0;
   int periods[] = {3, 5, 10, 15, 20};
   int count = ArraySize(periods);

   for(int p = 0; p < count; p++)
     {
      if(isHigh)
        {
         if(IsPivotHigh(tf, barIndex, periods[p], periods[p]))
            score++;
        }
      else
        {
         if(IsPivotLow(tf, barIndex, periods[p], periods[p]))
            score++;
        }
     }

   return score;
  }

//+------------------------------------------------------------------+
//| Calculate Swing Depth                                             |
//+------------------------------------------------------------------+
double CalculateSwingDepth(ENUM_TIMEFRAMES tf, int barIndex, bool isLow, int leftBars, int rightBars)
  {
   int barsAvail = TF_Bars(tf);
   double swingPrice = isLow ? TF_Low(tf, barIndex) : TF_High(tf, barIndex);

   double leftExtreme = swingPrice;
   double rightExtreme = swingPrice;

// Find opposite extreme on left side
   for(int i = 1; i <= leftBars + 3 && (barIndex + i) < barsAvail; i++)
     {
      if(isLow)
        {
         double h = TF_High(tf, barIndex + i);
         if(h > leftExtreme)
            leftExtreme = h;
        }
      else
        {
         double l = TF_Low(tf, barIndex + i);
         if(l < leftExtreme || leftExtreme == swingPrice)
            leftExtreme = l;
        }
     }

// Find opposite extreme on right side
   for(int i = 1; i <= rightBars + 3 && (barIndex - i) >= 0; i++)
     {
      if(isLow)
        {
         double h = TF_High(tf, barIndex - i);
         if(h > rightExtreme)
            rightExtreme = h;
        }
      else
        {
         double l = TF_Low(tf, barIndex - i);
         if(l < rightExtreme || rightExtreme == swingPrice)
            rightExtreme = l;
        }
     }

// Return smaller of two depths
   return MathMin(MathAbs(leftExtreme - swingPrice), MathAbs(rightExtreme - swingPrice));
  }

//+------------------------------------------------------------------+
//|              SECTION 4: SWEEP & BREAK DETECTION                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Sweep on Previous Bar                                       |
//+------------------------------------------------------------------+
bool CheckSweep(ENUM_TIMEFRAMES tf, double level, bool sweepBelow)
  {
   double prevHigh = TF_High(tf, 1);
   double prevLow = TF_Low(tf, 1);
   double prevClose = TF_Close(tf, 1);

   switch(InpSweepMethod)
     {
      case SWEEP_ANY_TOUCH:
         return sweepBelow ? (prevLow <= level) : (prevHigh >= level);

      case SWEEP_WICK_CLOSE_BACK:
         if(sweepBelow)
            return (prevLow <= level && prevClose > level);
         else
            return (prevHigh >= level && prevClose < level);

      case SWEEP_BODY_CLOSE:
         return sweepBelow ? (prevClose <= level) : (prevClose >= level);
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check Break on Previous Bar                                       |
//+------------------------------------------------------------------+
bool CheckBreak(ENUM_TIMEFRAMES tf, double level, bool breakAbove)
  {
   double prevHigh = TF_High(tf, 1);
   double prevLow = TF_Low(tf, 1);
   double prevClose = TF_Close(tf, 1);
   double prevOpen = TF_Open(tf, 1);

   switch(InpBreakMethod)
     {
      case BREAK_ANY_TOUCH:
         return breakAbove ? (prevHigh > level) : (prevLow < level);

      case BREAK_CANDLE_CLOSE:
         return breakAbove ? (prevClose > level) : (prevClose < level);

      case BREAK_FULL_BODY:
        {
         double bodyBottom = MathMin(prevOpen, prevClose);
         double bodyTop = MathMax(prevOpen, prevClose);
         return breakAbove ? (bodyBottom > level) : (bodyTop < level);
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check if Level is Broken (Historical)                             |
//+------------------------------------------------------------------+
bool IsLevelBroken(ENUM_TIMEFRAMES tf, double price, bool checkBelow, int fromBar)
  {
   for(int i = fromBar - 1; i >= 0; i--)
     {
      if(checkBelow)
        {
         if(TF_Low(tf, i) < price)
            return true;
        }
      else
        {
         if(TF_High(tf, i) > price)
            return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Check if Price Has Pulled Back from Extreme                       |
//+------------------------------------------------------------------+
bool HasPulledBackFromExtreme(ENUM_TIMEFRAMES tf, double extremePrice,
                              datetime extremeTime, bool isBullish, double atr)
  {
   int clBar = TF_BarShift(tf, extremeTime);
   if(clBar < 3)
      return false;

   double pullbackDist = atr * InpCL_PullbackMinATR;  // Was hardcoded 0.2

   for(int i = clBar - 1; i >= 1; i--)
     {
      double barClose = TF_Close(tf, i);

      if(isBullish && barClose < extremePrice - pullbackDist)
         return true;

      if(!isBullish && barClose > extremePrice + pullbackDist)
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|              SECTION 5: CROSSOVER FUNCTIONS                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Crossover Detection (Current crosses above level)                 |
//+------------------------------------------------------------------+
bool Crossover(double current, double level, double previous)
  {
   return (previous <= level && current > level);
  }

//+------------------------------------------------------------------+
//| Crossunder Detection (Current crosses below level)                |
//+------------------------------------------------------------------+
bool Crossunder(double current, double level, double previous)
  {
   return (previous >= level && current < level);
  }

//+------------------------------------------------------------------+
//|              SECTION 6: ZONE FUNCTIONS                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Two Zones Overlap                                        |
//+------------------------------------------------------------------+
bool ZonesOverlap(double top1, double bottom1, double top2, double bottom2)
  {
   double upper1 = MathMax(top1, bottom1);
   double lower1 = MathMin(top1, bottom1);
   double upper2 = MathMax(top2, bottom2);
   double lower2 = MathMin(top2, bottom2);

   return (lower1 <= upper2 && upper1 >= lower2);
  }

//+------------------------------------------------------------------+
//| Calculate Zone Overlap                                            |
//+------------------------------------------------------------------+
bool CalculateZoneOverlap(double top1, double bottom1, double top2, double bottom2,
                          double &overlapTop, double &overlapBottom)
  {
   if(!ZonesOverlap(top1, bottom1, top2, bottom2))
      return false;

   double upper1 = MathMax(top1, bottom1);
   double lower1 = MathMin(top1, bottom1);
   double upper2 = MathMax(top2, bottom2);
   double lower2 = MathMin(top2, bottom2);

   overlapTop = MathMin(upper1, upper2);
   overlapBottom = MathMax(lower1, lower2);

   return true;
  }

//+------------------------------------------------------------------+
//| Check if Price is in Zone                                         |
//+------------------------------------------------------------------+
bool IsPriceInZone(double price, double top, double bottom)
  {
   double upper = MathMax(top, bottom);
   double lower = MathMin(top, bottom);
   return (price >= lower && price <= upper);
  }

//+------------------------------------------------------------------+
//| Calculate Premium/Discount Zone                                   |
//+------------------------------------------------------------------+
ENUM_ZONE_TYPE CalculateZone(double price, double high, double low)
  {
   if(high <= low)
      return ZONE_NONE;

   double range = high - low;
   double eq = (high + low) / 2.0;
   double premiumPct = 70.0;
   double discountPct = 30.0;
   double eqBufferPct = 5.0;
   double eqBuffer = range * (eqBufferPct / 100.0);
   double premiumLevel = low + range * (premiumPct / 100.0);
   double discountLevel = low + range * (discountPct / 100.0);

   if(price >= premiumLevel)
      return ZONE_PREMIUM;
   else
      if(price <= discountLevel)
         return ZONE_DISCOUNT;
      else
         return ZONE_EQUILIBRIUM;
  }

//+------------------------------------------------------------------+
//|              SECTION 7: TIME FUNCTIONS                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if New Bar on Timeframe                                     |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &lastBarTime)
  {
   datetime currentBarTime = TF_Time(tf, 0);
   if(currentBarTime != lastBarTime)
     {
      lastBarTime = currentBarTime;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Get Server Hour                                                   |
//+------------------------------------------------------------------+
int GetServerHour()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return tm.hour;
  }

//+------------------------------------------------------------------+
//| Get Day of Week                                                   |
//+------------------------------------------------------------------+
int GetDayOfWeek()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return tm.day_of_week;
  }

//+------------------------------------------------------------------+
//| Check if Trading Day                                              |
//+------------------------------------------------------------------+
bool IsTradingDay()
  {
   if(!InpUseDayFilter)
      return true;

   int dow = GetDayOfWeek();

   switch(dow)
     {
      case 1:
         return InpTradeMonday;
      case 2:
         return InpTradeTuesday;
      case 3:
         return InpTradeWednesday;
      case 4:
         return InpTradeThursday;
      case 5:
         return InpTradeFriday;
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| Check Daily Reset                                                 |
//+------------------------------------------------------------------+
void CheckDailyReset()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   datetime today = StringToTime(IntegerToString(tm.year) + "." +
                                 IntegerToString(tm.mon) + "." +
                                 IntegerToString(tm.day));

   if(today != g_lastDayCheck)
     {
      g_stats.todayTrades = 0;
      g_stats.todayPnL = 0;
      g_dailyLossReached = false;
      g_maxTradesReached = false;
      g_lastDayCheck = today;

      Print("Daily reset performed");
     }
  }

//+------------------------------------------------------------------+
//|              SECTION 8: TRADE FILTER FUNCTIONS                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Spread Filter                                               |
//+------------------------------------------------------------------+
bool CheckSpreadFilter()
  {
   if(!InpUseSpreadFilter)
      return true;

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= InpMaxSpread);
  }

//+------------------------------------------------------------------+
//| Check Max Trades Filter                                           |
//+------------------------------------------------------------------+
bool CheckMaxTradesFilter()
  {
   if(!InpUseMaxTrades)
      return true;

   if(g_stats.todayTrades >= InpMaxDailyTrades)
     {
      g_maxTradesReached = true;
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Check Max Loss Filter                                             |
//+------------------------------------------------------------------+
bool CheckMaxLossFilter()
  {
   if(!InpUseMaxLoss)
      return true;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxLoss = balance * InpMaxDailyLossPercent / 100.0;

   if(g_stats.todayPnL <= -maxLoss)
     {
      g_dailyLossReached = true;
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Check All Trade Filters                                           |
//+------------------------------------------------------------------+
bool CheckAllFilters()
  {
   if(!g_tradingEnabled)
     {
      Print("Trading disabled");
      return false;
     }

   if(!IsTradingDay())
     {
      Print("Not a trading day");
      return false;
     }

   if(!CheckSpreadFilter())
     {
      Print("Spread too high");
      return false;
     }

   if(!CheckMaxTradesFilter())
     {
      Print("Max daily trades reached");
      return false;
     }

   if(!CheckMaxLossFilter())
     {
      Print("Max daily loss reached");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|              SECTION 9: OBJECT MANAGEMENT                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Delete Single Object                                              |
//+------------------------------------------------------------------+
void DeleteObject(string name)
  {
   if(name != "" && ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
  }

//+------------------------------------------------------------------+
//| Cleanup All Objects with Prefix                                   |
//+------------------------------------------------------------------+
void CleanupObjectsWithPrefix(string prefix)
  {
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| Cleanup All EA Objects                                            |
//+------------------------------------------------------------------+
void CleanupAllObjects()
  {
   CleanupObjectsWithPrefix(g_prefix);
   CleanupObjectsWithPrefix(g_drPrefix);
   CleanupObjectsWithPrefix(g_smObjPrefix);
   CleanupObjectsWithPrefix(g_dashPrefix);
  }

//+------------------------------------------------------------------+
//| Periodic Cleanup (Old Objects)                                    |
//+------------------------------------------------------------------+
void PeriodicCleanup()
  {
   if(TimeCurrent() - g_lastCleanupTime < 3600) // Every hour
      return;

   g_lastCleanupTime = TimeCurrent();

   int totalObjects = ObjectsTotal(0);
   if(totalObjects < 500)
      return;

   datetime cutoffTime = TimeCurrent() - 86400 * 3; // 3 days old
   int deleted = 0;

   for(int i = totalObjects - 1; i >= 0 && deleted < 100; i--)
     {
      string name = ObjectName(0, i);

      // Only delete our objects
      if(StringFind(name, g_prefix) != 0 &&
         StringFind(name, g_smObjPrefix) != 0 &&
         StringFind(name, g_drPrefix) != 0)
         continue;

      // Don't delete dashboard
      if(StringFind(name, g_dashPrefix) == 0)
         continue;

      datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
      if(objTime > 0 && objTime < cutoffTime)
        {
         ObjectDelete(0, name);
         deleted++;
        }
     }

   if(deleted > 0)
      Print("Cleaned up ", deleted, " old objects");
  }

//+------------------------------------------------------------------+
//|              SECTION 10: COLOR FUNCTIONS                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Darken Color                                                      |
//+------------------------------------------------------------------+
color ColorDarken(color baseColor, int percent)
  {
   int r = (baseColor & 0xFF);
   int g = ((baseColor >> 8) & 0xFF);
   int b = ((baseColor >> 16) & 0xFF);

   r = r * (100 - percent) / 100;
   g = g * (100 - percent) / 100;
   b = b * (100 - percent) / 100;

   return (color)((b << 16) | (g << 8) | r);
  }

//+------------------------------------------------------------------+
//| Lighten Color                                                     |
//+------------------------------------------------------------------+
color ColorLighten(color baseColor, int percent)
  {
   int r = (baseColor & 0xFF);
   int g = ((baseColor >> 8) & 0xFF);
   int b = ((baseColor >> 16) & 0xFF);

   r = MathMin(255, r + (255 - r) * percent / 100);
   g = MathMin(255, g + (255 - g) * percent / 100);
   b = MathMin(255, b + (255 - b) * percent / 100);

   return (color)((b << 16) | (g << 8) | r);
  }

//+------------------------------------------------------------------+
//| Blend Two Colors                                                  |
//+------------------------------------------------------------------+
color ColorBlend(color color1, color color2, int ratio)
  {
   int r1 = (color1 & 0xFF);
   int g1 = ((color1 >> 8) & 0xFF);
   int b1 = ((color1 >> 16) & 0xFF);

   int r2 = (color2 & 0xFF);
   int g2 = ((color2 >> 8) & 0xFF);
   int b2 = ((color2 >> 16) & 0xFF);

   int r = (r1 * ratio + r2 * (100 - ratio)) / 100;
   int g = (g1 * ratio + g2 * (100 - ratio)) / 100;
   int b = (b1 * ratio + b2 * (100 - ratio)) / 100;

   return (color)((b << 16) | (g << 8) | r);
  }

//+------------------------------------------------------------------+
//|              SECTION 11: STRING/ENUM FUNCTIONS                     |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Get AMD Phase Name                                                |
//+------------------------------------------------------------------+
string AMDPhaseToString(ENUM_AMD_PHASE phase)
  {
   switch(phase)
     {
      case AMD_ACCUMULATION:
         return "Accumulation";
      case AMD_MANIPULATION:
         return "Manipulation";
      case AMD_DISTRIBUTION:
         return "Distribution";
      default:
         return "Unknown";
     }
  }

//+------------------------------------------------------------------+
//| Get Killzone Name                                                 |
//+------------------------------------------------------------------+
string KillzoneToString(ENUM_KILLZONE kz)
  {
   switch(kz)
     {
      case KZ_ASIAN:
         return "Asian";
      case KZ_LONDON_OPEN:
         return "London Open";
      case KZ_LONDON:
         return "London";
      case KZ_NY_OPEN:
         return "NY Open";
      case KZ_NY:
         return "NY";
      case KZ_LONDON_NY_OVERLAP:
         return "LDN/NY Overlap";
      case KZ_LONDON_CLOSE:
         return "London Close";
      case KZ_OFF_HOURS:
         return "Off Hours";
      default:
         return "None";
     }
  }

//+------------------------------------------------------------------+
//| Get Zone Name                                                     |
//+------------------------------------------------------------------+
string ZoneToString(ENUM_ZONE_TYPE zone)
  {
   switch(zone)
     {
      case ZONE_PREMIUM:
         return "Premium";
      case ZONE_DISCOUNT:
         return "Discount";
      case ZONE_EQUILIBRIUM:
         return "Equilibrium";
      default:
         return "None";
     }
  }

//+------------------------------------------------------------------+
//| Get Signal Trigger Name                                           |
//+------------------------------------------------------------------+
string TriggerToString(ENUM_SIGNAL_TRIGGER trigger)
  {
   switch(trigger)
     {
      case TRIGGER_OB_ENTRY:
         return "Order Block";
      case TRIGGER_BREAKER_ENTRY:
         return "Breaker Block";
      case TRIGGER_MB_ENTRY:
         return "Mitigation Block";
      case TRIGGER_FVG_ENTRY:
         return "FVG";
      case TRIGGER_OTE_ENTRY:
         return "OTE Zone";
      case TRIGGER_DISPLACEMENT:
         return "Displacement";
      default:
         return "None";
     }
  }

//+------------------------------------------------------------------+
//| Get TF Short Name                                                 |
//+------------------------------------------------------------------+
string TFToString(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M2:
         return "M2";
      case PERIOD_M3:
         return "M3";
      case PERIOD_M4:
         return "M4";
      case PERIOD_M5:
         return "M5";
      case PERIOD_M6:
         return "M6";
      case PERIOD_M10:
         return "M10";
      case PERIOD_M12:
         return "M12";
      case PERIOD_M15:
         return "M15";
      case PERIOD_M20:
         return "M20";
      case PERIOD_M30:
         return "M30";
      case PERIOD_H1:
         return "H1";
      case PERIOD_H2:
         return "H2";
      case PERIOD_H3:
         return "H3";
      case PERIOD_H4:
         return "H4";
      case PERIOD_H6:
         return "H6";
      case PERIOD_H8:
         return "H8";
      case PERIOD_H12:
         return "H12";
      case PERIOD_D1:
         return "D1";
      case PERIOD_W1:
         return "W1";
      case PERIOD_MN1:
         return "MN";
      default:
         return "??";
     }
  }

//+------------------------------------------------------------------+
//|              SECTION 12: ALERT FUNCTIONS                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Send Alert                                                        |
//+------------------------------------------------------------------+
void SendAlert(string message, bool isSignal = false, bool isTrade = false, bool isStructure = false)
  {
// Check if this alert type is enabled
   if(isSignal && !InpAlertSignals)
      return;
   if(isTrade && !InpAlertTrades)
      return;
   if(isStructure && !InpAlertStructure)
      return;

// Prevent alert spam
   if(TimeCurrent() - g_lastAlertTime < 5)
      return;
   g_lastAlertTime = TimeCurrent();

   string fullMessage = _Symbol + " " + TFToString((ENUM_TIMEFRAMES)Period()) + ": " + message;

// Terminal alert
   Alert(fullMessage);

// Push notification
   if(InpPushNotification)
      SendNotification(fullMessage);

// Email notification
   if(InpEmailNotification)
      SendMail("ICT Unified EA Alert", fullMessage);

// Log to journal
   Print("ALERT: ", fullMessage);
  }

//+------------------------------------------------------------------+
//|              SECTION 13: TRADE HELPER FUNCTIONS                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Order Filling Type                                            |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingType()
  {
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);

   switch(InpFillingMode)
     {
      case FILL_FOK:
         if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
            return ORDER_FILLING_FOK;
         break;

      case FILL_IOC:
         if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
            return ORDER_FILLING_IOC;
         break;

      case FILL_RETURN:
         return ORDER_FILLING_RETURN;
     }

// Fallback
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;

   return ORDER_FILLING_RETURN;
  }

//+------------------------------------------------------------------+
//| Get Retcode Description                                           |
//+------------------------------------------------------------------+
string RetcodeToString(uint retcode)
  {
   switch(retcode)
     {
      case TRADE_RETCODE_REQUOTE:
         return "Requote";
      case TRADE_RETCODE_REJECT:
         return "Rejected";
      case TRADE_RETCODE_CANCEL:
         return "Canceled";
      case TRADE_RETCODE_PLACED:
         return "Order Placed";
      case TRADE_RETCODE_DONE:
         return "Done";
      case TRADE_RETCODE_DONE_PARTIAL:
         return "Done Partial";
      case TRADE_RETCODE_ERROR:
         return "Error";
      case TRADE_RETCODE_TIMEOUT:
         return "Timeout";
      case TRADE_RETCODE_INVALID:
         return "Invalid Request";
      case TRADE_RETCODE_INVALID_VOLUME:
         return "Invalid Volume";
      case TRADE_RETCODE_INVALID_PRICE:
         return "Invalid Price";
      case TRADE_RETCODE_INVALID_STOPS:
         return "Invalid Stops";
      case TRADE_RETCODE_TRADE_DISABLED:
         return "Trade Disabled";
      case TRADE_RETCODE_MARKET_CLOSED:
         return "Market Closed";
      case TRADE_RETCODE_NO_MONEY:
         return "No Money";
      case TRADE_RETCODE_PRICE_CHANGED:
         return "Price Changed";
      case TRADE_RETCODE_PRICE_OFF:
         return "Price Off";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         return "Too Many Requests";
      default:
         return "Unknown (" + IntegerToString(retcode) + ")";
     }
  }

//+------------------------------------------------------------------+
//| Normalize Price                                                   |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
   return NormalizeDouble(price, _Digits);
  }

//+------------------------------------------------------------------+
//| Normalize Lot Size                                                |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));

   return NormalizeDouble(lot, 2);
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size from Risk                                      |
//+------------------------------------------------------------------+
double CalculateLotFromRisk(double slDistance)
  {
   if(slDistance <= 0)
      return InpFixedLot;

   double lot = InpFixedLot;

   if(InpLotMode == LOT_RISK_PERCENT)
     {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * InpRiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue > 0 && tickSize > 0)
        {
         double slTicks = slDistance / tickSize;
         lot = riskAmount / (slTicks * tickValue);
        }
     }
   else
      if(InpLotMode == LOT_BALANCE_PERCENT)
        {
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double marginRequired = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
         if(marginRequired > 0)
           {
            lot = (balance * InpRiskPercent / 100.0) / marginRequired;
           }
        }

   return NormalizeLot(lot);
  }

//+------------------------------------------------------------------+
//| Check Session Filter (Bug #13 fix)                               |
//+------------------------------------------------------------------+
bool CheckSessionFilter()
  {
   if(!InpUseKillzoneFilter)
      return true;

// Allow trading if we're in any active killzone
   if(g_killzone.isActive)
      return true;

// Also allow if killzone is not OFF_HOURS
   if(g_killzone.current != KZ_OFF_HOURS && g_killzone.current != KZ_NONE)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
//|  SECTION 14: LAYER DISPLAY CONTROL & LABELING SYSTEM              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Map PD(NZ) array type → SM element type                               |
//+------------------------------------------------------------------+
ENUM_SM_ELEMENT NarrativeZoneToSMElement(ENUM_NARRATIVE_ZONE_TYPE zoneType)
  {
   switch(zoneType)
     {
      case NZ_ORDER_BLOCK:
         return SM_ELEM_ORDER_BLOCK;
      case NZ_BREAKER_BLOCK:
         return SM_ELEM_BREAKER;
      case NZ_MITIGATION_BLOCK:
         return SM_ELEM_MITIGATION;
      case NZ_FVG:
         return SM_ELEM_FVG;
      case NZ_IFVG:
         return SM_ELEM_IFVG;
      case NZ_FVG_CE:
         return SM_ELEM_FVG_CE;
      case NZ_OTE_ZONE:
         return SM_ELEM_OTE_ZONE;
      case NZ_VOLUME_IMBALANCE:
         return SM_ELEM_VOLUME_IMBALANCE;
      case NZ_LIQUIDITY_VOID:
         return SM_ELEM_LIQUIDITY_VOID;
      default:
         return SM_ELEM_NONE;
     }
  }

//+------------------------------------------------------------------+
//| Check if an SM element is used in any of the 8 stage slots        |
//+------------------------------------------------------------------+
bool SM_IsElementInStages(ENUM_SM_ELEMENT elem)
  {
   if(elem == SM_ELEM_NONE)
      return false;
   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      if(g_smStageCfg[s].primaryElem  == elem)
         return true;
      if(g_smStageCfg[s].secondaryElem == elem)
         return true;
     }
   return false;
  }


//+------------------------------------------------------------------+
//| Get current system tag ("PD" or "SM")                             |
//+------------------------------------------------------------------+
string GetSystemTag()
  {
   return "SM";
  }

//+------------------------------------------------------------------+
//| Get TF layer short tag                                            |
//+------------------------------------------------------------------+
string GetTFTag(ENUM_TF_LAYER layer)
  {
   switch(layer)
     {
      case LAYER_HTF:
         return "HTF";
      case LAYER_LTF:
         return "LTF";
      default:
         return "CTF";
     }
  }

//+------------------------------------------------------------------+
//| Build PD/SM element label: "CTF PD Bull FVG"                      |
//+------------------------------------------------------------------+
string BuildElementLabel(ENUM_TF_LAYER tf, bool isBullish,
                         string elemName, string suffix = "")
  {
   string label = GetTFTag(tf) + " " + GetSystemTag() + " "
                  + (isBullish ? "Bull " : "Bear ")
                  + elemName;
   if(suffix != "")
      label += " " + suffix;
   return label;
  }

//+------------------------------------------------------------------+
//| Build DR structure label (no system tag): "CTF Bull CL"           |
//+------------------------------------------------------------------+
string BuildDRLabel(ENUM_TF_LAYER tf, bool isBullish,
                    string elemName, string suffix = "")
  {
   string label = GetTFTag(tf) + " "
                  + (isBullish ? "Bull " : "Bear ")
                  + elemName;
   if(suffix != "")
      label += " " + suffix;
   return label;
  }

//+------------------------------------------------------------------+
//| Get Main CL vertical width for a TF layer                        |
//+------------------------------------------------------------------+
int GetMainCLWidth(ENUM_TF_LAYER layer)
  {
   switch(layer)
     {
      case LAYER_HTF:
         return InpHTF_MainCLWidth;
      case LAYER_LTF:
         return InpLTF_MainCLWidth;
      default:
         return InpCTF_MainCLWidth;
     }
  }

//+------------------------------------------------------------------+
//| Get Pullback CL vertical width for a TF layer                    |
//+------------------------------------------------------------------+
int GetPBCLWidth(ENUM_TF_LAYER layer)
  {
   switch(layer)
     {
      case LAYER_HTF:
         return InpHTF_PB_CLWidth;
      case LAYER_LTF:
         return InpLTF_PB_CLWidth;
      default:
         return InpCTF_PB_CLWidth;
     }
  }

#endif // ICT_UTILITIES_MQH
//+------------------------------------------------------------------+
