#ifndef ICT_SMTYPES_MQH
#define ICT_SMTYPES_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"

int SM_GetStageTimeout(const SSMStageConfig &cfg)
{
   return (cfg.timeoutBars > 0) ? cfg.timeoutBars : InpSM_GlobalTimeout;
}

ENUM_SM_STAGE_ROLE SM_StageIndexToRole(int idx)
{
   switch(idx)
   {
      case 0: return SM_STAGE_TRIGGER;
      case 1: return SM_STAGE_CONFIRMATION;
      case 2: return SM_STAGE_VALIDATION;
      case 3: return SM_STAGE_ENTRY;
      default: return SM_STAGE_TRIGGER;
   }
}

// Resolve TF layer to ENUM_TIMEFRAMES
ENUM_TIMEFRAMES SM_LayerToTF(ENUM_TF_LAYER lay)
{
   switch(lay)
   {
      case LAYER_HTF: return InpHTF_Timeframe;
      case LAYER_LTF: return InpLTF_Timeframe;
      default:        return PERIOD_CURRENT;
   }
}

// Get ATR for a TF layer
double SM_LayerATR(ENUM_TF_LAYER lay)
{
   switch(lay)
   {
      case LAYER_HTF: return GetHTFATR();
      case LAYER_LTF: return GetLTFATR();
      default:        return GetATRSafe();
   }
}

// Get active DR for a TF layer + direction
SDealingRange* SM_LayerDR(ENUM_TF_LAYER lay, bool bull)
{
   switch(lay)
   {
      case LAYER_HTF:
         return bull ? GetPointer(g_htfLayer.bullDR) : GetPointer(g_htfLayer.bearDR);
      case LAYER_LTF:
         return bull ? GetPointer(g_ltfLayer.bullDR) : GetPointer(g_ltfLayer.bearDR);
      default:
         return bull ? GetPointer(g_bullDR) : GetPointer(g_bearDR);
   }
}

// Check if TF layer is ready
bool SM_LayerReady(ENUM_TF_LAYER lay)
{
   switch(lay)
   {
      case LAYER_HTF: return g_htfLayer.isInitialized && g_htfLayer.isEnabled;
      case LAYER_LTF: return g_ltfLayer.isInitialized && g_ltfLayer.isEnabled;
      default:        return true;
   }
}

// Active direction on a TF layer
bool SM_LayerBullish(ENUM_TF_LAYER lay)
{
   switch(lay)
   {
      case LAYER_HTF: return g_htfLayer.isBullishActive;
      case LAYER_LTF: return g_ltfLayer.isBullishActive;
      default:        return g_isBullishActive;
   }
}

#endif