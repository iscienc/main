//+------------------------------------------------------------------+
//|                          ICT_SMT.mqh                              |
//|          Smart Money Technique Divergence Detection                |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_SMT_MQH
#define ICT_SMT_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize SMT                                                    |
//+------------------------------------------------------------------+
bool InitializeSMT()
{
   g_smtDivergence.Reset();
   
   Print("SMT Divergence System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: SMT DETECTION                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update SMT Analysis                                               |
//+------------------------------------------------------------------+
void UpdateSMTAnalysis()
{
   if(!InpUseSMT || InpSMT_Pair == SMT_PAIR_NONE)
   {
      g_smtDivergence.status = SMT_NONE;
      return;
   }
   
   // Get correlated pair symbol
   string smtSymbol = GetSMTPairSymbol();
   
   if(smtSymbol == "")
   {
      g_smtDivergence.status = SMT_NONE;
      return;
   }
   
   // Check if symbol is available
   if(!SymbolSelect(smtSymbol, true))
   {
      g_smtDivergence.status = SMT_NONE;
      return;
   }
   
   // Detect divergence
   DetectSMTDivergence(smtSymbol);
}

//+------------------------------------------------------------------+
//| Get SMT Pair Symbol                                               |
//+------------------------------------------------------------------+
string GetSMTPairSymbol()
{
   switch(InpSMT_Pair)
   {
      case SMT_PAIR_DXY:    return "DXY";
      case SMT_PAIR_EURUSD: return "EURUSD";
      case SMT_PAIR_GBPUSD: return "GBPUSD";
      case SMT_PAIR_USDJPY: return "USDJPY";
      case SMT_PAIR_XAUUSD: return "XAUUSD";
      case SMT_PAIR_ES:     return "ES"; // S&P futures
      case SMT_PAIR_NQ:     return "NQ"; // Nasdaq futures
      default:              return "";
   }
}

//+------------------------------------------------------------------+
//| Detect SMT Divergence                                             |
//+------------------------------------------------------------------+
void DetectSMTDivergence(string smtSymbol)
{
   int lookback = InpSMT_SwingLookback;
   int tolerance = InpSMT_TimeTolerance;
   
    
   // === ADD THIS BLOCK ===
   int mainBarsAvailable = iBars(_Symbol, PERIOD_CURRENT);
   int smtBarsAvailable = iBars(smtSymbol, PERIOD_CURRENT);
   
   // Ensure lookback doesn't exceed available bars
   if(lookback * 3 >= mainBarsAvailable || lookback * 3 >= smtBarsAvailable)
   {
      lookback = MathMin(mainBarsAvailable, smtBarsAvailable) / 3 - 1;
      if(lookback < 5)
      {
         g_smtDivergence.status = SMT_NONE;
         return;
      }
   }
   // === END OF ADDED BLOCK ===
   
   // Find swing points on main symbol
   int mainHighBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookback, 0);
   int mainLowBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookback, 0);
   
   double mainHigh = iHigh(_Symbol, PERIOD_CURRENT, mainHighBar);
   double mainLow = iLow(_Symbol, PERIOD_CURRENT, mainLowBar);
   
   // Find swing points on correlated symbol
   int smtHighBar = iHighest(smtSymbol, PERIOD_CURRENT, MODE_HIGH, lookback, 0);
   int smtLowBar = iLowest(smtSymbol, PERIOD_CURRENT, MODE_LOW, lookback, 0);
   
   double smtHigh = iHigh(smtSymbol, PERIOD_CURRENT, smtHighBar);
   double smtLow = iLow(smtSymbol, PERIOD_CURRENT, smtLowBar);
   
   // Check time alignment
   bool highsAligned = MathAbs(mainHighBar - smtHighBar) <= tolerance;
   bool lowsAligned = MathAbs(mainLowBar - smtLowBar) <= tolerance;
   
   // Determine correlation type
   bool isInverse = IsInverseCorrelation();
   
   // === BULLISH SMT DIVERGENCE ===
   // For inverse pairs (DXY): Main makes LL, Correlated makes HL
   // For direct pairs: Main makes LL, Correlated makes LL (but different magnitude)
   
   bool bullishDivergence = false;
   bool bearishDivergence = false;
   
    if(isInverse)
   {
      // === BULLISH SMT CHECK (inverse) ===
      // Get previous main swing low
      int prevMainLowStart = mainLowBar + 1;
      int prevMainLowCount = MathMin(lookback, mainBarsAvailable - prevMainLowStart - 1);
      int prevMainLowBar = (prevMainLowCount > 0) ? 
         iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, prevMainLowCount, prevMainLowStart) : mainLowBar;
      
      // Get previous SMT swing high
      int prevSmtHighStart = smtHighBar + 1;
      int prevSmtHighCount = MathMin(lookback, smtBarsAvailable - prevSmtHighStart - 1);
      int prevSmtHighBar = (prevSmtHighCount > 0) ? 
         iHighest(smtSymbol, PERIOD_CURRENT, MODE_HIGH, prevSmtHighCount, prevSmtHighStart) : smtHighBar;
      
      double prevMainLow = iLow(_Symbol, PERIOD_CURRENT, prevMainLowBar);
      double prevSmtHigh = iHigh(smtSymbol, PERIOD_CURRENT, prevSmtHighBar);
      
      if(mainLow < prevMainLow && smtHigh < prevSmtHigh && lowsAligned)
      {
         bullishDivergence = true;
      }
      
      // === BEARISH SMT CHECK (inverse) ===
      // Get previous main swing high
      int prevMainHighStart = mainHighBar + 1;
      int prevMainHighCount = MathMin(lookback, mainBarsAvailable - prevMainHighStart - 1);
      int prevMainHighBar = (prevMainHighCount > 0) ? 
         iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, prevMainHighCount, prevMainHighStart) : mainHighBar;
      
      // Get previous SMT swing low
      int prevSmtLowStart = smtLowBar + 1;
      int prevSmtLowCount = MathMin(lookback, smtBarsAvailable - prevSmtLowStart - 1);
      int prevSmtLowBar = (prevSmtLowCount > 0) ? 
         iLowest(smtSymbol, PERIOD_CURRENT, MODE_LOW, prevSmtLowCount, prevSmtLowStart) : smtLowBar;
      
      double prevMainHigh = iHigh(_Symbol, PERIOD_CURRENT, prevMainHighBar);
      double prevSmtLow = iLow(smtSymbol, PERIOD_CURRENT, prevSmtLowBar);
      
      if(mainHigh > prevMainHigh && smtLow > prevSmtLow && highsAligned)
      {
         bearishDivergence = true;
      }
   }
     else
   {
      // === BULLISH SMT CHECK (direct) ===
      int prevMainLowStart2 = mainLowBar + 1;
      int prevMainLowCount2 = MathMin(lookback, mainBarsAvailable - prevMainLowStart2 - 1);
      int prevMainLowBar2 = (prevMainLowCount2 > 0) ? 
         iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, prevMainLowCount2, prevMainLowStart2) : mainLowBar;
      
      int prevSmtLowStart2 = smtLowBar + 1;
      int prevSmtLowCount2 = MathMin(lookback, smtBarsAvailable - prevSmtLowStart2 - 1);
      int prevSmtLowBar2 = (prevSmtLowCount2 > 0) ? 
         iLowest(smtSymbol, PERIOD_CURRENT, MODE_LOW, prevSmtLowCount2, prevSmtLowStart2) : smtLowBar;
      
      double prevMainLow2 = iLow(_Symbol, PERIOD_CURRENT, prevMainLowBar2);
      double prevSmtLow2 = iLow(smtSymbol, PERIOD_CURRENT, prevSmtLowBar2);
      
      if(mainLow < prevMainLow2 && smtLow > prevSmtLow2)
      {
         bullishDivergence = true;
      }
      
      // === BEARISH SMT CHECK (direct) ===
      int prevMainHighStart2 = mainHighBar + 1;
      int prevMainHighCount2 = MathMin(lookback, mainBarsAvailable - prevMainHighStart2 - 1);
      int prevMainHighBar2 = (prevMainHighCount2 > 0) ? 
         iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, prevMainHighCount2, prevMainHighStart2) : mainHighBar;
      
      int prevSmtHighStart2 = smtHighBar + 1;
      int prevSmtHighCount2 = MathMin(lookback, smtBarsAvailable - prevSmtHighStart2 - 1);
      int prevSmtHighBar2 = (prevSmtHighCount2 > 0) ? 
         iHighest(smtSymbol, PERIOD_CURRENT, MODE_HIGH, prevSmtHighCount2, prevSmtHighStart2) : smtHighBar;
      
      double prevMainHigh2 = iHigh(_Symbol, PERIOD_CURRENT, prevMainHighBar2);
      double prevSmtHigh2 = iHigh(smtSymbol, PERIOD_CURRENT, prevSmtHighBar2);
      
      if(mainHigh > prevMainHigh2 && smtHigh < prevSmtHigh2)
      {
         bearishDivergence = true;
      }
   }
   
   // Update SMT status
   if(bullishDivergence)
   {
      g_smtDivergence.status = SMT_BULLISH_DIV;
      g_smtDivergence.time = iTime(_Symbol, PERIOD_CURRENT, mainLowBar);
      g_smtDivergence.mainPrice = mainLow;
      g_smtDivergence.correlatedPrice = smtHigh;
      g_smtDivergence.isConfirmed = true;
      g_smtDivergence.strength = CalculateSMTStrength(mainLowBar, smtHighBar);
      
      Print("📈 BULLISH SMT Divergence detected!");
   }
   else if(bearishDivergence)
   {
      g_smtDivergence.status = SMT_BEARISH_DIV;
      g_smtDivergence.time = iTime(_Symbol, PERIOD_CURRENT, mainHighBar);
      g_smtDivergence.mainPrice = mainHigh;
      g_smtDivergence.correlatedPrice = smtLow;
      g_smtDivergence.isConfirmed = true;
      g_smtDivergence.strength = CalculateSMTStrength(mainHighBar, smtLowBar);
      
      Print("📉 BEARISH SMT Divergence detected!");
   }
   else
   {
      g_smtDivergence.status = SMT_NONE;
      g_smtDivergence.isConfirmed = false;
   }
   
   g_smtDivergence.correlatedPair = InpSMT_Pair;
}

//+------------------------------------------------------------------+
//| Check if Inverse Correlation                                      |
//+------------------------------------------------------------------+
bool IsInverseCorrelation()
{
   // DXY is inverse to most pairs
   // Gold is inverse to DXY
   
   switch(InpSMT_Pair)
   {
      case SMT_PAIR_DXY:
         return true;  // DXY is inverse to XAUUSD, EURUSD, etc.
      
      case SMT_PAIR_XAUUSD:
         return false; // Gold is direct correlation with itself
      
      default:
         return false; // Most forex pairs are direct
   }
}

//+------------------------------------------------------------------+
//| Calculate SMT Strength                                            |
//+------------------------------------------------------------------+
int CalculateSMTStrength(int mainBar, int smtBar)
{
   int timeDiff = MathAbs(mainBar - smtBar);
   
   if(timeDiff <= 1)
      return 3; // Strong - simultaneous
   else if(timeDiff <= 3)
      return 2; // Moderate
   else
      return 1; // Weak
}

//+------------------------------------------------------------------+
//|              SECTION 3: CHECK FUNCTIONS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Has SMT Confirmation                                              |
//+------------------------------------------------------------------+
bool HasSMTConfirmation(bool forBullish)
{
   if(!InpUseSMT)
      return true; // SMT disabled, pass
   
   if(g_smtDivergence.status == SMT_NONE)
      return true; // No divergence, neutral
   
   if(forBullish)
      return (g_smtDivergence.status == SMT_BULLISH_DIV);
   else
      return (g_smtDivergence.status == SMT_BEARISH_DIV);
}

//+------------------------------------------------------------------+
//| Get SMT Score Bonus                                               |
//+------------------------------------------------------------------+
int GetSMTScoreBonus()
{
   if(!InpUseSMT)
      return 0;
   
   if(g_smtDivergence.status == SMT_NONE || !g_smtDivergence.isConfirmed)
      return 0;
   
   // Check if aligned with current direction
   bool aligned = false;
   
   if(g_currentDirection == DIR_BULLISH && g_smtDivergence.status == SMT_BULLISH_DIV)
      aligned = true;
   else if(g_currentDirection == DIR_BEARISH && g_smtDivergence.status == SMT_BEARISH_DIV)
      aligned = true;
   
   if(!aligned)
      return 0;
   
   return g_smtDivergence.strength * 3; // 3-9 points based on strength
}

//+------------------------------------------------------------------+
//| Get SMT Description                                               |
//+------------------------------------------------------------------+
string GetSMTDescription()
{
   if(g_smtDivergence.status == SMT_NONE)
      return "No SMT";
   
   string pair = "";
   switch(g_smtDivergence.correlatedPair)
   {
      case SMT_PAIR_DXY:    pair = "DXY"; break;
      case SMT_PAIR_EURUSD: pair = "EURUSD"; break;
      case SMT_PAIR_GBPUSD: pair = "GBPUSD"; break;
      case SMT_PAIR_XAUUSD: pair = "XAUUSD"; break;
      default: pair = "???";
   }
   
   string divType = (g_smtDivergence.status == SMT_BULLISH_DIV) ? "Bullish" : "Bearish";
   string strength = "";
   switch(g_smtDivergence.strength)
   {
      case 3: strength = "Strong"; break;
      case 2: strength = "Moderate"; break;
      case 1: strength = "Weak"; break;
   }
   
   return divType + " SMT vs " + pair + " (" + strength + ")";
}

#endif // ICT_SMT_MQH