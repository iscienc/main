//+------------------------------------------------------------------+
//| ICT_MTFLayers.mqh                                                |
//| Unified MTF Layer Contract    - per-layer Judas / AMD / SMT      |
//| NEW FILE. Include LAST in ICT_SMDetectors.mqh (after the phase   |
//| modules) so CTF delegates resolve. On-demand: no engine edits.   |
//|        "ICT Unified Professional EA v16"                         |
//+------------------------------------------------------------------+
#ifndef ICT_MTFLAYERS_MQH
#define ICT_MTFLAYERS_MQH

#include "ICT_SMTypes.mqh"
// Relies on symbols already visible from earlier includes in
// ICT_SMDetectors.mqh:
//   ICT_Globals   -> g_amdPhase, g_needDetectAMD, AMD_ACCUMULATION/MANIPULATION/DISTRIBUTION
//   ICT_JudasSwing-> HasActiveJudasSwing(), GetJudasSwingDirection()
//   ICT_SMT       -> HasSMTConfirmation(bool)
//   ICT_SMTypes   -> SM_LayerToTF / SM_LayerATR / SM_LayerReady

//==================================================================
// PATCH D - Judas, layer-aware
//   CTF delegates to the existing global Judas (identical behavior).
//   HTF/LTF: session-open sweep + reversal computed on the layer TF.
//==================================================================
bool SM_Detect_JudasLayer(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION &outDir)
  {
   outDir = DIR_NONE;
   if(!SM_LayerReady(tfLay))
      return false;

   if(tfLay == LAYER_CTF)
     {
      if(!HasActiveJudasSwing())
         return false;
      outDir = GetJudasSwingDirection();
      return (outDir != DIR_NONE);
     }

   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;

   int look = 12;
   double hi = -DBL_MAX, lo = DBL_MAX;
   int hiIdx = -1, loIdx = -1;
   for(int i = 1; i <= look; i++)
     {
      double h = iHigh(_Symbol, tf, i);
      double l = iLow (_Symbol, tf, i);
      if(h > hi) { hi = h; hiIdx = i; }
      if(l < lo) { lo = l; loIdx = i; }
     }
   double c1 = iClose(_Symbol, tf, 1);
   double o1 = iOpen (_Symbol, tf, 1);

   // Bearish Judas: swept the high, reversed back down.
   if(hiIdx >= 2 && (hi - c1) > atr * 0.5 && c1 < o1)
     { outDir = DIR_BEARISH; return true; }
   // Bullish Judas: swept the low, reversed back up.
   if(loIdx >= 2 && (c1 - lo) > atr * 0.5 && c1 > o1)
     { outDir = DIR_BULLISH; return true; }
   return false;
  }

//==================================================================
// PATCH E - AMD, layer-aware
//   CTF replicates the original global-driven logic byte-for-byte.
//   HTF/LTF: lightweight range-based phase proxy on the layer TF.
//==================================================================
void SM_ComputeLayerAMD(ENUM_TF_LAYER lay, int &phaseOut,
                        ENUM_TRADE_DIRECTION &dirOut, bool &activeOut)
  {
   if(lay == LAYER_CTF)
     {
      phaseOut  = (int)g_amdPhase.currentPhase;
      dirOut    = g_amdPhase.expectedDirection;
      activeOut = true;
      return;
     }

   phaseOut = (int)AMD_ACCUMULATION; dirOut = DIR_NONE; activeOut = false;
   ENUM_TIMEFRAMES tf = SM_LayerToTF(lay);
   double atr = SM_LayerATR(lay);
   if(atr <= 0)
      return;

   double r1 = iHigh(_Symbol, tf, 1) - iLow(_Symbol, tf, 1);
   double r2 = iHigh(_Symbol, tf, 2) - iLow(_Symbol, tf, 2);
   double c1 = iClose(_Symbol, tf, 1), o1 = iOpen(_Symbol, tf, 1);
   activeOut = true;

   if(r1 < atr * 0.7 && r2 < atr * 0.7)
     { phaseOut = (int)AMD_ACCUMULATION; dirOut = DIR_NONE; return; }
   if(r1 > atr * 1.3)
     { phaseOut = (int)AMD_MANIPULATION; dirOut = (c1 > o1) ? DIR_BULLISH : DIR_BEARISH; return; }
   phaseOut = (int)AMD_DISTRIBUTION; dirOut = (c1 > o1) ? DIR_BULLISH : DIR_BEARISH;
  }

// Direction accessor for SM_DIR_FROM_AMD (per stage layer).
ENUM_TRADE_DIRECTION SM_LayerAMDDirection(ENUM_TF_LAYER lay)
  {
   int ph; ENUM_TRADE_DIRECTION d; bool a;
   SM_ComputeLayerAMD(lay, ph, d, a);
   return d;
  }

bool SM_Detect_AMDLayer(ENUM_TF_LAYER tfLay, int phaseKind, ENUM_TRADE_DIRECTION dir)
  {
   if(tfLay == LAYER_CTF)
     {
      if(!g_needDetectAMD)                          return true;   // original guard preserved
      if(phaseKind == (int)AMD_ACCUMULATION)
         return (g_amdPhase.currentPhase == AMD_ACCUMULATION);
      if((int)g_amdPhase.currentPhase != phaseKind) return false;
      return (g_amdPhase.expectedDirection == dir || g_amdPhase.expectedDirection == DIR_NONE);
     }

   int ph; ENUM_TRADE_DIRECTION d; bool a;
   SM_ComputeLayerAMD(tfLay, ph, d, a);
   if(!a)                                 return false;
   if(ph != phaseKind)                    return false;
   if(phaseKind == (int)AMD_ACCUMULATION) return true;
   return (d == dir || d == DIR_NONE);
  }

//==================================================================
// PATCH E - SMT, layer-aware wrapper
//   SMT divergence is cross-symbol. Engine computes it on the chart
//   TF; CTF uses it directly. HTF/LTF reuse the confirmation gated
//   by layer-readiness. For TRUE per-TF SMT, thread an
//   ENUM_TIMEFRAMES into HasSMTConfirmation and call it with
//   SM_LayerToTF(tfLay) here.
//==================================================================
bool SM_Detect_SMTLayer(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir)
  {
   if(!SM_LayerReady(tfLay))
      return false;
   return HasSMTConfirmation(dir == DIR_BULLISH);
  }

#endif // ICT_MTFLAYERS_MQH
//+------------------------------------------------------------------+