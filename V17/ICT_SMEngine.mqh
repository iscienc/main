//+------------------------------------------------------------------+
//|                 ICT UNIFIED                                      |
//|                                      ICT_SMEngine.mqh            |
//|                   "ICT Unified Professional EA v18"              |
//+------------------------------------------------------------------+
#ifndef ICT_SMENGINE_MQH
#define ICT_SMENGINE_MQH

#include "ICT_SMTypes.mqh"
#include "ICT_SMPresets.mqh"
#include "ICT_SMDetectors.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../ML/ICT_ShadowTrades.mqh"



//+------------------------------------------------------------------+
bool InitializeSMEngine()
  {
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
      g_smInstances[i].Reset();
   g_smInstanceCount    = 0;
   g_smNextInstanceId   = 1;
   g_smBarCounter       = 0;
   g_lastSMEvent.Reset();
   g_nextSMCausalTag    = 1;
   g_smActiveEntryInstance = -1;

   SM_LoadPreset();
   SM_BuildLoadedElementSet();
   SM_LogLoadedElementSet();

   Print("SM Engine init. Preset=", EnumToString(InpSM_Preset));
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SM_RefreshLoadedSet()
  {
   SM_BuildLoadedElementSet();
   SM_LogLoadedElementSet();
  }

//+------------------------------------------------------------------+
void SM_ResetLoadedElements()
  {
   ArrayInitialize(g_smElemLoaded, false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SM_MarkLoaded(ENUM_SM_ELEMENT e)
  {
   int idx = (int)e;
   if(idx > 0 && idx < 128)
      g_smElemLoaded[idx] = true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_IsElementLoaded(ENUM_SM_ELEMENT e)
  {
   int idx = (int)e;
   if(idx <= 0 || idx >= 128)
      return false;
   return g_smElemLoaded[idx];
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SM_BuildLoadedElementSet()
  {
   SM_ResetLoadedElements();

   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      SM_MarkLoaded(g_smStageCfg[s].primaryElem);
      SM_MarkLoaded(g_smStageCfg[s].secondaryElem);
     }

   g_needDetectOB =
      SM_IsElementLoaded(SM_ELEM_ORDER_BLOCK) ||
      SM_IsElementLoaded(SM_ELEM_BREAKER) ||
      SM_IsElementLoaded(SM_ELEM_MITIGATION);

   g_needDetectFVG =
      SM_IsElementLoaded(SM_ELEM_FVG) ||
      SM_IsElementLoaded(SM_ELEM_IFVG) ||
      SM_IsElementLoaded(SM_ELEM_FVG_CE) ||
      SM_IsElementLoaded(SM_ELEM_VOLUME_IMBALANCE) ||
      SM_IsElementLoaded(SM_ELEM_LIQUIDITY_VOID);

   g_needDetectOTE = SM_IsElementLoaded(SM_ELEM_OTE_ZONE);

   g_needDetectAMD =
      SM_IsElementLoaded(SM_ELEM_AMD_ACCUMULATION) ||
      SM_IsElementLoaded(SM_ELEM_AMD_MANIPULATION) ||
      SM_IsElementLoaded(SM_ELEM_AMD_DISTRIBUTION);

// Also require AMD runtime when any stage direction policy depends on AMD
   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      if(g_smStageCfg[s].dirPolicy == SM_DIR_FROM_AMD)
        {
         g_needDetectAMD = true;
         break;
        }
     }

   g_needDetectJudas = SM_IsElementLoaded(SM_ELEM_JUDAS_SWING);
   g_needDetectSMT = SM_IsElementLoaded(SM_ELEM_SMT_DIVERGENCE);
   g_needDetectKillzone = SM_IsElementLoaded(SM_ELEM_KILLZONE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SM_LogLoadedElementSet()
  {
   Print("SM Loaded Set:",
         " OB=", (g_needDetectOB ? "ON" : "OFF"),
         " FVG=", (g_needDetectFVG ? "ON" : "OFF"),
         " OTE=", (g_needDetectOTE ? "ON" : "OFF"),
         " AMD=", (g_needDetectAMD ? "ON" : "OFF"),
         " Judas=", (g_needDetectJudas ? "ON" : "OFF"),
         " SMT=", (g_needDetectSMT ? "ON" : "OFF"),
         " KZ=", (g_needDetectKillzone ? "ON" : "OFF"));
  }

//+------------------------------------------------------------------+
SSMInstance* SM_AllocInstance()
  {
   if(InpSM_InstancePolicy == SM_INSTANCE_REPLACE)
     {
      for(int i = 0; i < SM_MAX_INSTANCES; i++)
         g_smInstances[i].Reset();
      g_smInstanceCount = 0;
     }
   if(g_smInstanceCount >= InpSM_MaxInstances)
      return NULL;

   int fi = -1;
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
      if(!g_smInstances[i].active)
        {
         fi = i;
         break;
        }
   if(fi < 0)
      return NULL;

   g_smInstances[fi].Reset();
   g_smInstances[fi].active = true;
   g_smInstances[fi].id     = g_smNextInstanceId++;
   g_smInstanceCount++;
   return GetPointer(g_smInstances[fi]);
  }

//+------------------------------------------------------------------+
void SM_DeactivateInstance(int i)
  {
   if(i < 0 || i >= SM_MAX_INSTANCES)
      return;
   if(!g_smInstances[i].active)
      return;
   g_smInstances[i].Reset();
   g_smInstanceCount = MathMax(0, g_smInstanceCount - 1);
  }

//+------------------------------------------------------------------+
//| Evaluate one stage of one instance. Returns true if stage done.  |
//+------------------------------------------------------------------+
bool SM_EvaluateStage(int instIdx, int s)
  {

   SSMStageConfig cfg = g_smStageCfg[s];
   SSMInstance *inst = GetPointer(g_smInstances[instIdx]);

   int ptag = -1, stag = -1;
   double pprice = 0, sprice = 0;
   bool primOK = false, secOK = false;

   if(cfg.primaryElem != SM_ELEM_NONE)
      primOK = SM_CheckElementSatisfied(cfg.primaryElem, cfg.primaryTF,
                                        inst, cfg, ptag, pprice);
   else
      primOK = true;

   if(cfg.secondaryElem != SM_ELEM_NONE)
      secOK = SM_CheckElementSatisfied(cfg.secondaryElem, cfg.secondaryTF,
                                       inst, cfg, stag, sprice);
   else
      // secOK = (cfg.logic != SM_LOGIC_AND);
      secOK = true;   // FIX: NONE should never block, even for AND

   bool ok = false;
   switch(cfg.logic)
     {
      case SM_LOGIC_SINGLE:
         ok = primOK;
         break;
      case SM_LOGIC_AND:
         ok = primOK && secOK;
         break;
      case SM_LOGIC_OR:
         ok = primOK || secOK;
         break;
     }
   if(!ok)
     {
      PrintFormat("[SMDBG][StageFail] chain=%d stage=%d prim=%s sec=%s logic=%d primOK=%d secOK=%d req=%d",
                  inst.id, s,
                  SM_ElementShortName(cfg.primaryElem),
                  SM_ElementShortName(cfg.secondaryElem),
                  (int)cfg.logic, (int)primOK, (int)secOK, (int)cfg.required);
      return false;
     }

// ★ CAUSAL CONTINUITY: causal element must trace to the chain's origin
   if(cfg.causalLink && inst.birthEventTag >= 0)
     {
      int usedTag = (ptag >= 0) ? ptag : stag;
      if(usedTag >= 0 && usedTag != inst.birthEventTag)
         return false;   // different lineage → not relevant to this chain
     }

// Stage satisfied
   inst.stageDone[s]    = true;
// ★ Capture both slot prices for later zone-based entry
   inst.stagePrimaryPrice[s]   = pprice;
   inst.stageSecondaryPrice[s] = sprice;
   inst.stageTime[s]    = TimeCurrent();
   inst.stageBarCtr[s]  = g_smBarCounter;
// ★ NEW: Capture resolved dir at Entry stage
//if(s == SM_MAX_STAGES - 1)


   if(s == 0)
     {
      ENUM_TRADE_DIRECTION d = SM_GetStageDirection(*inst, cfg);
      if(d != DIR_NONE)
         inst.direction = d;
      inst.triggerPrice    = (pprice > 0) ? pprice : iClose(_Symbol, PERIOD_CURRENT, 0);
      inst.birthEventTag   = g_lastSMEvent.valid ? g_lastSMEvent.tag : -1;
      // inst.triggerEventTag = g_lastSMEvent.valid ? g_lastSMEvent.tag : -1;

      // ★ FIX 1: Detect and mark counter-direction instances
      bool counterDir = false;
      for(int cs = 0; cs < SM_MAX_STAGES; cs++)
        {
         ENUM_SM_DIRECTION_POLICY p = g_smStageCfg[cs].dirPolicy;
         if(p == SM_DIR_COUNTER_TRIGGER || p == SM_DIR_INVERT_TRIGGER ||
            p == SM_DIR_FIXED_BULL      || p == SM_DIR_FIXED_BEAR)
           {
            counterDir = true;
            break;
           }
        }
      inst.isCounterDirPreset = counterDir;
     }
   if(s == 1)
     {
      inst.confirmPrice   = (pprice > 0) ? pprice : iClose(_Symbol, PERIOD_CURRENT, 0);
      inst.barsToConfirm  = g_smBarCounter - inst.stageBarCtr[0];
     }
   if(s == SM_MAX_STAGES - 1)
     {
      inst.causalTagUsed   = (ptag >= 0) ? ptag : stag;
      inst.barsToEntry     = g_smBarCounter - inst.stageBarCtr[0];
      inst.totalBarsInChain = inst.barsToEntry;
      // ★ NEW: Capture resolved direction at Entry stage
      inst.resolvedEntryDir = SM_GetStageDirection(*inst, cfg);  // single capture  CORRECT
      if(inst.resolvedEntryDir == DIR_NONE)
         inst.resolvedEntryDir = inst.direction; // fallback
      // Mark counter-direction chains:
      inst.isCounterDirPreset = (inst.resolvedEntryDir != DIR_NONE &&
                                 inst.direction != DIR_NONE &&
                                 inst.resolvedEntryDir != inst.direction);
     }

   if(s < SM_MAX_STAGES - 1)
      inst.currentStage = s + 1;
   return true;
  }

//+------------------------------------------------------------------+
//| Main update — call once per new CTF bar                          |
//+------------------------------------------------------------------+
void UpdateStateMachine(bool isNewBar)
  {
   if(!isNewBar)
      return;


   g_smBarCounter++;

// ── 1. Advance existing instances ──
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
     {
      if(!g_smInstances[i].active)
         continue;

      // Global timeout
      int chainAge = g_smBarCounter - g_smInstances[i].stageBarCtr[0];
      if(g_smInstances[i].stageBarCtr[0] > 0 && chainAge > InpSM_GlobalTimeout)
        { SM_DeactivateInstance(i); continue; }

      int s = g_smInstances[i].currentStage;
      if(s < 0 || s >= SM_MAX_STAGES)
        {
         SM_DeactivateInstance(i);
         continue;
        }
      if(g_smInstances[i].stageDone[s] || g_smInstances[i].stageSkipped[s])
        {
         if(s < SM_MAX_STAGES - 1)
            g_smInstances[i].currentStage++;
         continue;
        }

      // Previous stage must be done
      if(s > 0 && !g_smInstances[i].stageDone[s-1] && !g_smInstances[i].stageSkipped[s-1])
         continue;

      // Per-stage timeout
      int baseBar = (s == 0) ? g_smBarCounter : g_smInstances[i].stageBarCtr[s-1];
      int tmo = SM_GetStageTimeout(g_smStageCfg[s]);
      if(tmo > 0 && baseBar > 0 && (g_smBarCounter - baseBar) > tmo)
        {
         if(g_smStageCfg[s].required)
           {
            SM_DeactivateInstance(i);
            continue;
           }
         else
           {
            g_smInstances[i].stageSkipped[s] = true;
            if(s < SM_MAX_STAGES - 1)
               g_smInstances[i].currentStage++;
            continue;
           }
        }

      SM_EvaluateStage(i, s);
     }

// ── 2. Try spawning new trigger ──
   SM_TrySpawnTrigger();
  }

//+------------------------------------------------------------------+
//| Spawn guard: only fire trigger if conditions are NEW              |
//+------------------------------------------------------------------+
void SM_TrySpawnTrigger()
  {

   SSMStageConfig tcfg = g_smStageCfg[0];
// Check primary on trigger's TF
   SSMInstance dummy;
   dummy.Reset();

// Seed dummy direction so FROM_DR / FROM_AMD policies can resolve
   dummy.direction = g_currentDirection;
   if(dummy.direction == DIR_NONE)
      dummy.direction = g_isBullishActive ? DIR_BULLISH : DIR_BEARISH;

   int ptag = -1;
   double pprice = 0;
   bool primOK = SM_CheckElementSatisfied(tcfg.primaryElem, tcfg.primaryTF,
                                          dummy, tcfg, ptag, pprice);

   if(tcfg.logic != SM_LOGIC_SINGLE && tcfg.secondaryElem != SM_ELEM_NONE)
     {
      int stag = -1;
      double sprice = 0;
      bool secOK = SM_CheckElementSatisfied(tcfg.secondaryElem, tcfg.secondaryTF,
                                            dummy, tcfg, stag, sprice);
      if(tcfg.logic == SM_LOGIC_AND)
         primOK = primOK && secOK;
      else
         if(tcfg.logic == SM_LOGIC_OR)
            primOK = primOK || secOK;
     }

   if(!primOK)
     {
      PrintFormat("[SMDBG][SpawnSkip] trigElem=%s dirPolicy=%d curDir=%s amdPhase=%d amdDir=%s resolvedDir=%s",
                  SM_ElementShortName(tcfg.primaryElem),
                  (int)tcfg.dirPolicy,
                  DirectionToString(g_currentDirection),
                  (int)g_amdPhase.currentPhase,
                  DirectionToString(g_amdPhase.expectedDirection),
                  DirectionToString(SM_GetStageDirection(dummy, tcfg)));
      return;
     }

// Spawn guard: don't re-fire on the same structural event
   int currentEventTag = g_lastSMEvent.valid ? g_lastSMEvent.tag : -1;
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
     {
      if(!g_smInstances[i].active)
         continue;
      if(g_smInstances[i].triggerEventTag == currentEventTag && currentEventTag >= 0)
         return; // already spawned for this event
     }

   SSMInstance* ni = SM_AllocInstance();
   if(ni == NULL)
      return;

   ni.stageDone[0]    = true;
   ni.stageTime[0]    = TimeCurrent();
   ni.stageBarCtr[0]  = g_smBarCounter;
   ni.currentStage    = 1;

// ★ FIX 1: Resolve trigger direction via the trigger stage's dirPolicy
//          instead of hardcoding the DR bias. Makes SM_DIR_FROM_AMD,
//          SM_DIR_FIXED_*, etc. actually take effect at the trigger.
   ni.direction = SM_GetStageDirection(*ni, g_smStageCfg[0]);
   if(ni.direction == DIR_NONE)
      ni.direction = dummy.direction;   // safe fallback

// ★ FIX 1b: Seed counter-dir flag at birth from the ENTRY stage policy
   ENUM_SM_DIRECTION_POLICY entPol = g_smStageCfg[SM_MAX_STAGES-1].dirPolicy;
   ni.isCounterDirPreset = (entPol == SM_DIR_COUNTER_TRIGGER ||
                            entPol == SM_DIR_INVERT_TRIGGER ||
                            entPol == SM_DIR_FIXED_BULL ||
                            entPol == SM_DIR_FIXED_BEAR);

   ni.triggerPrice    = (pprice > 0) ? pprice : iClose(_Symbol, PERIOD_CURRENT, 0);
   ni.birthEventTag   = currentEventTag;
   ni.triggerEventTag = currentEventTag;

   PrintFormat("[SMDBG][SpawnOK] chain=%d trig=%s dir=%s eventTag=%d",
               ni.id,
               SM_ElementShortName(tcfg.primaryElem),
               DirectionToString(ni.direction),
               currentEventTag);
  }

//+------------------------------------------------------------------+
bool SM_HasReadyEntry()
  {

   g_smActiveEntryInstance = -1;
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
     {
      if(!g_smInstances[i].active)
         continue;
      if(g_smInstances[i].stageDone[SM_MAX_STAGES - 1])
        { g_smActiveEntryInstance = i; return true; }
     }
   return false;
  }

//+------------------------------------------------------------------+
string SM_ZoneName(ENUM_SM_ZONE_SRC z)
  {
   switch(z)
     {
      case SM_ZONE_CURRENT:
         return "Current Price";
      case SM_ZONE_TRIG_PRIMARY:
         return "Trigger Primary";
      case SM_ZONE_TRIG_SECONDARY:
         return "Trigger Secondary";
      case SM_ZONE_CONF_PRIMARY:
         return "Confirmation Primary";
      case SM_ZONE_CONF_SECONDARY:
         return "Confirmation Secondary";
      case SM_ZONE_VAL_PRIMARY:
         return "Validation Primary";
      case SM_ZONE_VAL_SECONDARY:
         return "Validation Secondary";
      case SM_ZONE_ENT_PRIMARY:
         return "Entry Primary";
      case SM_ZONE_ENT_SECONDARY:
         return "Entry Secondary";
     }
   return "Unknown";
  }

// Resolves the entry price for the selected zone on a specific chain instance.
// Returns false + reason when the slot is empty or price is missing.
bool SM_ResolveEntryZonePrice(const SSMInstance &inst, ENUM_SM_ZONE_SRC z,
                              double &outPrice, bool &isRestingZone, string &reason)
  {
   reason = "";
   isRestingZone = false;

   if(z == SM_ZONE_CURRENT)
     { outPrice = iClose(_Symbol, PERIOD_CURRENT, 0); return true; }

   int stageIdx = ((int)z - 1) / 2;
   int slot     = ((int)z - 1) % 2;   // 0 = primary, 1 = secondary
   if(stageIdx < 0 || stageIdx >= SM_MAX_STAGES)
     { reason = "invalid_zone_index"; return false; }

// Empty-slot guard (your requested warning)
   ENUM_SM_ELEMENT elem = (slot == 0) ? g_smStageCfg[stageIdx].primaryElem
                          : g_smStageCfg[stageIdx].secondaryElem;
   if(elem == SM_ELEM_NONE)
     {
      reason = "empty_zone_slot";
      PrintFormat("[SM][EntryZone] You chose '%s' as entry price zone, which is not in the SM chain.",
                  SM_ZoneName(z));
      return false;
     }

   double px = (slot == 0) ? inst.stagePrimaryPrice[stageIdx]
               : inst.stageSecondaryPrice[stageIdx];
   if(px <= 0.0)
     { reason = "zone_price_unset"; return false; }

   isRestingZone = true;
   outPrice = px;
   return true;
  }


// Is the final trade direction opposite the chain's detected direction?
bool SM_IsForcedCounter(const SSMInstance &inst, ENUM_TRADE_DIRECTION tradeDir)
  {
   ENUM_TRADE_DIRECTION chainDir = (inst.resolvedEntryDir != DIR_NONE)
                                   ? inst.resolvedEntryDir : inst.direction;
   return (chainDir != DIR_NONE && tradeDir != DIR_NONE && tradeDir != chainDir);
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
void GenerateSMTradeSignal()
  {
   int idx = g_smActiveEntryInstance;
   if(idx < 0 || idx >= SM_MAX_INSTANCES)
      return;
   if(!g_smInstances[idx].active || !g_smInstances[idx].stageDone[SM_MAX_STAGES-1])
      return;

   SSMInstance *inst = GetPointer(g_smInstances[idx]);
   g_currentSignal.Reset();

   g_currentSignal.chainId = inst.id; //set chain id so tracking/comments would be correct
// ★ SINGLE SOURCE OF TRUTH: final trade direction (EntryMode overrides chain)
   ENUM_TRADE_DIRECTION tradeDir = SM_ResolveTradeDirection(g_smInstances[idx]);
   bool isBull = (tradeDir == DIR_BULLISH);

   g_currentSignal.type = isBull ? SIGNAL_BUY : SIGNAL_SELL;
   g_currentSignal.time = TimeCurrent();

// ★ Resolve entry ZONE price (per-chain). Empty slot => no trade + warning.
   double zonePrice = 0.0;
   bool restingZone = false;
   string zr = "";
   if(!SM_ResolveEntryZonePrice(*inst, InpSM_EntryZone, zonePrice, restingZone, zr))
     { SM_DeactivateInstance(idx); g_smActiveEntryInstance = -1; return; }

// Optional offset INTO the zone (points), direction-aware
   double off = InpSM_ZoneOffsetPoints * _Point;

// ★ Decide market vs pending from exec mode + whether we actually have a resting zone
   bool wantPending = (InpSM_EntryExec != SM_EXEC_MARKET) && restingZone;

   double refPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   g_currentSignal.entryPrice = wantPending ? zonePrice : refPrice;

// ★ SL/TP/Lot now derive from the FINAL trade direction (isBull), not resolvedEntryDir
   g_currentSignal.slPrice = CalculateStopLoss(isBull);
   CalculateTakeProfits(isBull);
   g_currentSignal.lotSize = CalculateLotSize();

   double risk   = MathAbs(g_currentSignal.entryPrice - g_currentSignal.slPrice);
   double reward = MathAbs(g_currentSignal.tp1Price   - g_currentSignal.entryPrice);
   g_currentSignal.riskReward = (risk > 0) ? reward / risk : 0;

// ★ Pending-order fields + geometry guard
   if(wantPending)
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)-1;
      double p = zonePrice;

      if(InpSM_EntryExec == SM_EXEC_LIMIT)
        {
         if(isBull)
           {
            ot = ORDER_TYPE_BUY_LIMIT;
            p = zonePrice - off;
            if(p >= ask)
              {
               SM_DeactivateInstance(idx);
               g_smActiveEntryInstance=-1;
               Print("[SM][Entry] buy-limit not below price; skip");
               return;
              }
           }
         else
           {
            ot = ORDER_TYPE_SELL_LIMIT;
            p = zonePrice + off;
            if(p <= bid)
              {
               SM_DeactivateInstance(idx);
               g_smActiveEntryInstance=-1;
               Print("[SM][Entry] sell-limit not above price; skip");
               return;
              }
           }
        }
      else // SM_EXEC_STOP
        {
         if(isBull)
           {
            ot = ORDER_TYPE_BUY_STOP;
            p = zonePrice + off;
            if(p <= ask)
              {
               SM_DeactivateInstance(idx);
               g_smActiveEntryInstance=-1;
               Print("[SM][Entry] buy-stop not above price; skip");
               return;
              }
           }
         else
           {
            ot = ORDER_TYPE_SELL_STOP;
            p = zonePrice - off;
            if(p >= bid)
              {
               SM_DeactivateInstance(idx);
               g_smActiveEntryInstance=-1;
               Print("[SM][Entry] sell-stop not below price; skip");
               return;
              }
           }
        }

      g_currentSignal.isPending    = true;
      g_currentSignal.pendingType  = ot;
      g_currentSignal.pendingPrice = NormalizePrice(p);
      g_currentSignal.pendingExpiry= (InpSM_PendingExpiryBars > 0)
                                     ? TimeCurrent() + InpSM_PendingExpiryBars * PeriodSeconds(PERIOD_CURRENT)
                                     : 0;
      g_currentSignal.entryPrice   = g_currentSignal.pendingPrice; // recost risk at resting price
      risk   = MathAbs(g_currentSignal.entryPrice - g_currentSignal.slPrice);
      reward = MathAbs(g_currentSignal.tp1Price   - g_currentSignal.entryPrice);
      g_currentSignal.riskReward = (risk > 0) ? reward / risk : 0;
     }

   g_currentSignal.isValid = ValidateSignal();

   if(!g_currentSignal.isValid)
     {
      PrintFormat("[SMDBG][SignalInvalid] chain=%d type=%d entry=%.5f sl=%.5f tp1=%.5f lot=%.2f rr=%.2f",
                  inst.id, (int)g_currentSignal.type, g_currentSignal.entryPrice,
                  g_currentSignal.slPrice, g_currentSignal.tp1Price,
                  g_currentSignal.lotSize, g_currentSignal.riskReward);
      SM_DeactivateInstance(idx);
      g_smActiveEntryInstance = -1;
      return;
     }
// If forced counter, mark BEFORE gate check
   if(SM_IsForcedCounter(*inst, tradeDir))
      inst.isCounterDirPreset = true;

// ★ Flag EntryMode-forced counter-direction so the gate treats it as intentional
   string reason = "";
   if(!NAR_IsChainTradable(*inst, reason))
     {
      PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
      ClearSignal();
      g_hasValidSignal = false;
      SM_DeactivateInstance(idx);
      g_smActiveEntryInstance = -1;
      return;
     }

// only now publish signal
   g_hasValidSignal = true;
   g_waitingForOTE  = false;
   PrintSignalGenerated();

// Consume this chain so it cannot emit repeated signals every bar
   int usedIdx = idx;
   SM_DeactivateInstance(usedIdx);
   g_smActiveEntryInstance = -1;

   Shadow_RecordCandidate(g_currentSignal, inst.id, inst.causalTagUsed);
  }
//+------------------------------------------------------------------+
//| Fill ML feature vector with SM narrative data                    |
//+------------------------------------------------------------------+
void SM_FillMLFeatures(SMLFeatureVector &fv)
  {
   for(int f = MLF_SM_TRIGGER_TYPE; f <= MLF_SM_LTF_CONFIRMED; f++)
      fv.Set(f, 0.0);



// Find best active instance
   int bestIdx = -1, bestScore = -999;
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
     {
      if(!g_smInstances[i].active)
         continue;
      int done = 0, skip = 0;
      for(int s = 0; s < SM_MAX_STAGES; s++)
        {
         if(g_smInstances[i].stageDone[s])
            done++;
         if(g_smInstances[i].stageSkipped[s])
            skip++;
        }
      int sc = done * 10 - skip * 2;
      if(g_smInstances[i].stageDone[SM_MAX_STAGES-1])
         sc += 20;
      if(sc > bestScore)
        {
         bestScore = sc;
         bestIdx = i;
        }
     }
   if(bestIdx < 0)
      return;

   int doneN = 0, skipN = 0;
   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      if(g_smInstances[bestIdx].stageDone[s])
         doneN++;
      if(g_smInstances[bestIdx].stageSkipped[s])
         skipN++;
     }

   fv.Set(MLF_SM_STAGES_COMPLETE, (double)doneN / SM_MAX_STAGES);
   fv.Set(MLF_SM_STAGES_SKIPPED, (double)skipN / SM_MAX_STAGES);

   double elemMax = (double)SM_ELEM_PROVIDER3_SIGNAL;
   fv.Set(MLF_SM_TRIGGER_TYPE, (elemMax > 0) ? (double)g_smStageCfg[0].primaryElem / elemMax : 0);

   double denom = (double)MathMax(1, InpSM_GlobalTimeout);
   fv.Set(MLF_SM_BARS_TO_CONFIRM, MathMin(1.0, g_smInstances[bestIdx].barsToConfirm / denom));
   fv.Set(MLF_SM_BARS_TO_ENTRY,   MathMin(1.0, g_smInstances[bestIdx].barsToEntry / denom));
   fv.Set(MLF_SM_CAUSAL_USED, (g_smInstances[bestIdx].causalTagUsed >= 0) ? 1.0 : 0.0);
   double baseStrength = (double)doneN / (double)SM_MAX_STAGES;
   if(g_killzone.isActive)
      baseStrength += 0.1;
   fv.Set(MLF_SM_TRIGGER_STRENGTH, MathMin(1.0, MathMax(0.0, baseStrength)));

   double retrace = 0.0;
   if(g_smInstances[bestIdx].triggerPrice > 0 && g_smInstances[bestIdx].confirmPrice > 0)
     {
      double leg = MathAbs(g_smInstances[bestIdx].confirmPrice - g_smInstances[bestIdx].triggerPrice);
      if(leg > 0)
        {
         double cur = iClose(_Symbol, PERIOD_CURRENT, 0);
         double depth = (g_smInstances[bestIdx].direction == DIR_BULLISH)
                        ? g_smInstances[bestIdx].confirmPrice - cur
                        : cur - g_smInstances[bestIdx].confirmPrice;
         retrace = MathMax(0.0, MathMin(1.0, depth / leg));
        }
     }
   fv.Set(MLF_SM_RETRACE_DEPTH, retrace);
   fv.Set(MLF_SM_PRESET_ID, (double)InpSM_Preset / 6.0);

   MqlDateTime tmx;
   TimeToStruct(TimeCurrent(), tmx);
   fv.Set(MLF_SM_ENTRY_HOUR, (double)tmx.hour / 24.0);

   double chainAge = 0;
   if(g_smInstances[bestIdx].stageBarCtr[0] > 0)
      chainAge = (double)(g_smBarCounter - g_smInstances[bestIdx].stageBarCtr[0]) / denom;
   fv.Set(MLF_SM_CHAIN_SPEED, 1.0 - MathMin(1.0, chainAge));

   bool ltfUsed = false;
   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      if(!g_smInstances[bestIdx].stageDone[s])
         continue;
      if(g_smStageCfg[s].primaryTF == LAYER_LTF || g_smStageCfg[s].secondaryTF == LAYER_LTF)
        { ltfUsed = true; break; }
     }
   fv.Set(MLF_SM_LTF_CONFIRMED, ltfUsed ? 1.0 : 0.0);
  }

//+------------------------------------------------------------------+
//| Dashboard helpers                                                |
//+------------------------------------------------------------------+
string SM_ElementShortName(ENUM_SM_ELEMENT e)
  {
   switch(e)
     {
      case SM_ELEM_NONE:
         return "-";
      case SM_ELEM_CHOCH_BREAK:
         return "ChoCh";
      case SM_ELEM_BOS:
         return "BOS";
      case SM_ELEM_EXT_SWEEP:
         return "Sweep";
      case SM_ELEM_JUDAS_SWING:
         return "Judas";
      case SM_ELEM_DISPLACEMENT:
         return "Disp";
      case SM_ELEM_ORDER_BLOCK:
         return "OB";
      case SM_ELEM_FVG:
         return "FVG";
      case SM_ELEM_FVG_CE:
         return "CE";
      case SM_ELEM_VOLUME_IMBALANCE:
         return "VI";
      case SM_ELEM_LIQUIDITY_VOID:
         return "LV";
      case SM_ELEM_IFVG:
         return "IFVG";
      case SM_ELEM_BREAKER:
         return "Brk";
      case SM_ELEM_MITIGATION:
         return "MB";
      case SM_ELEM_OTE_ZONE:
         return "OTE";
      case SM_ELEM_BODY_CLOSE:
         return "Body";
      case SM_ELEM_RETRACE_TO_EZ:
         return "Retr";
      case SM_ELEM_SMT_DIVERGENCE:
         return "SMT";
      case SM_ELEM_DR_TARGET_AREA:
         return "DRTgt";
      case SM_ELEM_KILLZONE:
         return "KZ";
      case SM_ELEM_AMD_DISTRIBUTION:
         return "AMD-D";
      case SM_ELEM_AMD_MANIPULATION:
         return "AMD-M";
      case SM_ELEM_AMD_ACCUMULATION:
         return "AMD-A";
      case SM_ELEM_PROVIDER1_SIGNAL:
         return "Prov1";
      case SM_ELEM_PROVIDER2_SIGNAL:
         return "Prov2";
      case SM_ELEM_PROVIDER3_SIGNAL:
         return "Prov3";
      default:
         return "?";
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string SM_TFLabel(ENUM_TF_LAYER l)
  {
   switch(l)
     {
      case LAYER_HTF:
         return "H";
      case LAYER_LTF:
         return "L";
      default:
         return "C";
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string SM_StageConfigLine(int s)
  {
   string roles[4] = {"T","C","V","E"};
   if(s < 0 || s >= SM_MAX_STAGES)
      return "";
   string line = roles[s] + ": ";
   line += SM_TFLabel(g_smStageCfg[s].primaryTF) + "." + SM_ElementShortName(g_smStageCfg[s].primaryElem);
   if(g_smStageCfg[s].secondaryElem != SM_ELEM_NONE)
     {
      string lgc = (g_smStageCfg[s].logic == SM_LOGIC_AND) ? "&" : "|";
      line += " " + lgc + " " + SM_TFLabel(g_smStageCfg[s].secondaryTF) + "."
              + SM_ElementShortName(g_smStageCfg[s].secondaryElem);
     }
   if(!g_smStageCfg[s].required)
      line += " (opt)";
   if(g_smStageCfg[s].causalLink)
      line += " \x26A1";
   return line;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string SM_InstanceStatusLine(int i)
  {
   if(i < 0 || i >= SM_MAX_INSTANCES || !g_smInstances[i].active)
      return "";
   string marks[4] = {"T","C","V","E"};
   string stg = "";
   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      string m = g_smInstances[i].stageDone[s] ? "\x2713" :
                 g_smInstances[i].stageSkipped[s] ? "sk" : "\x25CB";
      stg += marks[s] + m + " ";
     }
   int age = (g_smInstances[i].stageBarCtr[0] > 0) ?
             (g_smBarCounter - g_smInstances[i].stageBarCtr[0]) : 0;
   string d = (g_smInstances[i].direction == DIR_BULLISH) ? "BUL" : "BER";

   string em = " [" + EnumToString(InpSM_EntryExec) + "/" + SM_ZoneName(InpSM_EntryZone) + "]";
   if(HasOrderForChain(g_smInstances[i].id))
      em += " [PEND]";
   return "#" + IntegerToString(g_smInstances[i].id) + " " + d + " " + stg + IntegerToString(age) + "b" + em;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SM_CountActiveInstances()
  {
   int n = 0;
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
      if(g_smInstances[i].active)
         n++;
   return n;
  }

#endif
//+------------------------------------------------------------------+
