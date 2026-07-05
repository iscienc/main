export interface Section {
  id: string;
  title: string;
  icon: string;
  color: string;
  subsections: Subsection[];
}

export interface Subsection {
  id: string;
  title: string;
  content: ContentBlock[];
}

export interface ContentBlock {
  type: 'text' | 'code' | 'table' | 'callout' | 'badge-list' | 'param-table';
  text?: string;
  language?: string;
  code?: string;
  calloutType?: 'info' | 'warning' | 'success' | 'tip';
  headers?: string[];
  rows?: string[][];
  items?: { label: string; color: string; desc: string }[];
}

export const knowledgeSections: Section[] = [
  // ─────────────────────────────────────────────────────
  // 1. PROJECT OVERVIEW
  // ─────────────────────────────────────────────────────
  {
    id: 'overview',
    title: 'Project Overview',
    icon: '🗺️',
    color: 'indigo',
    subsections: [
      {
        id: 'overview-intro',
        title: 'What Is This EA?',
        content: [
          {
            type: 'text',
            text: `**ICT_Unified_EA_v05** (codename *V7_DR_PULLBACK*) is a fully-featured MQL5 Expert Advisor that implements the complete ICT (Inner Circle Trader) methodology inside MetaTrader 5. It combines multi-timeframe structural analysis, a configurable state-machine entry engine, premium/discount PD-array detection, ML-assisted scoring, and a real-time dashboard — all in a single deployable EA.`
          },
          {
            type: 'callout',
            calloutType: 'info',
            text: `**Design Philosophy:** Every ICT concept (Dealing Ranges, Order Blocks, FVGs, OTE, AMD, Judas Swing, SMT, Killzones) is implemented as a standalone header (.mqh) with a clean interface, then orchestrated by the central state-machine engine and signal pipeline.`
          }
        ]
      },
      {
        id: 'overview-structure',
        title: 'File & Module Structure',
        content: [
          {
            type: 'code',
            language: 'text',
            code: `V7_DR_PULLBACK/
├── ICT_Unified_EA_v05.mq5          ← Main EA entry point (OnInit/OnTick/OnDeinit)
├── Indicator/
│   └── ICT_SampleProvider.mq5      ← External signal indicator
└── Include/
    └── ICT_Unified/
        ├── Core/                   ← Foundation layer
        │   ├── ICT_Config.mqh      ← All input parameters (200+ settings)
        │   ├── ICT_Types.mqh       ← Enums, structs, type definitions
        │   ├── ICT_Globals.mqh     ← Global variable declarations
        │   └── ICT_Utilities.mqh   ← Helper/utility functions
        ├── Structure/              ← Market structure detection
        │   ├── ICT_DealingRange.mqh
        │   ├── ICT_MultiTF.mqh
        │   └── ICT_SwingDetection.mqh
        ├── MarketPhase/            ← Session & phase analysis
        │   ├── ICT_AMD.mqh
        │   ├── ICT_JudasSwing.mqh
        │   ├── ICT_Killzones.mqh
        │   └── ICT_SMT.mqh
        ├── PDArrays/               ← Price delivery arrays
        │   ├── ICT_FairValueGaps.mqh
        │   ├── ICT_OrderBlocks.mqh
        │   ├── ICT_OTE.mqh
        │   ├── ICT_PDArrays_Master.mqh
        │   └── ICT_PDStacking.mqh
        ├── StateMachine/           ← Entry sequencing engine
        │   ├── ICT_SMEngine.mqh
        │   ├── ICT_SMDetectors.mqh
        │   ├── ICT_SMPresets.mqh
        │   ├── ICT_SMTypes.mqh
        │   └── ICT_NarrativeGate.mqh
        ├── Trading/                ← Order management
        │   ├── ICT_SignalEngine.mqh
        │   └── ICT_TradeManager.mqh
        ├── ML/                     ← Machine learning scoring
        │   ├── ICT_MLEngine.mqh
        │   └── ICT_MLDashboard.mqh
        ├── UI/                     ← On-chart visuals
        │   ├── ICT_Dashboard.mqh
        │   └── ICT_Drawing.mqh
        └── External/               ← External signal bridging
            ├── ICT_EAStatePublisher.mqh
            ├── ICT_ExternalProvider.mqh
            └── ICT_SignalOrchestrator.mqh`
          },
          {
            type: 'callout',
            calloutType: 'tip',
            text: `**Include Guards:** Every .mqh file uses \`#ifndef / #define / #endif\` guards, so the full codebase can be safely merged into a single compilation unit — which is exactly what the EA does.`
          }
        ]
      },
      {
        id: 'overview-flow',
        title: 'Execution Flow (OnTick)',
        content: [
          {
            type: 'code',
            language: 'cpp',
            code: `// Simplified OnTick execution order
void OnTick() {
    // 1. Pre-flight checks
    if(!IsNewBar()) return;           // bar-level processing
    CheckDailyReset();                // reset daily counters

    // 2. Market data refresh
    UpdateATR();                      // ATR for all TF layers
    UpdateMultiTF();                  // HTF / LTF bar data

    // 3. Structure analysis
    UpdateSwingDetection();           // external & internal swings
    UpdateDealingRange();             // DR origin, CL, inducements
    UpdatePullbackStructure();        // internal DR pullback levels

    // 4. Market phase
    UpdateKillzones();                // session detection
    UpdateMarketPhase();              // AMD phase
    UpdateJudasSwing();               // Judas/manipulation sweep
    UpdateSMT();                      // SMT divergence check

    // 5. PD Arrays
    UpdatePDArraysMaster();           // OBs, FVGs, OTE, stacking

    // 6. State Machine
    UpdateSMEngine();                 // advance all active SM instances
    CheckNarrativeGate();             // bias / narrative filter

    // 7. Signal & trading
    ProcessSignals();                 // evaluate entry conditions
    ManageTrades();                   // SL/TP/trailing for open trades

    // 8. UI refresh
    UpdateDashboard();                // on-chart info panel
    RedrawObjects();                  // structure & PD array drawings
}`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 2. CORE LAYER
  // ─────────────────────────────────────────────────────
  {
    id: 'core',
    title: 'Core Layer',
    icon: '⚙️',
    color: 'slate',
    subsections: [
      {
        id: 'core-types',
        title: 'ICT_Types.mqh — Key Enumerations & Structs',
        content: [
          {
            type: 'text',
            text: `All shared data types are defined here. Everything from swing points to state-machine stages lives in this file. Below are the most important types:`
          },
          {
            type: 'table',
            headers: ['Enum / Struct', 'Purpose', 'Key Values'],
            rows: [
              ['ENUM_DIRECTION', 'Bullish/bearish bias', 'DIR_NONE, DIR_BULLISH, DIR_BEARISH'],
              ['ENUM_AMD_PHASE', 'AMD market phase', 'AMD_ACCUMULATION, AMD_MANIPULATION, AMD_DISTRIBUTION, AMD_UNKNOWN'],
              ['ENUM_KILLZONE', 'Session / killzone', 'KZ_ASIAN, KZ_LONDON_OPEN, KZ_NY_OPEN, KZ_LONDON_NY_OVERLAP, KZ_OFF_HOURS…'],
              ['ENUM_SWEEP_METHOD', 'How sweep is confirmed', 'SWEEP_WICK_ONLY, SWEEP_WICK_CLOSE_BACK, SWEEP_BODY_CLOSE'],
              ['ENUM_BREAK_METHOD', 'How structure break is confirmed', 'BREAK_ANY_TOUCH, BREAK_CANDLE_CLOSE, BREAK_BODY_CLOSE'],
              ['ENUM_SM_ELEMENT', 'State-machine trigger element', '20+ elements: SM_ELEM_CHOCH_BREAK, SM_ELEM_BOS, SM_ELEM_FVG, SM_ELEM_ORDER_BLOCK, SM_ELEM_EXT_SWEEP…'],
              ['ENUM_SM_PRESET', 'Pre-built SM recipe', 'SM_PRESET_CHOCH_RETRACE, SM_PRESET_BOS_ENTRY, SM_PRESET_JUDAS_REVERSAL…'],
              ['ENUM_TF_LAYER', 'Timeframe layer tag', 'LAYER_HTF, LAYER_CTF, LAYER_LTF'],
              ['ENUM_PD_ARRAY_TYPE', 'PD array category', 'PD_ORDER_BLOCK, PD_BREAKER_BLOCK, PD_FVG, PD_OTE_ZONE, PD_MITIGATION_BLOCK'],
              ['ENUM_LOT_MODE', 'Position sizing method', 'LOT_FIXED, LOT_RISK_PERCENT, LOT_BALANCE_PERCENT'],
              ['ENUM_SL_MODE', 'Stop-loss placement', 'SL_FIXED, SL_STRUCTURE, SL_ATR_MULTIPLE'],
              ['SDealingRange', 'Full DR state struct', 'origin, corrLine, inducementLevels[], pdArrays[], pullbackStructure'],
              ['SSMInstance', 'Running SM instance', 'currentStage, direction, stageResults[], entryPrice, timeout'],
              ['SSwingPoint', 'A detected swing high/low', 'price, time, type (external/internal), status (active/swept/broken)'],
              ['SPDArray', 'A PD array zone', 'type, top, bottom, isBullish, isActive, testCount, tfLayer'],
            ]
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// Core swing point struct
struct SSwingPoint {
    double   price;
    datetime time;
    bool     isHigh;
    bool     isExternal;       // external vs internal swing
    ENUM_SWING_STATUS status;  // SWING_ACTIVE, SWING_SWEPT, SWING_BROKEN
    int      pivotScore;       // confluence score
    bool     isIDMT;           // inducement level flag
};

// State-machine stage configuration
struct SSMStageCfg {
    ENUM_SM_ELEMENT  primaryElem;
    ENUM_SM_ELEMENT  secondaryElem;
    ENUM_TF_LAYER    primaryTF;
    ENUM_TF_LAYER    secondaryTF;
    ENUM_SM_LOGIC    logic;        // SM_LOGIC_AND / SM_LOGIC_OR
    bool             causal;       // must follow previous stage
    bool             required;     // required for entry
    int              timeout;      // bars until stage expires
    ENUM_SM_DIRECTION_POLICY dirPolicy;
};`
          }
        ]
      },
      {
        id: 'core-globals',
        title: 'ICT_Globals.mqh — Global State Variables',
        content: [
          {
            type: 'text',
            text: `All module state is stored in global variables declared here. The modules read/write these variables directly — no hidden static state outside this file.`
          },
          {
            type: 'table',
            headers: ['Variable', 'Type', 'Purpose'],
            rows: [
              ['g_bullDR / g_bearDR', 'SDealingRange', 'Active bullish and bearish dealing range structures'],
              ['g_isBullishActive', 'bool', 'Which DR side is currently dominant'],
              ['g_swings[]', 'SSwingPoint[]', 'All detected swing highs/lows (external + internal)'],
              ['g_swingsCount', 'int', 'Active count in g_swings[]'],
              ['g_lastExternalHigh / Low', 'double', 'Most recent confirmed external swing prices'],
              ['g_amdPhase', 'SAMDPhase', 'Current AMD phase, confidence, expected direction'],
              ['g_judasSwing', 'SJudasSwing', 'Judas swing detection result'],
              ['g_killzone', 'SKillzone', 'Current session/killzone state'],
              ['g_smtResult', 'SSMTResult', 'SMT divergence signal'],
              ['g_pdArrays[]', 'SPDArray[]', 'All active PD arrays (OBs, FVGs, OTE, etc.)'],
              ['g_smInstances[]', 'SSMInstance[]', 'Running state-machine instances'],
              ['g_currentDirection', 'ENUM_DIRECTION', 'Current overall market bias'],
              ['g_atrBuffer[]', 'double[]', 'CTF ATR buffer (50-period)'],
              ['g_htfAtrBuffer[]', 'double[]', 'HTF ATR buffer'],
              ['g_ltfAtrBuffer[]', 'double[]', 'LTF ATR buffer'],
              ['g_stats', 'STradeStats', 'Daily/all-time P&L, trade counts, win rate'],
              ['g_prefix / g_drPrefix / g_pdPrefix', 'string', 'Chart object name prefixes per module'],
            ]
          }
        ]
      },
      {
        id: 'core-utilities',
        title: 'ICT_Utilities.mqh — Helper Functions',
        content: [
          {
            type: 'text',
            text: `ICT_Utilities is the largest "core" file, providing ~14 sections of helper logic shared across all modules.`
          },
          {
            type: 'table',
            headers: ['Section', 'Key Functions'],
            rows: [
              ['1. Initialization', 'ValidateInputs(), InitializeIndicators(), DeinitializeIndicators()'],
              ['2. Price Data', 'TF_Open/High/Low/Close/Time/Bars(), BodyTop/Bottom(), BodySize(), CandleRange(), UpperWick/LowerWick()'],
              ['3. Pivot Detection', 'IsPivotHigh(), IsPivotLow(), GetPivotScore()'],
              ['4. Sweep / Break', 'CheckSweep(tf, level, sweepBelow), CheckBreak(tf, level, breakAbove), CheckPriceNearLevel(), HasPulledBackFromExtreme()'],
              ['5. Crossovers', 'Crossover(), Crossunder()'],
              ['6. Zone Overlap', 'ZonesOverlap(), CalculateZoneOverlap(), IsPriceInZone(), GetZoneType()'],
              ['7. Trade Timing', 'GetCurrentHour(), GetDayOfWeek(), IsTradingDay(), CheckDailyReset()'],
              ['8. Filters', 'CheckSpreadFilter(), CheckMaxTradesFilter(), CheckMaxLossFilter(), CheckAllFilters()'],
              ['9. Object Mgmt', 'DeleteObject(), CleanupObjectsWithPrefix(), CleanupAllObjects(), PeriodicCleanup()'],
              ['10. Colors', 'ColorDarken(), ColorLighten(), ColorBlend()'],
              ['11. String / Enum', 'AMDPhaseToString(), KillzoneToString(), TriggerToString(), TFToString()'],
              ['12. Alerts', 'SendAlert(message, isSignal, isTrade, isStructure)'],
              ['13. Trade Helpers', 'GetFillingType(), NormalizePrice(), NormalizeLot(), CalculateLotFromRisk(), CheckSessionFilter()'],
              ['14. Layer / Label', 'PDTypeToSMElement(), SM_IsElementInStages(), ShouldDrawPDElement(), BuildElementLabel(), BuildDRLabel(), GetMainCLWidth(), GetPBCLWidth()'],
            ]
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// Lot calculation from risk %
double CalculateLotFromRisk(double slDistance) {
    if(slDistance <= 0) return InpFixedLot;
    double lot = InpFixedLot;
    if(InpLotMode == LOT_RISK_PERCENT) {
        double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * InpRiskPercent / 100.0;
        double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tickValue > 0 && tickSize > 0) {
            double slTicks = slDistance / tickSize;
            lot = riskAmount / (slTicks * tickValue);
        }
    }
    return NormalizeLot(lot);
}

// Zone type classifier
ENUM_ZONE_TYPE GetZoneType(double price, double rangeHigh, double rangeLow) {
    double range       = rangeHigh - rangeLow;
    double premiumLine = rangeLow + range * InpPremiumLevel / 100.0;
    double discountLine= rangeLow + range * InpDiscountLevel / 100.0;
    if(price >= premiumLine) return ZONE_PREMIUM;
    if(price <= discountLine) return ZONE_DISCOUNT;
    return ZONE_EQUILIBRIUM;
}`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 3. STRUCTURE MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'structure',
    title: 'Structure Module',
    icon: '🏗️',
    color: 'amber',
    subsections: [
      {
        id: 'structure-dr',
        title: 'ICT_DealingRange.mqh — Dealing Range Engine',
        content: [
          {
            type: 'text',
            text: `The Dealing Range (DR) is the foundational structural concept. It models the price delivery range defined by an **Origin** swing, a **Correction Line (CL)**, and a set of **Inducement** and **Counter** levels. Two DR instances are maintained simultaneously: one bullish and one bearish.`
          },
          {
            type: 'callout',
            calloutType: 'info',
            text: `**DR Anatomy:**\n- **Origin** — The external swing high/low that initiated the dealing range\n- **CL (Correction Line)** — Internal structure point where price corrects before distribution\n- **IDMT (Inducement)** — External swing used to trap traders before the real move\n- **Internal Levels** — Counter structure within the pullback`
          },
          {
            type: 'table',
            headers: ['Function', 'Purpose'],
            rows: [
              ['InitializeDealingRange()', 'Scans InpInitScanBars to bootstrap both DR sides'],
              ['UpdateDealingRange()', 'Called every bar; re-evaluates sweep/break conditions'],
              ['DetectDROrigin(isBull)', 'Finds the qualifying external pivot (InpDR_ExtPivotLeftBars/RightBars)'],
              ['UpdateCorrectionLine(dr)', 'Updates the CL using the configured update mode (pullback / immediate / pivot)'],
              ['ScanInducements(dr)', 'Finds up to InpMaxExtInducements external IDMTs above/below origin'],
              ['CheckOriginSweep(dr)', 'Tests if price swept the origin level (using InpSweepMethod)'],
              ['CheckCLBreak(dr)', 'Tests if price closed through the CL (using InpBreakMethod)'],
              ['UpdatePullbackStructure(dr)', 'Builds internal counter levels inside the pullback zone'],
              ['GetActiveDR()', 'Returns pointer to the currently dominant (bullish or bearish) DR'],
            ]
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// CL update logic (InpCL_UpdateMode)
void UpdateCorrectionLine(SDealingRange &dr) {
    switch(InpCL_UpdateMode) {
        case CL_IMMEDIATE_EXTREME:
            // Move CL as soon as new extreme is found
            if(dr.isBull && newExtremeLow < dr.corrLine.price)
                CommitCLUpdate(dr, newExtremeLow, newExtremeTime);
            break;
        case CL_PULLBACK_REQUIRED:
            // Only update after price has pulled back InpCL_PullbackMinATR
            if(HasPulledBackFromExtreme(...))
                CommitCLUpdate(dr, ...);
            break;
        case CL_PIVOT_CONFIRMED:
            // Update only when a confirmed pivot forms at the extreme
            if(IsPivotLow(PERIOD_CURRENT, bar, InpCL_PivotLeftBars, InpCL_PivotRightBars))
                CommitCLUpdate(dr, ...);
            break;
    }
    // Force update after InpCL_ForceUpdateBars regardless of mode
}`
          }
        ]
      },
      {
        id: 'structure-swing',
        title: 'ICT_SwingDetection.mqh — Swing Points',
        content: [
          {
            type: 'text',
            text: `Detects and tracks external (higher-degree) and internal (lower-degree) swing highs/lows using configurable pivot bar counts. Swing status transitions from ACTIVE → SWEPT → BROKEN.`
          },
          {
            type: 'table',
            headers: ['Parameter', 'Default', 'Description'],
            rows: [
              ['InpExtLeftBars', '15', 'Left bars for external pivot confirmation'],
              ['InpExtRightBars', '10', 'Right bars for external pivot confirmation'],
              ['InpIntLeftBars', '3', 'Left bars for internal pivot'],
              ['InpIntRightBars', '3', 'Right bars for internal pivot'],
              ['InpMaxSwingLookback', '300', 'Max bars to scan for swings'],
              ['InpMinBarsBetweenSwings', '3', 'Minimum separation between adjacent swings'],
              ['InpMaxSwingsDisplay', '20', 'Chart display limit'],
            ]
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// Sweep detection (InpSweepMethod = SWEEP_WICK_CLOSE_BACK)
bool CheckSweep(ENUM_TIMEFRAMES tf, double level, bool sweepBelow) {
    double prevHigh  = TF_High(tf, 1);
    double prevLow   = TF_Low(tf, 1);
    double prevClose = TF_Close(tf, 1);
    // Wick pierces level, then closes BACK on the correct side
    if(sweepBelow)
        return (prevLow < level && prevClose > level);
    else
        return (prevHigh > level && prevClose < level);
}`
          }
        ]
      },
      {
        id: 'structure-multitf',
        title: 'ICT_MultiTF.mqh — Multi-Timeframe Analysis',
        content: [
          {
            type: 'text',
            text: `Maintains HTF and LTF bar data in sync with the current chart. All structural analyses (DR, swings, PD arrays) can be performed at any of the three TF layers: HTF, CTF (chart), or LTF.`
          },
          {
            type: 'callout',
            calloutType: 'tip',
            text: `**Layer Tag System:** Every drawn object and SM stage element is tagged with LAYER_HTF / LAYER_CTF / LAYER_LTF so display and logic can be filtered independently per layer.`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 4. MARKET PHASE MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'marketphase',
    title: 'Market Phase Module',
    icon: '🌊',
    color: 'cyan',
    subsections: [
      {
        id: 'phase-amd',
        title: 'ICT_AMD.mqh — Accumulation / Manipulation / Distribution',
        content: [
          {
            type: 'text',
            text: `Detects the three-phase ICT AMD cycle in real time. Each phase is assigned a confidence score and expected direction. An **anti-flicker** mechanism requires **2 consecutive bars** of the same detected phase before committing a state change.`
          },
          {
            type: 'table',
            headers: ['Phase', 'Detection Condition', 'Confidence Base', 'Score Bonus'],
            rows: [
              ['ACCUMULATION', 'Current range < ATR × InpAccumulationRangeATR', '60% (75% if tight range)', '0'],
              ['MANIPULATION', 'Recent sweep detected AND no BOS yet', '70% (85% if Judas confirmed)', '+5 to +12'],
              ['DISTRIBUTION', 'Recent BOS AND recent displacement', '80%–95% based on expansion size', '+10 to +15'],
            ]
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// AMD phase detection pseudocode
void DetectAMDPhase() {
    static ENUM_AMD_PHASE pendingPhase = AMD_UNKNOWN;
    static int pendingCount = 0;
    const int confirmBars   = 2;   // anti-flicker threshold

    bool hasDisplacement = CheckRecentDisplacement(atr, 10);
    bool hasSweep        = CheckRecentSweep(atr, 15);
    bool hasBOS          = CheckRecentBOS(20);

    ENUM_AMD_PHASE detected = AMD_UNKNOWN;
    if(hasBOS && hasDisplacement) detected = AMD_DISTRIBUTION;
    else if(hasSweep && !hasBOS)  detected = AMD_MANIPULATION;
    else if(currentRange < atr * InpAccumulationRangeATR) detected = AMD_ACCUMULATION;

    // Anti-flicker: commit only after 2 consecutive matching bars
    if(detected != g_amdPhase.currentPhase) {
        if(detected == pendingPhase) pendingCount++;
        else { pendingPhase = detected; pendingCount = 1; }
        if(pendingCount < confirmBars) return;
    }
    g_amdPhase.currentPhase = detected;
}`
          }
        ]
      },
      {
        id: 'phase-judas',
        title: 'ICT_JudasSwing.mqh — Judas Swing Detection',
        content: [
          {
            type: 'text',
            text: `Detects the manipulation/Judas move — a sweep of a session high/low (typically during the London or NY open) that traps retail traders before the real distribution move begins.`
          },
          {
            type: 'table',
            headers: ['Field', 'Meaning'],
            rows: [
              ['g_judasSwing.type', 'JUDAS_NONE / JUDAS_BULLISH / JUDAS_BEARISH'],
              ['g_judasSwing.isConfirmed', 'True when the sweep + reversal is confirmed'],
              ['g_judasSwing.sweepLevel', 'Price level that was swept'],
              ['g_judasSwing.sweepTime', 'Bar time of the sweep candle'],
            ]
          },
          {
            type: 'callout',
            calloutType: 'warning',
            text: `A confirmed Judas swing sets the AMD phase to MANIPULATION and the expectedDirection to the reversal side. This feeds the state-machine trigger condition SM_ELEM_EXT_SWEEP.`
          }
        ]
      },
      {
        id: 'phase-killzones',
        title: 'ICT_Killzones.mqh — Session Killzones',
        content: [
          {
            type: 'text',
            text: `Identifies the current trading session and whether price is inside a high-probability killzone window. Active killzones apply a score multiplier (InpKZ_ScoreMultiplier) to all signal evaluations.`
          },
          {
            type: 'table',
            headers: ['Killzone', 'Default Hours (Server)', 'Input Flag'],
            rows: [
              ['Asian', '00:00 – 06:00', 'InpTradeAsianKZ (default OFF)'],
              ['London Open', '07:00 – 10:00', 'InpTradeLondonKZ'],
              ['London Close', '15:00 – 17:00', 'InpTradeLondonKZ'],
              ['NY Open', '12:00 – 15:00', 'InpTradeNYKZ'],
              ['LDN/NY Overlap', 'Automatically detected', 'derived'],
            ]
          }
        ]
      },
      {
        id: 'phase-smt',
        title: 'ICT_SMT.mqh — SMT Divergence',
        content: [
          {
            type: 'text',
            text: `Smart Money Technique (SMT) divergence is detected by comparing swing highs/lows on the current symbol against a correlated pair (e.g., DXY, EURUSD). Divergence occurs when one pair makes a new extreme and the other fails to — indicating institutional disagreement.`
          },
          {
            type: 'table',
            headers: ['Parameter', 'Default', 'Description'],
            rows: [
              ['InpSMT_Pair', 'SMT_PAIR_DXY', 'The correlation pair to compare against'],
              ['InpSMT_SwingLookback', '15', 'Bars to look back for swing comparison'],
              ['InpSMT_TimeTolerance', '3', 'Bar tolerance for swing alignment between pairs'],
            ]
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 5. PD ARRAYS MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'pdarrays',
    title: 'PD Arrays Module',
    icon: '📦',
    color: 'emerald',
    subsections: [
      {
        id: 'pd-ob',
        title: 'ICT_OrderBlocks.mqh — Order Blocks',
        content: [
          {
            type: 'text',
            text: `Detects institutional order blocks — the last bearish candle before a bullish displacement (bullish OB) or the last bullish candle before a bearish displacement (bearish OB). Also detects **Breaker Blocks** (failed OBs that flip polarity) and **Mitigation Blocks**.`
          },
          {
            type: 'table',
            headers: ['Parameter', 'Default', 'Description'],
            rows: [
              ['InpOB_Lookback', '20', 'Bars to scan for OBs'],
              ['InpOB_MinDisplacementATR', '1.5', 'Required displacement size (ATR multiples)'],
              ['InpOB_RequireInstitutional', 'false', 'Require extra-large "institutional" candle'],
              ['InpOB_InstitutionalMultiple', '2.0', 'Size multiplier for institutional candle test'],
              ['InpOB_MaxTestCount', '2', 'Max times OB can be touched before invalidation'],
              ['InpOB_MinBodyRatio', '0.5', 'Body must be ≥ 50% of candle range'],
              ['InpOB_ZoneIncludeWicks', 'true', 'Whether OB zone boundaries include wicks'],
              ['InpOB_MaxAge_Hours', '72', 'OBs older than this are auto-expired'],
              ['InpDetectBreakerBlocks', 'true', 'Enable breaker block detection'],
              ['InpDetectMitigationBlocks', 'true', 'Enable mitigation block detection'],
            ]
          },
          {
            type: 'callout',
            calloutType: 'info',
            text: `**Breaker Block Rule:** A breaker is a former OB that was swept and then broke structure in the opposite direction. It flips from supply to demand (or vice versa). Enabled via InpDetectBreakerBlocks + InpBreaker_RequirePriorTest.`
          }
        ]
      },
      {
        id: 'pd-fvg',
        title: 'ICT_FairValueGaps.mqh — FVGs, Volume Imbalances & Liquidity Voids',
        content: [
          {
            type: 'text',
            text: `Detects three types of price gaps: **Fair Value Gaps (FVG)** — 3-candle imbalance pattern; **Volume Imbalances** — overlap between adjacent candle bodies; and **Liquidity Voids** — large single-candle range gaps.`
          },
          {
            type: 'table',
            headers: ['Type', 'Detection Logic', 'Size Minimum'],
            rows: [
              ['FVG', 'C1 high < C3 low (bull) or C1 low > C3 high (bear)', 'InpFVG_MinSizeATR × ATR'],
              ['IFVG (Inverse FVG)', 'FVG that is fully filled → flips', 'Same as FVG'],
              ['Volume Imbalance', 'C1 close vs C2 open gap on same-direction candles', 'InpFVG_MinSizeATR × ATR'],
              ['Liquidity Void', 'Single candle high-low range gap', 'InpVoid_MinSizeATR × ATR'],
            ]
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// FVG detection logic
// Bullish FVG: candle[2].high < candle[0].low  (gap between C3 and C1)
// Bearish FVG: candle[2].low  > candle[0].high

bool IsBullishFVG(int bar) {
    double c1High  = TF_High(PERIOD_CURRENT, bar + 2);
    double c3Low   = TF_Low(PERIOD_CURRENT,  bar);
    double gapSize = c3Low - c1High;
    return (gapSize >= InpFVG_MinSizeATR * GetATR());
}

// Consequent Encroachment (CE) = midpoint of FVG zone
double GetFVG_CE(double fvgTop, double fvgBottom) {
    return (fvgTop + fvgBottom) / 2.0;
}`
          }
        ]
      },
      {
        id: 'pd-ote',
        title: 'ICT_OTE.mqh — Optimal Trade Entry Zones',
        content: [
          {
            type: 'text',
            text: `Calculates the OTE zone from a recent swing using Fibonacci retracements. The OTE zone spans the 61.8%–79% retracement — the highest-probability pullback area for institutional entries.`
          },
          {
            type: 'table',
            headers: ['Level', 'Default Value', 'Significance'],
            rows: [
              ['InpOTE_Fib618', '61.8%', 'Start of OTE zone'],
              ['InpOTE_Fib705', '70.5%', 'Optimal / "sweet spot" level'],
              ['InpOTE_Fib79', '79.0%', 'End of OTE zone (maximum retracement)'],
            ]
          }
        ]
      },
      {
        id: 'pd-stacking',
        title: 'ICT_PDStacking.mqh — PD Array Confluence',
        content: [
          {
            type: 'text',
            text: `When multiple PD arrays overlap spatially, they form a "stacked" confluence zone with elevated signal weight. The SM element **SM_ELEM_STACKED_PDA** triggers when at least InpMinStackCount arrays align.`
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// Stacking check: count overlapping PD arrays at current price
int CountStackedPDArrays(double price) {
    int stackCount = 0;
    for(int i = 0; i < g_pdArraysCount; i++) {
        if(!g_pdArrays[i].isActive) continue;
        if(IsPriceInZone(price, g_pdArrays[i].top, g_pdArrays[i].bottom))
            stackCount++;
    }
    return stackCount;
}
// Triggers entry when stackCount >= InpMinStackCount`
          }
        ]
      },
      {
        id: 'pd-master',
        title: 'ICT_PDArrays_Master.mqh — Master Orchestrator',
        content: [
          {
            type: 'text',
            text: `The master file calls all individual PD array detectors in the correct order and manages the unified g_pdArrays[] list. It also applies the layer gating logic — only PD arrays whose types are referenced in the active SM stages are drawn on the chart.`
          },
          {
            type: 'callout',
            calloutType: 'tip',
            text: `**Drawing Gate:** ShouldDrawPDElement(pdType) maps the PD array type to an SM element type and checks SM_IsElementInStages(). This prevents visual clutter when an array type isn't part of the current trading plan.`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 6. STATE MACHINE MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'statemachine',
    title: 'State Machine Engine',
    icon: '🔄',
    color: 'violet',
    subsections: [
      {
        id: 'sm-overview',
        title: 'Concept & Architecture',
        content: [
          {
            type: 'text',
            text: `The State Machine (SM) Engine is the intellectual core of the EA. It sequences entry conditions through up to **4 configurable stages** (Trigger → Confirmation → Validation → Entry). Multiple instances can run simultaneously with configurable coexistence or replacement policies.`
          },
          {
            type: 'table',
            headers: ['Stage', 'Default Elements', 'Logic', 'Role'],
            rows: [
              ['Stage 1: TRIGGER', 'SM_ELEM_CHOCH_BREAK OR SM_ELEM_EXT_SWEEP', 'OR', 'Initial structural event that activates the SM instance'],
              ['Stage 2: CONFIRMATION', 'SM_ELEM_DISPLACEMENT AND SM_ELEM_BOS', 'AND', 'Confirms institutional intent / follow-through'],
              ['Stage 3: VALIDATION', 'SM_ELEM_BOS AND SM_ELEM_PREMIUM_DISCOUNT', 'AND (optional)', 'Validates LTF context and PD zone location'],
              ['Stage 4: ENTRY', 'SM_ELEM_ORDER_BLOCK OR SM_ELEM_FVG', 'OR', 'Price returns to entry PD array — trade is placed'],
            ]
          },
          {
            type: 'callout',
            calloutType: 'info',
            text: `**Causal Flag:** When \`causal = true\` for a stage, the stage elements must appear in the correct chronological order relative to the previous stage. This prevents retroactive signal matching.`
          }
        ]
      },
      {
        id: 'sm-elements',
        title: 'SM Element Reference',
        content: [
          {
            type: 'text',
            text: `Each SM stage uses two configurable elements (primary + secondary) with AND/OR logic. Below is the complete element catalog:`
          },
          {
            type: 'table',
            headers: ['Element', 'What It Detects'],
            rows: [
              ['SM_ELEM_NONE', 'Empty / disabled slot'],
              ['SM_ELEM_CHOCH_BREAK', 'Change of Character — internal structure break counter-trend'],
              ['SM_ELEM_BOS', 'Break of Structure — closes through a swing high/low'],
              ['SM_ELEM_EXT_SWEEP', 'External swing point swept (liquidity grab)'],
              ['SM_ELEM_INT_SWEEP', 'Internal swing point swept'],
              ['SM_ELEM_DISPLACEMENT', 'Impulsive candle(s) meeting ATR threshold + body % criteria'],
              ['SM_ELEM_ORDER_BLOCK', 'Price inside an active order block zone'],
              ['SM_ELEM_FVG', 'Price inside an active fair value gap'],
              ['SM_ELEM_BREAKER', 'Price inside a breaker block zone'],
              ['SM_ELEM_MITIGATION', 'Price inside a mitigation block zone'],
              ['SM_ELEM_OTE_ZONE', 'Price inside OTE Fibonacci zone (61.8–79%)'],
              ['SM_ELEM_PREMIUM_DISCOUNT', 'Price in discount (for longs) or premium (for shorts)'],
              ['SM_ELEM_KILLZONE', 'Current time is inside an active killzone'],
              ['SM_ELEM_AMD_PHASE', 'AMD phase matches required phase for bias'],
              ['SM_ELEM_JUDAS_CONFIRMED', 'Judas swing is confirmed'],
              ['SM_ELEM_SMT_DIVERGENCE', 'SMT divergence signal is active'],
              ['SM_ELEM_STACKED_PDA', 'At least InpMinStackCount PD arrays overlap at price'],
              ['SM_ELEM_HTF_BIAS', 'HTF structure aligns with trade direction'],
              ['SM_ELEM_LTF_ENTRY', 'LTF entry confirmation present'],
              ['SM_ELEM_NARRATIVE_GATE', 'Narrative gate (bias filter) is open for this direction'],
            ]
          }
        ]
      },
      {
        id: 'sm-presets',
        title: 'ICT_SMPresets.mqh — Built-In Presets',
        content: [
          {
            type: 'text',
            text: `Presets pre-configure all 4 stages for common ICT setups. Selecting a preset via InpSM_Preset loads the stage configurations automatically at OnInit.`
          },
          {
            type: 'table',
            headers: ['Preset', 'Stage 1', 'Stage 2', 'Stage 3', 'Stage 4'],
            rows: [
              ['SM_PRESET_CHOCH_RETRACE', 'CHoCH Break', 'Displacement + BOS', 'BOS + P/D', 'OB or FVG'],
              ['SM_PRESET_BOS_ENTRY', 'BOS', 'Displacement', 'P/D Zone', 'OB or OTE'],
              ['SM_PRESET_JUDAS_REVERSAL', 'Ext Sweep + Judas', 'CHoCH Break', 'FVG', 'OB'],
              ['SM_PRESET_SMT_ENTRY', 'SMT Divergence', 'Ext Sweep', 'Displacement', 'FVG or OTE'],
              ['SM_PRESET_AMD_FULL', 'AMD Manipulation', 'CHoCH + Displacement', 'P/D Zone', 'Stacked PDA'],
            ]
          }
        ]
      },
      {
        id: 'sm-policy',
        title: 'Instance Policies & Timeouts',
        content: [
          {
            type: 'table',
            headers: ['Policy / Setting', 'Values', 'Behavior'],
            rows: [
              ['InpSM_InstancePolicy', 'SM_INSTANCE_COEXIST', 'New SM triggers create additional instances (up to InpSM_MaxInstances)'],
              ['InpSM_InstancePolicy', 'SM_INSTANCE_REPLACE', 'New trigger replaces the oldest pending instance'],
              ['InpSM_InstancePolicy', 'SM_INSTANCE_BLOCK', 'No new instances while one is active'],
              ['InpSM_MaxInstances', '4', 'Hard cap on simultaneous SM instances'],
              ['InpSM_GlobalTimeout', '80', 'Bars until any instance is auto-expired'],
              ['Per-stage timeout', 'e.g. InpSM_Conf_Timeout = 20', 'Stage-level bar timeout; instance expires if stage not met'],
            ]
          }
        ]
      },
      {
        id: 'sm-narrative',
        title: 'ICT_NarrativeGate.mqh — Bias Filter',
        content: [
          {
            type: 'text',
            text: `The Narrative Gate is a directional bias filter that gates SM instances. Only instances whose direction matches the current narrative (derived from HTF structure + AMD phase + SMT divergence) are allowed to progress past Stage 1.`
          },
          {
            type: 'callout',
            calloutType: 'warning',
            text: `Even if all 4 stages complete, if the Narrative Gate is CLOSED for that direction, no trade is executed. This prevents counter-narrative entries.`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 7. TRADING MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'trading',
    title: 'Trading Module',
    icon: '💹',
    color: 'green',
    subsections: [
      {
        id: 'trading-signal',
        title: 'ICT_SignalEngine.mqh — Signal Evaluation',
        content: [
          {
            type: 'text',
            text: `When an SM instance completes all required stages, the Signal Engine evaluates a composite **signal score** before placing a trade. The score aggregates contributions from all active confluence factors.`
          },
          {
            type: 'table',
            headers: ['Contributor', 'Score Range', 'Notes'],
            rows: [
              ['Base signal (SM completed)', '+50', 'All required stages met'],
              ['AMD Phase match', '+10 to +15', 'Distribution phase best; 0 if Accumulation'],
              ['Judas confirmed', '+12', 'Manipulation stage with confirmed Judas swing'],
              ['SMT Divergence', '+10', 'SMT signal present for same direction'],
              ['Killzone active', '× InpKZ_ScoreMultiplier', 'Multiplier applied to base score'],
              ['Stacked PDAs', '+5 per extra layer', 'Above InpMinStackCount'],
              ['HTF alignment', '+8', 'HTF structure matches trade direction'],
              ['Premium/Discount', '+5', 'Correct P/D zone for direction'],
            ]
          },
          {
            type: 'callout',
            calloutType: 'success',
            text: `**Minimum Score Threshold:** A trade is only placed if the total composite score meets the configured minimum. This ensures only high-confluence setups reach execution.`
          }
        ]
      },
      {
        id: 'trading-manager',
        title: 'ICT_TradeManager.mqh — Order & Risk Management',
        content: [
          {
            type: 'text',
            text: `Handles all trade lifecycle: entry, SL/TP placement, trailing, partial close, and daily risk limits.`
          },
          {
            type: 'table',
            headers: ['Feature', 'Input', 'Description'],
            rows: [
              ['Lot Sizing', 'InpLotMode', 'LOT_FIXED / LOT_RISK_PERCENT / LOT_BALANCE_PERCENT'],
              ['Stop Loss', 'InpSlMode', 'SL_FIXED (points) / SL_STRUCTURE (swing) / SL_ATR_MULTIPLE'],
              ['Take Profit', 'InpTpMode', 'TP_FIXED / TP_RR_RATIO / TP_STRUCTURE / TP_PDArray'],
              ['Trailing Stop', 'InpUseTrailing', 'Trails SL by ATR multiple or structure swing'],
              ['Breakeven', 'InpUseBreakeven', 'Moves SL to entry + buffer after partial profit'],
              ['Partial Close', 'InpUsePartialClose', 'Closes InpPartialClosePercent at first TP level'],
              ['Max Daily Trades', 'InpMaxDailyTrades', 'Hard limit on trades per day'],
              ['Max Daily Loss', 'InpMaxDailyLossPercent', 'Percent of balance — halts trading for the day'],
              ['Spread Filter', 'InpMaxSpread', 'Skips entry if spread exceeds threshold'],
              ['Day Filter', 'InpTrade[Mon..Fri]', 'Enable/disable trading on specific weekdays'],
            ]
          },
          {
            type: 'code',
            language: 'cpp',
            code: `// SL placement (SL_STRUCTURE mode)
double GetStructureSL(bool isBullish) {
    if(isBullish) {
        // SL below the origin swing low + buffer
        return g_bullDR.origin.price - GetATR() * InpSL_ATR_Buffer;
    } else {
        // SL above origin swing high + buffer
        return g_bearDR.origin.price + GetATR() * InpSL_ATR_Buffer;
    }
}

// Daily safety checks before placing any order
bool CheckAllFilters() {
    if(!g_tradingEnabled)         { Print("Trading disabled"); return false; }
    if(!IsTradingDay())           { Print("Not a trading day"); return false; }
    if(!CheckSpreadFilter())      { Print("Spread too high");   return false; }
    if(!CheckMaxTradesFilter())   { Print("Max trades hit");    return false; }
    if(!CheckMaxLossFilter())     { Print("Max loss hit");      return false; }
    return true;
}`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 8. ML MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'ml',
    title: 'ML Engine',
    icon: '🧠',
    color: 'rose',
    subsections: [
      {
        id: 'ml-engine',
        title: 'ICT_MLEngine.mqh — Machine Learning Scoring',
        content: [
          {
            type: 'text',
            text: `The ML Engine provides an additional scoring layer on top of the rule-based signal engine. It tracks historical pattern outcomes and adjusts signal weights based on past performance of similar configurations.`
          },
          {
            type: 'callout',
            calloutType: 'info',
            text: `**Implementation Note:** The ML engine uses an online learning approach — pattern features are extracted at entry time, and outcomes (win/loss, R-multiple) are recorded at trade close. Pattern similarity scoring uses a weighted feature distance metric rather than a neural network, keeping it fully interpretable and MQL5-compatible without external DLLs.`
          },
          {
            type: 'table',
            headers: ['Feature Vector Component', 'Description'],
            rows: [
              ['AMD Phase', 'Encoded phase at time of entry (0=None, 1=Accum, 2=Manip, 3=Dist)'],
              ['Killzone', 'Active killzone index at entry'],
              ['PD Array Types', 'Bitmask of which PD arrays were present'],
              ['SM Preset', 'Which preset triggered the trade'],
              ['HTF Alignment', 'Binary: HTF aligned yes/no'],
              ['OTE Zone', 'Binary: price in OTE yes/no'],
              ['SMT Divergence', 'Binary: SMT present yes/no'],
              ['Signal Score', 'Normalized composite signal score'],
            ]
          }
        ]
      },
      {
        id: 'ml-dashboard',
        title: 'ICT_MLDashboard.mqh — ML Performance Display',
        content: [
          {
            type: 'text',
            text: `Renders ML statistics in a dedicated section of the on-chart dashboard, showing pattern recognition accuracy, feature importance rankings, and recent prediction confidence.`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 9. UI MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'ui',
    title: 'UI Module',
    icon: '🖥️',
    color: 'sky',
    subsections: [
      {
        id: 'ui-dashboard',
        title: 'ICT_Dashboard.mqh — Information Panel',
        content: [
          {
            type: 'text',
            text: `Renders a comprehensive on-chart information panel organized into sections. All drawing uses MetaTrader 5 chart objects (labels, rectangles, lines) with a configurable position.`
          },
          {
            type: 'table',
            headers: ['Dashboard Section', 'Content'],
            rows: [
              ['Market Bias', 'Current direction, AMD phase + confidence, killzone name'],
              ['Dealing Range', 'Active DR side (Bull/Bear), origin price, CL price, sweep/break status'],
              ['State Machine', 'Active SM instances: current stage, direction, elapsed bars'],
              ['PD Arrays', 'Count of active OBs, FVGs, OTE zones; nearest zone to price'],
              ['Signal Score', 'Last signal score breakdown with component contributions'],
              ['Trade Stats', 'Today trades, today P&L, total win rate, consecutive wins/losses'],
              ['ML Stats', 'Pattern accuracy, recent prediction confidence (if ML enabled)'],
              ['Filters', 'Spread, session, day filter status — green/red indicators'],
            ]
          }
        ]
      },
      {
        id: 'ui-drawing',
        title: 'ICT_Drawing.mqh — Chart Object Drawing',
        content: [
          {
            type: 'text',
            text: `Provides all chart-drawing functions for structural elements and PD arrays. Every object is prefixed (g_prefix, g_drPrefix, g_pdPrefix) for easy selective cleanup.`
          },
          {
            type: 'table',
            headers: ['Drawing Function', 'Object Type'],
            rows: [
              ['DrawDROrigin(dr)', 'Horizontal line + label at origin price'],
              ['DrawCorrectionLine(dr)', 'Horizontal ray (thick) for CL; color/width per TF layer'],
              ['DrawInducement(level)', 'Dashed horizontal line at IDMT level'],
              ['DrawPullbackLevels(dr)', 'Dotted horizontal lines for counter levels'],
              ['DrawOrderBlock(ob)', 'Rectangle zone (body or wicks) + label'],
              ['DrawFVG(fvg)', 'Semi-transparent rectangle + CE midline'],
              ['DrawOTEZone(ote)', 'Fibonacci zone rectangle'],
              ['DrawSwingPoint(swing)', 'Triangle arrow + label (Hi/Lo, Ext/Int)'],
              ['DrawSMTDivergence()', 'Connecting line between divergent swing pairs'],
            ]
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 10. EXTERNAL MODULE
  // ─────────────────────────────────────────────────────
  {
    id: 'external',
    title: 'External Module',
    icon: '🔌',
    color: 'orange',
    subsections: [
      {
        id: 'ext-provider',
        title: 'ICT_ExternalProvider.mqh — External Signal Intake',
        content: [
          {
            type: 'text',
            text: `Allows the EA to receive signals from an external indicator (ICT_SampleProvider.mq5) via indicator buffers. This enables a separation of analysis (indicator) and execution (EA) for back-testing and forward testing comparison.`
          }
        ]
      },
      {
        id: 'ext-publisher',
        title: 'ICT_EAStatePublisher.mqh — EA State Export',
        content: [
          {
            type: 'text',
            text: `Exports internal EA state (current direction, SM stage, active PD arrays, signal score) to global variables that other EAs, indicators, or dashboards can read. Enables multi-chart panel coordination.`
          }
        ]
      },
      {
        id: 'ext-orchestrator',
        title: 'ICT_SignalOrchestrator.mqh — Signal Routing',
        content: [
          {
            type: 'text',
            text: `Routes signals from both the internal SM engine and the external provider through a unified interface, applying priority rules when both sources agree or conflict. Acts as the final gateway before signal scoring.`
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 11. CONFIGURATION REFERENCE
  // ─────────────────────────────────────────────────────
  {
    id: 'config',
    title: 'Full Input Reference',
    icon: '⚙️',
    color: 'teal',
    subsections: [
      {
        id: 'config-mtf',
        title: 'Multi-Timeframe Settings',
        content: [
          {
            type: 'param-table',
            headers: ['Input', 'Default', 'Description'],
            rows: [
              ['InpHTF_Timeframe', 'H4', 'Higher Timeframe for HTF analysis'],
              ['InpLTF_Timeframe', 'M1', 'Lower Timeframe for LTF refinement'],
              ['InpEnableHTF', 'true', 'Enable HTF structural analysis'],
              ['InpEnableLTF', 'true', 'Enable LTF entry refinement'],
            ]
          }
        ]
      },
      {
        id: 'config-dr',
        title: 'Dealing Range Structure',
        content: [
          {
            type: 'param-table',
            headers: ['Input', 'Default', 'Description'],
            rows: [
              ['InpCL_PivotLeftBars', '3', 'Pivot left bars for CL confirmation'],
              ['InpCL_PivotRightBars', '3', 'Pivot right bars for CL confirmation'],
              ['InpDR_ExtPivotLeftBars', '5', 'External IDMT pivot left bars'],
              ['InpDR_ExtPivotRightBars', '3', 'External IDMT pivot right bars'],
              ['InpInitScanBars', '200', 'Bars scanned on EA start'],
              ['InpMinBarsBetweenOrigins', '5', 'Minimum bars between DR origins'],
              ['InpSweepMethod', 'WICK_CLOSE_BACK', 'Wick pierces + close returns = sweep'],
              ['InpBreakMethod', 'CANDLE_CLOSE', 'Candle must close through for break'],
              ['InpMaxOriginsTrack', '5', 'Maximum simultaneous origin points'],
              ['InpCL_UpdateMode', 'PIVOT_CONFIRMED', 'When to advance the Correction Line'],
              ['InpCL_ForceUpdateBars', '30', 'Force CL move after N bars'],
              ['InpCL_PullbackMinATR', '0.2', 'Minimum pullback size to trigger CL update (ATR)'],
            ]
          }
        ]
      },
      {
        id: 'config-sm',
        title: 'State Machine Engine',
        content: [
          {
            type: 'param-table',
            headers: ['Input', 'Default', 'Description'],
            rows: [
              ['InpSM_Preset', 'SM_PRESET_CHOCH_RETRACE', 'Pre-built stage configuration'],
              ['InpSM_InstancePolicy', 'SM_INSTANCE_COEXIST', 'How multiple SM triggers are handled'],
              ['InpSM_MaxInstances', '4', 'Maximum simultaneous SM instances'],
              ['InpSM_GlobalTimeout', '80', 'Global instance timeout (bars)'],
              ['InpSM_Trig_Primary', 'SM_ELEM_CHOCH_BREAK', 'Stage 1 primary element'],
              ['InpSM_Trig_Secondary', 'SM_ELEM_EXT_SWEEP', 'Stage 1 secondary element'],
              ['InpSM_Trig_Logic', 'SM_LOGIC_OR', 'Stage 1 element logic (AND/OR)'],
              ['InpSM_Conf_Primary', 'SM_ELEM_DISPLACEMENT', 'Stage 2 primary element'],
              ['InpSM_Conf_Secondary', 'SM_ELEM_BOS', 'Stage 2 secondary element'],
              ['InpSM_Conf_Logic', 'SM_LOGIC_AND', 'Stage 2 element logic'],
              ['InpSM_Conf_Timeout', '20', 'Stage 2 timeout (bars)'],
              ['InpSM_Val_Primary', 'SM_ELEM_BOS', 'Stage 3 primary element'],
              ['InpSM_Val_Secondary', 'SM_ELEM_PREMIUM_DISCOUNT', 'Stage 3 secondary element'],
              ['InpSM_Val_Required', 'false', 'Stage 3 is optional'],
              ['InpSM_Ent_Primary', 'SM_ELEM_ORDER_BLOCK', 'Stage 4 primary element'],
              ['InpSM_Ent_Secondary', 'SM_ELEM_FVG', 'Stage 4 secondary element'],
              ['InpSM_Ent_Logic', 'SM_LOGIC_OR', 'Stage 4 element logic'],
              ['InpSM_Ent_Timeout', '20', 'Stage 4 timeout (bars)'],
            ]
          }
        ]
      },
      {
        id: 'config-risk',
        title: 'Risk Management',
        content: [
          {
            type: 'param-table',
            headers: ['Input', 'Default', 'Description'],
            rows: [
              ['InpLotMode', 'LOT_RISK_PERCENT', 'Position sizing method'],
              ['InpFixedLot', '0.1', 'Lot size when LOT_FIXED mode'],
              ['InpRiskPercent', '1.0', 'Account risk per trade (%)'],
              ['InpSlMode', 'SL_STRUCTURE', 'Stop loss placement method'],
              ['InpFixedSlPoints', '500', 'Fixed SL in points (when SL_FIXED)'],
              ['InpUseMaxTrades', 'true', 'Enable daily trade count limit'],
              ['InpMaxDailyTrades', '3', 'Maximum trades per day'],
              ['InpUseMaxLoss', 'true', 'Enable daily loss limit'],
              ['InpMaxDailyLossPercent', '2.0', 'Max daily loss as % of balance'],
              ['InpUseSpreadFilter', 'true', 'Enable spread filter'],
              ['InpMaxSpread', '20', 'Maximum allowed spread (points)'],
            ]
          }
        ]
      }
    ]
  },

  // ─────────────────────────────────────────────────────
  // 12. CONCEPTS GLOSSARY
  // ─────────────────────────────────────────────────────
  {
    id: 'glossary',
    title: 'ICT Concepts Glossary',
    icon: '📖',
    color: 'pink',
    subsections: [
      {
        id: 'glossary-terms',
        title: 'Key ICT Terminology Used in This EA',
        content: [
          {
            type: 'table',
            headers: ['Term', 'Definition'],
            rows: [
              ['Dealing Range (DR)', 'The price delivery range defined by an external swing origin and its subsequent correction. The EA tracks one bull DR and one bear DR simultaneously.'],
              ['Correction Line (CL)', 'The internal structural pivot point within a dealing range — the level where price "corrects" before the distribution move. CL break = BOS.'],
              ['IDMT / Inducement', 'An external swing point above/below the CL that lures retail traders into a position before the true move. When swept, it triggers a state-machine event.'],
              ['AMD Cycle', 'Accumulation → Manipulation → Distribution. The 3-phase model describing how institutions accumulate positions, manipulate price to sweep liquidity, then distribute into retail traders.'],
              ['Judas Swing', 'The manipulation candle(s) that sweep a session high/low before reversing. Named for the betrayal — price appears to break out, then reverses.'],
              ['CHoCH (Change of Character)', 'A break of a counter-trend internal swing — the first signal that the current structure is shifting. Weaker than a BOS.'],
              ['BOS (Break of Structure)', 'A confirmed close through a significant swing high (bullish BOS) or swing low (bearish BOS). Confirms trend continuation.'],
              ['Order Block (OB)', 'The last opposite-direction candle before an impulsive move. Represents institutional order flow. Price often returns to this zone for entry.'],
              ['Breaker Block', 'A former Order Block that was swept and then caused a BOS in the opposite direction. Flips from supply to demand (or vice versa).'],
              ['Fair Value Gap (FVG)', '3-candle imbalance where candle 1 and candle 3 do not overlap. Represents an area where price moved too quickly — often partially refilled.'],
              ['Consequent Encroachment (CE)', 'The exact midpoint of an FVG. Price commonly reacts at this level during pullbacks.'],
              ['OTE Zone', 'Optimal Trade Entry — the 61.8% to 79% Fibonacci retracement of a swing. The highest-probability pullback entry zone.'],
              ['SMT Divergence', 'When a correlated pair makes a new swing extreme but the primary instrument does not (or vice versa). Signals institutional manipulation / divergent flow.'],
              ['Killzone', 'High-volume trading sessions (London Open, NY Open) when institutional orders are most active. The EA applies a score multiplier during these windows.'],
              ['Premium/Discount', 'Price above the 50% (equilibrium) of a dealing range is "Premium" (institutions sell). Below equilibrium is "Discount" (institutions buy).'],
              ['Liquidity Void', 'A single-candle gap in price delivery — area with no price agreement. Price usually fills these voids in future sessions.'],
              ['PD Array Stacking', 'When multiple PD arrays (OB + FVG + OTE) overlap spatially. Creates a high-confluence entry zone.'],
              ['Narrative Gate', 'The EA-specific bias filter that ensures only trades aligned with the higher-timeframe narrative and AMD phase are executed.'],
            ]
          }
        ]
      }
    ]
  }
];
