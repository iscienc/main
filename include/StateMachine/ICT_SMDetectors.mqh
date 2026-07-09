//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef ICT_SMDETECTORS_MQH
#define ICT_SMDETECTORS_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "ICT_SMTypes.mqh"
#include "../NarrativeZones/ICT_NarrativeZones_Master.mqh"
#include "../Structure/ICT_DealingRange.mqh"
#include "../Structure/ICT_MultiTF.mqh"
#include "../MarketPhase/ICT_JudasSwing.mqh"
#include "../MarketPhase/ICT_AMD.mqh"
#include "../MarketPhase/ICT_SMT.mqh"
#include "../MarketPhase/ICT_Killzones.mqh"


//--- ★ NEW helper: flip a direction
ENUM_TRADE_DIRECTION InvertDir(ENUM_TRADE_DIRECTION d)
  {
   if(d == DIR_BULLISH)
      return DIR_BEARISH;
   if(d == DIR_BEARISH)
      return DIR_BULLISH;
   return DIR_NONE;
  }

//--- Direction policy resolver
ENUM_TRADE_DIRECTION SM_GetStageDirection(const SSMInstance &inst,
      const SSMStageConfig &cfg)
  {
   switch(cfg.dirPolicy)
     {
      case SM_DIR_FROM_TRIGGER:
         return inst.direction;
      case SM_DIR_FROM_DR:
         return g_currentDirection;
      case SM_DIR_FROM_AMD:
         return g_amdPhase.expectedDirection;
      case SM_DIR_COUNTER_TRIGGER: // ★ NEW
      case SM_DIR_INVERT_TRIGGER: // ★ NEW (fallthrough)
         return InvertDir(inst.direction);
      case SM_DIR_FIXED_BULL: // ★ NEW
         return DIR_BULLISH;
      case SM_DIR_FIXED_BEAR: // ★ NEW
         return DIR_BEARISH;
     }
   return inst.direction;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_ProviderSignal(int providerIdx, ENUM_TRADE_DIRECTION dir, double &outPrice)
  {
   outPrice = 0;
   if(providerIdx < 0 || providerIdx >= MAX_PROVIDERS)
      return false;
   if(!g_providers[providerIdx].enabled || !g_providers[providerIdx].connected)
      return false;

   SExternalSignal sig = g_providers[providerIdx].currentSignal;
   if(!sig.isValid || sig.isStale)
      return false;

   ENUM_TRADE_DIRECTION pdir = DIR_NONE;
   if(sig.direction == SIGNAL_BUY)
      pdir = DIR_BULLISH;
   else
      if(sig.direction == SIGNAL_SELL)
         pdir = DIR_BEARISH;

   if(pdir == DIR_NONE)
      return false;
   if(dir != DIR_NONE && pdir != dir)
      return false;

   outPrice = sig.EntryMid();
   if(outPrice <= 0)
      outPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   return true;
  }
//=====================================================================
//  INDIVIDUAL ELEMENT CHECKERS  (all TF-aware via ENUM_TF_LAYER)
//=====================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_ChoChBreak(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION &outDir,
                          double &outPrice)
  {
   if(!SM_LayerReady(tfLay))
      return false;
// Check if a structural event fired on this TF recently
   if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0)
      return false;
// Event must be recent (within 5 CTF bars)
   int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
   if(evAge < 0 || evAge > 5)
      return false;
// Check event TF matches (structural events store their TF layer)
   if(g_lastSMEvent.tfLayer != tfLay)
      return false;
   outDir   = g_lastSMEvent.direction;
   outPrice = g_lastSMEvent.price;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_BOS(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir)
  {
   if(!SM_LayerReady(tfLay))
      return false;
   bool bull = (dir == DIR_BULLISH);
   SDealingRange* dr = SM_LayerDR(tfLay, bull);
   if(!dr.corrLine.isActive)
      return false;
// BOS = CL updated recently on that TF
   int bosAge = 0;
   if(dr.corrLine.extremeTime > 0)
     {
      int bosBar = iBarShift(_Symbol, SM_LayerToTF(tfLay),
                             dr.corrLine.extremeTime, false);
      bosAge = bosBar; // bars ago on that TF
     }
   return (bosAge >= 0 && bosAge <= 5);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_ExtSweep(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir)
  {
   if(!SM_LayerReady(tfLay))
      return false;
   bool bull = (dir == DIR_BULLISH);
   SDealingRange* dr = SM_LayerDR(tfLay, bull);
   if(!dr.externalSwept)
      return false;
   if(dr.sweepTime == 0)
      return false;
   int sweepBar = iBarShift(_Symbol, SM_LayerToTF(tfLay), dr.sweepTime, false);
   return (sweepBar >= 0 && sweepBar <= 5);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_Judas(ENUM_TRADE_DIRECTION &outDir)
  {
   if(!HasActiveJudasSwing())
      return false;
   outDir = GetJudasSwingDirection();
   return (outDir != DIR_NONE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_Displacement(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir)
  {
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;
   if(!IsDisplacementCandle(tf, 1, atr))
      return false;
// Direction check
   double c = iClose(_Symbol, tf, 1);
   double o = iOpen(_Symbol, tf, 1);
   if(dir == DIR_BULLISH && c <= o)
      return false;
   if(dir == DIR_BEARISH && c >= o)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_BodyClose(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir)
  {
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double c = iClose(_Symbol, tf, 1);
   double o = iOpen(_Symbol, tf, 1);
   if(dir == DIR_BULLISH)
      return (c > o);
   if(dir == DIR_BEARISH)
      return (c < o);
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_OB(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                  bool causal, int &outTag, double &outPrice)
  {
   bool bull = (dir == DIR_BULLISH);
   outTag = -1;
   outPrice = 0;

   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
      // ★ C1: key off the chain's origin tag, not the live global event
      int useTag = (causal && g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : -1;
      if(useTag >= 0)
        {
         if(IsPriceAtCausalOB(bull, useTag, idx))
           { outTag = useTag; outPrice = g_orderBlocks[idx].midpoint; return true; }
         return false;   // causal requested, no lineage match -> fail closed
        }
      if(IsPriceAtOrderBlock(bull, idx))
        { outTag = g_orderBlocks[idx].causalTag; outPrice = g_orderBlocks[idx].midpoint; return true; }
      return false;
     }
// HTF/LTF: inline scan
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;


// ★ C3: enforce causal gate on non-CTF paths (was silently ignored)
   if(causal)
     {
      if(g_smActiveCausalTag < 0)
         return false;
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0)
         return false;
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20)
         return false;
      if(g_lastSMEvent.tfLayer != tfLay)
         return false;
     }

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   for(int i = 2; i <= 20; i++)
     {
      double co = iOpen(_Symbol, tf, i), cc = iClose(_Symbol, tf, i);
      double ch = iHigh(_Symbol, tf, i), cl = iLow(_Symbol, tf, i);
      double no = iOpen(_Symbol, tf, i-1), nc = iClose(_Symbol, tf, i-1);
      double nr = iHigh(_Symbol, tf, i-1) - iLow(_Symbol, tf, i-1);
      if(bull)
        {
         if(cc >= co)
            continue;
         if(nc <= no || nr < atr * 1.0 || nc <= ch)
            continue;
         double ot = MathMax(co, cc), ob = cl;
         if(price >= ob && price <= ot)
           {
            outPrice = (ot+ob)/2;
            if(causal)
               outTag = g_smActiveCausalTag;   // ★ C3: stamp lineage
            return true;
           }
        }
      else
        {
         if(cc <= co)
            continue;
         if(nc >= no || nr < atr * 1.0 || nc >= cl)
            continue;
         double ot = ch, ob = MathMin(co, cc);
         if(price >= ob && price <= ot)
           {
            outPrice = (ot+ob)/2;
            if(causal)
               outTag = g_smActiveCausalTag;   // ★ C3: stamp lineage
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_FVG(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                   bool causal, int &outTag, double &outPrice)
  {
   bool bull = (dir == DIR_BULLISH);
   outTag = -1;
   outPrice = 0;

   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
int useTag = (causal && g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : -1;   // ★ C1
      if(useTag >= 0)
        {
         if(IsPriceInCausalFVG(bull, useTag, idx))
           { outTag = useTag; outPrice = (g_fvgList[idx].top+g_fvgList[idx].bottom)*0.5; return true; }
         return false;   // fail closed
        }
      if(IsPriceInFVG(bull, idx))
        { outTag = g_fvgList[idx].causalTag; outPrice = (g_fvgList[idx].top+g_fvgList[idx].bottom)*0.5; return true; }
      return false;
     }
     
     
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;
      
  // ★ C3: enforce causal gate on non-CTF paths
   if(causal)
     {
      if(g_smActiveCausalTag < 0) return false;
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0) return false;
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20) return false;
      if(g_lastSMEvent.tfLayer != tfLay) return false;
     }

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   for(int i = 2; i <= 30; i++)
     {
      if(bull)
        {
         double h1 = iHigh(_Symbol, tf, i+1), l3 = iLow(_Symbol, tf, i-1);
         if(l3 <= h1) continue;
         if((l3 - h1) < atr * 0.15) continue;
         if(price >= h1 && price <= l3)
           {
            outPrice = (h1+l3)/2;
            if(causal) outTag = g_smActiveCausalTag;   // ★ C3
            return true;
           }
        }
      else
        {
         double l1 = iLow(_Symbol, tf, i+1), h3 = iHigh(_Symbol, tf, i-1);
         if(h3 >= l1) continue;
         if((l1 - h3) < atr * 0.15) continue;
         if(price >= h3 && price <= l1)
           {
            outPrice = (h3+l1)/2;
            if(causal) outTag = g_smActiveCausalTag;   // ★ C3
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_IFVG(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                    bool causal, int &outTag, double &outPrice)
  {
   bool bull = (dir == DIR_BULLISH);
   outTag = -1;
   outPrice = 0;

   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
     int useTag = (causal && g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : -1;   // ★ C1
      if(IsPriceInIFVG(bull, useTag, idx))
        {
         outTag   = g_fvgList[idx].causalTag;
         outPrice = (g_fvgList[idx].top + g_fvgList[idx].bottom) * 0.5;
         return true;
        }
      if(causal) return false;   // fail closed when lineage required
      return false;
     }

// HTF/LTF fallback: infer IFVG from invalidation + retest around FVG zone
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;

  // ★ C3: enforce causal gate on non-CTF paths
   if(causal)
     {
      if(g_smActiveCausalTag < 0) return false;
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0) return false;
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20) return false;
      if(g_lastSMEvent.tfLayer != tfLay) return false;
     }

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double breakBuffer = MathMax(_Point * 2, atr * 0.02);

   for(int i = 3; i <= 60; i++)
     {
      double h1 = iHigh(_Symbol, tf, i+1), l3 = iLow(_Symbol, tf, i-1);
      double l1 = iLow(_Symbol, tf, i+1), h3 = iHigh(_Symbol, tf, i-1);

      if(bull)
        {
         if(h3 >= l1) continue;
         if((l1 - h3) < atr * 0.15) continue;
         bool brokeUp = false;
         for(int b = i-1; b >= 1; b--)
           {
            double c = iClose(_Symbol, tf, b);
            if(c > l1 + breakBuffer) { brokeUp = true; break; }
           }
         if(!brokeUp) continue;
         if(price >= h3 && price <= l1)
           { outPrice = (h3 + l1) * 0.5; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
      else
        {
         if(l3 <= h1) continue;
         if((l3 - h1) < atr * 0.15) continue;
         bool brokeDn = false;
         for(int b = i-1; b >= 1; b--)
           {
            double c = iClose(_Symbol, tf, b);
            if(c < h1 - breakBuffer) { brokeDn = true; break; }
           }
         if(!brokeDn) continue;
         if(price >= h1 && price <= l3)
           { outPrice = (h1 + l3) * 0.5; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_FVG_CE(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                      bool causal, int &outTag, double &outPrice)
  {
   bool bull = (dir == DIR_BULLISH);
   outTag = -1;
   outPrice = 0;

   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
     int useTag = (causal && g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : -1;   // ★ C1
      if(IsPriceAtFVGCE(bull, useTag, idx))
        {
         outTag   = g_fvgList[idx].causalTag;
         outPrice = g_fvgList[idx].ce;
         return true;
        }
      if(causal) return false;   // fail closed
      return false;
     }

// HTF/LTF fallback CE from synthetic FVG scan
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;

  // ★ C3: enforce causal gate on non-CTF paths
   if(causal)
     {
      if(g_smActiveCausalTag < 0) return false;
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0) return false;
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20) return false;
      if(g_lastSMEvent.tfLayer != tfLay) return false;
     }

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double tol = MathMax(_Point * 5, atr * 0.03);
   for(int i = 2; i <= 50; i++)
     {
      if(bull)
        {
         double h1 = iHigh(_Symbol, tf, i+1), l3 = iLow(_Symbol, tf, i-1);
         if(l3 <= h1 || (l3 - h1) < atr * 0.15) continue;
         double ce = (h1 + l3) * 0.5;
         if(MathAbs(price - ce) <= tol)
           { outPrice = ce; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
      else
        {
         double l1 = iLow(_Symbol, tf, i+1), h3 = iHigh(_Symbol, tf, i-1);
         if(h3 >= l1 || (l1 - h3) < atr * 0.15) continue;
         double ce = (h3 + l1) * 0.5;
         if(MathAbs(price - ce) <= tol)
           { outPrice = ce; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_VolumeImbalance(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                               bool causal, int &outTag, double &outPrice)
  {
   bool bull = (dir == DIR_BULLISH);
   outTag = -1;
   outPrice = 0;

   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
     int useTag = (causal && g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : -1;   // ★ C1
      if(IsPriceAtVolumeImbalance(bull, useTag, idx))
        {
         outTag   = g_viList[idx].causalTag;
         outPrice = (g_viList[idx].top + g_viList[idx].bottom) * 0.5;
         return true;
        }
      if(causal) return false;   // fail closed
      return false;
     }

// HTF/LTF fallback from body-gap scan
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;

    // ★ C3: enforce causal gate on non-CTF paths
   if(causal)
     {
      if(g_smActiveCausalTag < 0) return false;
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0) return false;
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20) return false;
      if(g_lastSMEvent.tfLayer != tfLay) return false;
     }

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   for(int i = 3; i <= 40; i++)
     {
      if(bull)
        {
         double bodyBottom1 = MathMin(iOpen(_Symbol, tf, i+1), iClose(_Symbol, tf, i+1));
         double bodyTop3    = MathMax(iOpen(_Symbol, tf, i-1), iClose(_Symbol, tf, i-1));
         if(bodyTop3 <= bodyBottom1) continue;
         if((bodyTop3 - bodyBottom1) < atr * 0.1) continue;
         if(price >= bodyBottom1 && price <= bodyTop3)
           { outPrice = (bodyBottom1 + bodyTop3) * 0.5; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
      else
        {
         double bodyTop1    = MathMax(iOpen(_Symbol, tf, i+1), iClose(_Symbol, tf, i+1));
         double bodyBottom3 = MathMin(iOpen(_Symbol, tf, i-1), iClose(_Symbol, tf, i-1));
         if(bodyBottom3 >= bodyTop1) continue;
         if((bodyTop1 - bodyBottom3) < atr * 0.1) continue;
         if(price >= bodyBottom3 && price <= bodyTop1)
           { outPrice = (bodyBottom3 + bodyTop1) * 0.5; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_LiquidityVoid(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                             bool causal, int &outTag, double &outPrice)
  {
   bool bull = (dir == DIR_BULLISH);
   outTag = -1;
   outPrice = 0;

   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
      int useTag = (causal && g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : -1;   // ★ C1
      if(IsPriceAtLiquidityVoid(bull, useTag, idx))
        {
         outTag   = g_voidList[idx].causalTag;
         outPrice = (g_voidList[idx].top + g_voidList[idx].bottom) * 0.5;
         return true;
        }
      if(causal) return false;   // fail closed
      return false;
     }
// HTF/LTF fallback from large displacement candle non-overlap zone
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;

  // ★ C3: enforce causal gate on non-CTF paths
   if(causal)
     {
      if(g_smActiveCausalTag < 0) return false;
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0) return false;
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20) return false;
      if(g_lastSMEvent.tfLayer != tfLay) return false;
     }

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   for(int i = 3; i <= 40; i++)
     {
      double high = iHigh(_Symbol, tf, i), low = iLow(_Symbol, tf, i);
      if((high - low) < atr * InpVoid_MinSizeATR) continue;

      double open = iOpen(_Symbol, tf, i), close = iClose(_Symbol, tf, i);
      double prevHigh = iHigh(_Symbol, tf, i + 1), prevLow = iLow(_Symbol, tf, i + 1);
      double nextHigh = iHigh(_Symbol, tf, i - 1), nextLow = iLow(_Symbol, tf, i - 1);

      if(bull)
        {
         if(close <= open) continue;
         double zTop = high;
         double zBot = MathMax(prevHigh, nextHigh);
         if(zTop <= zBot + atr * 0.2) continue;
         if(price >= zBot && price <= zTop)
           { outPrice = (zTop + zBot) * 0.5; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
      else
        {
         if(close >= open) continue;
         double zTop = MathMin(prevLow, nextLow);
         double zBot = low;
         if(zTop <= zBot + atr * 0.2) continue;
         if(price >= zBot && price <= zTop)
           { outPrice = (zTop + zBot) * 0.5; if(causal) outTag = g_smActiveCausalTag; return true; }   // ★ C3
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_Breaker(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                       bool causal, int &outTag, double &outPrice)
  {
   outTag = -1;
   outPrice = 0.0;

   int requiredTag = -1;

// Causal gate (shared for CTF + HTF/LTF)
   if(causal)
     {
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0)
         return false;

      // must align with chain direction
      if(g_lastSMEvent.direction != dir)
         return false;

      // freshness gate (CTF bar counter)
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20)
         return false;

      // for strongest integrity, event TF must match selected TF layer
      if(g_lastSMEvent.tfLayer != tfLay)
         return false;

      requiredTag = (g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : g_lastSMEvent.tag;   // ★ C1
     }

// CTF: use existing breaker objects
   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
      if(IsPriceAtBreakerBlock(dir == DIR_BULLISH, idx))
        {
         outPrice = (g_breakerBlocks[idx].top + g_breakerBlocks[idx].bottom) * 0.5;
         if(causal)
            outTag = requiredTag; // step 3
         return true;
        }
      return false;
     }

// HTF/LTF fallback: synthetic breaker scan
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double breakBuf = MathMax(_Point * 3, atr * 0.03);

   for(int i = 6; i <= 80; i++)
     {
      double o = iOpen(_Symbol, tf, i);
      double c = iClose(_Symbol, tf, i);
      double h = iHigh(_Symbol, tf, i);
      double l = iLow(_Symbol, tf, i);

      if(dir == DIR_BULLISH)
        {
         // source zone candidate
         if(c <= o)
            continue;
         double zTop = h;
         double zBot = MathMin(o, c);

         bool invalidatedUp = false;
         for(int b = i - 1; b >= 1; b--)
           {
            double cb = iClose(_Symbol, tf, b);
            if(cb > zTop + breakBuf && IsDisplacementCandle(tf, b, atr))
              {
               invalidatedUp = true;
               break;
              }
           }
         if(!invalidatedUp)
            continue;

         if(price >= zBot && price <= zTop)
           {
            outPrice = (zTop + zBot) * 0.5;
            if(causal)
               outTag = requiredTag; // step 4/5 proxy chain-link
            return true;
           }
        }
      else
         if(dir == DIR_BEARISH)
           {
            if(c >= o)
               continue;
            double zTop = MathMax(o, c);
            double zBot = l;

            bool invalidatedDn = false;
            for(int b = i - 1; b >= 1; b--)
              {
               double cb = iClose(_Symbol, tf, b);
               if(cb < zBot - breakBuf && IsDisplacementCandle(tf, b, atr))
                 {
                  invalidatedDn = true;
                  break;
                 }
              }
            if(!invalidatedDn)
               continue;

            if(price >= zBot && price <= zTop)
              {
               outPrice = (zTop + zBot) * 0.5;
               if(causal)
                  outTag = requiredTag;
               return true;
              }
           }
     }

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_Mitigation(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir,
                          bool causal, int &outTag, double &outPrice)
  {
   outTag = -1;
   outPrice = 0.0;

   int requiredTag = -1;

// Causal gate
   if(causal)
     {
      if(!g_lastSMEvent.valid || g_lastSMEvent.tag < 0)
         return false;

      if(g_lastSMEvent.direction != dir)
         return false;

      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;
      if(evAge < 0 || evAge > 20)
         return false;

      if(g_lastSMEvent.tfLayer != tfLay)
         return false;

      requiredTag = (g_smActiveCausalTag >= 0) ? g_smActiveCausalTag : g_lastSMEvent.tag;   // ★ C1
     }

// CTF: use existing mitigation objects
   if(tfLay == LAYER_CTF)
     {
      int idx = -1;
      if(IsPriceAtMitigationBlock(dir == DIR_BULLISH, idx))
        {
         outPrice = (g_mitigationBlocks[idx].top + g_mitigationBlocks[idx].bottom) * 0.5;
         if(causal)
            outTag = requiredTag; // step 3
         return true;
        }
      return false;
     }

// HTF/LTF fallback: synthetic mitigation scan
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;

   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double breakBuf = MathMax(_Point * 2, atr * 0.02);

   for(int i = 5; i <= 80; i++)
     {
      double o = iOpen(_Symbol, tf, i);
      double c = iClose(_Symbol, tf, i);
      double h = iHigh(_Symbol, tf, i);
      double l = iLow(_Symbol, tf, i);

      if(dir == DIR_BULLISH)
        {
         if(c >= o)
            continue; // bearish source candle
         double zTop = MathMax(o, c);
         double zBot = l;

         bool continuationUp = false;
         for(int b = i - 1; b >= 1; b--)
           {
            if(iClose(_Symbol, tf, b) > h + breakBuf)
              {
               continuationUp = true;
               break;
              }
           }
         if(!continuationUp)
            continue;

         if(price >= zBot && price <= zTop)
           {
            outPrice = (zTop + zBot) * 0.5;
            if(causal)
               outTag = requiredTag;
            return true;
           }
        }
      else
         if(dir == DIR_BEARISH)
           {
            if(c <= o)
               continue; // bullish source candle
            double zTop = h;
            double zBot = MathMin(o, c);

            bool continuationDn = false;
            for(int b = i - 1; b >= 1; b--)
              {
               if(iClose(_Symbol, tf, b) < l - breakBuf)
                 {
                  continuationDn = true;
                  break;
                 }
              }
            if(!continuationDn)
               continue;

            if(price >= zBot && price <= zTop)
              {
               outPrice = (zTop + zBot) * 0.5;
               if(causal)
                  outTag = requiredTag;
               return true;
              }
           }
     }

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_OTE(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir)
  {
   if(tfLay == LAYER_CTF)
     {
      if(!g_oteZone.isValid)
         return false;
      if((dir == DIR_BULLISH) != g_oteZone.isBullish)
         return false;
      return IsPriceInOTEZone();
     }
// HTF/LTF: compute OTE from that TF's swing range
   ENUM_TIMEFRAMES tf = SM_LayerToTF(tfLay);
   int hb = iHighest(_Symbol, tf, MODE_HIGH, 50, 1);
   int lb = iLowest(_Symbol, tf, MODE_LOW, 50, 1);
   double sh = iHigh(_Symbol, tf, hb), sl = iLow(_Symbol, tf, lb);
   if(sh <= sl)
      return false;
   double range = sh - sl;
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   if(dir == DIR_BULLISH)
     {
      double top = sl + range * (1.0 - 0.618);
      double bot = sl + range * (1.0 - 0.79);
      return (price >= bot && price <= top);
     }
   else
     {
      double top = sl + range * 0.79;
      double bot = sl + range * 0.618;
      return (price >= bot && price <= top);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_RetraceToEZ(ENUM_TRADE_DIRECTION dir)
  {
   if(!g_entryZone.isValid)
      return false;
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   return g_entryZone.Contains(price);
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_SMTDivergence(ENUM_TRADE_DIRECTION dir)
  {
   return HasSMTConfirmation(dir == DIR_BULLISH);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_DRTarget(ENUM_TF_LAYER tfLay, ENUM_TRADE_DIRECTION dir)
  {
   bool bull = (dir == DIR_BULLISH);
   SDealingRange* oppDR = SM_LayerDR(tfLay, !bull);
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double atr = SM_LayerATR(tfLay);
   if(atr <= 0)
      return false;
   for(int i = 0; i < oppDR.originCount; i++)
     {
      if(oppDR.origins[i].role != ROLE_TARGET || oppDR.origins[i].isReached)
         continue;
      if(MathAbs(price - oppDR.origins[i].price) < atr * 0.3)
         return true;
     }
   return false;
  }

bool SM_Detect_Killzone() { return IsInKillzone(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_AMDDistribution(ENUM_TRADE_DIRECTION dir)
  {
   if(!g_needDetectAMD)
      return true;
   if(g_amdPhase.currentPhase != AMD_DISTRIBUTION)
      return false;
   return (g_amdPhase.expectedDirection == dir || g_amdPhase.expectedDirection == DIR_NONE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_AMDManipulation(ENUM_TRADE_DIRECTION dir)
  {
   if(!g_needDetectAMD)
      return true;
   if(g_amdPhase.currentPhase != AMD_MANIPULATION)
      return false;
   return (g_amdPhase.expectedDirection == dir || g_amdPhase.expectedDirection == DIR_NONE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SM_Detect_AMDAccumulation()
  {
   if(!g_needDetectAMD)
      return true;
   return (g_amdPhase.currentPhase == AMD_ACCUMULATION);
  }

//=====================================================================
//  MAIN DISPATCH
//=====================================================================
bool SM_CheckElementSatisfied(ENUM_SM_ELEMENT elem, ENUM_TF_LAYER tfLay,
                              const SSMInstance &inst,
                              const SSMStageConfig &cfg,
                              int &outTag, double &outPrice)
  {

   outTag = -1;
   outPrice = 0.0;

   g_smActiveCausalTag = (inst.birthEventTag >= 0) ? inst.birthEventTag
                         : (g_lastSMEvent.valid ? g_lastSMEvent.tag : -1);              //added for causal link FIX

   ENUM_TRADE_DIRECTION dir = SM_GetStageDirection(inst, cfg);

// Direction-independent elements first
   if(elem == SM_ELEM_NONE)
      return true;
   if(elem == SM_ELEM_KILLZONE)
      return SM_Detect_Killzone();
   if(elem == SM_ELEM_AMD_ACCUMULATION)
      return SM_Detect_AMDAccumulation();

   if(dir == DIR_NONE)
      return false;
   bool useCausal = cfg.causalLink;
   switch(elem)
     {
      case SM_ELEM_NONE:
         return true;

      case SM_ELEM_CHOCH_BREAK:
        {
         ENUM_TRADE_DIRECTION d = DIR_NONE;
         double p = 0.0;
         if(!SM_Detect_ChoChBreak(tfLay, d, p))
            return false;
         // inst is const, so we do not modify inst.direction here.
         outTag = (g_lastSMEvent.valid ? g_lastSMEvent.tag : -1);
         outPrice = p;
         return true;
        }

      case SM_ELEM_BOS:
         return SM_Detect_BOS(tfLay, dir);

      case SM_ELEM_EXT_SWEEP:
         return SM_Detect_ExtSweep(tfLay, dir);

      case SM_ELEM_JUDAS_SWING:
        {
         ENUM_TRADE_DIRECTION jd = DIR_NONE;
         if(!SM_Detect_Judas(jd))
            return false;
         // inst is const, so we do not modify inst.direction here.
         return (dir == DIR_NONE || jd == dir);
        }

      case SM_ELEM_DISPLACEMENT:
         return SM_Detect_Displacement(tfLay, dir);

      case SM_ELEM_BODY_CLOSE:
         return SM_Detect_BodyClose(tfLay, dir);

      case SM_ELEM_ORDER_BLOCK:
         return SM_Detect_OB(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_FVG:
         return SM_Detect_FVG(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_IFVG:
         return SM_Detect_IFVG(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_FVG_CE:
         return SM_Detect_FVG_CE(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_VOLUME_IMBALANCE:
         return SM_Detect_VolumeImbalance(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_LIQUIDITY_VOID:
         return SM_Detect_LiquidityVoid(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_BREAKER:
         return SM_Detect_Breaker(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_MITIGATION:
         return SM_Detect_Mitigation(tfLay, dir, useCausal, outTag, outPrice);

      case SM_ELEM_OTE_ZONE:
         return SM_Detect_OTE(tfLay, dir);

      case SM_ELEM_RETRACE_TO_EZ:
         return SM_Detect_RetraceToEZ(dir);

      case SM_ELEM_SMT_DIVERGENCE:
         return SM_Detect_SMTDivergence(dir);

      case SM_ELEM_DR_TARGET_AREA:
         return SM_Detect_DRTarget(tfLay, dir);

      case SM_ELEM_AMD_DISTRIBUTION:
         return SM_Detect_AMDDistribution(dir);

      case SM_ELEM_AMD_MANIPULATION:
         return SM_Detect_AMDManipulation(dir);

      case SM_ELEM_PROVIDER1_SIGNAL:
         return SM_Detect_ProviderSignal(0, dir, outPrice);

      case SM_ELEM_PROVIDER2_SIGNAL:
         return SM_Detect_ProviderSignal(1, dir, outPrice);

      case SM_ELEM_PROVIDER3_SIGNAL:
         return SM_Detect_ProviderSignal(2, dir, outPrice);

      default:
         return false;
     }
  }

#endif // ICT_SMDETECTORS_MQH
//+------------------------------------------------------------------+
