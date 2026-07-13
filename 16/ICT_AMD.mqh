//+------------------------------------------------------------------+
//|                          ICT_AMD.mqh                              |
//|       Accumulation, Manipulation, Distribution Detection          |
//|                "ICT Unified Professional EA v16"                  |
//+------------------------------------------------------------------+
#ifndef ICT_AMD_MQH
#define ICT_AMD_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Market Phase                                           |
//+------------------------------------------------------------------+
bool InitializeMarketPhase()
  {
   g_amdPhase.Reset();

   Print("AMD Phase Detection initialized");
   return true;
  }

//+------------------------------------------------------------------+
//|              SECTION 2: PHASE DETECTION                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Market Phase (Main Function)                               |
//+------------------------------------------------------------------+
void UpdateMarketPhase()
  {
   if(!g_needDetectAMD)
      return;

// Determine current phase based on price action
   DetectAMDPhase();
  }

//+------------------------------------------------------------------+
//| Detect AMD Phase                                                  |
//+------------------------------------------------------------------+
void DetectAMDPhase()
  {
   double atr = GetATR();
   if(atr <= 0)
      return;

// Anti-flicker static state (declared at function start)
   static ENUM_AMD_PHASE pendingPhase = AMD_UNKNOWN;
   static int pendingCount = 0;
   const int confirmBars = 2;

// Get recent price action
   int barsToAnalyze = InpAccumulationBars;

   double rangeHigh = iHigh(_Symbol, PERIOD_CURRENT,
                            iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, barsToAnalyze, 0));
   double rangeLow = iLow(_Symbol, PERIOD_CURRENT,
                          iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, barsToAnalyze, 0));
   double currentRange = rangeHigh - rangeLow;

// Get displacement info
   bool hasRecentDisplacement = CheckRecentDisplacement(atr, 10);
   bool hasRecentSweep = CheckRecentSweep(atr, 15);
   bool hasRecentBOS = CheckRecentBOS(20);

// Phase Logic
   ENUM_AMD_PHASE detectedPhase = AMD_UNKNOWN;
   int confidence = 0;

// === DISTRIBUTION ===
   if(hasRecentBOS && hasRecentDisplacement)
     {
      detectedPhase = AMD_DISTRIBUTION;
      confidence = 80;

      double expansionSize = MeasureExpansionSize();
      if(expansionSize > atr * 2.0)
         confidence = 95;
      else
         if(expansionSize > atr * 1.0)
            confidence = 85;
     }
// === MANIPULATION ===
   else
      if(hasRecentSweep && !hasRecentBOS)
        {
         detectedPhase = AMD_MANIPULATION;
         confidence = 70;

         if(HasJudasPattern())
            confidence = 85;
        }
      // === ACCUMULATION ===
      else
         if(currentRange < atr * InpAccumulationRangeATR)
           {
            detectedPhase = AMD_ACCUMULATION;
            confidence = 60;

            if(currentRange < atr * 0.75)
               confidence = 75;

            if(hasRecentDisplacement)
               confidence = 30;
           }

   ENUM_AMD_PHASE previousPhase = g_amdPhase.currentPhase;

// --- Anti-flicker: require confirmBars consecutive bars before committing ---
   if(detectedPhase != previousPhase)
     {
      if(detectedPhase == pendingPhase)
         pendingCount++;
      else
        {
         pendingPhase = detectedPhase;
         pendingCount = 1;
        }

      if(pendingCount < confirmBars)
         return; // Not confirmed yet - wait one more bar

      // Phase change is now confirmed - commit it
      g_amdPhase.phaseStartTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      Print("AMD Phase changed to: ", AMDPhaseToString(detectedPhase),
            " (Confidence: ", confidence, "%)");
     }
   else
     {
      pendingPhase = AMD_UNKNOWN;
      pendingCount = 0;
     }

// Commit phase
   g_amdPhase.currentPhase = detectedPhase;
   g_amdPhase.confidence   = confidence;

// Track accumulation extremes
   if(detectedPhase == AMD_ACCUMULATION)
     {
      if(g_amdPhase.accumulationHigh == 0 || rangeHigh > g_amdPhase.accumulationHigh)
         g_amdPhase.accumulationHigh = rangeHigh;
      if(g_amdPhase.accumulationLow == 0 || rangeLow < g_amdPhase.accumulationLow)
         g_amdPhase.accumulationLow = rangeLow;
     }

// Determine expected direction based on phase
   DetermineExpectedDirection(detectedPhase);
  }

//+------------------------------------------------------------------+
//| Check Recent Displacement                                         |
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
//| Check Recent Sweep                                                |
//+------------------------------------------------------------------+
bool CheckRecentSweep(double atr, int lookback)
  {
// Check if any recent bar swept a swing point
   for(int i = 0; i < g_swingsCount; i++)
     {
      if(g_swings[i].status == SWING_SWEPT)
        {
         int sweepBar = iBarShift(_Symbol, PERIOD_CURRENT, g_swings[i].time, false);
         if(sweepBar >= 0 && sweepBar <= lookback)
           {
            double minSweepSize = atr * InpManipulationSweepATR;
            double sweepRange = iHigh(_Symbol, PERIOD_CURRENT, sweepBar) - iLow(_Symbol, PERIOD_CURRENT, sweepBar);
            if(sweepRange >= minSweepSize)
               return true;
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check Recent BOS                                                  |
//+------------------------------------------------------------------+
bool CheckRecentBOS(int lookback)
  {
// Check if DR BOS happened recently
   SDealingRange* dr = g_isBullishActive ? GetPointer(g_bullDR) : GetPointer(g_bearDR);

   if(dr.corrLine.isActive)
     {
      int bosBar = iBarShift(_Symbol, PERIOD_CURRENT, dr.corrLine.extremeTime, false);
      // If CL is recent, we had a BOS
      if(bosBar >= 0 && bosBar <= lookback)
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Measure Expansion Size                                            |
//+------------------------------------------------------------------+
double MeasureExpansionSize()
  {
// Measure distance from recent swing extreme to current price
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);

   if(g_isBullishActive)
     {
      double swingLow = g_lastExternalLow;
      if(swingLow > 0)
         return currentPrice - swingLow;
     }
   else
     {
      double swingHigh = g_lastExternalHigh;
      if(swingHigh > 0)
         return swingHigh - currentPrice;
     }

   return 0;
  }

//+------------------------------------------------------------------+
//| Has Judas Pattern                                                 |
//+------------------------------------------------------------------+
bool HasJudasPattern()
  {
// Check if we have a recent Judas swing detected
   return (g_judasSwing.type != JUDAS_NONE && g_judasSwing.isConfirmed);
  }

//+------------------------------------------------------------------+
//| Determine Expected Direction                                      |
//+------------------------------------------------------------------+
void DetermineExpectedDirection(ENUM_AMD_PHASE phase)
  {
   switch(phase)
     {
      case AMD_ACCUMULATION:
         // During accumulation, direction is uncertain
         g_amdPhase.expectedDirection = DIR_NONE;
         break;

      case AMD_MANIPULATION:
         // After manipulation (Judas), expect reversal
         if(g_judasSwing.type == JUDAS_BULLISH)
            g_amdPhase.expectedDirection = DIR_BULLISH;
         else
            if(g_judasSwing.type == JUDAS_BEARISH)
               g_amdPhase.expectedDirection = DIR_BEARISH;
            else
               g_amdPhase.expectedDirection = DIR_NONE;
         break;

      case AMD_DISTRIBUTION:
         // During distribution, follow current trend
         g_amdPhase.expectedDirection = g_currentDirection;
         break;

      default:
         g_amdPhase.expectedDirection = DIR_NONE;
     }
  }

//+------------------------------------------------------------------+
//|              SECTION 3: PHASE UTILITIES                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get AMD Phase Score Bonus                                         |
//+------------------------------------------------------------------+
int GetAMDPhaseScoreBonus()
  {
   if(!g_needDetectAMD)
      return 0;

   int bonus = 0;

   switch(g_amdPhase.currentPhase)
     {
      case AMD_DISTRIBUTION:
         // Best phase for entries
         if(g_amdPhase.confidence >= 80)
            bonus = 15;
         else
            if(g_amdPhase.confidence >= 60)
               bonus = 10;
         break;

      case AMD_MANIPULATION:
         // Good if confirmed Judas
         if(g_judasSwing.isConfirmed)
            bonus = 12;
         else
            bonus = 5;
         break;

      case AMD_ACCUMULATION:
         // Wait for breakout
         bonus = 0;
         break;
     }

   return bonus;
  }

//+------------------------------------------------------------------+
//| Is Distribution Phase                                             |
//+------------------------------------------------------------------+
bool IsDistributionPhase()
  {
   return (g_amdPhase.currentPhase == AMD_DISTRIBUTION);
  }

//+------------------------------------------------------------------+
//| Is Manipulation Phase                                             |
//+------------------------------------------------------------------+
bool IsManipulationPhase()
  {
   return (g_amdPhase.currentPhase == AMD_MANIPULATION);
  }

//+------------------------------------------------------------------+
//| Is Accumulation Phase                                              |
//+------------------------------------------------------------------+
bool IsAccumulationPhase()
  {
   return (g_amdPhase.currentPhase == AMD_ACCUMULATION);
  }

//+------------------------------------------------------------------+
//| Get Phase Description                                             |
//+------------------------------------------------------------------+
string GetPhaseDescription()
  {
   string desc = AMDPhaseToString(g_amdPhase.currentPhase);
   desc += " (" + IntegerToString(g_amdPhase.confidence) + "%)";

   if(g_amdPhase.expectedDirection != DIR_NONE)
     {
      desc += " → " + DirectionToString(g_amdPhase.expectedDirection);
     }

   return desc;
  }

#endif // ICT_AMD_MQH
//+------------------------------------------------------------------+
