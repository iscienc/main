//+------------------------------------------------------------------+
//|                        ICT_Unified_EA_v15.mq5                    |
//|              Professional Unified ICT Trading System             |
//|                         Version 15                               |
//+------------------------------------------------------------------+
#property copyright "ICT Unified Professional EA v15"
#property link      ""
#property version   "15.00"
#property strict
#property description "Fully Integrated ICT Trading System"
#property description "Dealing Range Structure + State Machine Narrative"
#property description "Multi-Timeframe Analysis with State Machine Narrative"

//+------------------------------------------------------------------+
//| Include Files - Ordered by Dependency                             |
//+------------------------------------------------------------------+

// Core Layer (Must be first)
#include <ICT_Unified/Core/ICT_Types.mqh>
#include <ICT_Unified/Core/ICT_Config.mqh>
#include <ICT_Unified/Core/ICT_Globals.mqh>
#include <ICT_Unified/Core/ICT_Utilities.mqh>

// UI Layer (Drawing utilities needed early)
#include <ICT_Unified/UI/ICT_Drawing.mqh>

// Structure Layer
#include <ICT_Unified/Structure/ICT_SwingDetection.mqh>
#include <ICT_Unified/Structure/ICT_DealingRange.mqh>
#include <ICT_Unified/Structure/ICT_MultiTF.mqh>

// Market Phase Layer
#include <ICT_Unified/MarketPhase/ICT_Killzones.mqh>
#include <ICT_Unified/MarketPhase/ICT_AMD.mqh>
#include <ICT_Unified/MarketPhase/ICT_JudasSwing.mqh>
#include <ICT_Unified/MarketPhase/ICT_SMT.mqh>

// Narrative Zone Layer (OB/FVG/OTE)
#include <ICT_Unified/NarrativeZones/ICT_OrderBlocks.mqh>
#include <ICT_Unified/NarrativeZones/ICT_FairValueGaps.mqh>
#include <ICT_Unified/NarrativeZones/ICT_OTE.mqh>
#include <ICT_Unified/NarrativeZones/ICT_NarrativeZones_Master.mqh>

// State Machine
#include <ICT_Unified/StateMachine/ICT_SMTypes.mqh>
#include <ICT_Unified/StateMachine/ICT_SMEngine.mqh>

// ML Layer
#include <ICT_Unified/ML/ICT_MLEngine.mqh>
#include <ICT_Unified/ML/ICT_MLDashboard.mqh>
#include <ICT_Unified/ML/ICT_ShadowTrades.mqh>

// External Provider Layer
#include <ICT_Unified/External/ICT_ExternalProvider.mqh>
#include <ICT_Unified/External/ICT_SignalOrchestrator.mqh>

// Trading Layer
#include <ICT_Unified/Trading/ICT_SignalEngine.mqh>
#include <ICT_Unified/Trading/ICT_TradeManager.mqh>

// Dashboard (Last - needs all other components)
#include <ICT_Unified/UI/ICT_Dashboard.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("===========================================================");
   Print("ICT Unified Professional EA v15 - Initializing...");
   Print("===========================================================");

    Shadow_Init();
    g_perf.InitRolling();

    if(!ValidateInputs())
     {
      Print("Input validation failed");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!InitializeCore())
     {
      Print("Core initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeIndicators())
     {
      Print("Indicator initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeSwingDetection())
     {
      Print("Swing Detection initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeStructureLayer())
     {
      Print("Structure layer initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeMultiTF())
     {
      Print("Multi-TF initialization failed");
      return INIT_FAILED;
     }

// Keep this: SM detectors rely on OB/FVG/OTE data from this layer.
   if(!InitializeNarrativeZones())
     {
      Print("Narrative zone initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeMarketPhase())
     {
      Print("Market Phase initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeKillzones())
      Print("Killzone initialization note");

   if(!InitializeSMT())
      Print("SMT initialization note");

   if(!InitializeSignalEngine())
     {
      Print("Signal Engine initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeSMEngine())
     {
      Print("State Machine initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeTradeManager())
     {
      Print("Trade Manager initialization failed");
      return INIT_FAILED;
     }

   if(!InitializeDashboard())
      Print("Dashboard initialization failed (non-critical)");

   if(!InitializeMLEngine())
      Print("ML Engine initialization note");

   if(!InitializeMLDashboard())
      Print("ML Dashboard initialization note");

   if(!InitializeOrchestrator())
      Print("Orchestrator initialization note");

   EventSetTimer(1);

   Print("===========================================================");
   Print("ICT Unified EA v15 initialized successfully");
   Print("Magic Number: ", InpMagicNumber);
   Print("Symbol: ", _Symbol);
   Print("HTF: ", EnumToString(InpHTF_Timeframe));
   Print("CTF: ", EnumToString((ENUM_TIMEFRAMES)Period()));
   Print("LTF: ", EnumToString(InpLTF_Timeframe));
   Print("===========================================================");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeinitializeIndicators();
   CleanupAllObjects();

   DeinitMLEngine();
   CleanupMLDashboard();
   DeinitOrchestrator();

   EventKillTimer();

   Print("ICT Unified EA v15 deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   g_perf.Reset();
   g_perf.tickStartUs = GetMicrosecondCount();

   if(!UpdateATRBuffer())
      return;

   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);

   if(isNewBar)
   {
      StorePreviousBarData();
      g_lastBarTime = currentBarTime;
   }

   ulong t0 = 0, t1 = 0;

   // LAYER 1: STRUCTURE ANALYSIS (new bar only)
   if(isNewBar)
   {
      t0 = GetMicrosecondCount();

      UpdateDealingRangeSystem();
      UpdateMultiTF();
      DetectProfessionalSwings();

      if(g_needDetectAMD) UpdateMarketPhase(); else g_perf.skippedDetectors++;
      if(g_needDetectJudas) DetectJudasSwings(); else g_perf.skippedDetectors++;
      if(g_needDetectKillzone) UpdateKillzoneStatus(); else g_perf.skippedDetectors++;

      t1 = GetMicrosecondCount();
      g_perf.structUs += (t1 - t0);
   }

   // LAYER 2: NARRATIVE ZONES + SMT (new bar only)
   if(isNewBar)
   {
      t0 = GetMicrosecondCount();

      DetectAllNarrativeZonesLoadedOnly();
      if(g_needDetectSMT) UpdateSMTAnalysis(); else g_perf.skippedDetectors++;

      t1 = GetMicrosecondCount();
      g_perf.narrativeUs += (t1 - t0);
   }

   static bool s_loggedLoadedSetOnTick = false;
   if(!s_loggedLoadedSetOnTick)
   {
      SM_LogLoadedElementSet();
      s_loggedLoadedSetOnTick = true;
   }

   // LAYER 3: STATE MACHINE + EXECUTION (new bar only)
   if(isNewBar)
   {
      t0 = GetMicrosecondCount();

      Shadow_Update();

      if(g_mlInitialized && InpML_Mode != ML_OFF)
      {
         SMLFeatureVector fv = ExtractFeatures();
         g_mlPrediction = PredictOutcome(fv);
      }

      UpdateStateMachine(isNewBar);
      g_forceDashboardUpdate = true;

      if(SM_HasReadyEntry())
         GenerateSMTradeSignal();

      if(g_hasValidSignal && g_currentSignal.isValid && !g_currentSignal.isExecuted)
         ExecuteTrade();

      UpdateProviders();

      t1 = GetMicrosecondCount();
      g_perf.smUs += (t1 - t0);
   }

   // LAYER 4: TRADE MANAGEMENT (every tick)
   t0 = GetMicrosecondCount();
   ManageOpenPositions();
   t1 = GetMicrosecondCount();
   g_perf.tradeUs += (t1 - t0);

   // LAYER 5: DASHBOARD UPDATE
   t0 = GetMicrosecondCount();

   bool dashNeedsUpdate = g_forceDashboardUpdate;
   if(isNewBar)
   {
      int currentPosCount = CountOpenPositions();
      if(currentPosCount != g_lastPositionCount)
      {
         dashNeedsUpdate = true;
         g_lastPositionCount = currentPosCount;
      }
   }

   if(dashNeedsUpdate)
   {
      UpdateDashboard();
      if(g_mlInitialized && InpML_ShowDashboard)
         UpdateMLDashboard();

      g_forceDashboardUpdate = false;
   }

   PeriodicCleanup();

   t1 = GetMicrosecondCount();
   g_perf.dashUs += (t1 - t0);

   // Final telemetry snapshot
   g_perf.totalUs = GetMicrosecondCount() - g_perf.tickStartUs;

   g_perf.loadedFamilies =
      (g_needDetectOB ? 1 : 0) +
      (g_needDetectFVG ? 1 : 0) +
      (g_needDetectOTE ? 1 : 0) +
      (g_needDetectAMD ? 1 : 0) +
      (g_needDetectJudas ? 1 : 0) +
      (g_needDetectSMT ? 1 : 0) +
      (g_needDetectKillzone ? 1 : 0);

    g_perf.skippedFamilies = 7 - g_perf.loadedFamilies;

    // T4 telemetry guardrails
    g_perf.UpdateRolling();
    g_perf.UpdateBottleneck();
    g_perf.warnExceeded = (g_perf.totalUs > (ulong)MathMax(InpSM_PerfWarnThresholdUs, 1));

    if(g_perf.warnExceeded && isNewBar)
    {
       Print("[ICT PERF WARN] totalUs=", (int)g_perf.totalUs,
             " avg50=", (int)g_perf.avgTotalUs,
             " bottleneck=", g_perf.bottleneckText,
             " thresholdUs=", InpSM_PerfWarnThresholdUs);
    }
}
//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
  {
   static datetime lastDashUpdate = 0;

   if(TimeCurrent() - lastDashUpdate >= 5)
     {
      UpdateDashboardRealtime();
      lastDashUpdate = TimeCurrent();
     }

   CheckDailyReset();
  }

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
        {
         UpdateTradeStatistics();
         g_forceDashboardUpdate = true;
        }
     }
  }

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
  {
   HandleChartEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
