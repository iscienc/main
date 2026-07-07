//+------------------------------------------------------------------+
//|                      ICT_OrderBlocks.mqh                          |
//|           Order Blocks, Breaker Blocks, Mitigation Blocks          |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_ORDERBLOCKS_MQH
#define ICT_ORDERBLOCKS_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize PD Arrays - Order Blocks                               |
//+------------------------------------------------------------------+
bool InitializePDArrays_OB()
{
   ArrayResize(g_orderBlocks, g_maxOBs);
   ArrayResize(g_breakerBlocks, g_maxBreakers);
   ArrayResize(g_mitigationBlocks, g_maxMBs);
   
   g_obCount = 0;
   g_breakerCount = 0;
   g_mbCount = 0;
   
   Print("Order Block System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: ORDER BLOCK DETECTION                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect All Order Blocks                                           |
//+------------------------------------------------------------------+
void DetectAllOrderBlocks()
{
   if(!InpDetectOrderBlocks)
      return;
   
   double atr = GetATR();
   if(atr <= 0) return;
   
   // Scan for new OBs
   for(int i = InpOB_Lookback; i > 1; i--)
   {
      DetectBullishOB(i, atr);
      DetectBearishOB(i, atr);
   }
   
   // Update OB statuses
   UpdateOrderBlockStatuses();
   
   // Check for Breaker conversions
   if(InpDetectBreakerBlocks)
      CheckBreakerConversions();
   
   // Detect Mitigation Blocks
   if(InpDetectMitigationBlocks)
      DetectMitigationBlocks();
   
   // Cleanup old/invalid OBs
   CleanupOrderBlocks();
   
      // Detect Rejection Blocks
   DetectRejectionBlocks();
}

//+------------------------------------------------------------------+
//| Detect Bullish Order Block                                        |
//+------------------------------------------------------------------+
void DetectBullishOB(int barIndex, double atr)
{
   // Bullish OB = Last DOWN candle before strong UP move (displacement)
   
   // Check if this is a down candle
   double open = iOpen(_Symbol, PERIOD_CURRENT, barIndex);
   double close = iClose(_Symbol, PERIOD_CURRENT, barIndex);
   
   if(close >= open) // Not a down candle
      return;
   
   // ── IMPROVEMENT 1: Body ratio filter ──
   double obRange = iHigh(_Symbol, PERIOD_CURRENT, barIndex) - iLow(_Symbol, PERIOD_CURRENT, barIndex);
   double obBody = MathAbs(close - open);
   if(obRange > 0 && (obBody / obRange) < InpOB_MinBodyRatio)
      return;
   // ── END IMPROVEMENT 1 ──
   
   // Check if next candle (barIndex-1) is displacement up
   double nextOpen = iOpen(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextClose = iClose(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextHigh = iHigh(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextLow = iLow(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextRange = nextHigh - nextLow;
   
     // ── IMPROVEMENT 2: Multi-candle displacement check ──
   double obHigh = iHigh(_Symbol, PERIOD_CURRENT, barIndex);
   bool displacementValid = false;
   
   if(InpOB_DisplacementCandles <= 1)
   {
      // Single candle displacement (original logic)
      if(nextClose > nextOpen && 
         nextRange >= atr * InpOB_MinDisplacementATR &&
         nextClose > obHigh)
      {
         displacementValid = true;
      }
   }
   else
   {
      // Multi-candle displacement: check N consecutive candles
      double combinedMoveStart = iOpen(_Symbol, PERIOD_CURRENT, barIndex - 1);
      double combinedMoveEnd = iClose(_Symbol, PERIOD_CURRENT, barIndex - InpOB_DisplacementCandles);
      double totalMove = combinedMoveEnd - combinedMoveStart;
      bool allBullish = true;
      double highestClose = 0;
      
      for(int d = 1; d <= InpOB_DisplacementCandles && (barIndex - d) >= 0; d++)
      {
         double dOpen = iOpen(_Symbol, PERIOD_CURRENT, barIndex - d);
         double dClose = iClose(_Symbol, PERIOD_CURRENT, barIndex - d);
         
         if(dClose <= dOpen) allBullish = false;
         if(dClose > highestClose) highestClose = dClose;
      }
      
      if(totalMove >= atr * InpOB_MinDisplacementATR && highestClose > obHigh)
      {
         if(InpOB_RequireConsecDisplacement)
            displacementValid = allBullish;
         else
            displacementValid = true;
      }
   }
   
   if(!displacementValid)
      return;
   // ── END IMPROVEMENT 2 ──
      
      
   // Valid Bullish OB found
   double obLow = iLow(_Symbol, PERIOD_CURRENT, barIndex);
   double bodyTop = MathMax(open, close);
   double bodyBottom = MathMin(open, close);
   
   // Check if institutional candle
   bool isInstitutional = IsInstitutionalCandle(PERIOD_CURRENT, barIndex, atr);
   
   // Check if already exists
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].type == OB_BULLISH &&
         MathAbs(g_orderBlocks[i].bottom - obLow) < atr * 0.1)
         return; // Already exists
   }
   
   // Add new OB
   if(g_obCount >= g_maxOBs)
      RemoveOldestOB();
   
   int idx = g_obCount;
   
   g_orderBlocks[idx].Reset();
   g_orderBlocks[idx].type = OB_BULLISH;
   g_orderBlocks[idx].status = OB_FRESH;
   
   // ── IMPROVEMENT 3: Configurable zone boundaries ──
   if(InpOB_ZoneIncludeWicks)
   {
      // Full candle range (wider zone, more conservative)
      g_orderBlocks[idx].top = iHigh(_Symbol, PERIOD_CURRENT, barIndex);
      g_orderBlocks[idx].bottom = iLow(_Symbol, PERIOD_CURRENT, barIndex);
   }
   else
   {
      // Body-based zone (tighter, more precise)
      g_orderBlocks[idx].top = bodyTop;
      g_orderBlocks[idx].bottom = obLow;
   }
   g_orderBlocks[idx].midpoint = (g_orderBlocks[idx].top + g_orderBlocks[idx].bottom) / 2.0;
   // ── END IMPROVEMENT 3 ──
   
   
   g_orderBlocks[idx].time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   g_orderBlocks[idx].barIndex = barIndex;
   g_orderBlocks[idx].bodyTop = bodyTop;
   g_orderBlocks[idx].bodyBottom = bodyBottom;
   g_orderBlocks[idx].isInstitutional = isInstitutional;
   g_orderBlocks[idx].testCount = 0;
   g_orderBlocks[idx].objName = GeneratePDObjectName("OB");
   g_orderBlocks[idx].labelName = g_orderBlocks[idx].objName + "_lbl";
   
      // Causal tagging (OB created by recent structural event?)
   datetime obTime = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   if(g_lastSMEvent.valid && g_lastSMEvent.direction == DIR_BULLISH)
   {
      int evBar = iBarShift(_Symbol, PERIOD_CURRENT, g_lastSMEvent.time, false);
      if(evBar >= 0 && MathAbs(evBar - barIndex) <= 3) // within 3 bars from event
      {
         g_orderBlocks[idx].causalTag = g_lastSMEvent.tag;
         g_orderBlocks[idx].bornDirection = DIR_BULLISH;
         g_orderBlocks[idx].birthBar = barIndex;
      }
   }
   
   g_obCount++;
   
   if(InpShowOrderBlocks)
      RedrawOrderBlock(idx);
}

//+------------------------------------------------------------------+
//| Detect Bearish Order Block                                        |
//+------------------------------------------------------------------+
void DetectBearishOB(int barIndex, double atr)
{
   // Bearish OB = Last UP candle before strong DOWN move (displacement)
   
   double open = iOpen(_Symbol, PERIOD_CURRENT, barIndex);
   double close = iClose(_Symbol, PERIOD_CURRENT, barIndex);
   
    if(close <= open) // Not an up candle
      return;
   
   // ── IMPROVEMENT 1: Body ratio filter ──
   double obRange = iHigh(_Symbol, PERIOD_CURRENT, barIndex) - iLow(_Symbol, PERIOD_CURRENT, barIndex);
   double obBody = MathAbs(close - open);
   if(obRange > 0 && (obBody / obRange) < InpOB_MinBodyRatio)
      return;
   // ── END IMPROVEMENT 1 ──
   
   // Check if next candle is displacement down
   double nextOpen = iOpen(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextClose = iClose(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextHigh = iHigh(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextLow = iLow(_Symbol, PERIOD_CURRENT, barIndex - 1);
   double nextRange = nextHigh - nextLow;
   
   // ── IMPROVEMENT 2: Multi-candle displacement check (BEARISH) ──
   double obLow = iLow(_Symbol, PERIOD_CURRENT, barIndex);
   bool displacementValid = false;
   
   if(InpOB_DisplacementCandles <= 1)
   {
      // Single candle displacement (original logic)
      if(nextClose < nextOpen && 
         nextRange >= atr * InpOB_MinDisplacementATR &&
         nextClose < obLow)
      {
         displacementValid = true;
      }
   }
   else
   {
      // Multi-candle displacement: check N consecutive candles
      double combinedMoveStart = iOpen(_Symbol, PERIOD_CURRENT, barIndex - 1);
      double combinedMoveEnd = iClose(_Symbol, PERIOD_CURRENT, barIndex - InpOB_DisplacementCandles);
      double totalMove = combinedMoveStart - combinedMoveEnd;  // Reversed for bearish
      bool allBearish = true;
      double lowestClose = DBL_MAX;
      
      for(int d = 1; d <= InpOB_DisplacementCandles && (barIndex - d) >= 0; d++)
      {
         double dOpen = iOpen(_Symbol, PERIOD_CURRENT, barIndex - d);
         double dClose = iClose(_Symbol, PERIOD_CURRENT, barIndex - d);
         
         if(dClose >= dOpen) allBearish = false;  // Reversed: must be bearish
         if(dClose < lowestClose) lowestClose = dClose;  // Track lowest close
      }
      
      if(totalMove >= atr * InpOB_MinDisplacementATR && lowestClose < obLow)
      {
         if(InpOB_RequireConsecDisplacement)
            displacementValid = allBearish;  // All candles must be bearish
         else
            displacementValid = true;
      }
   }
   
   if(!displacementValid)
      return;
   // ── END IMPROVEMENT 2 ──
   // Valid Bearish OB found
   double obHigh = iHigh(_Symbol, PERIOD_CURRENT, barIndex);
   double bodyTop = MathMax(open, close);
   double bodyBottom = MathMin(open, close);
   
   bool isInstitutional = IsInstitutionalCandle(PERIOD_CURRENT, barIndex, atr);
   
   // Check if already exists
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].type == OB_BEARISH &&
         MathAbs(g_orderBlocks[i].top - obHigh) < atr * 0.1)
         return;
   }
   
   // Add new OB
   if(g_obCount >= g_maxOBs)
      RemoveOldestOB();
   
   int idx = g_obCount;
   
     g_orderBlocks[idx].Reset();
   g_orderBlocks[idx].type = OB_BEARISH;
   g_orderBlocks[idx].status = OB_FRESH;
   
   // ── IMPROVEMENT 3: Configurable zone boundaries ──
   if(InpOB_ZoneIncludeWicks)
   {
      // Full candle range (wider zone, more conservative)
      g_orderBlocks[idx].top = iHigh(_Symbol, PERIOD_CURRENT, barIndex);
      g_orderBlocks[idx].bottom = iLow(_Symbol, PERIOD_CURRENT, barIndex);
   }
   else
   {
      // Body-based zone (tighter, more precise)
      g_orderBlocks[idx].top = obHigh;
      g_orderBlocks[idx].bottom = bodyBottom;
   }
   g_orderBlocks[idx].midpoint = (g_orderBlocks[idx].top + g_orderBlocks[idx].bottom) / 2.0;
   // ── END IMPROVEMENT 3 ──
   g_orderBlocks[idx].time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   g_orderBlocks[idx].barIndex = barIndex;
   g_orderBlocks[idx].bodyTop = bodyTop;
   g_orderBlocks[idx].bodyBottom = bodyBottom;
   g_orderBlocks[idx].isInstitutional = isInstitutional;
   g_orderBlocks[idx].testCount = 0;
   g_orderBlocks[idx].objName = GeneratePDObjectName("OB");
   g_orderBlocks[idx].labelName = g_orderBlocks[idx].objName + "_lbl";
   
      // Causal tagging
   datetime obTime = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   if(g_lastSMEvent.valid && g_lastSMEvent.direction == DIR_BEARISH)
   {
      int evBar = iBarShift(_Symbol, PERIOD_CURRENT, g_lastSMEvent.time, false);
      if(evBar >= 0 && MathAbs(evBar - barIndex) <= 3)
      {
         g_orderBlocks[idx].causalTag = g_lastSMEvent.tag;
         g_orderBlocks[idx].bornDirection = DIR_BEARISH;
         g_orderBlocks[idx].birthBar = barIndex;
      }
   }
   
   g_obCount++;
   
   if(InpShowOrderBlocks)
      RedrawOrderBlock(idx);
}

//+------------------------------------------------------------------+
//|              SECTION 3: ORDER BLOCK STATUS                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Order Block Statuses                                       |
//+------------------------------------------------------------------+
void UpdateOrderBlockStatuses()
{
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double atr = GetATR();
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status == OB_FAILED)
         continue;
      
      bool priceInOB = IsPriceInZone(currentPrice, g_orderBlocks[i].top, g_orderBlocks[i].bottom);
      
      if(priceInOB && g_orderBlocks[i].status == OB_FRESH)
      {
         // First touch
         g_orderBlocks[i].status = OB_TESTED;
         g_orderBlocks[i].testCount = 1;
         g_orderBlocks[i].lastTestTime = currentTime;
         
         // Redraw
         if(InpShowOrderBlocks)
            RedrawOrderBlock(i);
      }
      else if(priceInOB && g_orderBlocks[i].status == OB_TESTED)
      {
         // Additional touch
         if(currentTime != g_orderBlocks[i].lastTestTime)
         {
            g_orderBlocks[i].testCount++;
            g_orderBlocks[i].lastTestTime = currentTime;
            
            // Check if too many tests
            if(g_orderBlocks[i].testCount >= InpOB_MaxTestCount)
            {
               g_orderBlocks[i].status = OB_MITIGATED;
               g_orderBlocks[i].mitigatedTime = currentTime;
               
               if(InpShowOrderBlocks)
                  RedrawOrderBlock(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Breaker Conversions                                         |
//+------------------------------------------------------------------+
void CheckBreakerConversions()
{
   double atr = GetATR();
   
   for(int i = g_obCount - 1; i >= 0; i--)
   {
      if(g_orderBlocks[i].status == OB_FAILED)
         continue;
      
      bool shouldConvert = false;
      ENUM_BREAKER_TYPE breakerType;
      
      // Bullish OB fails when price breaks below it with displacement
      if(g_orderBlocks[i].type == OB_BULLISH)
      {
         // Check if price broke below OB
         double recentLow = iLow(_Symbol, PERIOD_CURRENT, 
                                 iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 5, 0));
         
         if(recentLow < g_orderBlocks[i].bottom)
         {
            // Check for displacement down
            for(int j = 1; j <= 3; j++)
            {
               double barRange = CandleRange(PERIOD_CURRENT, j);
               if(barRange >= atr * InpBreaker_MinDisplacementATR &&
                  IsBearishCandle(PERIOD_CURRENT, j))
               {
                  shouldConvert = true;
                  breakerType = BREAKER_BEARISH;
                  break;
               }
            }
         }
      }
      // Bearish OB fails when price breaks above it with displacement
      else if(g_orderBlocks[i].type == OB_BEARISH)
      {
         double recentHigh = iHigh(_Symbol, PERIOD_CURRENT,
                                   iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 5, 0));
         
         if(recentHigh > g_orderBlocks[i].top)
         {
                      for(int j = 1; j <= 3; j++)
            {
               double barRange = CandleRange(PERIOD_CURRENT, j);
               if(barRange >= atr * InpBreaker_MinDisplacementATR &&
                  IsBullishCandle(PERIOD_CURRENT, j))
               {
                  shouldConvert = true;
                  breakerType = BREAKER_BULLISH;
                  break;
               }
            }
         }
      }
      
      if(shouldConvert)
      {
         // ── IMPROVEMENT 2: Require prior OB test before breaker conversion ──
         if(InpBreaker_RequirePriorTest && g_orderBlocks[i].testCount < 1)
         {
            // OB was never tested — skip breaker conversion
            // (Professional ICT: breaker forms when OB is tested then fails)
            shouldConvert = false;
         }
         // ── END IMPROVEMENT 2 ──
         
         if(shouldConvert)
         {
            ConvertOBToBreaker(i, breakerType);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Convert Order Block to Breaker Block                              |
//+------------------------------------------------------------------+
void ConvertOBToBreaker(int obIndex, ENUM_BREAKER_TYPE breakerType)
{
   if(obIndex >= g_obCount)
      return;
   
   // Create breaker block
   if(g_breakerCount >= g_maxBreakers)
      RemoveOldestBreaker();
   
   int idx = g_breakerCount;
   
   g_breakerBlocks[idx].Reset();
   g_breakerBlocks[idx].type = breakerType;
   g_breakerBlocks[idx].top = g_orderBlocks[obIndex].top;
   g_breakerBlocks[idx].bottom = g_orderBlocks[obIndex].bottom;
   g_breakerBlocks[idx].time = g_orderBlocks[obIndex].time;
   g_breakerBlocks[idx].barIndex = g_orderBlocks[obIndex].barIndex;
   g_breakerBlocks[idx].breakTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_breakerBlocks[idx].originalOBTop = g_orderBlocks[obIndex].top;
   g_breakerBlocks[idx].originalOBBottom = g_orderBlocks[obIndex].bottom;
   g_breakerBlocks[idx].objName = GeneratePDObjectName("BRK");
   g_breakerBlocks[idx].labelName = g_breakerBlocks[idx].objName + "_lbl";
   
   g_breakerCount++;
   
   // Mark OB as failed
   g_orderBlocks[obIndex].status = OB_FAILED;
   
   // Delete OB objects
   DeleteObject(g_orderBlocks[obIndex].objName);
   DeleteObject(g_orderBlocks[obIndex].labelName);
   
   // Draw breaker
   if(InpShowOrderBlocks)
      ReDrawBreakerBlock(idx);
   
   Print("OB converted to ", (breakerType == BREAKER_BULLISH ? "BULLISH" : "BEARISH"),
         " BREAKER at ", DoubleToString(g_breakerBlocks[idx].top, _Digits));
}

//+------------------------------------------------------------------+
//|              SECTION 4: MITIGATION BLOCKS                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Mitigation Blocks                                          |
//+------------------------------------------------------------------+
void DetectMitigationBlocks()
{
   // Mitigation Block = First candle to return into prior range after BOS
   
   // We need recent BOS to detect MB
   // Use DR BOS timing if available
   
   SDealingRange* dr = g_isBullishActive ? GetPointer(g_bullDR) : GetPointer(g_bearDR);
   
   // If CL was recently updated (BOS happened), look for MB
   if(!dr.corrLine.isActive)
      return;
   
   // Look for first candle returning to entry zone
   if(!g_entryZone.isValid)
      return;
   
   // Scan recent candles for MB formation
   for(int i = 2; i <= 10; i++)
   {
      double candleHigh = iHigh(_Symbol, PERIOD_CURRENT, i);
      double candleLow = iLow(_Symbol, PERIOD_CURRENT, i);
      double candleOpen = iOpen(_Symbol, PERIOD_CURRENT, i);
      double candleClose = iClose(_Symbol, PERIOD_CURRENT, i);
      
      // Check if candle entered entry zone
      bool enteredZone = IsPriceInZone(candleHigh, g_entryZone.upperBound, g_entryZone.lowerBound) ||
                         IsPriceInZone(candleLow, g_entryZone.upperBound, g_entryZone.lowerBound);
      
      if(!enteredZone)
         continue;
      
      // Check if previous candles were outside zone
      bool prevOutside = true;
      for(int j = i + 1; j <= i + 3; j++)
      {
         double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, j);
         double prevLow = iLow(_Symbol, PERIOD_CURRENT, j);
         
         if(IsPriceInZone(prevHigh, g_entryZone.upperBound, g_entryZone.lowerBound) ||
            IsPriceInZone(prevLow, g_entryZone.upperBound, g_entryZone.lowerBound))
         {
            prevOutside = false;
            break;
         }
      }
      
      if(!prevOutside)
         continue;
      
      // This could be an MB
      ENUM_MB_TYPE mbType;
      double mbTop, mbBottom;
      
      if(g_isBullishActive)
      {
         // Bullish MB
         mbType = MB_BULLISH;
         mbTop = MathMax(candleOpen, candleClose);
         mbBottom = candleLow;
      }
      else
      {
         // Bearish MB
         mbType = MB_BEARISH;
         mbTop = candleHigh;
         mbBottom = MathMin(candleOpen, candleClose);
      }
      
      // Check if already exists
      bool exists = false;
      for(int k = 0; k < g_mbCount; k++)
      {
         if(MathAbs(g_mitigationBlocks[k].top - mbTop) < _Point * 20)
         {
            exists = true;
            break;
         }
      }
      
      if(exists)
         continue;
      
      // Add MB
      if(g_mbCount >= g_maxMBs)
         RemoveOldestMB();
      
      int idx = g_mbCount;
      
      g_mitigationBlocks[idx].Reset();
      g_mitigationBlocks[idx].type = mbType;
      g_mitigationBlocks[idx].top = mbTop;
      g_mitigationBlocks[idx].bottom = mbBottom;
      g_mitigationBlocks[idx].time = iTime(_Symbol, PERIOD_CURRENT, i);
      g_mitigationBlocks[idx].barIndex = i;
      g_mitigationBlocks[idx].bosTime = dr.corrLine.extremeTime;
      g_mitigationBlocks[idx].bosLevel = dr.corrLine.extremePrice;
      g_mitigationBlocks[idx].objName = GeneratePDObjectName("MB");
      g_mitigationBlocks[idx].labelName = g_mitigationBlocks[idx].objName + "_lbl";
      
      g_mbCount++;
      
      if(InpShowOrderBlocks)
         ReDrawMitigationBlock(idx);
      
      // Only add one MB per BOS
      break;
   }
}

//+------------------------------------------------------------------+
//|              SECTION 5: CLEANUP FUNCTIONS                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Remove Oldest Order Block                                         |
//+------------------------------------------------------------------+
void RemoveOldestOB()
{
   if(g_obCount == 0)
      return;
   
   int oldestIdx = 0;
   datetime oldestTime = g_orderBlocks[0].time;
   
   for(int i = 1; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].time < oldestTime)
      {
         oldestTime = g_orderBlocks[i].time;
         oldestIdx = i;
      }
   }
   
   DeleteObject(g_orderBlocks[oldestIdx].objName);
   DeleteObject(g_orderBlocks[oldestIdx].labelName);
   
   for(int i = oldestIdx; i < g_obCount - 1; i++)
      g_orderBlocks[i] = g_orderBlocks[i + 1];
   
   g_obCount--;
}

//+------------------------------------------------------------------+
//| Remove Oldest Breaker                                             |
//+------------------------------------------------------------------+
void RemoveOldestBreaker()
{
   if(g_breakerCount == 0)
      return;
   
   int oldestIdx = 0;
   datetime oldestTime = g_breakerBlocks[0].time;
   
   for(int i = 1; i < g_breakerCount; i++)
   {
      if(g_breakerBlocks[i].time < oldestTime)
      {
         oldestTime = g_breakerBlocks[i].time;
         oldestIdx = i;
      }
   }
   
   DeleteObject(g_breakerBlocks[oldestIdx].objName);
   DeleteObject(g_breakerBlocks[oldestIdx].labelName);
   
   for(int i = oldestIdx; i < g_breakerCount - 1; i++)
      g_breakerBlocks[i] = g_breakerBlocks[i + 1];
   
   g_breakerCount--;
}

//+------------------------------------------------------------------+
//| Remove Oldest Mitigation Block                                    |
//+------------------------------------------------------------------+
void RemoveOldestMB()
{
   if(g_mbCount == 0)
      return;
   
   int oldestIdx = 0;
   datetime oldestTime = g_mitigationBlocks[0].time;
   
   for(int i = 1; i < g_mbCount; i++)
   {
      if(g_mitigationBlocks[i].time < oldestTime)
      {
         oldestTime = g_mitigationBlocks[i].time;
         oldestIdx = i;
      }
   }
   
   DeleteObject(g_mitigationBlocks[oldestIdx].objName);
   DeleteObject(g_mitigationBlocks[oldestIdx].labelName);
   
   for(int i = oldestIdx; i < g_mbCount - 1; i++)
      g_mitigationBlocks[i] = g_mitigationBlocks[i + 1];
   
   g_mbCount--;
}

//+------------------------------------------------------------------+
//| Cleanup Order Blocks                                              |
//+------------------------------------------------------------------+
void CleanupOrderBlocks()
{
      datetime cutoffTime = iTime(_Symbol, PERIOD_CURRENT, 0) - (int)(InpOB_MaxAge_Hours * 3600);
   
   // Cleanup OBs
   for(int i = g_obCount - 1; i >= 0; i--)
   {
      if(g_orderBlocks[i].time < cutoffTime || g_orderBlocks[i].status == OB_FAILED)
      {
         DeleteObject(g_orderBlocks[i].objName);
         DeleteObject(g_orderBlocks[i].labelName);
         
         for(int j = i; j < g_obCount - 1; j++)
            g_orderBlocks[j] = g_orderBlocks[j + 1];
         
         g_obCount--;
      }
   }
   
   // Cleanup Breakers
   for(int i = g_breakerCount - 1; i >= 0; i--)
   {
      if(g_breakerBlocks[i].time < cutoffTime)
      {
         DeleteObject(g_breakerBlocks[i].objName);
         DeleteObject(g_breakerBlocks[i].labelName);
         
         for(int j = i; j < g_breakerCount - 1; j++)
            g_breakerBlocks[j] = g_breakerBlocks[j + 1];
         
         g_breakerCount--;
      }
   }
   
   // Cleanup MBs
   for(int i = g_mbCount - 1; i >= 0; i--)
   {
      if(g_mitigationBlocks[i].time < cutoffTime || g_mitigationBlocks[i].isTested)
      {
         DeleteObject(g_mitigationBlocks[i].objName);
         DeleteObject(g_mitigationBlocks[i].labelName);
         
         for(int j = i; j < g_mbCount - 1; j++)
            g_mitigationBlocks[j] = g_mitigationBlocks[j + 1];
         
         g_mbCount--;
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 6: DRAWING FUNCTIONS                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Order Block                                                  |
//+------------------------------------------------------------------+
void RedrawOrderBlock(int index)
{
   if(index >= g_obCount) return;
   if(!ShouldDrawPDElement(PD_ORDER_BLOCK)) return;

   bool isBull = (g_orderBlocks[index].type == OB_BULLISH);
   string label = BuildElementLabel(LAYER_CTF, isBull, "OB");

   datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   DrawOrderBlock(g_orderBlocks[index].objName,
                  g_orderBlocks[index].time,
                  g_orderBlocks[index].top,
                  g_orderBlocks[index].bottom,
                  endTime,
                  g_orderBlocks[index].type,
                  g_orderBlocks[index].status,
                  g_orderBlocks[index].isInstitutional,
                  label);
}

//+------------------------------------------------------------------+
//| Draw Breaker Block                                                |
//+------------------------------------------------------------------+
void ReDrawBreakerBlock(int index)
{
   if(index >= g_breakerCount) return;
   if(!ShouldDrawPDElement(PD_BREAKER_BLOCK)) return;

   bool isBull = (g_breakerBlocks[index].type == BREAKER_BULLISH);
   string label = BuildElementLabel(LAYER_CTF, isBull, "Breaker");

   datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   DrawBreakerBlock(g_breakerBlocks[index].objName,
                    g_breakerBlocks[index].time,
                    g_breakerBlocks[index].top,
                    g_breakerBlocks[index].bottom,
                    endTime,
                    g_breakerBlocks[index].type,
                    label);
}

//+------------------------------------------------------------------+
//| Draw Mitigation Block                                             |
//+------------------------------------------------------------------+
void ReDrawMitigationBlock(int index)
{
   if(index >= g_mbCount) return;
   if(!ShouldDrawPDElement(PD_MITIGATION_BLOCK)) return;

   bool isBull = (g_mitigationBlocks[index].type == MB_BULLISH);
   string label = BuildElementLabel(LAYER_CTF, isBull, "MB");

   datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   DrawMitigationBlock(g_mitigationBlocks[index].objName,
                       g_mitigationBlocks[index].time,
                       g_mitigationBlocks[index].top,
                       g_mitigationBlocks[index].bottom,
                       endTime,
                       g_mitigationBlocks[index].type,
                       label);
}

//+------------------------------------------------------------------+
//| Extend Order Block Rectangles                                     |
//+------------------------------------------------------------------+
void ExtendOrderBlockRectangles()
{
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Extend OBs
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status != OB_FAILED)
      {
         if(ObjectFind(0, g_orderBlocks[i].objName) >= 0)
         {
            ObjectSetInteger(0, g_orderBlocks[i].objName, OBJPROP_TIME, 1, currentTime);
         }
      }
   }
   
   // Extend Breakers
   for(int i = 0; i < g_breakerCount; i++)
   {
      if(!g_breakerBlocks[i].isTested)
      {
         if(ObjectFind(0, g_breakerBlocks[i].objName) >= 0)
         {
            ObjectSetInteger(0, g_breakerBlocks[i].objName, OBJPROP_TIME, 1, currentTime);
         }
      }
   }
   
   // Extend MBs
   for(int i = 0; i < g_mbCount; i++)
   {
      if(!g_mitigationBlocks[i].isTested)
      {
         if(ObjectFind(0, g_mitigationBlocks[i].objName) >= 0)
         {
            ObjectSetInteger(0, g_mitigationBlocks[i].objName, OBJPROP_TIME, 1, currentTime);
         }
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 7: CHECK FUNCTIONS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Price at Order Block                                     |
//+------------------------------------------------------------------+
bool IsPriceAtOrderBlock(bool lookForBullish, int &outIndex)
{
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status == OB_FAILED)
         continue;
      
      bool isBullishOB = (g_orderBlocks[i].type == OB_BULLISH);
      
      if(lookForBullish == isBullishOB)
      {
         if(price >= g_orderBlocks[i].bottom && price <= g_orderBlocks[i].top)
         {
            outIndex = i;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Price at Breaker Block                                   |
//+------------------------------------------------------------------+
bool IsPriceAtBreakerBlock(bool lookForBullish, int &outIndex)
{
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_breakerCount; i++)
   {
      if(g_breakerBlocks[i].isTested)
         continue;
      
      bool isBullishBreaker = (g_breakerBlocks[i].type == BREAKER_BULLISH);
      
      if(lookForBullish == isBullishBreaker)
      {
         if(price >= g_breakerBlocks[i].bottom && price <= g_breakerBlocks[i].top)
         {
            outIndex = i;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Price at Mitigation Block                                |
//+------------------------------------------------------------------+
bool IsPriceAtMitigationBlock(bool lookForBullish, int &outIndex)
{
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_mbCount; i++)
   {
      if(g_mitigationBlocks[i].isTested)
         continue;
      
      bool isBullishMB = (g_mitigationBlocks[i].type == MB_BULLISH);
      
      if(lookForBullish == isBullishMB)
      {
         if(price >= g_mitigationBlocks[i].bottom && price <= g_mitigationBlocks[i].top)
         {
            outIndex = i;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Best Order Block (Fresh, closest to price)                    |
//+------------------------------------------------------------------+
int GetBestOrderBlock(bool isBullish)
{
   int bestIdx = -1;
   double bestDistance = DBL_MAX;
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status == OB_FAILED)
         continue;
      
      bool isBullishOB = (g_orderBlocks[i].type == OB_BULLISH);
      if(isBullish != isBullishOB)
         continue;
      
      // Prefer fresh
      if(g_orderBlocks[i].status == OB_FRESH)
      {
         double distance = MathAbs(price - g_orderBlocks[i].midpoint);
         if(distance < bestDistance)
         {
            bestDistance = distance;
            bestIdx = i;
         }
      }
   }
   
   // If no fresh, take tested
   if(bestIdx < 0)
   {
      for(int i = 0; i < g_obCount; i++)
      {
         if(g_orderBlocks[i].status == OB_TESTED)
         {
            bool isBullishOB = (g_orderBlocks[i].type == OB_BULLISH);
            if(isBullish == isBullishOB)
            {
               double distance = MathAbs(price - g_orderBlocks[i].midpoint);
               if(distance < bestDistance)
               {
                  bestDistance = distance;
                  bestIdx = i;
               }
            }
         }
      }
   }
   
   return bestIdx;
}

//+------------------------------------------------------------------+
//| Count Fresh Order Blocks                                          |
//+------------------------------------------------------------------+
int CountFreshOrderBlocks(bool isBullish)
{
   int count = 0;
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status == OB_FRESH)
      {
         bool isBullishOB = (g_orderBlocks[i].type == OB_BULLISH);
         if(isBullish == isBullishOB)
            count++;
      }
   }
   return count;
}


//+------------------------------------------------------------------+
//| Get Best Breaker Block                                            |
//+------------------------------------------------------------------+
int GetBestBreakerBlock(bool isBullish)
{
   int bestIdx = -1;
   double bestPrice = 0;
   
   for(int i = 0; i < g_breakerCount; i++)
   {
      bool isBullishBreaker = (g_breakerBlocks[i].type == BREAKER_BULLISH);
      if(isBullish != isBullishBreaker)
         continue;
      
      if(g_breakerBlocks[i].isTested)
         continue;
      
      double price = g_breakerBlocks[i].top;
      if(bestIdx < 0)
      {
         bestIdx = i;
         bestPrice = price;
      }
   }
   
   return bestIdx;
}

//+------------------------------------------------------------------+
//| Get Best Mitigation Block                                         |
//+------------------------------------------------------------------+
int GetBestMitigationBlock(bool isBullish)
{
   int bestIdx = -1;
   
   for(int i = 0; i < g_mbCount; i++)
   {
      bool isBullishMB = (g_mitigationBlocks[i].type == MB_BULLISH);
      if(isBullish != isBullishMB)
         continue;
      
      if(g_mitigationBlocks[i].isTested)
         continue;
      
      bestIdx = i;
      break;
   }
   
   return bestIdx;
}


//+------------------------------------------------------------------+
//| Detect Rejection Blocks                                           |
//+------------------------------------------------------------------+
void DetectRejectionBlocks()
{
   double atr = GetATR();
   if(atr <= 0) return;
   
   for(int i = 2; i <= 15; i++)
   {
      double open  = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      double high  = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low   = iLow(_Symbol, PERIOD_CURRENT, i);
      
      double bodyTop    = MathMax(open, close);
      double bodyBottom = MathMin(open, close);
      double bodySize   = bodyTop - bodyBottom;
      double upperWick  = high - bodyTop;
      double lowerWick  = bodyBottom - low;
      double candleRange = high - low;
      
      // Skip tiny candles
      if(bodySize < _Point * 5 || candleRange < atr * 0.3)
         continue;
      
      // Check for BULLISH rejection (long lower wick = buying pressure)
      if(lowerWick > bodySize * 2.0 && lowerWick > upperWick * 1.5)
      {
         // Check duplicate
         bool exists = false;
         for(int k = 0; k < g_rejectionCount; k++)
         {
            if(MathAbs(g_rejectionBlocks[k].wickBottom - low) < _Point * 10)
            { exists = true; break; }
         }
         if(exists) continue;
         
         if(g_rejectionCount >= g_maxRejections) break;
         
         int idx = g_rejectionCount;
         g_rejectionBlocks[idx].Reset();
         g_rejectionBlocks[idx].direction = DIR_BULLISH;
         g_rejectionBlocks[idx].wickTop = high;
         g_rejectionBlocks[idx].wickBottom = low;
         g_rejectionBlocks[idx].bodyTop = bodyTop;
         g_rejectionBlocks[idx].bodyBottom = bodyBottom;
         g_rejectionBlocks[idx].time = iTime(_Symbol, PERIOD_CURRENT, i);
         g_rejectionBlocks[idx].barIndex = i;
         g_rejectionBlocks[idx].rejectionRatio = lowerWick / bodySize;
         g_rejectionBlocks[idx].objName = GeneratePDObjectName("RejBlk");
         g_rejectionCount++;
      }
      
      // Check for BEARISH rejection (long upper wick = selling pressure)
      if(upperWick > bodySize * 2.0 && upperWick > lowerWick * 1.5)
      {
         bool exists = false;
         for(int k = 0; k < g_rejectionCount; k++)
         {
            if(MathAbs(g_rejectionBlocks[k].wickTop - high) < _Point * 10)
            { exists = true; break; }
         }
         if(exists) continue;
         
         if(g_rejectionCount >= g_maxRejections) break;
         
         int idx = g_rejectionCount;
         g_rejectionBlocks[idx].Reset();
         g_rejectionBlocks[idx].direction = DIR_BEARISH;
         g_rejectionBlocks[idx].wickTop = high;
         g_rejectionBlocks[idx].wickBottom = low;
         g_rejectionBlocks[idx].bodyTop = bodyTop;
         g_rejectionBlocks[idx].bodyBottom = bodyBottom;
         g_rejectionBlocks[idx].time = iTime(_Symbol, PERIOD_CURRENT, i);
         g_rejectionBlocks[idx].barIndex = i;
         g_rejectionBlocks[idx].rejectionRatio = upperWick / bodySize;
         g_rejectionBlocks[idx].objName = GeneratePDObjectName("RejBlk");
         g_rejectionCount++;
      }
   }
}


#endif // ICT_ORDERBLOCKS_MQH