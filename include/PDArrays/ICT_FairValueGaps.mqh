//+------------------------------------------------------------------+
//|                      ICT_FairValueGaps.mqh                        |
//|       Fair Value Gaps, Volume Imbalance, Liquidity Voids           |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_FAIRVALUEGAPS_MQH
#define ICT_FAIRVALUEGAPS_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize PD Arrays - FVG                                        |
//+------------------------------------------------------------------+
bool InitializePDArrays_FVG()
{
   ArrayResize(g_fvgList, g_maxFVGs);
   ArrayResize(g_viList, g_maxVIs);
   ArrayResize(g_voidList, g_maxVoids);
   
   g_fvgCount = 0;
   g_viCount = 0;
   g_voidCount = 0;
   
   Print("FVG System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: FAIR VALUE GAP DETECTION                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect All Fair Value Gaps                                        |
//+------------------------------------------------------------------+
void DetectAllFVGs()
{
   if(!InpDetectFVG)
      return;
   
   double atr = GetATR();
   if(atr <= 0) return;
   
   // Scan for new FVGs
   for(int i = InpFVG_Lookback; i > 2; i--)
   {
      DetectBullishFVG(i, atr);
      DetectBearishFVG(i, atr);
   }
   
   // Update FVG statuses
   UpdateFVGStatuses();
   
   // Cleanup old FVGs
   CleanupFVGs();
   
   // Detect Volume Imbalances
   if(InpDetectVolumeImbalance)
      DetectVolumeImbalances();
   
   // Detect Liquidity Voids
   if(InpDetectLiquidityVoid)
      DetectLiquidityVoids();
         // Update Volume Imbalance statuses
   UpdateVIStatuses();
}

//+------------------------------------------------------------------+
//| Detect Bullish FVG                                                |
//+------------------------------------------------------------------+
void DetectBullishFVG(int barIndex, double atr)
{
   // Bullish FVG: Gap between candle 1's high and candle 3's low
   // Candle 2 must be bullish (up candle)
   
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, barIndex + 1);   // Candle before gap
   double low3 = iLow(_Symbol, PERIOD_CURRENT, barIndex - 1);      // Candle after gap
   
   // Check if candle 2 (middle) is bullish
   double open2 = iOpen(_Symbol, PERIOD_CURRENT, barIndex);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, barIndex);
   
   if(InpFVG_RequireMiddleCandleDir && close2 <= open2)
      return;
   
   // Check for gap
   if(low3 <= high1) // No gap
      return;
   
   double gapSize = low3 - high1;
   
   // Check minimum size
   if(gapSize < atr * InpFVG_MinSizeATR)
      return;
   
   // Valid Bullish FVG
   double fvgTop = low3;
   double fvgBottom = high1;
   double ce = (fvgTop + fvgBottom) / 2.0; // 50% level
   
   // Check if already exists
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].type == FVG_BULLISH &&
         MathAbs(g_fvgList[i].top - fvgTop) < atr * 0.1)
         return;
   }
   
   // Add new FVG
   if(g_fvgCount >= g_maxFVGs)
      RemoveOldestFVG();
   
   int idx = g_fvgCount;
   
   g_fvgList[idx].Reset();
   g_fvgList[idx].type = FVG_BULLISH;
   g_fvgList[idx].status = FVG_OPEN;
   g_fvgList[idx].top = fvgTop;
   g_fvgList[idx].bottom = fvgBottom;
   g_fvgList[idx].ce = ce;
   g_fvgList[idx].time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   g_fvgList[idx].barIndex = barIndex;
   
      // Causal tagging
   if(g_lastSMEvent.valid && g_lastSMEvent.direction == DIR_BULLISH)
   {
      int evBar = iBarShift(_Symbol, PERIOD_CURRENT, g_lastSMEvent.time, false);
      if(evBar >= 0 && MathAbs(evBar - barIndex) <= 3)
      {
         g_fvgList[idx].causalTag = g_lastSMEvent.tag;
         g_fvgList[idx].bornDirection = DIR_BULLISH;
         g_fvgList[idx].birthBar = barIndex;
      }
   }
   
   g_fvgList[idx].fillPercent = 0;
   g_fvgList[idx].objName = GeneratePDObjectName("FVG");
   g_fvgList[idx].labelName = g_fvgList[idx].objName + "_lbl";
   
   
   g_fvgCount++;
   
   if(InpShowFVG)
      RedrawFVG(idx);
}

//+------------------------------------------------------------------+
//| Detect Bearish FVG                                                |
//+------------------------------------------------------------------+
void DetectBearishFVG(int barIndex, double atr)
{
   // Bearish FVG: Gap between candle 1's low and candle 3's high
   // Candle 2 must be bearish (down candle)
   
   double low1 = iLow(_Symbol, PERIOD_CURRENT, barIndex + 1);
   double high3 = iHigh(_Symbol, PERIOD_CURRENT, barIndex - 1);
   
   double open2 = iOpen(_Symbol, PERIOD_CURRENT, barIndex);
   double close2 = iClose(_Symbol, PERIOD_CURRENT, barIndex);
   
   if(InpFVG_RequireMiddleCandleDir && close2 >= open2)
      return;
   
   // Check for gap
   if(high3 >= low1) // No gap
      return;
   
   double gapSize = low1 - high3;
   
   if(gapSize < atr * InpFVG_MinSizeATR)
      return;
   
   // Valid Bearish FVG
   double fvgTop = low1;
   double fvgBottom = high3;
   double ce = (fvgTop + fvgBottom) / 2.0;
   
   // Check if already exists
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].type == FVG_BEARISH &&
         MathAbs(g_fvgList[i].bottom - fvgBottom) < atr * 0.1)
         return;
   }
   
   // Add new FVG
   if(g_fvgCount >= g_maxFVGs)
      RemoveOldestFVG();
   
   int idx = g_fvgCount;
   
   g_fvgList[idx].Reset();
   g_fvgList[idx].type = FVG_BEARISH;
   g_fvgList[idx].status = FVG_OPEN;
   g_fvgList[idx].top = fvgTop;
   g_fvgList[idx].bottom = fvgBottom;
   g_fvgList[idx].ce = ce;
   g_fvgList[idx].time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   g_fvgList[idx].barIndex = barIndex;
   
      // Causal tagging
   if(g_lastSMEvent.valid && g_lastSMEvent.direction == DIR_BEARISH)
   {
      int evBar = iBarShift(_Symbol, PERIOD_CURRENT, g_lastSMEvent.time, false);
      if(evBar >= 0 && MathAbs(evBar - barIndex) <= 3)
      {
         g_fvgList[idx].causalTag = g_lastSMEvent.tag;
         g_fvgList[idx].bornDirection = DIR_BEARISH;
         g_fvgList[idx].birthBar = barIndex;
      }
   }
   
   g_fvgList[idx].fillPercent = 0;
   g_fvgList[idx].objName = GeneratePDObjectName("FVG");
   g_fvgList[idx].labelName = g_fvgList[idx].objName + "_lbl";
   
   g_fvgCount++;
   
   if(InpShowFVG)
      RedrawFVG(idx);
}

//+------------------------------------------------------------------+
//|              SECTION 3: FVG STATUS UPDATES                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update FVG Statuses                                               |
//+------------------------------------------------------------------+
void UpdateFVGStatuses()
{
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double atr = GetATR();
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status == FVG_FULLY_FILLED)
         continue;
      
      if(g_fvgList[i].type == FVG_BULLISH)
      {
         // Bullish FVG fills when price goes down into it
         if(currentPrice <= g_fvgList[i].top)
         {
            // Calculate fill percentage
            double fillLevel = MathMax(currentPrice, g_fvgList[i].bottom);
            g_fvgList[i].fillPercent = (g_fvgList[i].top - fillLevel) / 
                                        g_fvgList[i].Height() * 100.0;
            
            // Check CE reached
            if(currentPrice <= g_fvgList[i].ce && g_fvgList[i].ceReachedTime == 0)
            {
               g_fvgList[i].ceReachedTime = currentTime;
               g_fvgList[i].status = FVG_PARTIALLY_FILLED;
               
               if(InpShowFVG)
                  RedrawFVG(i);
            }
            
            // Check fully filled
            if(currentPrice <= g_fvgList[i].bottom)
            {
               g_fvgList[i].status = FVG_FULLY_FILLED;
               g_fvgList[i].filledTime = currentTime;
               
               if(InpShowFVG)
                  RedrawFVG(i);
            }
         }
      }
      else // BEARISH
      {
         // Bearish FVG fills when price goes up into it
         if(currentPrice >= g_fvgList[i].bottom)
         {
            double fillLevel = MathMin(currentPrice, g_fvgList[i].top);
            g_fvgList[i].fillPercent = (fillLevel - g_fvgList[i].bottom) / 
                                        g_fvgList[i].Height() * 100.0;
            
            if(currentPrice >= g_fvgList[i].ce && g_fvgList[i].ceReachedTime == 0)
            {
               g_fvgList[i].ceReachedTime = currentTime;
               g_fvgList[i].status = FVG_PARTIALLY_FILLED;
               
               if(InpShowFVG)
                  RedrawFVG(i);
            }
            
            if(currentPrice >= g_fvgList[i].top)
            {
               g_fvgList[i].status = FVG_FULLY_FILLED;
               g_fvgList[i].filledTime = currentTime;
               
               if(InpShowFVG)
                  RedrawFVG(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 4: VOLUME IMBALANCE                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Volume Imbalances                                          |
//+------------------------------------------------------------------+
void DetectVolumeImbalances()
{
   double atr = GetATR();
   
   // Volume Imbalance = Gap between candle BODIES (not wicks)
   
   for(int i = 10; i > 2; i--)
   {
      // Bullish VI
      double bodyBottom1 = BodyBottom(PERIOD_CURRENT, i + 1);
      double bodyTop3 = BodyTop(PERIOD_CURRENT, i - 1);
      
      if(bodyTop3 > bodyBottom1)
      {
         double gapSize = bodyTop3 - bodyBottom1;
         if(gapSize >= atr * 0.1)
         {
            AddVolumeImbalance(VI_BULLISH, bodyTop3, bodyBottom1, 
                               iTime(_Symbol, PERIOD_CURRENT, i), i);
         }
      }
      
      // Bearish VI
      double bodyTop1 = BodyTop(PERIOD_CURRENT, i + 1);
      double bodyBottom3 = BodyBottom(PERIOD_CURRENT, i - 1);
      
      if(bodyBottom3 < bodyTop1)
      {
         double gapSize = bodyTop1 - bodyBottom3;
         if(gapSize >= atr * 0.1)
         {
            AddVolumeImbalance(VI_BEARISH, bodyTop1, bodyBottom3,
                               iTime(_Symbol, PERIOD_CURRENT, i), i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Volume Imbalance Fill Status                               |
//+------------------------------------------------------------------+
void UpdateVIStatuses()
{
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = g_viCount - 1; i >= 0; i--)
   {
      if(g_viList[i].isFilled)
         continue;
      
      if(g_viList[i].type == VI_BULLISH)
      {
         // Bullish VI fills when price drops into it
         if(currentPrice <= g_viList[i].bottom)
         {
            g_viList[i].isFilled = true;
            // Dim the visual
            if(ObjectFind(0, g_viList[i].objName) >= 0)
               ObjectSetInteger(0, g_viList[i].objName, OBJPROP_COLOR, clrDimGray);
         }
      }
      else // VI_BEARISH
      {
         // Bearish VI fills when price rises into it
         if(currentPrice >= g_viList[i].top)
         {
            g_viList[i].isFilled = true;
            if(ObjectFind(0, g_viList[i].objName) >= 0)
               ObjectSetInteger(0, g_viList[i].objName, OBJPROP_COLOR, clrDimGray);
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Add Volume Imbalance                                              |
//+------------------------------------------------------------------+
void AddVolumeImbalance(ENUM_VI_TYPE type, double top, double bottom,
                        datetime time, int barIndex)
{
   for(int i = 0; i < g_viCount; i++)
   {
      if(g_viList[i].type == type &&
         MathAbs(g_viList[i].top - top) < _Point * 20)
         return;
   }
   if(g_viCount >= g_maxVIs) return;

   int idx = g_viCount;
   g_viList[idx].Reset();
   g_viList[idx].type = type;
   g_viList[idx].top = top;
   g_viList[idx].bottom = bottom;
   g_viList[idx].time = time;
   g_viList[idx].barIndex = barIndex;
   g_viList[idx].isFilled = false;
   g_viList[idx].objName = GeneratePDObjectName("VI");
   
      // Causal tagging
   if(g_lastSMEvent.valid)
   {
      int evBar = iBarShift(_Symbol, PERIOD_CURRENT, g_lastSMEvent.time, false);
      if(evBar >= 0 && MathAbs(evBar - barIndex) <= 3)
      {
         g_viList[idx].causalTag = g_lastSMEvent.tag;
         g_viList[idx].bornDirection = (type == VI_BULLISH) ? DIR_BULLISH : DIR_BEARISH;
         g_viList[idx].birthBar = barIndex;
      }
   }
   
   g_viCount++;

   // Draw VI only if allowed by current framework
   if(InpShowFVG && ShouldDrawPDElement(PD_VOLUME_IMBALANCE))
   {
      datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      bool isBull = (type == VI_BULLISH);
      color viColor = isBull ? ColorLighten(InpBullFVG_Color, 30)
                             : ColorLighten(InpBearFVG_Color, 30);
      DrawRectangle(g_viList[idx].objName, time, top, endTime, bottom, viColor, true);

      // Label
      string lbl = BuildElementLabel(LAYER_CTF, isBull, "VI");
      string lblName = g_viList[idx].objName + "_lbl";
      double mid = (top + bottom) / 2.0;
      DrawText(lblName, time, mid, lbl, clrWhite, 7, ANCHOR_LEFT);
   }
}

//+------------------------------------------------------------------+
//|              SECTION 5: LIQUIDITY VOID                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Liquidity Voids                                            |
//+------------------------------------------------------------------+
void DetectLiquidityVoids()
{
   double atr = GetATR();
   if(atr <= 0) return;
   
   // Liquidity Void = Large single-candle move with little overlap
   
   for(int i = 5; i > 1; i--)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      double range = high - low;
      
      if(range < atr * InpVoid_MinSizeATR)
         continue;
      
      // Check for single-direction move
      double open = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      
      // Check overlap with previous and next candles
      double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
      double prevLow = iLow(_Symbol, PERIOD_CURRENT, i + 1);
      double nextHigh = iHigh(_Symbol, PERIOD_CURRENT, i - 1);
      double nextLow = iLow(_Symbol, PERIOD_CURRENT, i - 1);
      
      if(close > open) // Bullish candle
      {
         // Void is the part that wasn't overlapped
         double voidTop = high;
         double voidBottom = MathMax(prevHigh, nextHigh);
         
         if(voidTop > voidBottom + atr * 0.2)
         {
            AddLiquidityVoid(VOID_BULLISH, voidTop, voidBottom,
                            iTime(_Symbol, PERIOD_CURRENT, i), i);
         }
      }
      else // Bearish candle
      {
         double voidTop = MathMin(prevLow, nextLow);
         double voidBottom = low;
         
         if(voidTop > voidBottom + atr * 0.2)
         {
            AddLiquidityVoid(VOID_BEARISH, voidTop, voidBottom,
                            iTime(_Symbol, PERIOD_CURRENT, i), i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Add Liquidity Void                                                |
//+------------------------------------------------------------------+
void AddLiquidityVoid(ENUM_VOID_TYPE type, double top, double bottom,
                      datetime time, int barIndex)
{
   // Check duplicate
   for(int i = 0; i < g_voidCount; i++)
   {
      if(g_voidList[i].type == type &&
         MathAbs(g_voidList[i].top - top) < _Point * 30)
         return;
   }
   
   if(g_voidCount >= g_maxVoids)
      return;
   
   int idx = g_voidCount;
   
   g_voidList[idx].Reset();
   g_voidList[idx].type = type;
   g_voidList[idx].top = top;
   g_voidList[idx].bottom = bottom;
   g_voidList[idx].startTime = time;
   g_voidList[idx].startBar = barIndex;
   g_voidList[idx].isFilled = false;
   g_voidList[idx].objName = GeneratePDObjectName("Void");
   
      // Causal tagging
   if(g_lastSMEvent.valid)
   {
      int evBar = iBarShift(_Symbol, PERIOD_CURRENT, g_lastSMEvent.time, false);
      if(evBar >= 0 && MathAbs(evBar - barIndex) <= 3)
      {
         g_voidList[idx].causalTag = g_lastSMEvent.tag;
         g_voidList[idx].bornDirection = (type == VOID_BULLISH) ? DIR_BULLISH : DIR_BEARISH;
         g_voidList[idx].birthBar = barIndex;
      }
   }
   
   g_voidCount++;
}

//+------------------------------------------------------------------+
//|              SECTION 6: CLEANUP                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Remove Oldest FVG                                                 |
//+------------------------------------------------------------------+
void RemoveOldestFVG()
{
   if(g_fvgCount == 0)
      return;
   
   int oldestIdx = 0;
   datetime oldestTime = g_fvgList[0].time;
   
   for(int i = 1; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].time < oldestTime)
      {
         oldestTime = g_fvgList[i].time;
         oldestIdx = i;
      }
   }
   
   DeleteObject(g_fvgList[oldestIdx].objName);
   DeleteObject(g_fvgList[oldestIdx].labelName);
   
   for(int i = oldestIdx; i < g_fvgCount - 1; i++)
      g_fvgList[i] = g_fvgList[i + 1];
   
   g_fvgCount--;
}

//+------------------------------------------------------------------+
//| Cleanup FVGs                                                      |
//+------------------------------------------------------------------+
void CleanupFVGs()
{
   datetime cutoffTime = iTime(_Symbol, PERIOD_CURRENT, 0) - 86400 * 2;
   
   for(int i = g_fvgCount - 1; i >= 0; i--)
   {
      if(g_fvgList[i].time < cutoffTime || g_fvgList[i].status == FVG_FULLY_FILLED)
      {
         DeleteObject(g_fvgList[i].objName);
         DeleteObject(g_fvgList[i].labelName);
         
         for(int j = i; j < g_fvgCount - 1; j++)
            g_fvgList[j] = g_fvgList[j + 1];
         
         g_fvgCount--;
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 7: DRAWING                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw FVG                                                          |
//+------------------------------------------------------------------+
void RedrawFVG(int index)
{
   if(index >= g_fvgCount) return;
   if(!ShouldDrawPDElement(PD_FVG)) return;

   bool isBull = (g_fvgList[index].type == FVG_BULLISH);
   string label = BuildElementLabel(LAYER_CTF, isBull, "FVG");

   datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   DrawFVG(g_fvgList[index].objName,
           g_fvgList[index].time,
           g_fvgList[index].top,
           g_fvgList[index].bottom,
           endTime,
           g_fvgList[index].type,
           g_fvgList[index].status,
           g_fvgList[index].ce,
           label);
   // Note: removed redundant _dir label (now covered by main label)
}
//+------------------------------------------------------------------+
//| Extend FVG Rectangles                                             |
//+------------------------------------------------------------------+
void ExtendFVGRectangles()
{
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status != FVG_FULLY_FILLED)
      {
         if(ObjectFind(0, g_fvgList[i].objName) >= 0)
         {
            ObjectSetInteger(0, g_fvgList[i].objName, OBJPROP_TIME, 1, currentTime);
         }
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 8: CHECK FUNCTIONS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Price in FVG                                             |
//+------------------------------------------------------------------+
bool IsPriceInFVG(bool lookForBullish, int &outIndex)
{
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status == FVG_FULLY_FILLED)
         continue;
      
      bool isBullishFVG = (g_fvgList[i].type == FVG_BULLISH);
      
      if(lookForBullish == isBullishFVG)
      {
         if(price >= g_fvgList[i].bottom && price <= g_fvgList[i].top)
         {
            outIndex = i;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Price at FVG Consequent Encroachment                     |
//+------------------------------------------------------------------+
bool IsPriceAtFVGCE(bool lookForBullish, int causalTag, int &outIndex)
{
   outIndex = -1;
   if(!InpDetectFVG || !InpFVG_ShowCE)
      return false;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double atr = GetATR();
   double tol = (atr > 0) ? atr * 0.03 : _Point * 10;

   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status == FVG_FULLY_FILLED)
         continue;

      bool bullFVG = (g_fvgList[i].type == FVG_BULLISH);
      if(bullFVG != lookForBullish)
         continue;

      if(causalTag >= 0 && g_fvgList[i].causalTag != causalTag)
         continue;

      if(MathAbs(price - g_fvgList[i].ce) <= tol)
      {
         outIndex = i;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if Price at Volume Imbalance                                |
//+------------------------------------------------------------------+
bool IsPriceAtVolumeImbalance(bool lookForBullish, int causalTag, int &outIndex)
{
   outIndex = -1;
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);

   for(int i = 0; i < g_viCount; i++)
   {
      if(g_viList[i].isFilled)
         continue;

      bool bullVI = (g_viList[i].type == VI_BULLISH);
      if(bullVI != lookForBullish)
         continue;

      if(causalTag >= 0 && g_viList[i].causalTag != causalTag)
         continue;

      double top = MathMax(g_viList[i].top, g_viList[i].bottom);
      double bottom = MathMin(g_viList[i].top, g_viList[i].bottom);
      if(price >= bottom && price <= top)
      {
         outIndex = i;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if Price at Liquidity Void                                  |
//+------------------------------------------------------------------+
bool IsPriceAtLiquidityVoid(bool lookForBullish, int causalTag, int &outIndex)
{
   outIndex = -1;
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);

   for(int i = 0; i < g_voidCount; i++)
   {
      if(g_voidList[i].isFilled)
         continue;

      bool bullVoid = (g_voidList[i].type == VOID_BULLISH);
      if(bullVoid != lookForBullish)
         continue;

      if(causalTag >= 0 && g_voidList[i].causalTag != causalTag)
         continue;

      double top = MathMax(g_voidList[i].top, g_voidList[i].bottom);
      double bottom = MathMin(g_voidList[i].top, g_voidList[i].bottom);
      if(price >= bottom && price <= top)
      {
         outIndex = i;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if Price in Inverse FVG (IFVG)                              |
//+------------------------------------------------------------------+
bool IsPriceInIFVG(bool lookForBullish, int causalTag, int &outIndex)
{
   outIndex = -1;
   if(!InpDetectFVG || !InpFVG_DetectInverse)
      return false;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double atr = GetATR();
   if(atr <= 0)
      return false;

   double breakBuffer = MathMax(_Point * 2, atr * 0.02);

   for(int i = 0; i < g_fvgCount; i++)
   {
      if(causalTag >= 0 && g_fvgList[i].causalTag != causalTag)
         continue;

      // IFVG direction is opposite to source FVG type
      bool ifvgBull = (g_fvgList[i].type == FVG_BEARISH);
      if(ifvgBull != lookForBullish)
         continue;

      // Need mature/engaged source FVG
      if(g_fvgList[i].status == FVG_OPEN)
         continue;

      int ageBars = iBarShift(_Symbol, PERIOD_CURRENT, g_fvgList[i].time, false);
      if(ageBars < 2)
         continue;

      int scanBars = MathMin(ageBars, InpFVG_Lookback * 12);
      bool broken = false;

      if(lookForBullish)
      {
         for(int b = 1; b <= scanBars; b++)
         {
            double c = iClose(_Symbol, PERIOD_CURRENT, b);
            if(c > g_fvgList[i].top + breakBuffer && IsDisplacementCandle(PERIOD_CURRENT, b, atr))
            {
               broken = true;
               break;
            }
         }
      }
      else
      {
         for(int b = 1; b <= scanBars; b++)
         {
            double c = iClose(_Symbol, PERIOD_CURRENT, b);
            if(c < g_fvgList[i].bottom - breakBuffer && IsDisplacementCandle(PERIOD_CURRENT, b, atr))
            {
               broken = true;
               break;
            }
         }
      }

      if(!broken)
         continue;

      double top = MathMax(g_fvgList[i].top, g_fvgList[i].bottom);
      double bottom = MathMin(g_fvgList[i].top, g_fvgList[i].bottom);
      if(price >= bottom && price <= top)
      {
         outIndex = i;
         return true;
      }
   }

   return false;
}



//+------------------------------------------------------------------+
//| Get Open FVG Count                                                |
//+------------------------------------------------------------------+
int GetOpenFVGCount(bool isBullish)
{
   int count = 0;
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status == FVG_OPEN)
      {
         bool isBullishFVG = (g_fvgList[i].type == FVG_BULLISH);
         if(isBullish == isBullishFVG)
            count++;
      }
   }
   return count;
}



#endif // ICT_FAIRVALUEGAPS_MQH