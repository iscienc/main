//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef ICT_NARRATIVE_GATE_MQH
#define ICT_NARRATIVE_GATE_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"

// Minimum institutional chain quality
int NAR_MinCompletedStages()
  {
// Trigger + Confirmation + Entry minimum quality
   return 3;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NAR_MaxChainAgeBars()
  {
   return MathMax(20, InpSM_GlobalTimeout);
  }

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
// Keep killzone filter if enabled
   if(InpUseKillzoneFilter && !IsInKillzone())
      return false;

// Pure Narrative SM: no premium/discount gate dependency
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NAR_CountStageDone(const SSMInstance &inst)
  {
   int n = 0;
   for(int s = 0; s < SM_MAX_STAGES; s++)
     {
      if(inst.stageDone[s])
         n++;
     }
   return n;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NAR_HasRequiredNarrativeAtEntry(const SSMInstance &inst)
  {
   bool isBull = (inst.direction == DIR_BULLISH);
   int idx = -1;

// At least one actionable first-order narrative element
   if(IsPriceAtOrderBlock(isBull, idx))
      return true;
   if(IsPriceInFVG(isBull, idx))
      return true;
   if(IsPriceAtBreakerBlock(isBull, idx))
      return true;
   if(IsPriceAtMitigationBlock(isBull, idx))
      return true;
   if(IsPriceInOTEZone())
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
      return false;
     }

   int done = NAR_CountStageDone(inst);
   if(done < NAR_MinCompletedStages())
     {
      reason = "insufficient_stage_progress";
      return false;
     }

   int age = (inst.stageBarCtr[0] > 0) ? (g_smBarCounter - inst.stageBarCtr[0]) : 0;
   if(age > NAR_MaxChainAgeBars())
     {
      reason = "chain_timeout";
      return false;
     }

// ★ UPDATED: Align on resolvedEntryDir (the actual trade direction)
   ENUM_TRADE_DIRECTION checkDir = inst.resolvedEntryDir;
   if(checkDir == DIR_NONE)
      checkDir = inst.direction; // fallback
   if(!NAR_DirectionAligned(checkDir))
     {
      reason = "direction_mismatch";
      return false;
     }

   if(!NAR_EnvironmentOK(inst.direction))
     {
      reason = "environment_filter";
      return false;
     }

   if(!NAR_HasRequiredNarrativeAtEntry(inst))
     {
      reason = "no_entry_element";
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
      // ★ UPDATED: Filter on resolvedEntryDir, not trigger direction
      ENUM_TRADE_DIRECTION instDir = g_smInstances[i].resolvedEntryDir;
      if(instDir == DIR_NONE)
         instDir = g_smInstances[i].direction;
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
