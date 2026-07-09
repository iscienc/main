//+------------------------------------------------------------------+
//|                     ICT_SignalEngine.mqh                          |
//|              Signal Generation with Entry Logic                   |
//|                    ICT Unified Professional EA v12.0              |
//+------------------------------------------------------------------+
#ifndef ICT_SIGNALENGINE_MQH
#define ICT_SIGNALENGINE_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../StateMachine/ICT_NarrativeGate.mqh"
#include "../ML/ICT_MLEngine.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                            |
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
//|              SECTION 2: MAIN SIGNAL PROCESSING                    |
//+------------------------------------------------------------------+
// FIXED ProcessEntrySignals():
void ProcessEntrySignals()
{
   if(!InpEnableTrading || !g_tradingEnabled) return;
   if(!CheckAllFilters()) return;

   string narReason = "";
   bool tradeFound = false;
   bool isBullish = false;

   // Step 1: Try aligned direction (DR bias) — existing aligned presets (1-6)
   ENUM_TRADE_DIRECTION direction = g_currentDirection;
   if(direction != DIR_NONE && IsNarrativeTradable(direction, narReason))
   {
      isBullish  = (direction == DIR_BULLISH);
      tradeFound = true;
   }

   // Step 2: Try counter-direction chains (presets 7, 8, CUSTOM counter-dir)
   if(!tradeFound)
   {
      // DIR_NONE = accept any resolvedEntryDir
      if(IsNarrativeTradable(DIR_NONE, narReason))
      {
         ENUM_TRADE_DIRECTION resolvedDir = GetReadyInstanceDirection();
         if(resolvedDir != DIR_NONE)
         {
            isBullish  = (resolvedDir == DIR_BULLISH);
            tradeFound = true;
         }
      }
   }

   if(!tradeFound) return;

   if(!CheckForEntryTrigger(isBullish)) return;
   if(!ValidateEntryConditions(isBullish)) return;
   if(!CheckEntryConfirmations(isBullish)) return;
   if(g_mlInitialized && InpML_Mode != ML_OFF && ShouldMLBlockTrade())
   { RecordPrediction(g_mlPrediction.probability, false, 0); return; }
   if(!CheckExternalAgreement(isBullish)) return;
   GenerateTradeSignal(isBullish);
}

// NEW helper — returns resolvedEntryDir of first fully-staged active instance
ENUM_TRADE_DIRECTION GetReadyInstanceDirection()
{
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
   {
      if(!g_smInstances[i].active) continue;
      if(!g_smInstances[i].stageDone[SM_MAX_STAGES - 1]) continue;
      ENUM_TRADE_DIRECTION d = g_smInstances[i].resolvedEntryDir;
      if(d == DIR_NONE) d = g_smInstances[i].direction;
      return d;
   }
   return DIR_NONE;
}

//+------------------------------------------------------------------+
//| Check for Entry Trigger                                           |
//+------------------------------------------------------------------+
bool CheckForEntryTrigger(bool isBullish)
{
   int idx = -1;
   ENUM_NARRATIVE_ZONE_TYPE narrativeType = NZ_NONE;

   g_triggerNarrativeIndex = -1;
   g_triggerNarrativeType = NZ_NONE;

   if(!IsPriceAtAnyNarrativeZone(isBullish, narrativeType, idx))
      return false;

   bool result = false;

   switch(narrativeType)
   {
      case NZ_ORDER_BLOCK:
         result = ValidateOrderBlockEntry(idx, isBullish);
         break;

      case NZ_BREAKER_BLOCK:
         result = ValidateBreakerEntry(idx, isBullish);
         break;

      case NZ_MITIGATION_BLOCK:
         result = ValidateMitigationEntry(idx, isBullish);
         break;

      case NZ_FVG:
         result = ValidateFVGEntry(idx, isBullish);
         break;

      case NZ_OTE_ZONE:
         result = ValidateOTEEntry(isBullish);
         break;

      default:
         result = false;
         break;
   }

   if(result)
   {
      g_triggerNarrativeIndex = idx;
      g_triggerNarrativeType = narrativeType;
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

   bool isBullishOB = (ob.type == OB_BULLISH);
   if(isBullish != isBullishOB)
      return false;

   if(ob.status == OB_FAILED || ob.status == OB_MITIGATED)
      return false;

   if(ob.testCount >= InpOB_MaxTestCount)
      return false;

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

   bool isBullishBreaker = (breaker.type == BREAKER_BULLISH);
   if(isBullish != isBullishBreaker)
      return false;

   if(breaker.isTested)
      return false;

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

   if(isBullish != g_oteZone.isBullish)
      return false;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double zoneTop = g_oteZone.ZoneTop();
   double zoneBottom = g_oteZone.ZoneBottom();

   return (price >= zoneBottom && price <= zoneTop);
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
ENUM_SIGNAL_TRIGGER TriggerFromNarrativeType(ENUM_NARRATIVE_ZONE_TYPE t)
{
   switch(t)
   {
      case NZ_ORDER_BLOCK:      return TRIGGER_OB_ENTRY;
      case NZ_BREAKER_BLOCK:    return TRIGGER_BREAKER_ENTRY;
      case NZ_MITIGATION_BLOCK: return TRIGGER_MB_ENTRY;
      case NZ_FVG:              return TRIGGER_FVG_ENTRY;
      case NZ_OTE_ZONE:         return TRIGGER_OTE_ENTRY;
      default:                  return TRIGGER_NONE;
   }
}

//+------------------------------------------------------------------+
//| Generate Trade Signal                                             |
//+------------------------------------------------------------------+
void GenerateTradeSignal(bool isBullish)
{
   g_currentSignal.Reset();

   g_currentSignal.type = isBullish ? SIGNAL_BUY : SIGNAL_SELL;
   g_currentSignal.trigger = TriggerFromNarrativeType(g_triggerNarrativeType);
   g_currentSignal.time = TimeCurrent();
   g_currentSignal.entryPrice = iClose(_Symbol, PERIOD_CURRENT, 0);

   g_currentSignal.slPrice = CalculateStopLoss(isBullish);
   CalculateTakeProfits(isBullish);
   g_currentSignal.lotSize = CalculateLotSize();

   double risk = MathAbs(g_currentSignal.entryPrice - g_currentSignal.slPrice);
   double reward = MathAbs(g_currentSignal.tp1Price - g_currentSignal.entryPrice);
   g_currentSignal.riskReward = (risk > 0.0) ? reward / risk : 0.0;

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
//| Calculate Stop Loss (all methods)                                 |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBullish)
{
   double sl = 0.0;
   double atr = GetATR();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double buffer = InpSlBufferPoints * point;
   double entry = iClose(_Symbol, PERIOD_CURRENT, 0);

   switch(InpSlMode)
   {
      case SL_FIXED_POINTS:    sl = CalculateSL_FixedPoints(isBullish, entry, point); break;
      case SL_ATR_BASED:       sl = CalculateSL_ATR(isBullish, entry, atr); break;
      case SL_STRUCTURE:       sl = CalculateSL_Structure(isBullish, buffer); break;
      case SL_SWING:           sl = CalculateSL_Swing(isBullish, buffer); break;
      case SL_FVG_CANDLE:      sl = CalculateSL_FVGCandle(isBullish, buffer); break;
      case SL_FIB_EXTENSION:   sl = CalculateSL_FibExtension(isBullish, buffer); break;
      case SL_MAX_LOSS_AMOUNT: sl = CalculateSL_MaxLossAmount(isBullish, entry); break;
      case SL_COMPOSITE:       sl = CalculateSL_Composite(isBullish, entry, atr, buffer); break;
   }

   if(sl > 0 && atr > 0)
   {
      double slDist = MathAbs(entry - sl);
      double minDist = atr * InpSL_MinDistanceATR;
      double maxDist = atr * InpSL_MaxDistanceATR;

      if(slDist < minDist)
         sl = isBullish ? entry - minDist : entry + minDist;
      else if(slDist > maxDist)
         sl = isBullish ? entry - maxDist : entry + maxDist;
   }

   return NormalizePrice(sl);
}

double CalculateSL_FixedPoints(bool isBullish, double entry, double point)
{
   return isBullish ? entry - InpFixedSlPoints * point : entry + InpFixedSlPoints * point;
}

double CalculateSL_ATR(bool isBullish, double entry, double atr)
{
   return isBullish ? entry - atr * InpAtrSlMultiplier : entry + atr * InpAtrSlMultiplier;
}

double CalculateSL_Structure(bool isBullish, double buffer)
{
   double sl = 0.0;
   SDealingRange* dr = isBullish ? GetPointer(g_bullDR) : GetPointer(g_bearDR);

   for(int i = 0; i < dr.originCount; i++)
   {
      if(dr.origins[i].role == ROLE_CHOCH)
      {
         sl = dr.origins[i].price;
         break;
      }
   }

   if(sl == 0.0)
      sl = isBullish ? g_lastExternalLow : g_lastExternalHigh;

   if(sl == 0.0)
   {
      if(isBullish)
         sl = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 0));
      else
         sl = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 0));
   }

   return isBullish ? sl - buffer : sl + buffer;
}

double CalculateSL_Swing(bool isBullish, double buffer)
{
   double sl = 0.0;

   if(isBullish)
      sl = (g_lastExternalLow > 0) ? g_lastExternalLow :
           iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 0));
   else
      sl = (g_lastExternalHigh > 0) ? g_lastExternalHigh :
           iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 0));

   return isBullish ? sl - buffer : sl + buffer;
}

double CalculateSL_FVGCandle(bool isBullish, double buffer)
{
   double sl = 0.0;
   int fvgIdx = -1;

   if(g_triggerNarrativeType == NZ_FVG && g_triggerNarrativeIndex >= 0 && g_triggerNarrativeIndex < g_fvgCount)
   {
      fvgIdx = g_triggerNarrativeIndex;
   }
   else
   {
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
      int fvgCurrentBar = iBarShift(_Symbol, PERIOD_CURRENT, g_fvgList[fvgIdx].time, false);
      int c1Bar = fvgCurrentBar + 1;

      if(c1Bar < iBars(_Symbol, PERIOD_CURRENT))
      {
         if(isBullish) sl = iLow(_Symbol, PERIOD_CURRENT, c1Bar) - buffer;
         else          sl = iHigh(_Symbol, PERIOD_CURRENT, c1Bar) + buffer;
      }
   }

   if(sl == 0.0)
      sl = CalculateSL_Structure(isBullish, buffer);

   return sl;
}

double CalculateSL_FibExtension(bool isBullish, double buffer)
{
   double swingHigh = 0.0, swingLow = 0.0;

   if(g_oteZone.isValid)
   {
      swingHigh = g_oteZone.swingHigh;
      swingLow = g_oteZone.swingLow;
   }
   else
   {
      int lookback = InpFibSL_SwingLookback;
      int highBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, lookback, 1);
      int lowBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, lookback, 1);
      swingHigh = iHigh(_Symbol, PERIOD_CURRENT, highBar);
      swingLow = iLow(_Symbol, PERIOD_CURRENT, lowBar);
   }

   if(swingHigh <= swingLow || swingHigh == 0.0)
      return CalculateSL_ATR(isBullish, iClose(_Symbol, PERIOD_CURRENT, 0), GetATR());

   double swingRange = swingHigh - swingLow;
   double extension = (InpFibSL_Level - 100.0) / 100.0;

   if(isBullish) return swingLow - swingRange * extension - buffer;
   return swingHigh + swingRange * extension + buffer;
}

double CalculateSL_MaxLossAmount(bool isBullish, double entry)
{
   double maxLoss = InpMaxLossAmount;
   double lot = (InpLotMode == LOT_FIXED) ? InpFixedLot : SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0 || lot <= 0)
      return CalculateSL_ATR(isBullish, entry, GetATR());

   double slDistancePrice = maxLoss * tickSize / (lot * tickValue);
   return isBullish ? entry - slDistancePrice : entry + slDistancePrice;
}

double CalculateSL_Composite(bool isBullish, double entry, double atr, double buffer)
{
   double candidates[];
   ArrayResize(candidates, 0);

   double minDist = atr * InpSL_MinDistanceATR;
   double sl = 0.0;

   sl = CalculateSL_Structure(isBullish, buffer);
   if(sl > 0 && MathAbs(entry - sl) >= minDist) { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

   sl = CalculateSL_Swing(isBullish, buffer);
   if(sl > 0 && MathAbs(entry - sl) >= minDist) { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

   sl = CalculateSL_ATR(isBullish, entry, atr);
   if(sl > 0 && MathAbs(entry - sl) >= minDist) { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

   if(g_triggerNarrativeType == NZ_FVG || g_fvgCount > 0)
   {
      sl = CalculateSL_FVGCandle(isBullish, buffer);
      if(sl > 0 && MathAbs(entry - sl) >= minDist) { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }
   }

   sl = CalculateSL_FibExtension(isBullish, buffer);
   if(sl > 0 && MathAbs(entry - sl) >= minDist) { ArrayResize(candidates, ArraySize(candidates)+1); candidates[ArraySize(candidates)-1] = sl; }

   if(ArraySize(candidates) == 0)
      return CalculateSL_ATR(isBullish, entry, atr);

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

   return best;
}

//+------------------------------------------------------------------+
//| Calculate Take Profits                                            |
//+------------------------------------------------------------------+
void CalculateTakeProfits(bool isBullish)
{
   double entry = iClose(_Symbol, PERIOD_CURRENT, 0);
   double sl = g_currentSignal.slPrice;
   double atr = GetATR();
   double risk = MathAbs(entry - sl);
   if(risk <= 0) risk = atr;

   g_currentSignal.tp1Price = 0;
   g_currentSignal.tp2Price = 0;
   g_currentSignal.tp3Price = 0;

   switch(InpTpMode)
   {
      case TP_FIXED_RR:    CalculateTP_FixedRR(isBullish, entry, risk); break;
      case TP_STRUCTURE:   CalculateTP_Structure(isBullish, entry, risk); break;
      case TP_ATR_BASED:   CalculateTP_ATR(isBullish, entry, atr); break;
      case TP_MULTIPLE_RR: CalculateTP_MultipleRR(isBullish, entry, risk); break;
      case TP_DR_TARGETS:  CalculateTP_DRTargets(isBullish, entry, risk); break;
   }

   g_currentSignal.tp1Price = NormalizePrice(g_currentSignal.tp1Price);
   g_currentSignal.tp2Price = NormalizePrice(g_currentSignal.tp2Price);
   g_currentSignal.tp3Price = NormalizePrice(g_currentSignal.tp3Price);

   ValidateTPDirection(isBullish, entry);
}

void CalculateTP_FixedRR(bool isBullish, double entry, double risk)
{
   g_currentSignal.tp1Price = isBullish ? entry + risk * InpRiskReward : entry - risk * InpRiskReward;
   g_currentSignal.tp2Price = g_currentSignal.tp1Price;
   g_currentSignal.tp3Price = g_currentSignal.tp1Price;
}

void CalculateTP_Structure(bool isBullish, double entry, double risk)
{
   SDealingRange* oppDR = isBullish ? GetPointer(g_bearDR) : GetPointer(g_bullDR);
   SDealingRange* sameDR = isBullish ? GetPointer(g_bullDR) : GetPointer(g_bearDR);

   for(int i = 0; i < sameDR.internalCount; i++)
   {
      if(sameDR.internals[i].isBroken) continue;
      double p = sameDR.internals[i].price;
      if((isBullish && p > entry) || (!isBullish && p < entry))
      {
         g_currentSignal.tp1Price = p;
         break;
      }
   }

   for(int j = 0; j < oppDR.originCount; j++)
   {
      if(oppDR.origins[j].role != ROLE_TARGET || oppDR.origins[j].isReached) continue;
      double p = oppDR.origins[j].price;
      if((isBullish && p > entry) || (!isBullish && p < entry))
      {
         g_currentSignal.tp2Price = p;
         break;
      }
   }

   if(g_htfLayer.isInitialized)
   {
      SDealingRange* htfOppDR = isBullish ? GetPointer(g_htfLayer.bearDR) : GetPointer(g_htfLayer.bullDR);
      for(int k = 0; k < htfOppDR.originCount; k++)
      {
         if(htfOppDR.origins[k].role != ROLE_TARGET || htfOppDR.origins[k].isReached) continue;
         double p = htfOppDR.origins[k].price;
         if((isBullish && p > entry) || (!isBullish && p < entry))
         {
            g_currentSignal.tp3Price = p;
            break;
         }
      }
   }

   if(g_currentSignal.tp1Price == 0) g_currentSignal.tp1Price = isBullish ? entry + risk * InpTP1_RR : entry - risk * InpTP1_RR;
   if(g_currentSignal.tp2Price == 0) g_currentSignal.tp2Price = isBullish ? entry + risk * InpTP2_RR : entry - risk * InpTP2_RR;
   if(g_currentSignal.tp3Price == 0) g_currentSignal.tp3Price = isBullish ? entry + risk * InpTP3_RR : entry - risk * InpTP3_RR;
}

void CalculateTP_ATR(bool isBullish, double entry, double atr)
{
   g_currentSignal.tp1Price = isBullish ? entry + atr * InpPartialATR_Mult1 : entry - atr * InpPartialATR_Mult1;
   g_currentSignal.tp2Price = isBullish ? entry + atr * InpPartialATR_Mult2 : entry - atr * InpPartialATR_Mult2;
   g_currentSignal.tp3Price = isBullish ? entry + atr * InpPartialATR_Mult3 : entry - atr * InpPartialATR_Mult3;
}

void CalculateTP_MultipleRR(bool isBullish, double entry, double risk)
{
   g_currentSignal.tp1Price = isBullish ? entry + risk * InpTP1_RR : entry - risk * InpTP1_RR;
   g_currentSignal.tp2Price = isBullish ? entry + risk * InpTP2_RR : entry - risk * InpTP2_RR;
   g_currentSignal.tp3Price = isBullish ? entry + risk * InpTP3_RR : entry - risk * InpTP3_RR;
}

void CalculateTP_DRTargets(bool isBullish, double entry, double risk)
{
   double tp1 = 0, tp2 = 0, tp3 = 0;
   bool found = GetDRTargetPrices(entry, isBullish, tp1, tp2, tp3);

   if(found && tp1 > 0)
   {
      g_currentSignal.tp1Price = tp1;
      g_currentSignal.tp2Price = (tp2 > 0) ? tp2 : 0;
      g_currentSignal.tp3Price = (tp3 > 0) ? tp3 : 0;
   }

   if(g_currentSignal.tp1Price == 0 || g_currentSignal.tp2Price == 0 || g_currentSignal.tp3Price == 0)
   {
      SDealingRange* oppDR = isBullish ? GetPointer(g_bearDR) : GetPointer(g_bullDR);

      for(int i = 0; i < oppDR.originCount; i++)
      {
         if(oppDR.origins[i].role != ROLE_TARGET || oppDR.origins[i].isReached) continue;
         double p = oppDR.origins[i].price;
         bool valid = (isBullish && p > entry) || (!isBullish && p < entry);
         if(!valid) continue;

         if(MathAbs(p - g_currentSignal.tp1Price) < _Point * 5) continue;
         if(MathAbs(p - g_currentSignal.tp2Price) < _Point * 5) continue;

         if(g_currentSignal.tp1Price == 0) { g_currentSignal.tp1Price = p; continue; }
         if(g_currentSignal.tp2Price == 0) { g_currentSignal.tp2Price = p; continue; }
         if(g_currentSignal.tp3Price == 0) { g_currentSignal.tp3Price = p; break; }
      }
   }

   if(g_currentSignal.tp1Price == 0) g_currentSignal.tp1Price = isBullish ? entry + risk * InpTP1_RR : entry - risk * InpTP1_RR;
   if(g_currentSignal.tp2Price == 0) g_currentSignal.tp2Price = isBullish ? entry + risk * InpTP2_RR : entry - risk * InpTP2_RR;
   if(g_currentSignal.tp3Price == 0) g_currentSignal.tp3Price = isBullish ? entry + risk * InpTP3_RR : entry - risk * InpTP3_RR;

   EnsureTPOrdering(isBullish);
}

void EnsureTPOrdering(bool isBullish)
{
   double tps[3];
   tps[0] = g_currentSignal.tp1Price;
   tps[1] = g_currentSignal.tp2Price;
   tps[2] = g_currentSignal.tp3Price;

   double entry = (g_currentSignal.entryPrice > 0) ? g_currentSignal.entryPrice : iClose(_Symbol, PERIOD_CURRENT, 0);

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
               double tmp = tps[j];
               tps[j] = tps[j+1];
               tps[j+1] = tmp;
            }
         }
      }
   }

   g_currentSignal.tp1Price = tps[0];
   g_currentSignal.tp2Price = tps[1];
   g_currentSignal.tp3Price = tps[2];
}

void ValidateTPDirection(bool isBullish, double entry)
{
   if(isBullish)
   {
      if(g_currentSignal.tp1Price <= entry) g_currentSignal.tp1Price = entry + GetATR();
      if(g_currentSignal.tp2Price <= entry) g_currentSignal.tp2Price = g_currentSignal.tp1Price * 1.5;
      if(g_currentSignal.tp3Price <= entry) g_currentSignal.tp3Price = g_currentSignal.tp1Price * 2.0;
   }
   else
   {
      if(g_currentSignal.tp1Price >= entry) g_currentSignal.tp1Price = entry - GetATR();
      if(g_currentSignal.tp2Price >= entry) g_currentSignal.tp2Price = g_currentSignal.tp1Price * 0.5 + entry * 0.5;
      if(g_currentSignal.tp3Price >= entry) g_currentSignal.tp3Price = g_currentSignal.tp1Price;
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                                |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lot = 0.0;

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

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Validate Signal                                                   |
//+------------------------------------------------------------------+
bool ValidateSignal()
{
   if(g_currentSignal.type == SIGNAL_NONE) return false;
   if(g_currentSignal.entryPrice <= 0) return false;
   if(g_currentSignal.slPrice <= 0) return false;
   if(g_currentSignal.tp1Price <= 0) return false;
   if(g_currentSignal.lotSize <= 0) return false;

   bool isBullish = (g_currentSignal.type == SIGNAL_BUY);

   if(isBullish)
   {
      if(g_currentSignal.slPrice >= g_currentSignal.entryPrice) return false;
      if(g_currentSignal.tp1Price <= g_currentSignal.entryPrice) return false;
   }
   else
   {
      if(g_currentSignal.slPrice <= g_currentSignal.entryPrice) return false;
      if(g_currentSignal.tp1Price >= g_currentSignal.entryPrice) return false;
   }

   if(g_currentSignal.riskReward < 0.5) return false;
   if(g_maxTradesReached || g_dailyLossReached) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Print Signal Generated                                            |
//+------------------------------------------------------------------+
void PrintSignalGenerated()
{
   string dir = (g_currentSignal.type == SIGNAL_BUY) ? "BUY" : "SELL";

   Print("======================================================");
   Print("SIGNAL GENERATED: ", dir);
   Print("RR: ", DoubleToString(g_currentSignal.riskReward, 2));
   Print("Entry: ", DoubleToString(g_currentSignal.entryPrice, _Digits));
   Print("SL: ", DoubleToString(g_currentSignal.slPrice, _Digits));
   Print("TP1: ", DoubleToString(g_currentSignal.tp1Price, _Digits));
   Print("TP2: ", DoubleToString(g_currentSignal.tp2Price, _Digits));
   Print("Lot: ", DoubleToString(g_currentSignal.lotSize, 2));
   Print("======================================================");

   if(InpAlertSignals)
   {
      string msg = dir + " Signal @ " + DoubleToString(g_currentSignal.entryPrice, _Digits);
      SendAlert(msg, InpAlertTrades, InpPushNotification, InpEmailNotification);
   }
}

//+------------------------------------------------------------------+
//|              SECTION 5: SIGNAL HELPERS                            |
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

string GetTriggerDescription(ENUM_SIGNAL_TRIGGER trigger)
{
   switch(trigger)
   {
      case TRIGGER_OB_ENTRY:      return "Order Block";
      case TRIGGER_BREAKER_ENTRY: return "Breaker Block";
      case TRIGGER_MB_ENTRY:      return "Mitigation Block";
      case TRIGGER_FVG_ENTRY:     return "Fair Value Gap";
      case TRIGGER_OTE_ENTRY:     return "OTE Zone";
      case TRIGGER_DISPLACEMENT:  return "Displacement";
      default:                    return "None";
   }
}

bool HasActiveSignal()
{
   return g_hasValidSignal && g_currentSignal.isValid;
}

void ClearSignal()
{
   g_hasValidSignal = false;
   g_waitingForOTE = false;
   g_currentSignal.Reset();
   g_pendingSignal.Reset();
}

#endif // ICT_SIGNALENGINE_MQH