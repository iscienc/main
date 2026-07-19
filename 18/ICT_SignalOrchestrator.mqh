//+------------------------------------------------------------------+
//|              ICT_SignalOrchestrator.mqh                           |
//|         Manages External Providers + Ensemble Scoring             |
//|                "ICT Unified Professional EA v15"                  |
//+------------------------------------------------------------------+
#ifndef ICT_SIGNAL_ORCHESTRATOR_MQH
#define ICT_SIGNAL_ORCHESTRATOR_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Config.mqh"
#include "../Core/ICT_Globals.mqh"
#include "ICT_ExternalProvider.mqh"

//+------------------------------------------------------------------+
//| Initialize Orchestrator                                           |
//+------------------------------------------------------------------+
bool InitializeOrchestrator()
  {
   if(InpProviderMode == PROV_DISABLED)
     {
      g_orchestratorInitialized = false;
      return true;
     }

   g_ensembleResult.Reset();
   g_activeProviderCount = 0;

   for(int i = 0; i < MAX_PROVIDERS; i++)
      g_providers[i].Reset();

// Initialize enabled providers
   if(InpProvider1_Enable && InpProvider1_Name != "")
      InitializeProvider(0, InpProvider1_Name, InpProvider1_Weight);

   if(InpProvider2_Enable && InpProvider2_Name != "")
      InitializeProvider(1, InpProvider2_Name, InpProvider2_Weight);

   if(InpProvider3_Enable && InpProvider3_Name != "")
      InitializeProvider(2, InpProvider3_Name, InpProvider3_Weight);

   if(g_activeProviderCount == 0)
     {
      Print("Orchestrator: No providers connected");
      g_orchestratorInitialized = false;
      return true;
     }

   g_orchestratorInitialized = true;
   Print("Orchestrator: ", g_activeProviderCount, " provider(s) active. Mode: ", EnumToString(InpProviderMode));
   return true;
  }

//+------------------------------------------------------------------+
//| Update All Providers (Call each tick/bar)                         |
//+------------------------------------------------------------------+
void UpdateProviders()
  {
   if(!g_orchestratorInitialized || InpProviderMode == PROV_DISABLED)
      return;

// Read signals from all providers
   for(int i = 0; i < MAX_PROVIDERS; i++)
     {
      if(!g_providers[i].enabled)
         continue;

      SExternalSignal sig = ReadProviderSignal(i);
      g_providers[i].currentSignal = sig;

      // Check expiration
      if(sig.isValid && sig.signalTime > 0)
        {
         int barsSince = iBarShift(_Symbol, PERIOD_CURRENT, sig.signalTime, false);
         sig.barsSinceSignal = barsSince;
         if(barsSince > sig.expirationBars)
           {
            sig.lifecycle = SLC_EXPIRED;
            sig.isValid = false;
           }
        }
     }

// Compute ensemble
   ComputeEnsemble();
  }

//+------------------------------------------------------------------+
//| Compute Ensemble Result                                           |
//+------------------------------------------------------------------+
void ComputeEnsemble()
  {
   g_ensembleResult.Reset();

   int buyVotes = 0, sellVotes = 0;
   double totalWeight = 0;
   double weightedScoreSum = 0;
   double bestEntry = 0, bestSL = 0, bestTP1 = 0, bestTP2 = 0;
   double bestWeight = 0;

   for(int i = 0; i < MAX_PROVIDERS; i++)
     {
      if(!g_providers[i].enabled)
         continue;

      SExternalSignal sig = g_providers[i].currentSignal;
      if(!sig.isValid || sig.isStale)
         continue;

      double w = g_providers[i].weight;

      if(sig.direction == SIGNAL_BUY)
         buyVotes++;
      else
         if(sig.direction == SIGNAL_SELL)
            sellVotes++;

      weightedScoreSum += sig.confidence * w;
      totalWeight += w;

      // Track best provider for SL/TP
      if(w > bestWeight)
        {
         bestWeight = w;
         bestEntry = sig.EntryMid();
         bestSL = sig.stopLoss;
         bestTP1 = sig.takeProfit1;
         bestTP2 = sig.takeProfit2;
        }
     }

   if(totalWeight <= 0)
      return;

// Direction by majority
   g_ensembleResult.agreeCount = MathMax(buyVotes, sellVotes);
   g_ensembleResult.disagreeCount = MathMin(buyVotes, sellVotes);
   g_ensembleResult.unanimousDirection = (buyVotes == 0 || sellVotes == 0) && (buyVotes + sellVotes > 0);

   if(buyVotes > sellVotes)
      g_ensembleResult.direction = SIGNAL_BUY;
   else
      if(sellVotes > buyVotes)
         g_ensembleResult.direction = SIGNAL_SELL;
      else
         g_ensembleResult.direction = SIGNAL_NONE;

   g_ensembleResult.consensusConfidence = weightedScoreSum / totalWeight;
   g_ensembleResult.entryPrice = bestEntry;
   g_ensembleResult.stopLoss = bestSL;
   g_ensembleResult.takeProfit1 = bestTP1;
   g_ensembleResult.takeProfit2 = bestTP2;
   g_ensembleResult.isValid = (g_ensembleResult.direction != SIGNAL_NONE);

// Build description
   g_ensembleResult.description = "Ext: " + IntegerToString(buyVotes) + "B/" +
                                  IntegerToString(sellVotes) + "S Score:" +
                                  DoubleToString(g_ensembleResult.consensusConfidence, 1);
  }

//+------------------------------------------------------------------+
//| Blend External with Internal Score                               |
//+------------------------------------------------------------------+
int GetBlendedScore(int internalScore)
  {
   return internalScore;
  }

//+------------------------------------------------------------------+
//| Check External Direction Agreement                               |
//+------------------------------------------------------------------+
bool CheckExternalAgreement(bool internalBullish)
  {
   if(!g_orchestratorInitialized || InpProviderMode == PROV_DISABLED)
      return true; // No external = no conflict

   if(!g_ensembleResult.isValid)
      return true; // No signal = pass

   bool externalBullish = (g_ensembleResult.direction == SIGNAL_BUY);

   switch(InpConflictMode)
     {
      case CONFLICT_INTERNAL_WINS:
         return true; // Always pass

      case CONFLICT_EXTERNAL_WINS:
         return (internalBullish == externalBullish);

      case CONFLICT_AGREEMENT_REQUIRED:
         return (internalBullish == externalBullish);

      case CONFLICT_HIGHEST_CONFIDENCE:
        {
         // No score model anymore: use directional strength rule
         // If conflict and external is unanimous, external wins; otherwise internal wins
         if(internalBullish == externalBullish)
            return true;

         if(g_ensembleResult.unanimousDirection)
            return false; // block internal if unanimous opposite external

         return true; // internal wins when external not unanimous
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Get External SL/TP if configured                                 |
//+------------------------------------------------------------------+
bool GetExternalSLTP(double &sl, double &tp1, double &tp2)
  {
   if(!InpExternalUseOwnSLTP || !g_ensembleResult.isValid)
      return false;

   if(g_ensembleResult.stopLoss > 0)
      sl = g_ensembleResult.stopLoss;
   if(g_ensembleResult.takeProfit1 > 0)
      tp1 = g_ensembleResult.takeProfit1;
   if(g_ensembleResult.takeProfit2 > 0)
      tp2 = g_ensembleResult.takeProfit2;

   return true;
  }

//+------------------------------------------------------------------+
//| Get Provider Status String                                       |
//+------------------------------------------------------------------+
string GetProviderStatusString()
  {
   if(!g_orchestratorInitialized)
      return "Providers: OFF";

   string status = "Providers: ";
   for(int i = 0; i < MAX_PROVIDERS; i++)
     {
      if(!g_providers[i].enabled)
         continue;
      status += g_providers[i].name;
      status += g_providers[i].connected ? " ✓" : " ✗";
      if(g_providers[i].currentSignal.isValid)
         status += "(" + (g_providers[i].currentSignal.direction == SIGNAL_BUY ? "B" : "S") + ")";
      status += " | ";
     }
   return status;
  }

//+------------------------------------------------------------------+
//| Deinitialize Orchestrator                                        |
//+------------------------------------------------------------------+
void DeinitOrchestrator()
  {
   ReleaseAllProviders();
   g_orchestratorInitialized = false;
  }

#endif // ICT_SIGNAL_ORCHESTRATOR_MQH
//+------------------------------------------------------------------+
