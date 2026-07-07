//+------------------------------------------------------------------+
//|                        ICT_Unified_EA_v8.mq5                      |
//|              Professional Unified ICT Trading System              |
//|                         Version 8.0                               |
//+------------------------------------------------------------------+
#property copyright "ICT Unified Professional EA v8.0"
#property link      ""
#property version   "8.00"
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

// PD Array Layer
#include <ICT_Unified/PDArrays/ICT_OrderBlocks.mqh>
#include <ICT_Unified/PDArrays/ICT_FairValueGaps.mqh>
#include <ICT_Unified/PDArrays/ICT_OTE.mqh>
#include <ICT_Unified/PDArrays/ICT_PDStacking.mqh>
#include <ICT_Unified/PDArrays/ICT_PDArrays_Master.mqh>

// SM_State Machine
#include <ICT_Unified/StateMachine/ICT_SMTypes.mqh>
#include <ICT_Unified/StateMachine/ICT_SMEngine.mqh>

// Scoring Layer
//Removed

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
   Print("═══════════════════════════════════════════════════════════");
   Print("  ICT Unified Professional EA v8.0 - Initializing...");
   Print("═══════════════════════════════════════════════════════════");
Shadow_Init();
// Validate inputs
   if(!ValidateInputs())
     {
      Print("❌ Input validation failed!");
      return INIT_PARAMETERS_INCORRECT;
     }

// Initialize Core Systems
   if(!InitializeCore())
     {
      Print("❌ Core initialization failed!");
      return INIT_FAILED;
     }

// Initialize Indicators
   if(!InitializeIndicators())
     {
      Print("❌ Indicator initialization failed!");
      return INIT_FAILED;
     }
   if(!InitializeSwingDetection())
     {
      Print("❌ Swing Detection initialization failed!");
      return INIT_FAILED;
     }
// Initialize Structure Layer (Dealing Range)
   if(!InitializeStructureLayer())
     {
      Print("❌ Structure layer initialization failed!");
      return INIT_FAILED;
     }
   if(!InitializeMultiTF())
     {
      Print("❌ Multi-TF initialization failed!");
      return INIT_FAILED;
     }
// Initialize PD Array Detection
   if(!InitializePDArrays())
     {
      Print("❌ PD Array initialization failed!");
      return INIT_FAILED;
     }

// Initialize Market Phase Detection
   if(!InitializeMarketPhase())
     {
      Print("❌ Market Phase initialization failed!");
      return INIT_FAILED;
     }
   if(!InitializeKillzones())
     {
      Print("⚠️ Killzone initialization note");
     }

   if(!InitializeSMT())
     {
      Print("⚠️ SMT initialization note");
     }
   if(!InitializeSignalEngine())
     {
      Print("❌ Signal Engine initialization failed!");
      return INIT_FAILED;
     }
      if(!InitializeSMEngine())
        {
         Print("❌ State Machine initialization failed!");
         return INIT_FAILED;
        }

   if(!InitializeTradeManager())
     {
      Print("❌ Trade Manager initialization failed!");
      return INIT_FAILED;
     }
// Initialize Dashboard
   if(!InitializeDashboard())
     {
      Print("⚠️ Dashboard initialization failed (non-critical)");
     }
// Initialize ML Engine
   if(!InitializeMLEngine())
      Print("⚠️ ML Engine initialization note");

   if(!InitializeMLDashboard())
      Print("⚠️ ML Dashboard initialization note");

// Initialize External Providers

   if(!InitializeOrchestrator())
      Print("⚠️ Orchestrator initialization note");
// Set timer for periodic updates
   EventSetTimer(1);

   Print("═══════════════════════════════════════════════════════════");
   Print("  ✅ ICT Unified EA v8                                                                                                                                                                                                            .0 Initialized Successfully!");
   Print("  Magic Number: ", InpMagicNumber);
   Print("  Symbol: ", _Symbol);
   Print("  HTF: ", EnumToString(InpHTF_Timeframe));
   Print("  CTF: ", EnumToString((ENUM_TIMEFRAMES)Period()));
   Print("  LTF: ", EnumToString(InpLTF_Timeframe));
   Print("═══════════════════════════════════════════════════════════");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Release indicators
   DeinitializeIndicators();

// Cleanup chart objects
   CleanupAllObjects();

   DeinitMLEngine();
   CleanupMLDashboard();
   DeinitOrchestrator();


// Kill timer
   EventKillTimer();

   Print("ICT Unified EA v8.0 deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!UpdateATRBuffer()) return;

   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);

   if(isNewBar)
   {
      StorePreviousBarData();
      g_lastBarTime = currentBarTime;
   }

   //=== LAYER 1: STRUCTURE ANALYSIS (New Bar Only) ===
   if(isNewBar)
   {
      UpdateDealingRangeSystem();
      UpdateMultiTF();
      DetectProfessionalSwings();
      UpdateMarketPhase();
      DetectJudasSwings();
      UpdateKillzoneStatus();
      
   }

   //=== LAYER 2: PD ARRAY DETECTION (New Bar Only) ===
   if(isNewBar)
   {
      DetectAllPDArrays();
      UpdateSMTAnalysis();
      
   }

   //=== LAYER 3: Removed SCORING & SIGNAL GENERATION (New Bar Only) ===
if(isNewBar)
{
Shadow_Update();
   // ML prediction BEFORE signal processing
   if(g_mlInitialized && InpML_Mode != ML_OFF)
   {
      SMLFeatureVector fv = ExtractFeatures();
      g_mlPrediction = PredictOutcome(fv);
   }

   // Single engine: State Machine only
   UpdateStateMachine(isNewBar);
   g_forceDashboardUpdate = true;
   if(SM_HasReadyEntry())
      GenerateSMTradeSignal();

   // Execute trade if valid
   if(g_hasValidSignal && g_currentSignal.isValid && !g_currentSignal.isExecuted)
      ExecuteTrade();


   UpdateProviders();
}

   //=== LAYER 4: TRADE MANAGEMENT (Every Tick) ===
   ManageOpenPositions();

   //=== LAYER 5: DASHBOARD UPDATE ===
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
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
  {
// Update dashboard every second if needed
   static datetime lastDashUpdate = 0;
   if(TimeCurrent() - lastDashUpdate >= 5)  // Every 5 seconds instead of 2
     {
      UpdateDashboardRealtime();
      lastDashUpdate = TimeCurrent();
     }

// Check daily reset
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
// Handle dashboard button clicks, etc.
   HandleChartEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
