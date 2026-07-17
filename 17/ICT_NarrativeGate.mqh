//+------------------------------------------------------------------+
//| ICT_NarrativeGate.mqh                                            |
//|     "ICT Unified Professional EA v17"                            |
//+------------------------------------------------------------------+
#ifndef ICT_NARRATIVE_GATE_MQH
#define ICT_NARRATIVE_GATE_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "ICT_SMDetectors.mqh"   // ★ Patch F: SM_Detect_* (layer-aware) visible here

int NAR_MinCompletedStages() { return 3; }        // Trigger + Confirmation + Entry

int NAR_MaxChainAgeBars() { return MathMax(20, InpSM_GlobalTimeout); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NAR_DirectionAligned(ENUM_TRADE_DIRECTION dir)
  {
   if(dir == DIR_NONE)
      return false;
   if(g_currentDirection == DIR_NONE)
      return true;
   return (dir == g_currentDirection);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NAR_EnvironmentOK(ENUM_TRADE_DIRECTION dir)
  {
   if(InpUseKillzoneFilter && !IsInKillzone())
      return false;
   return true;                                   // Pure Narrative SM
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NAR_CountStageDone(const SSMInstance &inst)
  {
   int n = 0;
   for(int s = 0; s < SM_MAX_STAGES; s++)
      if(inst.stageDone[s])
         n++;
   return n;
  }

//+------------------------------------------------------------------+
//| PATCH F: entry narrative validated on the ENTRY STAGE's TF layer |
//+------------------------------------------------------------------+
bool NAR_HasRequiredNarrativeAtEntry(const SSMInstance &inst)
  {
// ★ FIX 3: if the entry stage has no element, there is no zone to require.
   if(g_smStageCfg[SM_MAX_STAGES - 1].primaryElem == SM_ELEM_NONE &&
      g_smStageCfg[SM_MAX_STAGES - 1].secondaryElem == SM_ELEM_NONE)
      return true;

   ENUM_TRADE_DIRECTION entryDir = inst.resolvedEntryDir;
   if(entryDir == DIR_NONE)
      entryDir = inst.direction;

   ENUM_TF_LAYER eLay = g_smStageCfg[SM_MAX_STAGES - 1].primaryTF;
   int tag = -1;
   double px = 0.0;

   if(SM_Detect_OB(eLay, entryDir, false, tag, px))
      return true;
   if(SM_Detect_FVG(eLay, entryDir, false, tag, px))
      return true;
   if(SM_Detect_Breaker(eLay, entryDir, false, tag, px))
      return true;
   if(SM_Detect_Mitigation(eLay, entryDir, false, tag, px))
      return true;
   if(SM_Detect_OTE(eLay, entryDir))
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NAR_IsChainTradable(const SSMInstance &inst, string &reason)
  {
   reason = "";
   if(!inst.active)
     {
      reason = "inactive_chain";
      PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
      return false;
     }

// ★ FIX 1: entry stage must be complete
   if(!inst.stageDone[SM_MAX_STAGES - 1])
     {
      reason = "entry_not_done";
      PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
      return false;
     }

// ★ FIX 2: every REQUIRED, non-empty stage must be done.
//          Skipped OPTIONAL stages do NOT block the chain.
   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      if(g_smStageCfg[s].required &&
         g_smStageCfg[s].primaryElem != SM_ELEM_NONE &&
         !inst.stageDone[s])
        {
        reason = "required_stage_incomplete";
        PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
        return false; }
     }

   int age = (inst.stageBarCtr[0] > 0) ? (g_smBarCounter - inst.stageBarCtr[0]) : 0;
   if(age > NAR_MaxChainAgeBars())
     {
      reason = "chain_timeout";
      PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
      return false;
     }

   ENUM_TRADE_DIRECTION checkDir = SM_ResolveTradeDirection(inst);
   if(!inst.isCounterDirPreset && !NAR_DirectionAligned(checkDir))
     {
     reason = "direction_mismatch";
     PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
     return false;
     }

   if(!NAR_EnvironmentOK(inst.direction))
     {
      reason = "environment_filter";
      PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
      return false;
     }
   if(!NAR_HasRequiredNarrativeAtEntry(inst))
     {
      reason = "no_entry_element";
      PrintFormat("[SMDBG][GateBlock] chain=%d reason=%s", inst.id, reason);
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNarrativeTradable(ENUM_TRADE_DIRECTION dir, string &reason)
  {
   reason = "no_ready_chain";
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
     {
      if(!g_smInstances[i].active)
         continue;
      if(!g_smInstances[i].stageDone[SM_MAX_STAGES - 1])
         continue;

      ENUM_TRADE_DIRECTION instDir = SM_ResolveTradeDirection(g_smInstances[i]);
      if(dir != DIR_NONE && instDir != dir)
         continue;

      string r = "";
      if(NAR_IsChainTradable(g_smInstances[i], r))
        {
         reason = "";
         return true;
        }
      reason = r;
     }
   return false;
  }

#endif
//+------------------------------------------------------------------+
