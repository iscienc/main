//+------------------------------------------------------------------+
//|                          ICT_AMD.mqh                             |
//|       Accumulation, Manipulation, Distribution Detection         |
//|                ICT Unified Professional EA v16.1                |
//+------------------------------------------------------------------+
#ifndef ICT_AMD_MQH
#define ICT_AMD_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool InitializeMarketPhase()
  {
   g_amdPhase.Reset();
   Print("AMD Phase Detection initialized (v16.1 fixed)");
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetAMDRangeHigh()
  {
   double h = 0.0;
   if(g_amdPhase.accumulationHigh > 0.0)
      h = MathMax(h, g_amdPhase.accumulationHigh);
   if(g_amdPhase.manipulationHigh > 0.0)
      h = MathMax(h, g_amdPhase.manipulationHigh);
   if(g_amdPhase.distributionHigh > 0.0)
      h = MathMax(h, g_amdPhase.distributionHigh);
   return h;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetAMDRangeLow()
  {
   double l = DBL_MAX;
   if(g_amdPhase.accumulationLow > 0.0)
      l = MathMin(l, g_amdPhase.accumulationLow);
   if(g_amdPhase.manipulationLow > 0.0)
      l = MathMin(l, g_amdPhase.manipulationLow);
   if(g_amdPhase.distributionLow > 0.0)
      l = MathMin(l, g_amdPhase.distributionLow);
   return (l == DBL_MAX) ? 0.0 : l;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateMarketPhase()
  {
   if(!g_needDetectAMD)
      return;
   DetectAMDPhase();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasJudasPattern()
  {
   if(!g_needDetectJudas)
      return false;
   if(!g_judasSwing.isConfirmed || g_judasSwing.reversalTime <= 0)
      return false;

   int reversalBar = iBarShift(_Symbol, PERIOD_CURRENT, g_judasSwing.reversalTime, false);
   return (reversalBar >= 0 && reversalBar <= InpJudasLookback);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DetectAMDPhase()
{
   double atr = GetATR();
   if(atr <= 0.0) return;

   static ENUM_AMD_PHASE pendingPhase = AMD_UNKNOWN;
   static int pendingCount = 0;

   const int CONFIRM_ACC = 2;
   const int CONFIRM_MANIP = 2;
   const int CONFIRM_DIST = 3;

   int barsToAnalyze = (int)MathMax(5, InpAccumulationBars);
   int highestShift = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, barsToAnalyze, 0);
   int lowestShift = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, barsToAnalyze, 0);
   if(highestShift < 0 || lowestShift < 0) return;

   double rangeHigh = iHigh(_Symbol, PERIOD_CURRENT, highestShift);
   double rangeLow = iLow(_Symbol, PERIOD_CURRENT, lowestShift);
   double currentBarRange = iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0);

   bool hasRecentDisplacement = CheckRecentDisplacement(atr, 10);
   bool hasRecentSweep = CheckRecentSweep(atr, 15);
   bool hasRecentBOS = CheckRecentBOS(20);

   bool accWasSeen = (g_amdPhase.accumulationHigh > 0.0 && g_amdPhase.accumulationLow > 0.0);

   // ✅ FIX: Default to current phase to prevent random resets
   ENUM_AMD_PHASE detectedPhase = g_amdPhase.currentPhase;
   int confidence = g_amdPhase.confidence;

   // ✅ FIX: Strict Phase Progression. Order matters!
   
   // 1. DISTRIBUTION: If we have a BOS, we are in Distribution (trend is active)
   if(hasRecentBOS)
   {
      detectedPhase = AMD_DISTRIBUTION;
      confidence = hasRecentDisplacement ? 85 : 65;
   }
   // 2. MANIPULATION: Sweep without BOS
   else if(hasRecentSweep && !hasRecentBOS)
   {
      detectedPhase = AMD_MANIPULATION;
      confidence = 75;
   }
   // 3. ACCUMULATION: Only if NO BOS and NO Sweep
   else if(!hasRecentBOS && !hasRecentSweep)
   {
      if(currentBarRange < atr * InpAccumulationRangeATR || !accWasSeen)
      {
         detectedPhase = AMD_ACCUMULATION;
         confidence = 60;
      }
   }

   // If no phase detected, decay confidence but don't reset pendingCount
   if(detectedPhase == AMD_UNKNOWN)
   {
      if(g_amdPhase.confidence > 0)
         g_amdPhase.confidence = MathMax(0, g_amdPhase.confidence - 5);
      return;
   }

   int requiredConfirm = CONFIRM_ACC;
   if(detectedPhase == AMD_MANIPULATION) requiredConfirm = CONFIRM_MANIP;
   else if(detectedPhase == AMD_DISTRIBUTION) requiredConfirm = CONFIRM_DIST;

   if(detectedPhase != g_amdPhase.currentPhase)
   {
      if(detectedPhase == pendingPhase)
         pendingCount++;
      else
      {
         pendingPhase = detectedPhase;
         pendingCount = 1;
      }

      if(pendingCount < requiredConfirm)
         return; // Wait for confirmation

      g_amdPhase.phaseStartTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      g_amdPhase.phaseBarCount = 0;
      Print("AMD Phase changed to: ", AMDPhaseToString(detectedPhase), " (Confidence: ", confidence, "%)");

      pendingPhase = AMD_UNKNOWN;
      pendingCount = 0;
   }
   else
   {
      pendingPhase = AMD_UNKNOWN;
      pendingCount = 0;
   }

   g_amdPhase.currentPhase = detectedPhase;
   g_amdPhase.confidence = confidence;
   g_amdPhase.phaseBarCount++;

   // Update phase boundaries
   if(detectedPhase == AMD_ACCUMULATION)
   {
      if(g_amdPhase.accumulationHigh == 0.0 || rangeHigh > g_amdPhase.accumulationHigh)
         g_amdPhase.accumulationHigh = rangeHigh;
      if(g_amdPhase.accumulationLow == 0.0 || rangeLow < g_amdPhase.accumulationLow)
         g_amdPhase.accumulationLow = rangeLow;
      if(g_amdPhase.accumulationStartTime == 0)
         g_amdPhase.accumulationStartTime = g_amdPhase.phaseStartTime;
   }
   else if(detectedPhase == AMD_MANIPULATION)
   {
      if(g_amdPhase.accumulationHigh == 0.0 || rangeHigh > g_amdPhase.accumulationHigh)
         g_amdPhase.accumulationHigh = rangeHigh;
      if(g_amdPhase.accumulationLow == 0.0 || rangeLow < g_amdPhase.accumulationLow)
         g_amdPhase.accumulationLow = rangeLow;
      if(g_amdPhase.accumulationStartTime == 0)
         g_amdPhase.accumulationStartTime = g_amdPhase.phaseStartTime;

      g_amdPhase.rangeHigh = g_amdPhase.accumulationHigh;
      g_amdPhase.rangeLow = g_amdPhase.accumulationLow;

      if(g_amdPhase.manipulationHigh == 0.0 || rangeHigh > g_amdPhase.manipulationHigh)
         g_amdPhase.manipulationHigh = rangeHigh;
      if(g_amdPhase.manipulationLow == 0.0 || rangeLow < g_amdPhase.manipulationLow)
         g_amdPhase.manipulationLow = rangeLow;
      if(g_amdPhase.manipulationStartTime == 0)
         g_amdPhase.manipulationStartTime = g_amdPhase.phaseStartTime;

      if(g_amdPhase.manipulationHigh > g_amdPhase.rangeHigh)
         g_amdPhase.rangeHigh = g_amdPhase.manipulationHigh;
      if(g_amdPhase.manipulationLow < g_amdPhase.rangeLow)
         g_amdPhase.rangeLow = g_amdPhase.manipulationLow;
         
      Print("✓ Manipulation stored: H=", g_amdPhase.manipulationHigh, " L=", g_amdPhase.manipulationLow);
   }
   else if(detectedPhase == AMD_DISTRIBUTION)
   {
      if(g_amdPhase.distributionHigh == 0.0 || rangeHigh > g_amdPhase.distributionHigh)
         g_amdPhase.distributionHigh = rangeHigh;
      if(g_amdPhase.distributionLow == 0.0 || rangeLow < g_amdPhase.distributionLow)
         g_amdPhase.distributionLow = rangeLow;
      if(g_amdPhase.distributionStartTime == 0)
         g_amdPhase.distributionStartTime = g_amdPhase.phaseStartTime;

      if(g_amdPhase.distributionHigh > g_amdPhase.rangeHigh)
         g_amdPhase.rangeHigh = g_amdPhase.distributionHigh;
      if(g_amdPhase.distributionLow < g_amdPhase.rangeLow)
         g_amdPhase.rangeLow = g_amdPhase.distributionLow;
         
      Print("✓ Distribution stored: H=", g_amdPhase.distributionHigh, " L=", g_amdPhase.distributionLow);
   }

   // Cycle completion check
   if(detectedPhase == AMD_DISTRIBUTION && g_amdPhase.currentPhase != AMD_DISTRIBUTION && 
      g_amdPhase.accumulationHigh > 0.0 && g_amdPhase.manipulationHigh > 0.0 && g_amdPhase.distributionHigh > 0.0)
   {
      g_amdPhase.amdCycle++;
      double rangeSize = (g_amdPhase.rangeHigh - g_amdPhase.rangeLow) / _Point;
      Print("✓ AMD CYCLE #", g_amdPhase.amdCycle, " COMPLETED | Range Size: ", rangeSize, " points");
   }

   // ✅ Call your EXACT function signature
   DetermineExpectedDirection(detectedPhase);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   bool CheckRecentDisplacement(double atr, int lookback)
     {
      for(int i = 1; i <= lookback; i++)
        {
         if(IsDisplacementCandle(PERIOD_CURRENT, i, atr))
            return true;
        }
      return false;
     }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   bool CheckRecentSweep(double atr, int lookback)
     {
      for(int i = 0; i < g_swingsCount; i++)
        {
         if(g_swings[i].status == SWING_SWEPT)
           {
            int sweepBar = iBarShift(_Symbol, PERIOD_CURRENT, g_swings[i].time, false);
            if(sweepBar >= 0 && sweepBar <= lookback)
              {
               double minSweepSize = atr * InpManipulationSweepATR;
               double sweepRange = iHigh(_Symbol, PERIOD_CURRENT, sweepBar)
                                   - iLow(_Symbol, PERIOD_CURRENT, sweepBar);
               if(sweepRange >= minSweepSize)
                  return true;
              }
           }
        }
      return false;
     }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   bool CheckRecentBOS(int lookback)
     {
      SDealingRange *dr = g_isBullishActive ? GetPointer(g_bullDR) : GetPointer(g_bearDR);
      if(dr.corrLine.isActive)
        {
         int bosBar = iBarShift(_Symbol, PERIOD_CURRENT, dr.corrLine.extremeTime, false);
         if(bosBar >= 0 && bosBar <= lookback)
            return true;
        }
      return false;
     }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   double MeasureExpansionSize()
     {
      double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
      if(g_isBullishActive)
        {
         double swingLow = g_lastExternalLow;
         if(swingLow > 0.0)
            return currentPrice - swingLow;
        }
      else
        {
         double swingHigh = g_lastExternalHigh;
         if(swingHigh > 0.0)
            return swingHigh - currentPrice;
        }
      return 0.0;
     }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DetermineExpectedDirection(ENUM_AMD_PHASE phase)
{
   switch(phase)
     {
      case AMD_ACCUMULATION:
         // ✅ SAFETY FALLBACK: If the system is stuck in Accumulation but a clear trend 
         // is already active (e.g., CHOCH/BOS detected by other modules), allow the 
         // trend direction to pass through instead of blocking with DIR_NONE.
         if(g_amdPhase.phaseBarCount > 10) 
         {
            g_amdPhase.expectedDirection = g_isBullishActive ? DIR_BULLISH : DIR_BEARISH;
         }
         else
         {
            g_amdPhase.expectedDirection = DIR_NONE;
         }
         break;
         
      case AMD_MANIPULATION:
         g_amdPhase.expectedDirection = g_isBullishActive ? DIR_BEARISH : DIR_BULLISH;
         break;
         
      case AMD_DISTRIBUTION:
         g_amdPhase.expectedDirection = g_isBullishActive ? DIR_BULLISH : DIR_BEARISH;
         break;
         
      default:
         g_amdPhase.expectedDirection = DIR_NONE;
         break;
     }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   string AMDPhaseToString(ENUM_AMD_PHASE phase)
     {
      switch(phase)
        {
         case AMD_ACCUMULATION:
            return "ACCUMULATION";
         case AMD_MANIPULATION:
            return "MANIPULATION";
         case AMD_DISTRIBUTION:
            return "DISTRIBUTION";
         default:
            return "UNKNOWN";
        }
     }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   string GetPhaseDescription()
     {
      string s = AMDPhaseToString(g_amdPhase.currentPhase);
      s += " [" + IntegerToString(g_amdPhase.confidence) + "%]";
      if(g_amdPhase.amdCycle > 0)
         s += " Cycle#" + IntegerToString(g_amdPhase.amdCycle);
      return s;
     }

#endif // ICT_AMD_MQH
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
