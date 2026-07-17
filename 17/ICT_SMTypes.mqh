//|                                       |
//|  "ICT Unified Professional EA v17"    |
//|---------------------------------------|

#ifndef ICT_SMTYPES_MQH
#define ICT_SMTYPES_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"

// ── Patch A: layer count + index helper ──────────────────────────
#define TF_LAYER_COUNT 3          // 0=CTF, 1=HTF, 2=LTF (extend freely)

int SM_LayerIndex(ENUM_TF_LAYER lay)
  {
   switch(lay){ case LAYER_HTF: return 1; case LAYER_LTF: return 2; default: return 0; }
  }

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
      case LAYER_HTF: return bull ? GetPointer(g_htfLayer.bullDR) : GetPointer(g_htfLayer.bearDR);
      case LAYER_LTF: return bull ? GetPointer(g_ltfLayer.bullDR) : GetPointer(g_ltfLayer.bearDR);
      default:        return bull ? GetPointer(g_bullDR)        : GetPointer(g_bearDR);
     }
  }

// ── Patch A (G8): one-shot warning when a stage needs a disabled layer ──
void SM_LayerWarnOnce(ENUM_TF_LAYER lay)
  {
   static bool warned[TF_LAYER_COUNT];
   int i = SM_LayerIndex(lay);
   if(i > 0 && !warned[i])
     {
      warned[i] = true;
      PrintFormat("[SM][MTF] Stage requires %s layer but it is disabled/uninitialized - stage will never satisfy.",
                  (lay==LAYER_HTF ? "HTF" : "LTF"));
     }
  }

// Check if TF layer is ready (now with telemetry on the not-ready path)
bool SM_LayerReady(ENUM_TF_LAYER lay)
  {
   switch(lay)
     {
      case LAYER_HTF:
        { bool ok = g_htfLayer.isInitialized && g_htfLayer.isEnabled;
          if(!ok) SM_LayerWarnOnce(LAYER_HTF); return ok; }
      case LAYER_LTF:
        { bool ok = g_ltfLayer.isInitialized && g_ltfLayer.isEnabled;
          if(!ok) SM_LayerWarnOnce(LAYER_LTF); return ok; }
      default: return true;
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

// ── Patch B: unified freshness clock (recency in the layer's OWN bars) ──
int SM_LayerBarsSince(datetime whenUtc, ENUM_TF_LAYER lay)
  {
   if(whenUtc <= 0) return INT_MAX;
   int shift = iBarShift(_Symbol, SM_LayerToTF(lay), whenUtc, false);
   return (shift < 0) ? INT_MAX : shift;
  }

#endif