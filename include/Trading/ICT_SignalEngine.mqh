//+------------------------------------------------------------------+
//|                     ICT_SignalEngine.mqh                          |
//|              Signal Generation with Entry Logic                    |
//|                    ICT Unified Professional EA v8.0                 |
//+------------------------------------------------------------------+
#ifndef ICT_SIGNALENGINE_MQH
#define ICT_SIGNALENGINE_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../StateMachine/ICT_NarrativeGate.mqh"
#include "../ML/ICT_MLEngine.mqh"


//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Signal Engine                                          |
//+------------------------------------------------------------------+
bool InitializeSignalEngine()
  {
   g_currentSignal.Reset();
   g_pendingSignal.Reset();
   g_hasValidSignal = false;
   g_waitingForOTE = false;

   Print("Signal Engine initialized");
   return true;
  }

//+------------------------------------------------------------------+
//|              SECTION 2: MAIN SIGNAL PROCESSING                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Entry Signals (Main Orchestrator)                         |
//+------------------------------------------------------------------+
void ProcessEntrySignals()
  {
// Reset signal state
   g_hasValidSignal = false;
   g_currentSignal.Reset();

// Check if trading is enabled
   if(!InpEnableTrading || !g_tradingEnabled)
      return;

// Check all filters
   if(!CheckAllFilters())
      return;

// Determine direction from DR analysis
   ENUM_TRADE_DIRECTION direction = g_currentDirection;

   if(direction == DIR_NONE)
      return;

   bool isBullish = (direction == DIR_BULLISH);

   string narReason = "";
   if(!IsNarrativeTradable(direction, narReason))
      return;

// Check for PD Array entry trigger
   if(!CheckForEntryTrigger(isBullish))
      return;

// Validate entry conditions
   if(!ValidateEntryConditions(isBullish))
      return;

// Check additional confirmations
   if(!CheckEntryConfirmations(isBullish))
      return;
// ML Filter
// ML Filter
   if(g_mlInitialized && InpML_Mode != ML_OFF && ShouldMLBlockTrade())
     {
      RecordPrediction(g_mlPrediction.probability, false, 0);
      return;
     }

// External provider agreement check
   if(!CheckExternalAgreement(isBullish))
      return;

// Generate signal
   GenerateTradeSignal(isBullish);
  }

//+------------------------------------------------------------------+
//| Check for Entry Trigger                                           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check for Entry Trigger (MODIFIED - stores trigger context)       |
//+------------------------------------------------------------------+
bool CheckForEntryTrigger(bool isBullish)
  {
   int idx;
   ENUM_PD_ARRAY_TYPE pdType;

// Reset trigger context
   g_triggerPDIndex = -1;
   g_triggerPDType = PD_NONE;

   if(!IsPriceAtAnyPDArray(isBullish, pdType, idx))
      return false;

   bool result = false;

   switch(pdType)
     {
      case PD_ORDER_BLOCK:
         result = ValidateOrderBlockEntry(idx, isBullish);
         break;
      case PD_BREAKER_BLOCK:
         result = ValidateBreakerEntry(idx, isBullish);
         break;
      case PD_MITIGATION_BLOCK:
         result = ValidateMitigationEntry(idx, isBullish);
         break;
      case PD_FVG:
         result = ValidateFVGEntry(idx, isBullish);
         break;
      case PD_OTE_ZONE:
         result = ValidateOTEEntry(isBullish);
         break;
      default:
         if(idx >= 0 && idx < g_stackCount)
            result = ValidateStackedEntry(idx, isBullish);
     }

// Store trigger context for SL/TP calculation
   if(result)
     {
      g_triggerPDIndex = idx;
      g_triggerPDType = pdType;
     }

   return result;
  }

//+------------------------------------------------------------------+
//| Validate Order Block Entry                                        |
//+------------------------------------------------------------------+
bool ValidateOrderBlockEntry(int idx, bool isBullish)
  {
   if(idx < 0 || idx >= g_obCount)
      return false;

   SOrderBlock ob = g_orderBlocks[idx];

// Direction check
   bool isBullishOB = (ob.type == OB_BULLISH);
   if(isBullish != isBullishOB)
      return false;

// Status check - prefer fresh or tested once
   if(ob.status == OB_FAILED || ob.status == OB_MITIGATED)
      return false;

// Test count check
   if(ob.testCount >= InpOB_MaxTestCount)
      return false;

// Institutional candle bonus
   if(InpOB_RequireInstitutional && !ob.isInstitutional)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Validate Breaker Entry                                            |
//+------------------------------------------------------------------+
bool ValidateBreakerEntry(int idx, bool isBullish)
  {
   if(idx < 0 || idx >= g_breakerCount)
      return false;

   SBreakerBlock breaker = g_breakerBlocks[idx];

// Direction check
   bool isBullishBreaker = (breaker.type == BREAKER_BULLISH);
   if(isBullish != isBullishBreaker)
      return false;

// Prefer untested breakers
   if(breaker.isTested)
      return false; // Could be valid but lower priority

   return true;
  }

//+------------------------------------------------------------------+
//| Validate Mitigation Entry                                         |
//+------------------------------------------------------------------+
bool ValidateMitigationEntry(int idx, bool isBullish)
  {
   if(idx < 0 || idx >= g_mbCount)
      return false;

   SMitigationBlock mb = g_mitigationBlocks[idx];

   bool isBullishMB = (mb.type == MB_BULLISH);
   if(isBullish != isBullishMB)
      return false;

   if(mb.isTested)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Validate FVG Entry                                                |
//+------------------------------------------------------------------+
bool ValidateFVGEntry(int idx, bool isBullish)
  {
   if(idx < 0 || idx >= g_fvgCount)
      return false;

   SFairValueGap fvg = g_fvgList[idx];

   bool isBullishFVG = (fvg.type == FVG_BULLISH);
   if(isBullish != isBullishFVG)
      return false;

// Only trade unfilled or partially filled FVGs
   if(fvg.status == FVG_FULLY_FILLED)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Validate OTE Entry                                                |
//+------------------------------------------------------------------+
bool ValidateOTEEntry(bool isBullish)
  {
   if(!InpUseOTE)
      return false;

   if(!g_oteZone.isValid)
      return false;

// Direction check
   if(isBullish != g_oteZone.isBullish)
      return false;

// Price must be in OTE zone
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double zoneTop = g_oteZone.ZoneTop();
   double zoneBottom = g_oteZone.ZoneBottom();

   return (price >= zoneBottom && price <= zoneTop);
  }

//+------------------------------------------------------------------+
//| Validate Stacked Entry                                            |
//+------------------------------------------------------------------+
bool ValidateStackedEntry(int idx, bool isBullish)
  {
   if(idx < 0 || idx >= g_stackCount)
      return false;

   SPDStack stack = g_pdStacks[idx];

// Direction check
   if(stack.direction != (isBullish ? DIR_BULLISH : DIR_BEARISH))
      return false;

// Must have minimum stack count
   if(stack.stackCount < InpMinStackCount)
      return false;

// Stack score check
   if(stack.stackStrength < 20)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Validate Entry Conditions                                         |
//+------------------------------------------------------------------+
bool ValidateEntryConditions(bool isBullish)
{
   return true;
}

//+------------------------------------------------------------------+
//| Check Entry Confirmations                                         |
//+------------------------------------------------------------------+
bool CheckEntryConfirmations(bool isBullish)
{
   return true;
}
//+------------------------------------------------------------------+
//|              SECTION 3: SIGNAL GENERATION                         |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TRIGGER TriggerFromPDType(ENUM_PD_ARRAY_TYPE t)
  {
   switch(t)
     {
      case PD_ORDER_BLOCK:
         return TRIGGER_OB_ENTRY;
      case PD_BREAKER_BLOCK:
         return TRIGGER_BREAKER_ENTRY;
      case PD_MITIGATION_BLOCK:
         return TRIGGER_MB_ENTRY;
      case PD_FVG:
         return TRIGGER_FVG_ENTRY;
      case PD_OTE_ZONE:
         return TRIGGER_OTE_ENTRY;
      default:
         return TRIGGER_NONE;
     }
  }
//+------------------------------------------------------------------+
//| Generate Trade Signal                                             |
//+------------------------------------------------------------------+
void GenerateTradeSignal(bool isBullish)
  {
   g_currentSignal.Reset();

   g_currentSignal.type = isBullish ? SIGNAL_BUY : SIGNAL_SELL;
   g_currentSignal.trigger = TriggerFromPDType(g_triggerPDType);
   g_currentSignal.time = TimeCurrent();
   g_currentSignal.entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);

   g_currentSignal.slPrice = CalculateStopLoss(isBullish);
   CalculateTakeProfits(isBullish);
   g_currentSignal.lotSize = CalculateLotSize();

   double risk = MathAbs(g_currentSignal.entryPrice - g_currentSignal.slPrice);
   double reward = MathAbs(g_currentSignal.tp1Price - g_currentSignal.entryPrice);
   g_currentSignal.riskReward = (risk > 0) ? reward / risk : 0;

// narrative snapshot (no score system)
   g_currentSignal.narrative.Reset();
   g_currentSignal.narrative.direction = isBullish ? DIR_BULLISH : DIR_BEARISH;
   g_currentSignal.narrative.activeChains = SM_CountActiveInstances();

   g_currentSignal.isValid = ValidateSignal();

   if(g_currentSignal.isValid)
     {
      g_hasValidSignal = true;

      if(g_mlInitialized && InpML_Mode != ML_OFF)
        {
         g_posTracking.signalFeatures = ExtractFeatures();
         g_posTracking.hasSignalFeatures = true;
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate Stop Loss (COMPLETE REWRITE - All Methods)              |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBullish)
  {
   double sl = 0;
   double atr = GetATR();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double buffer = InpSlBufferPoints * point;
   double entry = iClose(_Symbol, PERIOD_CURRENT, 0);

   switch(InpSlMode)
     {
      case SL_FIXED_POINTS:
         sl = CalculateSL_FixedPoints(isBullish, entry, point);
         break;

      case SL_ATR_BASED:
         sl = CalculateSL_ATR(isBullish, entry, atr);
         break;

      case SL_STRUCTURE:
         sl = CalculateSL_Structure(isBullish, buffer);
         break;

      case SL_SWING:
         sl = CalculateSL_Swing(isBullish, buffer);
         break;

      case SL_FVG_CANDLE:
         sl = CalculateSL_FVGCandle(isBullish, buffer);
         break;

      case SL_FIB_EXTENSION:
         sl = CalculateSL_FibExtension(isBullish, buffer);
         break;

      case SL_MAX_LOSS_AMOUNT:
         sl = CalculateSL_MaxLossAmount(isBullish, entry);
         break;

      case SL_COMPOSITE:
         sl = CalculateSL_Composite(isBullish, entry, atr, buffer);
         break;
     }

// Safety: Enforce min/max SL distance
   if(sl > 0 && atr > 0)
     {
      double slDist = MathAbs(entry - sl);
      double minDist = atr * InpSL_MinDistanceATR;
      double maxDist = atr * InpSL_MaxDistanceATR;

      if(slDist < minDist)
        {
         sl = isBullish ? entry - minDist : entry + minDist;
         Print("SL adjusted to minimum distance: ", DoubleToString(minDist / point, 0), " pts");
        }
      else
         if(slDist > maxDist)
           {
            sl = isBullish ? entry - maxDist : entry + maxDist;
            Print("SL capped to maximum distance: ", DoubleToString(maxDist / point, 0), " pts");
           }
     }

   return NormalizePrice(sl);
  }

//+------------------------------------------------------------------+
//| SL Method: Fixed Points                                           |
//+------------------------------------------------------------------+
double CalculateSL_FixedPoints(bool isBullish, double entry, double point)
  {
   return isBullish ? entry - InpFixedSlPoints * point
          : entry + InpFixedSlPoints * point;
  }

//+------------------------------------------------------------------+
//| SL Method: ATR-Based                                              |
//+------------------------------------------------------------------+
double CalculateSL_ATR(bool isBullish, double entry, double atr)
  {
   return isBullish ? entry - atr * InpAtrSlMultiplier
          : entry + atr * InpAtrSlMultiplier;
  }

//+------------------------------------------------------------------+
//| SL Method: Structure (DR Origin/ChoCh Level)                      |
//| Places SL behind the active ChoCh origin (invalidation level)     |
//+------------------------------------------------------------------+
double CalculateSL_Structure(bool isBullish, double buffer)
  {
   double sl = 0;
   SDealingRange* dr = isBullish ? GetPointer(g_bullDR) : GetPointer(g_bearDR);

// Primary: ChoCh origin
   for(int i = 0; i < dr.originCount; i++)
     {
      if(dr.origins[i].role == ROLE_CHOCH)
        {
         sl = dr.origins[i].price;
         break;
        }
     }

// Fallback: external swing
   if(sl == 0)
     {
      sl = isBullish ? g_lastExternalLow : g_lastExternalHigh;
     }

// Fallback: recent extreme
   if(sl == 0)
     {
      if(isBullish)
         sl = iLow(_Symbol, PERIOD_CURRENT,
                   iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 0));
      else
         sl = iHigh(_Symbol, PERIOD_CURRENT,
                    iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 0));
     }

// Apply buffer
   sl = isBullish ? sl - buffer : sl + buffer;

   return sl;
  }

//+------------------------------------------------------------------+
//| SL Method: Recent Swing                                           |
//| Places SL behind the most recent external swing point             |
//+------------------------------------------------------------------+
double CalculateSL_Swing(bool isBullish, double buffer)
  {
   double sl = 0;

   if(isBullish)
      sl = g_lastExternalLow > 0 ? g_lastExternalLow :
           iLow(_Symbol, PERIOD_CURRENT,
                iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 0));
   else
      sl = g_lastExternalHigh > 0 ? g_lastExternalHigh :
           iHigh(_Symbol, PERIOD_CURRENT,
                 iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 0));

   return isBullish ? sl - buffer : sl + buffer;
  }

//+------------------------------------------------------------------+
//| SL Method: FVG First Candle                                       |
//| Places SL behind the first candle (C1) of the triggering FVG      |
//| Bullish FVG: SL below C1 low | Bearish FVG: SL above C1 high    |
//+------------------------------------------------------------------+
double CalculateSL_FVGCandle(bool isBullish, double buffer)
  {
   double sl = 0;
   int fvgIdx = -1;

// Find the FVG that triggered entry (or nearest active FVG)
   if(g_triggerPDType == PD_FVG && g_triggerPDIndex >= 0 && g_triggerPDIndex < g_fvgCount)
     {
      fvgIdx = g_triggerPDIndex;
     }
   else
     {
      // Find nearest untested FVG in the right direction
      double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
      double minDist = DBL_MAX;

      for(int i = 0; i < g_fvgCount; i++)
        {
         bool dirMatch = (isBullish && g_fvgList[i].type == FVG_BULLISH) ||
                         (!isBullish && g_fvgList[i].type == FVG_BEARISH);

         if(!dirMatch || g_fvgList[i].status == FVG_FULLY_FILLED)
            continue;

         double dist = MathAbs(currentPrice - g_fvgList[i].ce);
         if(dist < minDist)
           {
            minDist = dist;
            fvgIdx = i;
           }
        }
     }

   if(fvgIdx >= 0 && fvgIdx < g_fvgCount)
     {
      // C1 is the bar BEFORE the middle FVG candle (bar+1 from FVG bar)
      int fvgCurrentBar = iBarShift(_Symbol, PERIOD_CURRENT, g_fvgList[fvgIdx].time, false);
      int c1Bar = fvgCurrentBar + 1;

      if(c1Bar < iBars(_Symbol, PERIOD_CURRENT))
        {
         if(isBullish)
            sl = iLow(_Symbol, PERIOD_CURRENT, c1Bar) - buffer;
         else
            sl = iHigh(_Symbol, PERIOD_CURRENT, c1Bar) + buffer;
        }
     }

// Fallback to structure if no FVG found
   if(sl == 0)
     {
      Print("SL_FVG_CANDLE: No valid FVG found, falling back to Structure");
      sl = CalculateSL_Structure(isBullish, buffer);
     }

   return sl;
  }

//+------------------------------------------------------------------+
//| SL Method: Fibonacci Extension                                    |
//| Takes the relevant swing range and extends SL beyond the extreme  |
//| BUY: SL = SwingLow - SwingRange * (FibLevel-100)/100             |
//| SELL: SL = SwingHigh + SwingRange * (FibLevel-100)/100           |
//+------------------------------------------------------------------+
double CalculateSL_FibExtension(bool isBullish, double buffer)
  {
   double sl = 0;
   double swingHigh = 0, swingLow = 0;

// Try OTE zone swings first (most relevant)
   if(g_oteZone.isValid)
     {
      swingHigh = g_oteZone.swingHigh;
      swingLow = g_oteZone.swingLow;
     }
   else
     {
      // Find recent swing range
      int lookback = InpFibSL_SwingLookback;
      int highBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookback, 1);
      int lowBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookback, 1);

      swingHigh = iHigh(_Symbol, PERIOD_CURRENT, highBar);
      swingLow = iLow(_Symbol, PERIOD_CURRENT, lowBar);
     }

   if(swingHigh <= swingLow || swingHigh == 0)
     {
      Print("SL_FIB_EXTENSION: Invalid swing range, falling back to ATR");
      return CalculateSL_ATR(isBullish, iClose(_Symbol, PERIOD_CURRENT, 0), GetATR());
     }

   double swingRange = swingHigh - swingLow;
   double extension = (InpFibSL_Level - 100.0) / 100.0;

   if(isBullish)
      sl = swingLow - swingRange * extension - buffer;
   else
      sl = swingHigh + swingRange * extension + buffer;

   return sl;
  }

//+------------------------------------------------------------------+
//| SL Method: Max Loss Amount                                        |
//| Sets SL so that max loss = fixed currency amount                  |
//| Works best with LOT_FIXED mode; with LOT_RISK_PERCENT, the       |
//| lot size adjusts anyway so this becomes circular — in that case   |
//| we use InpFixedLot as reference lot.                              |
//+------------------------------------------------------------------+
double CalculateSL_MaxLossAmount(bool isBullish, double entry)
  {
   double maxLoss = InpMaxLossAmount;

// Determine the lot size reference
   double lot = InpFixedLot;
   if(InpLotMode == LOT_FIXED)
      lot = InpFixedLot;
   else
      lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN); // Use min lot as reference

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0 || lot <= 0)
     {
      Print("SL_MAX_LOSS_AMOUNT: Invalid tick/lot info, falling back to ATR");
      return CalculateSL_ATR(isBullish, entry, GetATR());
     }

// SL distance in price = maxLoss / (lot * tickValue / tickSize)
   double slDistancePrice = maxLoss * tickSize / (lot * tickValue);

   return isBullish ? entry - slDistancePrice : entry + slDistancePrice;
  }

//+------------------------------------------------------------------+
//| SL Method: Composite (Tightest Valid)                              |
//| Calculates SL using ALL methods, picks the tightest one that      |
//| still meets the minimum distance requirement                      |
//+------------------------------------------------------------------+
double CalculateSL_Composite(bool isBullish, double entry, double atr, double buffer)
  {
   double candidates[];
   ArrayResize(candidates, 0);
   double minDist = atr * InpSL_MinDistanceATR;

// Collect all valid SL candidates
   double sl;

// Structure
   sl = CalculateSL_Structure(isBullish, buffer);
   if(sl > 0 && MathAbs(entry - sl) >= minDist)
     { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

// Swing
   sl = CalculateSL_Swing(isBullish, buffer);
   if(sl > 0 && MathAbs(entry - sl) >= minDist)
     { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

// ATR
   sl = CalculateSL_ATR(isBullish, entry, atr);
   if(sl > 0 && MathAbs(entry - sl) >= minDist)
     { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

// FVG (only if relevant)
   if(g_triggerPDType == PD_FVG || g_fvgCount > 0)
     {
      sl = CalculateSL_FVGCandle(isBullish, buffer);
      if(sl > 0 && MathAbs(entry - sl) >= minDist)
        { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }
     }

// Fib Extension
   sl = CalculateSL_FibExtension(isBullish, buffer);
   if(sl > 0 && MathAbs(entry - sl) >= minDist)
     { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

// Pick tightest (closest to entry)
   if(ArraySize(candidates) == 0)
      return CalculateSL_ATR(isBullish, entry, atr); // Absolute fallback

   double best = candidates[0];
   double bestDist = MathAbs(entry - best);

   for(int i = 1; i < ArraySize(candidates); i++)
     {
      double dist = MathAbs(entry - candidates[i]);
      if(dist < bestDist)
        {
         best = candidates[i];
         bestDist = dist;
        }
     }

   Print("SL_COMPOSITE: Chose tightest SL at ", DoubleToString(best, _Digits),
         " (", DoubleToString(bestDist / _Point, 0), " pts from entry)");

   return best;
  }
//+------------------------------------------------------------------+
//| Calculate Take Profits (COMPLETE REWRITE - All Methods)           |
//+------------------------------------------------------------------+
void CalculateTakeProfits(bool isBullish)
  {
   double entry = iClose(_Symbol, PERIOD_CURRENT, 0);
   double sl = g_currentSignal.slPrice;
   double atr = GetATR();
   double risk = MathAbs(entry - sl);
   if(risk <= 0)
      risk = atr; // Fallback

   g_currentSignal.tp1Price = 0;
   g_currentSignal.tp2Price = 0;
   g_currentSignal.tp3Price = 0;

   switch(InpTpMode)
     {
      case TP_FIXED_RR:
         CalculateTP_FixedRR(isBullish, entry, risk);
         break;

      case TP_STRUCTURE:
         CalculateTP_Structure(isBullish, entry, risk);
         break;

      case TP_ATR_BASED:
         CalculateTP_ATR(isBullish, entry, atr);
         break;

      case TP_MULTIPLE_RR:
         CalculateTP_MultipleRR(isBullish, entry, risk);
         break;

      case TP_DR_TARGETS:
         CalculateTP_DRTargets(isBullish, entry, risk);
         break;
     }

// Normalize all TPs
   g_currentSignal.tp1Price = NormalizePrice(g_currentSignal.tp1Price);
   g_currentSignal.tp2Price = NormalizePrice(g_currentSignal.tp2Price);
   g_currentSignal.tp3Price = NormalizePrice(g_currentSignal.tp3Price);

// Validate: ensure TPs are in the right direction
   ValidateTPDirection(isBullish, entry);
  }

//+------------------------------------------------------------------+
//| TP Method: Fixed Risk:Reward (Single TP at full RR)               |
//+------------------------------------------------------------------+
void CalculateTP_FixedRR(bool isBullish, double entry, double risk)
  {
   g_currentSignal.tp1Price = isBullish ? entry + risk * InpRiskReward
                              : entry - risk * InpRiskReward;
   g_currentSignal.tp2Price = g_currentSignal.tp1Price; // Same - single TP
   g_currentSignal.tp3Price = g_currentSignal.tp1Price;
  }

//+------------------------------------------------------------------+
//| TP Method: DR Structure Targets                                   |
//| TP1=Internal, TP2=Opposing Origin Target, TP3=HTF Target         |
//+------------------------------------------------------------------+
void CalculateTP_Structure(bool isBullish, double entry, double risk)
  {
   SDealingRange* oppDR = isBullish ? GetPointer(g_bearDR) : GetPointer(g_bullDR);
   SDealingRange* sameDR = isBullish ? GetPointer(g_bullDR) : GetPointer(g_bearDR);

// TP1: Internal level from same DR (nearest in profit direction)
   for(int i = 0; i < sameDR.internalCount; i++)
     {
      if(sameDR.internals[i].isBroken)
         continue;
      double p = sameDR.internals[i].price;
      if(isBullish && p > entry)
        {
         g_currentSignal.tp1Price = p;
         break;
        }
      if(!isBullish && p < entry)
        {
         g_currentSignal.tp1Price = p;
         break;
        }
     }

// TP2: Nearest unreached target from opposing DR
   for(int i = 0; i < oppDR.originCount; i++)
     {
      if(oppDR.origins[i].role != ROLE_TARGET || oppDR.origins[i].isReached)
         continue;
      double p = oppDR.origins[i].price;
      if(isBullish && p > entry)
        {
         g_currentSignal.tp2Price = p;
         break;
        }
      if(!isBullish && p < entry)
        {
         g_currentSignal.tp2Price = p;
         break;
        }
     }

// TP3: HTF opposing target
   if(g_htfLayer.isInitialized)
     {
      SDealingRange* htfOppDR = isBullish ? GetPointer(g_htfLayer.bearDR) : GetPointer(g_htfLayer.bullDR);
      for(int i = 0; i < htfOppDR.originCount; i++)
        {
         if(htfOppDR.origins[i].role != ROLE_TARGET || htfOppDR.origins[i].isReached)
            continue;
         double p = htfOppDR.origins[i].price;
         if(isBullish && p > entry)
           {
            g_currentSignal.tp3Price = p;
            break;
           }
         if(!isBullish && p < entry)
           {
            g_currentSignal.tp3Price = p;
            break;
           }
        }
     }

// Fill gaps with RR-based fallback
   if(g_currentSignal.tp1Price == 0)
      g_currentSignal.tp1Price = isBullish ? entry + risk * InpTP1_RR : entry - risk * InpTP1_RR;
   if(g_currentSignal.tp2Price == 0)
      g_currentSignal.tp2Price = isBullish ? entry + risk * InpTP2_RR : entry - risk * InpTP2_RR;
   if(g_currentSignal.tp3Price == 0)
      g_currentSignal.tp3Price = isBullish ? entry + risk * InpTP3_RR : entry - risk * InpTP3_RR;
  }

//+------------------------------------------------------------------+
//| TP Method: ATR-Based                                              |
//+------------------------------------------------------------------+
void CalculateTP_ATR(bool isBullish, double entry, double atr)
  {
   g_currentSignal.tp1Price = isBullish ? entry + atr * InpPartialATR_Mult1
                              : entry - atr * InpPartialATR_Mult1;
   g_currentSignal.tp2Price = isBullish ? entry + atr * InpPartialATR_Mult2
                              : entry - atr * InpPartialATR_Mult2;
   g_currentSignal.tp3Price = isBullish ? entry + atr * InpPartialATR_Mult3
                              : entry - atr * InpPartialATR_Mult3;
  }

//+------------------------------------------------------------------+
//| TP Method: Multiple RR Levels                                     |
//| TP1=1R, TP2=2R, TP3=3R (or user-defined RR multiples)           |
//+------------------------------------------------------------------+
void CalculateTP_MultipleRR(bool isBullish, double entry, double risk)
  {
   g_currentSignal.tp1Price = isBullish ? entry + risk * InpTP1_RR : entry - risk * InpTP1_RR;
   g_currentSignal.tp2Price = isBullish ? entry + risk * InpTP2_RR : entry - risk * InpTP2_RR;
   g_currentSignal.tp3Price = isBullish ? entry + risk * InpTP3_RR : entry - risk * InpTP3_RR;
  }

//+------------------------------------------------------------------+
//| TP Method: DR Target Lines (NEW - Main Feature)                   |
//| Uses reclassified external IDMT lines from ChoCh as TPs          |
//| TP1 = nearest target to entry                                    |
//| TP2 = 2nd nearest                                                |
//| TP3 = 3rd nearest                                                |
//+------------------------------------------------------------------+
void CalculateTP_DRTargets(bool isBullish, double entry, double risk)
  {
   double tp1 = 0, tp2 = 0, tp3 = 0;

// Try to get DR Target Lines (reclassified externals)
   bool found = GetDRTargetPrices(entry, isBullish, tp1, tp2, tp3);

   if(found && tp1 > 0)
     {
      g_currentSignal.tp1Price = tp1;
      g_currentSignal.tp2Price = (tp2 > 0) ? tp2 : 0;
      g_currentSignal.tp3Price = (tp3 > 0) ? tp3 : 0;

      Print("TP_DR_TARGETS: Found ", (tp3 > 0 ? 3 : (tp2 > 0 ? 2 : 1)), " target(s)");
     }

// Fill missing TPs with opposing DR origin targets
   if(g_currentSignal.tp1Price == 0 || g_currentSignal.tp2Price == 0 || g_currentSignal.tp3Price == 0)
     {
      SDealingRange* oppDR = isBullish ? GetPointer(g_bearDR) : GetPointer(g_bullDR);

      for(int i = 0; i < oppDR.originCount; i++)
        {
         if(oppDR.origins[i].role != ROLE_TARGET || oppDR.origins[i].isReached)
            continue;

         double p = oppDR.origins[i].price;
         bool valid = (isBullish && p > entry) || (!isBullish && p < entry);
         if(!valid)
            continue;

         // Don't duplicate existing TPs
         if(MathAbs(p - g_currentSignal.tp1Price) < _Point * 5)
            continue;
         if(MathAbs(p - g_currentSignal.tp2Price) < _Point * 5)
            continue;

         if(g_currentSignal.tp1Price == 0)
           {
            g_currentSignal.tp1Price = p;
            continue;
           }
         if(g_currentSignal.tp2Price == 0)
           {
            g_currentSignal.tp2Price = p;
            continue;
           }
         if(g_currentSignal.tp3Price == 0)
           {
            g_currentSignal.tp3Price = p;
            break;
           }
        }
     }

// Final fallback: RR-based for any still-missing TPs
   if(g_currentSignal.tp1Price == 0)
      g_currentSignal.tp1Price = isBullish ? entry + risk * InpTP1_RR : entry - risk * InpTP1_RR;
   if(g_currentSignal.tp2Price == 0)
      g_currentSignal.tp2Price = isBullish ? entry + risk * InpTP2_RR : entry - risk * InpTP2_RR;
   if(g_currentSignal.tp3Price == 0)
      g_currentSignal.tp3Price = isBullish ? entry + risk * InpTP3_RR : entry - risk * InpTP3_RR;

// Ensure proper ordering (TP1 closest, TP3 farthest)
   EnsureTPOrdering(isBullish);
  }

//+------------------------------------------------------------------+
//| Ensure TPs are ordered: TP1 closest → TP3 farthest               |
//+------------------------------------------------------------------+
void EnsureTPOrdering(bool isBullish)
  {
   double tps[3];
   tps[0] = g_currentSignal.tp1Price;
   tps[1] = g_currentSignal.tp2Price;
   tps[2] = g_currentSignal.tp3Price;

   double entry = g_currentSignal.entryPrice > 0 ? g_currentSignal.entryPrice :
                  iClose(_Symbol, PERIOD_CURRENT, 0);

// Sort by distance from entry (ascending)
   for(int i = 0; i < 2; i++)
     {
      for(int j = 0; j < 2 - i; j++)
        {
         if(tps[j] > 0 && tps[j+1] > 0)
           {
            double dist1 = MathAbs(tps[j] - entry);
            double dist2 = MathAbs(tps[j+1] - entry);
            if(dist1 > dist2)
              {
               double temp = tps[j];
               tps[j] = tps[j+1];
               tps[j+1] = temp;
              }
           }
        }
     }

   g_currentSignal.tp1Price = tps[0];
   g_currentSignal.tp2Price = tps[1];
   g_currentSignal.tp3Price = tps[2];
  }

//+------------------------------------------------------------------+
//| Validate TP Direction (safety check)                              |
//+------------------------------------------------------------------+
void ValidateTPDirection(bool isBullish, double entry)
  {
   if(isBullish)
     {
      if(g_currentSignal.tp1Price <= entry)
         g_currentSignal.tp1Price = entry + GetATR();
      if(g_currentSignal.tp2Price <= entry)
         g_currentSignal.tp2Price = g_currentSignal.tp1Price * 1.5;
      if(g_currentSignal.tp3Price <= entry)
         g_currentSignal.tp3Price = g_currentSignal.tp1Price * 2.0;
     }
   else
     {
      if(g_currentSignal.tp1Price >= entry)
         g_currentSignal.tp1Price = entry - GetATR();
      if(g_currentSignal.tp2Price >= entry)
         g_currentSignal.tp2Price = g_currentSignal.tp1Price * 0.5 + entry * 0.5;
      if(g_currentSignal.tp3Price >= entry)
         g_currentSignal.tp3Price = g_currentSignal.tp1Price;
     }
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size                                                |
//+------------------------------------------------------------------+
double CalculateLotSize()
  {
   double lot = 0;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   switch(InpLotMode)
     {
      case LOT_FIXED:
         lot = InpFixedLot;
         break;

      case LOT_RISK_PERCENT:
        {
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double risk = balance * InpRiskPercent / 100.0;
         double sl = MathAbs(g_currentSignal.entryPrice - g_currentSignal.slPrice);

         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

         if(sl > 0 && tickValue > 0 && tickSize > 0)
           {
            double slPoints = sl / tickSize;
            lot = risk / (slPoints * tickValue);
           }
        }
      break;

      case LOT_BALANCE_PERCENT:
        {
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         lot = balance * InpRiskPercent / 100.0 / 100000.0;
        }
      break;
     }

// Normalize to lot step
   lot = MathFloor(lot / lotStep) * lotStep;

// Clamp to limits
   lot = MathMax(minLot, MathMin(maxLot, lot));

   return NormalizeDouble(lot, 2);
  }

//+------------------------------------------------------------------+
//| Validate Signal                                                   |
//+------------------------------------------------------------------+
bool ValidateSignal()
  {
   if(g_currentSignal.type == SIGNAL_NONE)
      return false;

   if(g_currentSignal.entryPrice <= 0)
      return false;

   if(g_currentSignal.slPrice <= 0)
      return false;

   if(g_currentSignal.tp1Price <= 0)
      return false;

   if(g_currentSignal.lotSize <= 0)
      return false;

// Check SL is reasonable
   bool isBullish = (g_currentSignal.type == SIGNAL_BUY);

   if(isBullish)
     {
      if(g_currentSignal.slPrice >= g_currentSignal.entryPrice)
         return false;
      if(g_currentSignal.tp1Price <= g_currentSignal.entryPrice)
         return false;
     }
   else
     {
      if(g_currentSignal.slPrice <= g_currentSignal.entryPrice)
         return false;
      if(g_currentSignal.tp1Price >= g_currentSignal.entryPrice)
         return false;
     }

// Check RR ratio
   if(g_currentSignal.riskReward < 0.5)
      return false;

// Check daily limits
   if(g_maxTradesReached || g_dailyLossReached)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Print Signal Generated                                            |
//+------------------------------------------------------------------+
void PrintSignalGenerated()
  {
   string dir = (g_currentSignal.type == SIGNAL_BUY) ? "BUY" : "SELL";

   Print("══════════════════════════════════════════════════════");
   Print("  SIGNAL GENERATED: ", dir);
   Print("  RR: ", DoubleToString(g_currentSignal.riskReward, 2));
   Print("  Entry: ", DoubleToString(g_currentSignal.entryPrice, _Digits));
   Print("  SL: ", DoubleToString(g_currentSignal.slPrice, _Digits));
   Print("  TP1: ", DoubleToString(g_currentSignal.tp1Price, _Digits));
   Print("  TP2: ", DoubleToString(g_currentSignal.tp2Price, _Digits));
   Print("  Lot: ", DoubleToString(g_currentSignal.lotSize, 2));
   Print("══════════════════════════════════════════════════════");

   if(InpAlertSignals)
     {
      string msg = dir + " Signal @ " + DoubleToString(g_currentSignal.entryPrice, _Digits);
      SendAlert(msg, InpAlertTrades, InpPushNotification, InpEmailNotification);
     }
  }



//+------------------------------------------------------------------+
//|              SECTION 5: SIGNAL HELPERS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Signal Description                                            |
//+------------------------------------------------------------------+
string GetSignalDescription()
  {
   if(!g_hasValidSignal)
      return "No Active Signal";

   string desc = "";
   desc += (g_currentSignal.type == SIGNAL_BUY) ? "BUY" : "SELL";
   desc += " @ " + DoubleToString(g_currentSignal.entryPrice, _Digits);
   desc += " via " + GetTriggerDescription(g_currentSignal.trigger);
   desc += " RR:" + DoubleToString(g_currentSignal.riskReward, 1);
   return desc;
  }

//+------------------------------------------------------------------+
//| Get Trigger Description                                           |
//+------------------------------------------------------------------+
string GetTriggerDescription(ENUM_SIGNAL_TRIGGER trigger)
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
         return "Fair Value Gap";
      case TRIGGER_OTE_ENTRY:
         return "OTE Zone";
      case TRIGGER_STACKED_ENTRY:
         return "Stacked Arrays";
      case TRIGGER_DISPLACEMENT:
         return "Displacement";
      default:
         return "None";
     }
  }




//+------------------------------------------------------------------+
//| Has Active Signal                                                 |
//+------------------------------------------------------------------+
bool HasActiveSignal()
  {
   return g_hasValidSignal && g_currentSignal.isValid;
  }

//+------------------------------------------------------------------+
//| Clear Signal                                                      |
//+------------------------------------------------------------------+
void ClearSignal()
  {
   g_hasValidSignal = false;
   g_waitingForOTE = false;
   g_currentSignal.Reset();
   g_pendingSignal.Reset();
  }

#endif // ICT_SIGNALENGINE_MQH
