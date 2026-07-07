//+------------------------------------------------------------------+
//|                      ICT_JudasSwing.mqh                           |
//|               Judas Swing / False Breakout Detection               |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_JUDASSWING_MQH
#define ICT_JUDASSWING_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: DETECTION                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Judas Swings                                               |
//+------------------------------------------------------------------+
void DetectJudasSwings()
{
   if(!InpDetectJudasSwing)
      return;
   
   double atr = GetATR();
   if(atr <= 0) return;
   
   // Look for Judas swing pattern
   // 1. Sweep of recent swing point
   // 2. Quick reversal with displacement
   // 3. Happens at session open
   
   // Only check during killzone opens
   if(!g_killzone.isActive)
      return;
   
   // Check for bullish Judas (sweep low, reverse up)
   CheckBullishJudas(atr);
   
   // Check for bearish Judas (sweep high, reverse down)
   CheckBearishJudas(atr);
}

//+------------------------------------------------------------------+
//| Check Bullish Judas Swing                                         |
//+------------------------------------------------------------------+
void CheckBullishJudas(double atr)
{
   // Bullish Judas = Sweep below swing low, then reverse up
   
   // Find recent swing low
   double swingLow = g_lastExternalLow;
   datetime swingLowTime = g_lastExternalLowTime;
   
   if(swingLow <= 0)
      return;
   
   // Check if price swept below this level recently
   double prevLow = g_prevBarLow;
   double prevClose = g_prevBarClose;
   double prevHigh = g_prevBarHigh;
   datetime prevTime = g_prevBarTime;
   
   // Sweep condition: Wick below level, close back above
   if(prevLow < swingLow && prevClose > swingLow)
   {
      // Check for displacement reversal
      if(IsDisplacementCandle(PERIOD_CURRENT, 1, atr))
      {
         // Confirmed Bullish Judas
         g_judasSwing.type = JUDAS_BULLISH;
         g_judasSwing.falseBreakLevel = swingLow;
         g_judasSwing.sweptLevel = swingLow;
         g_judasSwing.sweepTime = swingLowTime;
         g_judasSwing.reversalTime = prevTime;
         g_judasSwing.reversalPrice = prevClose;
         g_judasSwing.isConfirmed = true;
         g_judasSwing.tradeDirection = DIR_BULLISH;
         
         // Draw Judas swing
         DrawJudasSwingVisualization();
         
         Print("🔴 BULLISH JUDAS SWING detected! Swept: ", DoubleToString(swingLow, _Digits));
         
         SendAlert("Bullish Judas Swing at " + DoubleToString(swingLow, _Digits), true, false, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Bearish Judas Swing                                         |
//+------------------------------------------------------------------+
void CheckBearishJudas(double atr)
{
   // Bearish Judas = Sweep above swing high, then reverse down
   
   double swingHigh = g_lastExternalHigh;
   datetime swingHighTime = g_lastExternalHighTime;
   
   if(swingHigh <= 0)
      return;
   
   double prevHigh = g_prevBarHigh;
   double prevClose = g_prevBarClose;
   datetime prevTime = g_prevBarTime;
   
   // Sweep condition: Wick above level, close back below
   if(prevHigh > swingHigh && prevClose < swingHigh)
   {
      if(IsDisplacementCandle(PERIOD_CURRENT, 1, atr))
      {
         g_judasSwing.type = JUDAS_BEARISH;
         g_judasSwing.falseBreakLevel = swingHigh;
         g_judasSwing.sweptLevel = swingHigh;
         g_judasSwing.sweepTime = swingHighTime;
         g_judasSwing.reversalTime = prevTime;
         g_judasSwing.reversalPrice = prevClose;
         g_judasSwing.isConfirmed = true;
         g_judasSwing.tradeDirection = DIR_BEARISH;
         
         DrawJudasSwingVisualization();
         
         Print("🔴 BEARISH JUDAS SWING detected! Swept: ", DoubleToString(swingHigh, _Digits));
         
         SendAlert("Bearish Judas Swing at " + DoubleToString(swingHigh, _Digits), true, false, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Judas Swing Visualization                                    |
//+------------------------------------------------------------------+
void DrawJudasSwingVisualization()
{
   string name = g_prefix + "Judas_" + IntegerToString(g_objCount++);
   
   DrawJudasSwing(name,
                  g_judasSwing.sweepTime,
                  g_judasSwing.sweptLevel,
                  g_judasSwing.reversalTime,
                  g_judasSwing.reversalPrice,
                  g_judasSwing.type);
}

//+------------------------------------------------------------------+
//|              SECTION 2: CHECK FUNCTIONS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Has Active Judas Swing                                            |
//+------------------------------------------------------------------+
bool HasActiveJudasSwing()
{
   if(!InpDetectJudasSwing)
      return false;
   
   // Judas is active for a limited time after detection
   if(!g_judasSwing.isConfirmed)
      return false;
   
   // Check if still valid (within lookback)
   int reversalBar = iBarShift(_Symbol, PERIOD_CURRENT, g_judasSwing.reversalTime, false);
   
   return (reversalBar >= 0 && reversalBar <= InpJudasLookback);
}

//+------------------------------------------------------------------+
//| Get Judas Swing Direction                                         |
//+------------------------------------------------------------------+
ENUM_TRADE_DIRECTION GetJudasSwingDirection()
{
   if(!HasActiveJudasSwing())
      return DIR_NONE;
   
   return g_judasSwing.tradeDirection;
}

//+------------------------------------------------------------------+
//| Get Judas Swing Score Bonus                                       |
//+------------------------------------------------------------------+
int GetJudasSwingScoreBonus()
{
   if(!InpDetectJudasSwing)
      return 0;
   
   if(!HasActiveJudasSwing())
      return 0;
   
   // Bonus based on recency
   int reversalBar = iBarShift(_Symbol, PERIOD_CURRENT, g_judasSwing.reversalTime, false);
   
   if(reversalBar <= 3)
      return 15;
   else if(reversalBar <= 5)
      return 10;
   else
      return 5;
}

//+------------------------------------------------------------------+
//| Invalidate Old Judas                                              |
//+------------------------------------------------------------------+
void InvalidateOldJudas()
{
   if(g_judasSwing.type == JUDAS_NONE)
      return;
   
   int reversalBar = iBarShift(_Symbol, PERIOD_CURRENT, g_judasSwing.reversalTime, false);
   
   if(reversalBar > InpJudasLookback)
   {
      g_judasSwing.Reset();
   }
}

#endif // ICT_JUDASSWING_MQH