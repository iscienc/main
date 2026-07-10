//+------------------------------------------------------------------+
//|                         ICT_Globals.mqh                           |
//|                      Global Variables Storage                      |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_GLOBALS_MQH
#define ICT_GLOBALS_MQH



#include "ICT_Types.mqh"

//+------------------------------------------------------------------+
//|                  SECTION 1: INDICATOR HANDLES                      |
//+------------------------------------------------------------------+

int g_atrHandle = INVALID_HANDLE;
int g_htfAtrHandle = INVALID_HANDLE;
int g_ltfAtrHandle = INVALID_HANDLE;
int g_smtHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//|                  SECTION 2: INDICATOR BUFFERS                      |
//+------------------------------------------------------------------+

double g_atrBuffer[];
double g_htfAtrBuffer[];
double g_ltfAtrBuffer[];
double g_smtBuffer[];

//+------------------------------------------------------------------+
//|                  SECTION 3: TIMING VARIABLES                       |
//+------------------------------------------------------------------+

datetime g_lastBarTime = 0;
datetime g_lastHTFBarTime = 0;
datetime g_lastLTFBarTime = 0;
datetime g_lastAlertTime = 0;
datetime g_lastDayCheck = 0;
datetime g_lastCleanupTime = 0;
datetime g_lastDashboardUpdate = 0;
datetime g_lastStatsUpdate = 0;

//+------------------------------------------------------------------+
//|                  SECTION Telemetry - performance                 |
//+------------------------------------------------------------------+
#define ICT_PERF_WINDOW 50

enum ENUM_PERF_BOTTLENECK
{
   PERF_BOTTLENECK_NONE = 0,
   PERF_BOTTLENECK_STRUCT,
   PERF_BOTTLENECK_NARR,
   PERF_BOTTLENECK_SM,
   PERF_BOTTLENECK_TRADE,
   PERF_BOTTLENECK_DASH
};

struct SPerfTelemetry
{
   ulong tickStartUs;
   ulong structUs;
   ulong narrativeUs;
   ulong smUs;
   ulong tradeUs;
   ulong dashUs;
   ulong totalUs;

   int loadedFamilies;
   int skippedFamilies;
   int skippedDetectors;

   // Rolling averages (last N ticks), optimized with running sums
   ulong rollingStruct[ICT_PERF_WINDOW];
   ulong rollingNarrative[ICT_PERF_WINDOW];
   ulong rollingSm[ICT_PERF_WINDOW];
   ulong rollingTrade[ICT_PERF_WINDOW];
   ulong rollingDash[ICT_PERF_WINDOW];
   ulong rollingTotal[ICT_PERF_WINDOW];

   ulong sumStruct;
   ulong sumNarrative;
   ulong sumSm;
   ulong sumTrade;
   ulong sumDash;
   ulong sumTotal;

   int rollingIdx;
   int rollingCount;

   ulong avgStructUs;
   ulong avgNarrativeUs;
   ulong avgSmUs;
   ulong avgTradeUs;
   ulong avgDashUs;
   ulong avgTotalUs;

   ENUM_PERF_BOTTLENECK bottleneck;
   string bottleneckText;

   bool warnExceeded;

   void Reset()
   {
      tickStartUs = 0;
      structUs = 0;
      narrativeUs = 0;
      smUs = 0;
      tradeUs = 0;
      dashUs = 0;
      totalUs = 0;
      loadedFamilies = 0;
      skippedFamilies = 0;
      skippedDetectors = 0;
      warnExceeded = false;
   }

   void InitRolling()
   {
      for(int i = 0; i < ICT_PERF_WINDOW; i++)
      {
         rollingStruct[i] = 0;
         rollingNarrative[i] = 0;
         rollingSm[i] = 0;
         rollingTrade[i] = 0;
         rollingDash[i] = 0;
         rollingTotal[i] = 0;
      }

      sumStruct = 0;
      sumNarrative = 0;
      sumSm = 0;
      sumTrade = 0;
      sumDash = 0;
      sumTotal = 0;

      rollingIdx = 0;
      rollingCount = 0;

      avgStructUs = 0;
      avgNarrativeUs = 0;
      avgSmUs = 0;
      avgTradeUs = 0;
      avgDashUs = 0;
      avgTotalUs = 0;

      bottleneck = PERF_BOTTLENECK_NONE;
      bottleneckText = "NONE";
      warnExceeded = false;
   }

   void UpdateRolling()
   {
      sumStruct -= rollingStruct[rollingIdx];
      sumNarrative -= rollingNarrative[rollingIdx];
      sumSm -= rollingSm[rollingIdx];
      sumTrade -= rollingTrade[rollingIdx];
      sumDash -= rollingDash[rollingIdx];
      sumTotal -= rollingTotal[rollingIdx];

      rollingStruct[rollingIdx] = structUs;
      rollingNarrative[rollingIdx] = narrativeUs;
      rollingSm[rollingIdx] = smUs;
      rollingTrade[rollingIdx] = tradeUs;
      rollingDash[rollingIdx] = dashUs;
      rollingTotal[rollingIdx] = totalUs;

      sumStruct += structUs;
      sumNarrative += narrativeUs;
      sumSm += smUs;
      sumTrade += tradeUs;
      sumDash += dashUs;
      sumTotal += totalUs;

      if(rollingCount < ICT_PERF_WINDOW)
         rollingCount++;

      rollingIdx++;
      if(rollingIdx >= ICT_PERF_WINDOW)
         rollingIdx = 0;

      if(rollingCount > 0)
      {
         avgStructUs = sumStruct / (ulong)rollingCount;
         avgNarrativeUs = sumNarrative / (ulong)rollingCount;
         avgSmUs = sumSm / (ulong)rollingCount;
         avgTradeUs = sumTrade / (ulong)rollingCount;
         avgDashUs = sumDash / (ulong)rollingCount;
         avgTotalUs = sumTotal / (ulong)rollingCount;
      }
   }

   void UpdateBottleneck()
   {
      bottleneck = PERF_BOTTLENECK_STRUCT;
      bottleneckText = "STRUCT";
      ulong top = structUs;

      if(narrativeUs > top)
      {
         top = narrativeUs;
         bottleneck = PERF_BOTTLENECK_NARR;
         bottleneckText = "NARR";
      }

      if(smUs > top)
      {
         top = smUs;
         bottleneck = PERF_BOTTLENECK_SM;
         bottleneckText = "SM";
      }

      if(tradeUs > top)
      {
         top = tradeUs;
         bottleneck = PERF_BOTTLENECK_TRADE;
         bottleneckText = "TRADE";
      }

      if(dashUs > top)
      {
         bottleneck = PERF_BOTTLENECK_DASH;
         bottleneckText = "DASH";
      }
   }
};

SPerfTelemetry g_perf;

int g_smActiveCausalTag = -1; //added for causal link FIX
//+------------------------------------------------------------------+
//|                  // SM loaded-element runtime registry                            |
//+------------------------------------------------------------------+

bool g_smElemLoaded[128];

// Runtime detection gates derived from loaded SM elements
bool g_needDetectOB = false;
bool g_needDetectFVG = false;
bool g_needDetectOTE = false;
bool g_needDetectAMD = false;
bool g_needDetectJudas = false;
bool g_needDetectSMT = false;
bool g_needDetectKillzone = false;
//+------------------------------------------------------------------+
//|                  SECTION 4: STATE FLAGS                            |
//+------------------------------------------------------------------+

bool g_isInitialized = false;
bool g_drInitialized = false;
bool g_mtfInitialized = false;
bool g_pdArraysInitialized = false;
bool g_scoringInitialized = false;
bool g_dashboardInitialized = false;


bool g_forceDashboardUpdate = false;
bool g_forceRedraw = false;

bool g_tradingEnabled = true;
bool g_dailyLossReached = false;
bool g_maxTradesReached = false;

int g_lastPositionCount = 0;

//+------------------------------------------------------------------+
//|                  SECTION 5: PREVIOUS BAR DATA                      |
//+------------------------------------------------------------------+

double g_prevBarOpen = 0;
double g_prevBarHigh = 0;
double g_prevBarLow = 0;
double g_prevBarClose = 0;
datetime g_prevBarTime = 0;

double g_prevHTFOpen = 0;
double g_prevHTFHigh = 0;
double g_prevHTFLow = 0;
double g_prevHTFClose = 0;

double g_prevLTFOpen = 0;
double g_prevLTFHigh = 0;
double g_prevLTFLow = 0;
double g_prevLTFClose = 0;

//+------------------------------------------------------------------+
//|                  SECTION 6: DIRECTION & TREND                      |
//+------------------------------------------------------------------+
ENUM_TRADE_DIRECTION g_currentDirection = DIR_NONE;
ENUM_TRADE_DIRECTION g_htfDirection = DIR_NONE;
ENUM_TRADE_DIRECTION g_ctfDirection = DIR_NONE;
ENUM_TRADE_DIRECTION g_ltfDirection = DIR_NONE;

bool g_allTFsAligned = false;
bool g_htfCtfAligned = false;

//+------------------------------------------------------------------+
//|                  SECTION 7: DEALING RANGE STRUCTURES               |
//+------------------------------------------------------------------+

// Current Timeframe Dealing Ranges
SDealingRange g_bullDR;
SDealingRange g_bearDR;
bool g_isBullishActive = true;

// Multi-Timeframe Layers
SMTFLayer g_htfLayer;
SMTFLayer g_ctfLayer;
SMTFLayer g_ltfLayer;

// Entry Zone (defined by DR structure)
SEntryZone g_entryZone;

//+------------------------------------------------------------------+
//|                  SECTION 8: SWING POINT ARRAYS                     |
//+------------------------------------------------------------------+

SSwingPoint g_swings[];
int g_swingsCount = 0;
int g_maxSwings = 100;

// Quick access to recent swings
double g_lastExternalHigh = 0;
double g_lastExternalLow = 0;
datetime g_lastExternalHighTime = 0;
datetime g_lastExternalLowTime = 0;

double g_lastInternalHigh = 0;
double g_lastInternalLow = 0;

//+------------------------------------------------------------------+
//|                  SECTION 9: narrative ARRAY STORAGE                       |
//+------------------------------------------------------------------+

// Order Blocks
SOrderBlock g_orderBlocks[];
int g_obCount = 0;
int g_maxOBs = 30;

// Breaker Blocks
SBreakerBlock g_breakerBlocks[];
int g_breakerCount = 0;
int g_maxBreakers = 20;

// Mitigation Blocks
SMitigationBlock g_mitigationBlocks[];
int g_mbCount = 0;
int g_maxMBs = 20;

// Fair Value Gaps
SFairValueGap g_fvgList[];
int g_fvgCount = 0;
int g_maxFVGs = 40;

// Volume Imbalances
SVolumeImbalance g_viList[];
int g_viCount = 0;
int g_maxVIs = 30;

// Liquidity Voids
SLiquidityVoid g_voidList[];
int g_voidCount = 0;
int g_maxVoids = 20;

// Rejection Blocks
SRejectionBlock g_rejectionBlocks[];
int g_rejectionCount = 0;
int g_maxRejections = 20;

// OTE Zone
SOTEZone g_oteZone;



// Liquidity Pools
SLiquidityPool g_liquidityPools[];
int g_lpCount = 0;
int g_maxLPs = 30;

//+------------------------------------------------------------------+
//|                  SECTION 10: MARKET PHASE                          |
//+------------------------------------------------------------------+

SAMDPhase g_amdPhase;
SJudasSwing g_judasSwing;
SSMTDivergence g_smtDivergence;
SKillzoneStatus g_killzone;
SRangeInfo g_rangeInfo;



//+------------------------------------------------------------------+
//|                  SECTION 12: SIGNALS & TRADING                     |
//+------------------------------------------------------------------+

STradeSignal g_currentSignal;
STradeSignal g_pendingSignal;
bool g_hasValidSignal = false;
bool g_waitingForOTE = false;

STradeStats g_stats;
SSignalHistory g_signalHistory[];
int g_signalHistoryCount = 0;
int g_maxSignalHistory = 20;

//+------------------------------------------------------------------+
//|         SECTION 12B: POSITION TRACKING & DR TARGETS (NEW)          |
//+------------------------------------------------------------------+

// Active position tracking for multi-TP management
SPositionTracking g_posTracking;

// DR Target Lines (reclassified from externals after ChoCh)
SDR_TargetLine g_drTargetLines[];
int g_drTargetLineCount = 0;
int g_maxDRTargetLines = 20;

// Trigger context (which PD array triggered the current signal)
int g_triggerNarrativeIndex = -1;
ENUM_NARRATIVE_ZONE_TYPE g_triggerNarrativeType = NZ_NONE;
//+------------------------------------------------------------------+
//|                  SECTION 13: OBJECT MANAGEMENT                     |
//+------------------------------------------------------------------+

string g_prefix = "ICT_U_";
string g_drPrefix = "ICT_DR_";
string g_smObjPrefix = "ICT_SM_";
string g_dashPrefix = "ICT_DASH_";

int g_objCount = 0;
int g_drObjCount = 0;

//+------------------------------------------------------------------+
//|                  SECTION 14: DASHBOARD COLORS                      |
//+------------------------------------------------------------------+

// Theme Colors
color g_bgColor = C'20,20,35';
color g_bgColorLight = C'35,35,55';
color g_bgColorLighter = C'50,50,75';
color g_borderColor = C'60,60,100';
color g_textColor = C'220,220,220';
color g_textColorDim = C'140,140,160';
color g_textColorBright = C'255,255,255';

color g_accentCyan = C'0,220,220';
color g_accentMagenta = C'220,0,180';
color g_accentGold = C'255,200,0';
color g_accentPurple = C'150,100,255';

color g_bullColor = C'0,200,100';
color g_bullColorBright = C'0,255,128';
color g_bullColorDim = C'0,120,60';

color g_bearColor = C'200,50,50';
color g_bearColorBright = C'255,70,70';
color g_bearColorDim = C'120,30,30';

color g_neutralColor = C'128,128,128';
color g_warningColor = C'255,180,0';
color g_dangerColor = C'255,50,50';
color g_successColor = C'50,255,100';

//+------------------------------------------------------------------+
//|                  SECTION 15: DASHBOARD DIMENSIONS                  |
//+------------------------------------------------------------------+

int g_dashWidth = 340;
int g_dashMainHeight = 320;
int g_dashScoreHeight = 180;
int g_dashNarrativeHeight = 160;
int g_dashLevelsHeight = 280;
int g_dashSignalHeight = 120;
int g_dashStatsHeight = 100;
int g_dashPadding = 10;
int g_dashRowHeight = 18;
int g_dashSMHeight = 120;      // NEW: SM panel height

//+------------------------------------------------------------------+
//|                  SECTION 16: COUNTERS & STATISTICS                 |
//+------------------------------------------------------------------+

int g_structureShiftCount = 0;
int g_sweepCount = 0;
int g_bosCount = 0;
int g_chochCount = 0;

//+------------------------------------------------------------------+
//|                  SECTION 17: TEMPORARY WORKING ARRAYS              |
//+------------------------------------------------------------------+

// Used for calculations
double g_tempPrices[];
datetime g_tempTimes[];
int g_tempIndices[];

//+------------------------------------------------------------------+
//|              SECTION 18: INITIALIZATION FUNCTIONS                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize All Global Arrays                                      |
//+------------------------------------------------------------------+
void InitializeGlobalArrays()
  {
// Swing Points
   ArrayResize(g_swings, g_maxSwings);
   ArraySetAsSeries(g_swings, false);
   g_swingsCount = 0;

// Order Blocks
   ArrayResize(g_orderBlocks, g_maxOBs);
   g_obCount = 0;

// Breaker Blocks
   ArrayResize(g_breakerBlocks, g_maxBreakers);
   g_breakerCount = 0;

// Mitigation Blocks
   ArrayResize(g_mitigationBlocks, g_maxMBs);
   g_mbCount = 0;

// FVGs
   ArrayResize(g_fvgList, g_maxFVGs);
   g_fvgCount = 0;

// Volume Imbalances
   ArrayResize(g_viList, g_maxVIs);
   g_viCount = 0;

// Liquidity Voids
   ArrayResize(g_voidList, g_maxVoids);
   g_voidCount = 0;

// Rejection Blocks
   ArrayResize(g_rejectionBlocks, g_maxRejections);
   g_rejectionCount = 0;


// Liquidity Pools
   ArrayResize(g_liquidityPools, g_maxLPs);
   g_lpCount = 0;

// Signal History
   ArrayResize(g_signalHistory, g_maxSignalHistory);
   g_signalHistoryCount = 0;

// ATR Buffers
   ArraySetAsSeries(g_atrBuffer, true);
   ArraySetAsSeries(g_htfAtrBuffer, true);
   ArraySetAsSeries(g_ltfAtrBuffer, true);

// Temp Arrays
   ArrayResize(g_tempPrices, 100);
   ArrayResize(g_tempTimes, 100);
   ArrayResize(g_tempIndices, 100);

// DR Target Lines
   ArrayResize(g_drTargetLines, g_maxDRTargetLines);
   g_drTargetLineCount = 0;

// Position tracking
   g_posTracking.Reset();

   g_mlAdaptive.Reset();
   g_mlDiag.Reset();
   g_mlClosedTradeCount = 0;

// State Machine or in ResetAllGlobals()//
// State Machine
   for(int i = 0; i < SM_MAX_STAGES; i++)
      g_smStageCfg[i].Reset();
   for(int i = 0; i < SM_MAX_INSTANCES; i++)
      g_smInstances[i].Reset();
   g_smInstanceCount = 0;
   g_smNextInstanceId = 1;
   g_smBarCounter = 0;           // NEW
   g_lastSMEvent.Reset();
   g_nextSMCausalTag = 1;
   g_smActiveEntryInstance = -1;

  }

//+------------------------------------------------------------------+
//| Reset Dealing Range Structures                                    |
//+------------------------------------------------------------------+
void ResetDealingRanges()
  {
   g_bullDR.Reset();
   g_bearDR.Reset();
   g_htfLayer.Reset();
   g_ctfLayer.Reset();
   g_ltfLayer.Reset();
   g_entryZone.Reset();
   g_isBullishActive = true;
  }

//+------------------------------------------------------------------+
//| Reset All narrative Arrays                                               |
//+------------------------------------------------------------------+
void ResetAllNarrativeArrays()
  {
// Reset Order Blocks
   for(int i = 0; i < g_obCount; i++)
      g_orderBlocks[i].Reset();
   g_obCount = 0;

// Reset Breaker Blocks
   for(int i = 0; i < g_breakerCount; i++)
      g_breakerBlocks[i].Reset();
   g_breakerCount = 0;

// Reset Mitigation Blocks
   for(int i = 0; i < g_mbCount; i++)
      g_mitigationBlocks[i].Reset();
   g_mbCount = 0;

// Reset FVGs
   for(int i = 0; i < g_fvgCount; i++)
      g_fvgList[i].Reset();
   g_fvgCount = 0;

// Reset Volume Imbalances
   for(int i = 0; i < g_viCount; i++)
      g_viList[i].Reset();
   g_viCount = 0;

// Reset Liquidity Voids
   for(int i = 0; i < g_voidCount; i++)
      g_voidList[i].Reset();
   g_voidCount = 0;

// Reset OTE
   g_oteZone.Reset();
  }

//+------------------------------------------------------------------+
//| Reset Market Phase Data                                           |
//+------------------------------------------------------------------+
void ResetMarketPhase()
  {
   g_amdPhase.Reset();
   g_judasSwing.Reset();
   g_smtDivergence.Reset();
   g_killzone.Reset();
   g_rangeInfo.Reset();
  }



//+------------------------------------------------------------------+
//| Reset Signals                                                     |
//+------------------------------------------------------------------+
void ResetSignals()
  {
   g_currentSignal.Reset();
   g_pendingSignal.Reset();
   g_hasValidSignal = false;
   g_waitingForOTE = false;


   g_triggerNarrativeType = NZ_NONE;
   g_triggerNarrativeIndex = -1;
  }

//+------------------------------------------------------------------+
//| Reset Statistics                                                  |
//+------------------------------------------------------------------+
void ResetStatistics()
  {
   g_stats.Reset();
   g_structureShiftCount = 0;
   g_sweepCount = 0;
   g_bosCount = 0;
   g_chochCount = 0;
  }

//+------------------------------------------------------------------+
//| Full Global Reset                                                 |
//+------------------------------------------------------------------+
void ResetAllGlobals()
  {
   InitializeGlobalArrays();
   ResetDealingRanges();
   ResetAllNarrativeArrays();
   ResetMarketPhase();
   ResetSignals();
   ResetStatistics();
   
   g_smActiveCausalTag = -1; //added for causal link fix

   g_currentDirection = DIR_NONE;
   g_htfDirection = DIR_NONE;
   g_ctfDirection = DIR_NONE;
   g_ltfDirection = DIR_NONE;

   g_allTFsAligned = false;
   g_htfCtfAligned = false;

   g_tradingEnabled = true;
   g_dailyLossReached = false;
   g_maxTradesReached = false;

   g_lastBarTime = 0;
   g_lastHTFBarTime = 0;
   g_lastLTFBarTime = 0;

   ArrayInitialize(g_smElemLoaded, false);

   g_needDetectOB = false;
   g_needDetectFVG = false;
   g_needDetectOTE = false;
   g_needDetectAMD = false;
   g_needDetectJudas = false;
   g_needDetectSMT = false;
   g_needDetectKillzone = false;
  }

//+------------------------------------------------------------------+
//| Store Previous Bar Data (CTF)                                     |
//+------------------------------------------------------------------+
void StorePreviousBarData()
  {
   g_prevBarOpen = iOpen(_Symbol, PERIOD_CURRENT, 1);
   g_prevBarHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   g_prevBarLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   g_prevBarClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   g_prevBarTime = iTime(_Symbol, PERIOD_CURRENT, 1);
  }

//+------------------------------------------------------------------+
//| Store Previous Bar Data (HTF)                                     |
//+------------------------------------------------------------------+
void StorePreviousBarDataHTF()
  {
   g_prevHTFOpen = iOpen(_Symbol, InpHTF_Timeframe, 1);
   g_prevHTFHigh = iHigh(_Symbol, InpHTF_Timeframe, 1);
   g_prevHTFLow = iLow(_Symbol, InpHTF_Timeframe, 1);
   g_prevHTFClose = iClose(_Symbol, InpHTF_Timeframe, 1);
  }

//+------------------------------------------------------------------+
//| Store Previous Bar Data (LTF)                                     |
//+------------------------------------------------------------------+
void StorePreviousBarDataLTF()
  {
   g_prevLTFOpen = iOpen(_Symbol, InpLTF_Timeframe, 1);
   g_prevLTFHigh = iHigh(_Symbol, InpLTF_Timeframe, 1);
   g_prevLTFLow = iLow(_Symbol, InpLTF_Timeframe, 1);
   g_prevLTFClose = iClose(_Symbol, InpLTF_Timeframe, 1);
  }

//+------------------------------------------------------------------+
//| Get Current ATR Value                                             |
//+------------------------------------------------------------------+
double GetATR(int index = 0)
  {
   if(ArraySize(g_atrBuffer) > index)
      return g_atrBuffer[index];
   return 0;
  }
//+------------------------------------------------------------------+
//| Get  ATR Safe for first start                                            |
//+------------------------------------------------------------------+
double GetATRSafe()
  {
   double atr = GetATR();
   if(atr > 0)
      return atr;

// Fallback: manual calculation from recent bars
   double totalRange = 0;
   int count = 0;
   int available = iBars(_Symbol, PERIOD_CURRENT);
   int bars = MathMin(14, available - 1);

   for(int i = 1; i <= bars; i++)
     {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      if(h > 0 && l > 0 && h > l)
        {
         totalRange += (h - l);
         count++;
        }
     }

   if(count > 0)
      return totalRange / count;

// Absolute minimum fallback
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price > 0)
      return price * 0.001; // 0.1% of price

   return _Point * 100;
  }
//+------------------------------------------------------------------+
//| Get HTF ATR Value                                                 |
//+------------------------------------------------------------------+
double GetHTFATR(int index = 0)
  {
   if(ArraySize(g_htfAtrBuffer) > index)
      return g_htfAtrBuffer[index];
   return GetATR(index);
  }

//+------------------------------------------------------------------+
//| Get LTF ATR Value                                                 |
//+------------------------------------------------------------------+
double GetLTFATR(int index = 0)
  {
   if(ArraySize(g_ltfAtrBuffer) > index)
      return g_ltfAtrBuffer[index];
   return GetATR(index);
  }

//+------------------------------------------------------------------+
//| Update ATR Buffer                                                 |
//+------------------------------------------------------------------+
bool UpdateATRBuffer()
  {
   if(g_atrHandle == INVALID_HANDLE)
      return false;

   if(CopyBuffer(g_atrHandle, 0, 0, 10, g_atrBuffer) <= 0)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Update HTF ATR Buffer                                             |
//+------------------------------------------------------------------+
bool UpdateHTFATRBuffer()
  {
   if(g_htfAtrHandle == INVALID_HANDLE)
      return false;

   if(CopyBuffer(g_htfAtrHandle, 0, 0, 10, g_htfAtrBuffer) <= 0)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Update LTF ATR Buffer                                             |
//+------------------------------------------------------------------+
bool UpdateLTFATRBuffer()
  {
   if(g_ltfAtrHandle == INVALID_HANDLE)
      return false;

   if(CopyBuffer(g_ltfAtrHandle, 0, 0, 10, g_ltfAtrBuffer) <= 0)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Get Active Dealing Range                                          |
//+------------------------------------------------------------------+
SDealingRange* GetActiveDR()
  {
   if(g_isBullishActive)
      return GetPointer(g_bullDR);
   else
      return GetPointer(g_bearDR);
  }

//+------------------------------------------------------------------+
//| Get Direction String                                              |
//+------------------------------------------------------------------+
string DirectionToString(ENUM_TRADE_DIRECTION dir)
  {
   switch(dir)
     {
      case DIR_BULLISH:
         return "BULLISH";
      case DIR_BEARISH:
         return "BEARISH";
      default:
         return "NONE";
     }
  }

//+------------------------------------------------------------------+
//| Direction to Color                                                |
//+------------------------------------------------------------------+
color DirectionToColor(ENUM_TRADE_DIRECTION dir)
  {
   switch(dir)
     {
      case DIR_BULLISH:
         return g_bullColor;
      case DIR_BEARISH:
         return g_bearColor;
      default:
         return g_neutralColor;
     }
  }


//+------------------------------------------------------------------+
//|                  SECTION 19: ML ENGINE GLOBALS                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|         SECTION 19: ML ENGINE GLOBALS (ENHANCED)                   |
//+------------------------------------------------------------------+

ENUM_ML_STATUS g_mlStatus = ML_STATUS_OFF;
SMLWeights     g_mlWeights;
SMLPrediction  g_mlPrediction;
SMLStats       g_mlStats;
SMLAdaptiveStats g_mlAdaptive;   // NEW
SMLDiagnostic  g_mlDiag;         // NEW
bool           g_mlInitialized = false;
bool           g_mlDashboardInitialized = false;
string         g_mlDashPrefix = "ICT_ML_";
int            g_mlDashWidth = 300;

SMLTrainingSample g_mlSamples[];
int               g_mlSampleCount = 0;
int               g_mlSampleWriteIdx = 0;

SMLPredictionHistory g_mlPredHistory[];
int                  g_mlPredHistCount = 0;
int                  g_mlPredHistWriteIdx = 0;

double g_mlFeatureMean[ML_FEATURE_COUNT];
double g_mlFeatureStd[ML_FEATURE_COUNT];
bool   g_mlStatsComputed = false;
int    g_mlClosedTradeCount = 0;    // NEW: actual closed trades with outcomes

//+------------------------------------------------------------------+
//|                  SECTION 20: EXTERNAL PROVIDER GLOBALS              |
//+------------------------------------------------------------------+

SProviderInfo    g_providers[MAX_PROVIDERS];
SEnsembleResult  g_ensembleResult;
bool             g_providersInitialized = false;
bool             g_orchestratorInitialized = false;
int              g_activeProviderCount = 0;




//+------------------------------------------------------------------+
//|         SECTION 21: STATE MACHINE GLOBALS                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|         SECTION 21: STATE MACHINE GLOBALS                          |
//+------------------------------------------------------------------+

SSMStageConfig g_smStageCfg[SM_MAX_STAGES];
SSMInstance     g_smInstances[SM_MAX_INSTANCES];
int            g_smInstanceCount    = 0;
int            g_smNextInstanceId   = 1;
int            g_smBarCounter       = 0;       // NEW: monotonic bar counter

SSMStructuralEvent g_lastSMEvent;
int                g_nextSMCausalTag = 1;

int                g_smActiveEntryInstance = -1;

//+------------------------------------------------------------------+
//| Register Structural Event (called by DR/MultiTF before SM init)  |
//+------------------------------------------------------------------+
void SM_RegisterStructuralEvent(double price, ENUM_TRADE_DIRECTION dir,
                                int barIndex, ENUM_TF_LAYER tfLayer)
  {
   g_lastSMEvent.Reset();
   g_lastSMEvent.time       = iTime(_Symbol, PERIOD_CURRENT, barIndex);
   g_lastSMEvent.price      = price;
   g_lastSMEvent.direction  = dir;
   g_lastSMEvent.barIndex   = barIndex;
   g_lastSMEvent.tag        = g_nextSMCausalTag++;
   g_lastSMEvent.barCounter = g_smBarCounter;
   g_lastSMEvent.tfLayer    = tfLayer;
   g_lastSMEvent.valid      = true;
  }


#endif // ICT_GLOBALS_MQH
//+------------------------------------------------------------------+
