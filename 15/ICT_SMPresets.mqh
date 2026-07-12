//|                                       |
//|  "ICT Unified Professional EA v15"    |
//|---------------------------------------|

#ifndef ICT_SMPRESETS_MQH
#define ICT_SMPRESETS_MQH

#include "ICT_SMTypes.mqh"

void SM_LoadPreset()
{
   // Stage 0: TRIGGER
   g_smStageCfg[0].Reset();
   g_smStageCfg[0].role         = SM_STAGE_TRIGGER;
   g_smStageCfg[0].primaryElem  = InpSM_Trig_Primary;
   g_smStageCfg[0].primaryTF    = InpSM_Trig_PrimaryTF;
   g_smStageCfg[0].secondaryElem= InpSM_Trig_Secondary;
   g_smStageCfg[0].secondaryTF  = InpSM_Trig_SecondaryTF;
   g_smStageCfg[0].logic        = InpSM_Trig_Logic;
   g_smStageCfg[0].causalLink   = InpSM_Trig_Causal;
   g_smStageCfg[0].required     = InpSM_Trig_Required;
   g_smStageCfg[0].timeoutBars  = InpSM_Trig_Timeout;
   g_smStageCfg[0].dirPolicy    = InpSM_Trig_DirPolicy;

   // Stage 1: CONFIRMATION
   g_smStageCfg[1].Reset();
   g_smStageCfg[1].role         = SM_STAGE_CONFIRMATION;
   g_smStageCfg[1].primaryElem  = InpSM_Conf_Primary;
   g_smStageCfg[1].primaryTF    = InpSM_Conf_PrimaryTF;
   g_smStageCfg[1].secondaryElem= InpSM_Conf_Secondary;
   g_smStageCfg[1].secondaryTF  = InpSM_Conf_SecondaryTF;
   g_smStageCfg[1].logic        = InpSM_Conf_Logic;
   g_smStageCfg[1].causalLink   = InpSM_Conf_Causal;
   g_smStageCfg[1].required     = InpSM_Conf_Required;
   g_smStageCfg[1].timeoutBars  = InpSM_Conf_Timeout;
   g_smStageCfg[1].dirPolicy    = InpSM_Conf_DirPolicy;

   // Stage 2: VALIDATION
   g_smStageCfg[2].Reset();
   g_smStageCfg[2].role         = SM_STAGE_VALIDATION;
   g_smStageCfg[2].primaryElem  = InpSM_Val_Primary;
   g_smStageCfg[2].primaryTF    = InpSM_Val_PrimaryTF;
   g_smStageCfg[2].secondaryElem= InpSM_Val_Secondary;
   g_smStageCfg[2].secondaryTF  = InpSM_Val_SecondaryTF;
   g_smStageCfg[2].logic        = InpSM_Val_Logic;
   g_smStageCfg[2].causalLink   = InpSM_Val_Causal;
   g_smStageCfg[2].required     = InpSM_Val_Required;
   g_smStageCfg[2].timeoutBars  = InpSM_Val_Timeout;
   g_smStageCfg[2].dirPolicy    = InpSM_Val_DirPolicy;

   // Stage 3: ENTRY
   g_smStageCfg[3].Reset();
   g_smStageCfg[3].role         = SM_STAGE_ENTRY;
   g_smStageCfg[3].primaryElem  = InpSM_Ent_Primary;
   g_smStageCfg[3].primaryTF    = InpSM_Ent_PrimaryTF;
   g_smStageCfg[3].secondaryElem= InpSM_Ent_Secondary;
   g_smStageCfg[3].secondaryTF  = InpSM_Ent_SecondaryTF;
   g_smStageCfg[3].logic        = InpSM_Ent_Logic;
   g_smStageCfg[3].causalLink   = InpSM_Ent_Causal;
   g_smStageCfg[3].required     = InpSM_Ent_Required;
   g_smStageCfg[3].timeoutBars  = InpSM_Ent_Timeout;
   g_smStageCfg[3].dirPolicy    = InpSM_Ent_DirPolicy;

   if(InpSM_Preset == SM_PRESET_CUSTOM) return;

   switch(InpSM_Preset)
   {
      case SM_PRESET_CHOCH_RETRACE:
         g_smStageCfg[0].primaryElem   = SM_ELEM_CHOCH_BREAK;
         g_smStageCfg[0].primaryTF     = LAYER_HTF;
         g_smStageCfg[0].secondaryElem = SM_ELEM_EXT_SWEEP;
         g_smStageCfg[0].secondaryTF   = LAYER_HTF;
         g_smStageCfg[0].logic         = SM_LOGIC_OR;
         g_smStageCfg[0].dirPolicy     = SM_DIR_FROM_DR;

         g_smStageCfg[1].primaryElem   = SM_ELEM_DISPLACEMENT;
         g_smStageCfg[1].primaryTF     = LAYER_CTF;
         g_smStageCfg[1].secondaryElem = SM_ELEM_BOS;
         g_smStageCfg[1].secondaryTF   = LAYER_CTF;
         g_smStageCfg[1].logic         = SM_LOGIC_AND;
         g_smStageCfg[1].causalLink    = true;

         g_smStageCfg[2].primaryElem   = SM_ELEM_BOS;
         g_smStageCfg[2].primaryTF     = LAYER_LTF;
         g_smStageCfg[2].secondaryElem = SM_ELEM_ORDER_BLOCK;
         g_smStageCfg[2].secondaryTF   = LAYER_CTF;
         g_smStageCfg[2].logic         = SM_LOGIC_AND;
         g_smStageCfg[2].required      = false;

         g_smStageCfg[3].primaryElem   = SM_ELEM_ORDER_BLOCK;
         g_smStageCfg[3].primaryTF     = LAYER_CTF;
         g_smStageCfg[3].secondaryElem = SM_ELEM_FVG;
         g_smStageCfg[3].secondaryTF   = LAYER_CTF;
         g_smStageCfg[3].logic         = SM_LOGIC_OR;
         g_smStageCfg[3].causalLink    = true;
         break;

      case SM_PRESET_SWEEP_BOS_FVG:
         g_smStageCfg[0].primaryElem = SM_ELEM_EXT_SWEEP; g_smStageCfg[0].primaryTF = LAYER_CTF;
         g_smStageCfg[0].logic = SM_LOGIC_SINGLE;
         g_smStageCfg[1].primaryElem = SM_ELEM_BOS; g_smStageCfg[1].primaryTF = LAYER_CTF;
         g_smStageCfg[1].secondaryElem = SM_ELEM_DISPLACEMENT; g_smStageCfg[1].secondaryTF = LAYER_CTF;
         g_smStageCfg[1].logic = SM_LOGIC_AND; g_smStageCfg[1].causalLink = true;
         g_smStageCfg[2].primaryElem = SM_ELEM_NONE; g_smStageCfg[2].required = false;
         g_smStageCfg[3].primaryElem = SM_ELEM_FVG; g_smStageCfg[3].primaryTF = LAYER_CTF;
         g_smStageCfg[3].secondaryElem = SM_ELEM_ORDER_BLOCK; g_smStageCfg[3].secondaryTF = LAYER_CTF;
         g_smStageCfg[3].logic = SM_LOGIC_OR; g_smStageCfg[3].causalLink = true;
         break;

      case SM_PRESET_JUDAS_REVERSAL:
         g_smStageCfg[0].primaryElem = SM_ELEM_JUDAS_SWING; g_smStageCfg[0].primaryTF = LAYER_CTF;
         g_smStageCfg[0].logic = SM_LOGIC_SINGLE; g_smStageCfg[0].dirPolicy = SM_DIR_FROM_AMD;
         g_smStageCfg[1].primaryElem = SM_ELEM_DISPLACEMENT; g_smStageCfg[1].primaryTF = LAYER_CTF;
         g_smStageCfg[1].secondaryElem = SM_ELEM_BOS; g_smStageCfg[1].secondaryTF = LAYER_CTF;
         g_smStageCfg[1].logic = SM_LOGIC_AND; g_smStageCfg[1].causalLink = true;
         g_smStageCfg[2].primaryElem = SM_ELEM_OTE_ZONE; g_smStageCfg[2].primaryTF = LAYER_CTF;
         g_smStageCfg[2].required = false;
         g_smStageCfg[3].primaryElem = SM_ELEM_ORDER_BLOCK; g_smStageCfg[3].primaryTF = LAYER_CTF;
         g_smStageCfg[3].secondaryElem = SM_ELEM_FVG; g_smStageCfg[3].secondaryTF = LAYER_CTF;
         g_smStageCfg[3].logic = SM_LOGIC_OR; g_smStageCfg[3].causalLink = true;
         break;

      case SM_PRESET_OTE_PULLBACK:
         g_smStageCfg[0].primaryElem = SM_ELEM_DISPLACEMENT; g_smStageCfg[0].primaryTF = LAYER_CTF;
         g_smStageCfg[0].logic = SM_LOGIC_SINGLE; g_smStageCfg[0].dirPolicy = SM_DIR_FROM_DR;
         g_smStageCfg[1].primaryElem = SM_ELEM_BOS; g_smStageCfg[1].primaryTF = LAYER_CTF;
         g_smStageCfg[1].logic = SM_LOGIC_SINGLE; g_smStageCfg[1].causalLink = true;
         g_smStageCfg[2].primaryElem = SM_ELEM_OTE_ZONE; g_smStageCfg[2].primaryTF = LAYER_CTF;
         g_smStageCfg[2].secondaryElem = SM_ELEM_ORDER_BLOCK; g_smStageCfg[2].secondaryTF = LAYER_CTF;
         g_smStageCfg[2].logic = SM_LOGIC_AND; g_smStageCfg[2].required = true;
         g_smStageCfg[3].primaryElem = SM_ELEM_ORDER_BLOCK; g_smStageCfg[3].primaryTF = LAYER_CTF;
         g_smStageCfg[3].secondaryElem = SM_ELEM_FVG; g_smStageCfg[3].secondaryTF = LAYER_CTF;
         g_smStageCfg[3].logic = SM_LOGIC_OR; g_smStageCfg[3].causalLink = true;
         break;

      case SM_PRESET_SMT_REVERSAL:
         g_smStageCfg[0].primaryElem = SM_ELEM_SMT_DIVERGENCE; g_smStageCfg[0].primaryTF = LAYER_CTF;
         g_smStageCfg[0].logic = SM_LOGIC_SINGLE; g_smStageCfg[0].dirPolicy = SM_DIR_FROM_AMD;
         g_smStageCfg[1].primaryElem = SM_ELEM_CHOCH_BREAK; g_smStageCfg[1].primaryTF = LAYER_CTF;
         g_smStageCfg[1].secondaryElem = SM_ELEM_BOS; g_smStageCfg[1].secondaryTF = LAYER_CTF;
         g_smStageCfg[1].logic = SM_LOGIC_OR; g_smStageCfg[1].causalLink = true;
         g_smStageCfg[2].primaryElem = SM_ELEM_DISPLACEMENT; g_smStageCfg[2].primaryTF = LAYER_CTF;
         g_smStageCfg[2].required = true;
         g_smStageCfg[3].primaryElem = SM_ELEM_ORDER_BLOCK; g_smStageCfg[3].primaryTF = LAYER_CTF;
         g_smStageCfg[3].secondaryElem = SM_ELEM_FVG; g_smStageCfg[3].secondaryTF = LAYER_CTF;
         g_smStageCfg[3].logic = SM_LOGIC_OR; g_smStageCfg[3].causalLink = true;
         break;

      case SM_PRESET_MTF_NARRATIVE:
         g_smStageCfg[0].primaryElem = SM_ELEM_CHOCH_BREAK; g_smStageCfg[0].primaryTF = LAYER_HTF;
         g_smStageCfg[0].secondaryElem = SM_ELEM_EXT_SWEEP; g_smStageCfg[0].secondaryTF = LAYER_HTF;
         g_smStageCfg[0].logic = SM_LOGIC_OR; g_smStageCfg[0].dirPolicy = SM_DIR_FROM_DR;
         g_smStageCfg[1].primaryElem = SM_ELEM_BOS; g_smStageCfg[1].primaryTF = LAYER_CTF;
         g_smStageCfg[1].secondaryElem = SM_ELEM_EXT_SWEEP; g_smStageCfg[1].secondaryTF = LAYER_CTF;
         g_smStageCfg[1].logic = SM_LOGIC_AND; g_smStageCfg[1].causalLink = true; g_smStageCfg[1].required = true;
         g_smStageCfg[2].primaryElem = SM_ELEM_BOS; g_smStageCfg[2].primaryTF = LAYER_LTF;
         g_smStageCfg[2].secondaryElem = SM_ELEM_ORDER_BLOCK; g_smStageCfg[2].secondaryTF = LAYER_LTF;
         g_smStageCfg[2].logic = SM_LOGIC_AND; g_smStageCfg[2].causalLink = true; g_smStageCfg[2].required = true;
         g_smStageCfg[3].primaryElem = SM_ELEM_FVG; g_smStageCfg[3].primaryTF = LAYER_LTF;
         g_smStageCfg[3].secondaryElem = SM_ELEM_OTE_ZONE; g_smStageCfg[3].secondaryTF = LAYER_LTF;
         g_smStageCfg[3].logic = SM_LOGIC_OR; g_smStageCfg[3].causalLink = true;
         break;
         
case SM_PRESET_BEARISH_SWEEP_BULLISH_ENTRY:  // ★ NEW
         // Stage 0 TRIGGER: Bearish CHOCH/Sweep
         g_smStageCfg[0].primaryElem  = SM_ELEM_CHOCH_BREAK;
         g_smStageCfg[0].primaryTF    = LAYER_CTF;
         g_smStageCfg[0].logic        = SM_LOGIC_SINGLE;
         g_smStageCfg[0].dirPolicy    = SM_DIR_FROM_DR; // detect bearish
         // Stage 1 CONFIRM: Bullish FVG (counter-trigger)
         g_smStageCfg[1].primaryElem  = SM_ELEM_FVG;
         g_smStageCfg[1].primaryTF    = LAYER_CTF;
         g_smStageCfg[1].logic        = SM_LOGIC_SINGLE;
         g_smStageCfg[1].dirPolicy    = SM_DIR_COUNTER_TRIGGER; // ★ bullish FVG
         // Stage 2 VALIDATE: Bullish BOS (counter-trigger)
         g_smStageCfg[2].primaryElem  = SM_ELEM_BOS;
         g_smStageCfg[2].primaryTF    = LAYER_LTF;
         g_smStageCfg[2].logic        = SM_LOGIC_SINGLE;
         g_smStageCfg[2].required     = false;
         g_smStageCfg[2].dirPolicy    = SM_DIR_COUNTER_TRIGGER; // ★ bullish BOS
         // Stage 3 ENTRY: Bullish OB or FVG → BUY
         g_smStageCfg[3].primaryElem  = SM_ELEM_ORDER_BLOCK;
         g_smStageCfg[3].secondaryElem= SM_ELEM_FVG;
         g_smStageCfg[3].primaryTF    = LAYER_CTF;
         g_smStageCfg[3].secondaryTF  = LAYER_CTF;
         g_smStageCfg[3].logic        = SM_LOGIC_OR;
         g_smStageCfg[3].causalLink   = true;
         g_smStageCfg[3].dirPolicy    = SM_DIR_COUNTER_TRIGGER; // ★ BUY entry
         break;
 
      case SM_PRESET_BULLISH_SWEEP_BEARISH_ENTRY:  // ★ NEW (mirror)
         g_smStageCfg[0].primaryElem  = SM_ELEM_CHOCH_BREAK;
         g_smStageCfg[0].primaryTF    = LAYER_CTF;
         g_smStageCfg[0].logic        = SM_LOGIC_SINGLE;
         g_smStageCfg[0].dirPolicy    = SM_DIR_FROM_DR; // detect bullish
         g_smStageCfg[1].primaryElem  = SM_ELEM_FVG;
         g_smStageCfg[1].primaryTF    = LAYER_CTF;
         g_smStageCfg[1].logic        = SM_LOGIC_SINGLE;
         g_smStageCfg[1].dirPolicy    = SM_DIR_COUNTER_TRIGGER; // ★ bearish FVG
         g_smStageCfg[2].primaryElem  = SM_ELEM_BOS;
         g_smStageCfg[2].primaryTF    = LAYER_LTF;
         g_smStageCfg[2].logic        = SM_LOGIC_SINGLE;
         g_smStageCfg[2].required     = false;
         g_smStageCfg[2].dirPolicy    = SM_DIR_COUNTER_TRIGGER; // ★ bearish BOS
         g_smStageCfg[3].primaryElem  = SM_ELEM_ORDER_BLOCK;
         g_smStageCfg[3].secondaryElem= SM_ELEM_FVG;
         g_smStageCfg[3].primaryTF    = LAYER_CTF;
         g_smStageCfg[3].secondaryTF  = LAYER_CTF;
         g_smStageCfg[3].logic        = SM_LOGIC_OR;
         g_smStageCfg[3].causalLink   = true;
         g_smStageCfg[3].dirPolicy    = SM_DIR_COUNTER_TRIGGER; // ★ SELL entry
         break;

   }
}

#endif