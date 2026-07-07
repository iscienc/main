//+------------------------------------------------------------------+
//|                         ICT_Config.mqh                            |
//|                    Input Parameters Configuration                  |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_CONFIG_MQH
#define ICT_CONFIG_MQH

//+------------------------------------------------------------------+
//|              MULTI-TIMEFRAME CONFIGURATION                         |
//+------------------------------------------------------------------+
input group "══════════════ MULTI-TIMEFRAME SETTINGS ══════════════"
input ENUM_TIMEFRAMES InpHTF_Timeframe = PERIOD_H4;           // Higher Timeframe
input ENUM_TIMEFRAMES InpLTF_Timeframe = PERIOD_M1;           // Lower Timeframe
input bool            InpEnableHTF = true;                    // Enable HTF Analysis
input bool            InpEnableLTF = true;                    // Enable LTF Refinement

//+------------------------------------------------------------------+
//|              DEALING RANGE STRUCTURE SETTINGS                      |
//+------------------------------------------------------------------+
input group "══════════════ DEALING RANGE STRUCTURE ══════════════"
input int             InpCL_PivotLeftBars = 3;                // CL Pivot Left Bars
input int             InpCL_PivotRightBars = 3;               // CL Pivot Right Bars

input int             InpDR_ExtPivotLeftBars = 5;             // External IDMT Pivot Left Bars
input int             InpDR_ExtPivotRightBars = 3;            // External IDMT Pivot Right Bars
input int             InpDR_IntPivotLeftBars = 3;             // Internal Level Pivot Left Bars
input int             InpDR_IntPivotRightBars = 2;            // Internal Level Pivot Right Bars

input int             InpInitScanBars = 200;                  // Initial Scan Bars
input int             InpMinBarsBetweenOrigins = 5;           // Min Bars Between Origins
input ENUM_SWEEP_METHOD InpSweepMethod = SWEEP_WICK_CLOSE_BACK; // Sweep Detection Method
input ENUM_BREAK_METHOD InpBreakMethod = BREAK_CANDLE_CLOSE;  // Break Detection Method
input int             InpMaxOriginsTrack = 5;                 // Max Origins to Track
input int             InpMaxExtInducements = 10;              // Max External Inducements
input double          InpExtMinDepthATR = 0.3;                // External Min Depth (ATR)
input int             InpExtMinPivotScore = 1;                // External Min Pivot Score
input double          InpExtMinDistanceATR = 0.2;             // External Min Distance (ATR)
input bool            InpExtRequireBOS = false;               // External Requires BOS Move
input double          InpExtBOS_MoveATR = 0.5;                // External BOS Move (ATR)
input bool            InpUseDistanceDim = true;               // Use Distance Dimming
input double          InpDimDistanceATR = 5.0;                // Dim Distance (ATR)
enum ENUM_CL_UPDATE_MODE
{
   CL_PULLBACK_REQUIRED = 0,    // After Pullback (Conservative)
   CL_IMMEDIATE_EXTREME = 1,    // Immediate on New Extreme (Aggressive)
   CL_PIVOT_CONFIRMED = 2       // After Pivot Confirmation (Moderate)
};

input ENUM_CL_UPDATE_MODE InpCL_UpdateMode = CL_PIVOT_CONFIRMED;  // CL Update Mode
input int    InpCL_ForceUpdateBars = 30;        // Force CL Update After N Bars
input double InpCL_PullbackMinATR = 0.2;        // Pullback Min Distance (ATR Multiple)
input group "══════════════ PULLBACK STRUCTURE DETECTION ══════════════"
input bool InpDetectPullbackStructure = true; // Detect Pullback Internal Structure
input int InpMaxPullbackCounters = 10; // Max Pullback Counter Levels
input bool InpShowPullbackOrigin = true; // Show Pullback Origin on Chart
input bool InpShowPullbackCL = true; // Show Pullback CL on Chart
input bool InpShowPullbackCounters = true; // Show Pullback Counter Levels
input color InpPullbackOriginColor = clrDeepPink; // Pullback Origin Color
input color InpPullbackCLColor = clrDodgerBlue; // Pullback CL Color
input color InpPullbackCounterColor = clrDarkKhaki; // Pullback Counter Color


//+------------------------------------------------------------------+
//|              SWING DETECTION SETTINGS                              |
//+------------------------------------------------------------------+
input group "══════════════ SWING DETECTION ══════════════"
input bool            InpShowSwingPoints = true;              // Show Swing Points
input bool            InpShowExternalSwings = true;           // Show External Swings
input bool            InpShowInternalSwings = false;          // Show Internal Swings
input int             InpExtLeftBars = 15;                    // External Pivot Left Bars
input int             InpExtRightBars = 10;                   // External Pivot Right Bars
input int             InpIntLeftBars = 3;                     // Internal Pivot Left Bars
input int             InpIntRightBars = 3;                    // Internal Pivot Right Bars
input int             InpMaxSwingLookback = 300;              // Max Swing Lookback
input int             InpMinBarsBetweenSwings = 3;            // Min Bars Between Swings
input int             InpMaxSwingsDisplay = 20;               // Max Swings to Display

//+------------------------------------------------------------------+
//|              ORDER BLOCK SETTINGS                                  |
//+------------------------------------------------------------------+
input group "══════════════ ORDER BLOCKS ══════════════"
input bool            InpDetectOrderBlocks = true;            // Detect Order Blocks
input bool            InpShowOrderBlocks = true;              // Show Order Blocks
input int             InpOB_Lookback = 20;                    // OB Lookback Bars
input double          InpOB_MinDisplacementATR = 1.5;         // Min Displacement (ATR)
input bool            InpOB_RequireInstitutional = false;     // Require Institutional Candle
input double          InpOB_InstitutionalMultiple = 2.0;      // Institutional Candle Size (ATR)
input int             InpOB_MaxTestCount = 2;                 // Max Test Count Before Invalid
input double InpOB_MinBodyRatio = 0.5;             // OB Min Body-to-Range Ratio
input bool   InpOB_RequireConsecDisplacement = false; // Require 2+ Displacement Candles
input int    InpOB_DisplacementCandles = 1;         // Displacement Candle Count (1-3)
input bool   InpOB_ZoneIncludeWicks = true;         // OB Zone Includes Wicks
input double InpOB_MaxAge_Hours = 72.0;             // OB Max Age (Hours)
input bool   InpDetectBreakerBlocks = true;          // Detect Breaker Blocks
input bool   InpBreaker_RequirePriorTest = true;    // Breaker Requires Prior OB Test
input double InpBreaker_MinDisplacementATR = 1.0;   // Breaker Min Break Displacement (ATR)
input bool   InpDetectMitigationBlocks = true;       // Detect Mitigation Blocks

//+------------------------------------------------------------------+
//|              FAIR VALUE GAP SETTINGS                               |
//+------------------------------------------------------------------+
input group "══════════════ FAIR VALUE GAPS ══════════════"
input bool            InpDetectFVG = true;                    // Detect Fair Value Gaps
input bool            InpShowFVG = true;                      // Show FVG Zones
input int             InpFVG_Lookback = 30;                   // FVG Lookback Bars
input double          InpFVG_MinSizeATR = 0.2;                // Min FVG Size (ATR)
input bool            InpFVG_ShowCE = true;                   // Show Consequent Encroachment
input bool            InpDetectVolumeImbalance = true;        // Detect Volume Imbalance
input bool            InpDetectLiquidityVoid = true;          // Detect Liquidity Voids
input double          InpVoid_MinSizeATR = 1.0;               // Min Void Size (ATR)
input bool   InpFVG_RequireMiddleCandleDir = false; // Require Middle Candle Direction Match
input bool   InpFVG_DetectInverse = false;          // Detect Inverse FVG (IFVG)
input double InpFVG_MinBodyRangeRatio = 0.3;        // FVG Min Middle Candle Body Ratio
//+------------------------------------------------------------------+
//|              OTE & ZONE SETTINGS                                   |
//+------------------------------------------------------------------+
input group "══════════════ OTE & PREMIUM/DISCOUNT ══════════════"
input bool            InpUseOTE = true;                       // Use OTE Zones
input double          InpOTE_Fib618 = 61.8;                   // OTE 61.8% Level
input double          InpOTE_Fib705 = 70.5;                   // OTE 70.5% Level (Optimal)
input double          InpOTE_Fib79 = 79.0;                    // OTE 79% Level
input bool            InpUsePremiumDiscount = true;           // Use Premium/Discount Filter
input int             InpPD_RangeLookback = 50;               // P/D Range Lookback
input double          InpPremiumLevel = 70.0;                 // Premium Level (%)
input double          InpDiscountLevel = 30.0;                // Discount Level (%)
input double          InpEquilibriumBuffer = 5.0;             // Equilibrium Buffer (%)

//+------------------------------------------------------------------+
//|              MARKET PHASE SETTINGS                                 |
//+------------------------------------------------------------------+
input group "══════════════ MARKET PHASE (AMD) ══════════════"
input bool            InpDetectAMD = true;                    // Detect AMD Phases
input int             InpAccumulationBars = 20;               // Accumulation Detection Bars
input double          InpAccumulationRangeATR = 1.5;          // Max Accumulation Range (ATR)
input double          InpManipulationSweepATR = 0.3;          // Manipulation Sweep Size (ATR)
input bool            InpDetectJudasSwing = true;             // Detect Judas Swings
input int             InpJudasLookback = 10;                  // Judas Lookback Bars

//+------------------------------------------------------------------+
//|              KILLZONE SETTINGS                                     |
//+------------------------------------------------------------------+
input group "══════════════ KILLZONES & SESSIONS ══════════════"
input bool            InpUseKillzoneFilter = true;            // Use Killzone Filter
input bool            InpTradeAsianKZ = false;                // Trade Asian Killzone
input int             InpAsianStart = 0;                      // Asian Start Hour (Server)
input int             InpAsianEnd = 6;                        // Asian End Hour (Server)
input bool            InpTradeLondonKZ = true;                // Trade London Killzone
input int             InpLondonOpenStart = 7;                 // London Open Start Hour
input int             InpLondonOpenEnd = 10;                  // London Open End Hour
input int             InpLondonCloseStart = 15;               // London Close Start Hour
input int             InpLondonCloseEnd = 17;                 // London Close End Hour
input bool            InpTradeNYKZ = true;                    // Trade NY Killzone
input int             InpNYOpenStart = 12;                    // NY Open Start Hour
input int             InpNYOpenEnd = 15;                      // NY Open End Hour
input double          InpKZ_ScoreMultiplier = 1.25;           // Killzone Score Multiplier

//+------------------------------------------------------------------+
//|              SMT DIVERGENCE SETTINGS                               |
//+------------------------------------------------------------------+
input group "══════════════ SMT DIVERGENCE ══════════════"
input bool            InpUseSMT = true;                       // Use SMT Divergence
input ENUM_SMT_PAIR   InpSMT_Pair = SMT_PAIR_DXY;             // SMT Correlation Pair
input int             InpSMT_SwingLookback = 15;              // SMT Swing Lookback
input int             InpSMT_TimeTolerance = 3;               // SMT Time Tolerance (Bars)


input group "══════════════ DISPLACEMENT DETECTION ══════════════"
input int    InpDisp_MinConsecutive = 1;            // Min Consecutive Displacement Candles
input double InpDisp_MinBodyPercent = 60.0;         // Min Body % of Candle Range
input bool   InpDisp_RequireFVGCreated = false;     // Require FVG Created by Displacement

//+------------------------------------------------------------------+
//|              ENTRY & CONFIRMATION SETTINGS                         |
//+------------------------------------------------------------------+
input group "══════════════ ENTRY CRITERIA ══════════════"
input bool InpEnableTrading = true;              // Enable Live Trading
input double          InpDisplacementMultiplier = 1.5;        // Displacement Size (ATR)
input int             InpMinStackCount = 2;                   // Min stack count for SM_ELEM_STACKED_PDA


//+------------------------------------------------------------------+
//|              STATE MACHINE ENTRY ENGINE                            |
//+------------------------------------------------------------------+
input group "══════════════ STATE MACHINE ENGINE ══════════════"
input ENUM_SM_PRESET   InpSM_Preset         = SM_PRESET_CHOCH_RETRACE;
input ENUM_SM_INSTANCE_POLICY InpSM_InstancePolicy = SM_INSTANCE_COEXIST;
input int              InpSM_MaxInstances   = 4;
input int              InpSM_GlobalTimeout  = 80;
input bool             InpSM_ShowOnChart    = true;
input bool             InpSM_ShowOnDashboard= true;

// Stage 1: TRIGGER
input ENUM_SM_ELEMENT  InpSM_Trig_Primary     = SM_ELEM_CHOCH_BREAK;
input ENUM_TF_LAYER    InpSM_Trig_PrimaryTF   = LAYER_CTF;        // NEW
input ENUM_SM_ELEMENT  InpSM_Trig_Secondary   = SM_ELEM_EXT_SWEEP;
input ENUM_TF_LAYER    InpSM_Trig_SecondaryTF = LAYER_CTF;        // NEW
input ENUM_SM_LOGIC    InpSM_Trig_Logic       = SM_LOGIC_OR;
input bool             InpSM_Trig_Causal      = false;
input bool             InpSM_Trig_Required    = true;
input int              InpSM_Trig_Timeout     = 0;
input ENUM_SM_DIRECTION_POLICY InpSM_Trig_DirPolicy = SM_DIR_FROM_DR;

// Stage 2: CONFIRMATION
input ENUM_SM_ELEMENT  InpSM_Conf_Primary     = SM_ELEM_DISPLACEMENT;
input ENUM_TF_LAYER    InpSM_Conf_PrimaryTF   = LAYER_CTF;        // NEW
input ENUM_SM_ELEMENT  InpSM_Conf_Secondary   = SM_ELEM_BOS;
input ENUM_TF_LAYER    InpSM_Conf_SecondaryTF = LAYER_CTF;        // NEW
input ENUM_SM_LOGIC    InpSM_Conf_Logic       = SM_LOGIC_AND;
input bool             InpSM_Conf_Causal      = true;
input bool             InpSM_Conf_Required    = true;
input int              InpSM_Conf_Timeout     = 20;
input ENUM_SM_DIRECTION_POLICY InpSM_Conf_DirPolicy = SM_DIR_FROM_TRIGGER;

// Stage 3: VALIDATION
input ENUM_SM_ELEMENT  InpSM_Val_Primary      = SM_ELEM_BOS;
input ENUM_TF_LAYER    InpSM_Val_PrimaryTF    = LAYER_LTF;        // NEW
input ENUM_SM_ELEMENT  InpSM_Val_Secondary    = SM_ELEM_PREMIUM_DISCOUNT;
input ENUM_TF_LAYER    InpSM_Val_SecondaryTF  = LAYER_CTF;        // NEW
input ENUM_SM_LOGIC    InpSM_Val_Logic        = SM_LOGIC_AND;
input bool             InpSM_Val_Causal       = false;
input bool             InpSM_Val_Required     = false;
input int              InpSM_Val_Timeout      = 15;
input ENUM_SM_DIRECTION_POLICY InpSM_Val_DirPolicy = SM_DIR_FROM_TRIGGER;

// Stage 4: ENTRY
input ENUM_SM_ELEMENT  InpSM_Ent_Primary      = SM_ELEM_ORDER_BLOCK;
input ENUM_TF_LAYER    InpSM_Ent_PrimaryTF    = LAYER_CTF;        // NEW
input ENUM_SM_ELEMENT  InpSM_Ent_Secondary    = SM_ELEM_FVG;
input ENUM_TF_LAYER    InpSM_Ent_SecondaryTF  = LAYER_CTF;        // NEW
input ENUM_SM_LOGIC    InpSM_Ent_Logic        = SM_LOGIC_OR;
input bool             InpSM_Ent_Causal       = true;
input bool             InpSM_Ent_Required     = true;
input int              InpSM_Ent_Timeout      = 20;
input ENUM_SM_DIRECTION_POLICY InpSM_Ent_DirPolicy = SM_DIR_FROM_TRIGGER;

//+------------------------------------------------------------------+
//|              RISK MANAGEMENT SETTINGS                              |
//+------------------------------------------------------------------+
input group "══════════════ RISK MANAGEMENT ══════════════"
input ENUM_LOT_MODE   InpLotMode = LOT_RISK_PERCENT;          // Lot Sizing Mode
input double          InpFixedLot = 0.1;                      // Fixed Lot Size
input double          InpRiskPercent = 1.0;                   // Risk Per Trade (%)
input ENUM_SL_MODE    InpSlMode = SL_STRUCTURE;               // Stop Loss Mode
input int             InpFixedSlPoints = 500;                 // Fixed SL (Points)
input double          InpAtrSlMultiplier = 1.5;               // ATR SL Multiplier
input int             InpSlBufferPoints = 30;                 // SL Buffer (Points)
input ENUM_TP_MODE    InpTpMode = TP_STRUCTURE;               // Take Profit Mode
input double          InpRiskReward = 3.0;                    // Fixed Risk:Reward Ratio
input bool InpUsePartialClose = true;            // Use Partial Close
input double          InpAtrTpMultiplier = 3.0;               // ATR TP Multiplier
input bool            InpUseMultipleTP = true;                // Use Multiple TPs
input double          InpTP1_Percent = 40.0;                  // TP1 Close Percent
input double          InpTP1_RR = 1.0;                        // TP1 Risk:Reward
input double          InpTP2_Percent = 30.0;                  // TP2 Close Percent
input double          InpTP2_RR = 2.0;                        // TP2 Risk:Reward
input bool            InpMoveToBreakeven = true;              // Move SL to Breakeven
input double          InpBreakevenAt_RR = 1.0;                // Breakeven at RR
input bool            InpUseTrailingStop = true;              // Use Trailing Stop
input int             InpTrailingStart = 200;                 // Trailing Start (Points)
input int             InpTrailingStep = 100;                  // Trailing Step (Points)

//+------------------------------------------------------------------+
//|         ENHANCED SL/TP SETTINGS (NEW)                              |
//+------------------------------------------------------------------+
input group "══════════════ ENHANCED SL METHODS ══════════════"
input double          InpFibSL_Level = 127.2;                 // Fib SL Extension Level (%)
input int             InpFibSL_SwingLookback = 30;            // Fib SL Swing Lookback Bars
input double          InpMaxLossAmount = 100.0;               // Max Loss Amount (Account Currency)
input double          InpSL_MinDistanceATR = 0.3;             // Min SL Distance (ATR Multiple)
input double          InpSL_MaxDistanceATR = 5.0;             // Max SL Distance (ATR Multiple)

input group "══════════════ ENHANCED TP / PARTIAL CLOSE ══════════════"
input ENUM_PARTIAL_MODE InpPartialMode = PARTIAL_RR_BASED;    // Partial Close Trigger Mode
input double          InpPartialFixedPoints1 = 200;           // Partial Fixed Points TP1
input double          InpPartialFixedPoints2 = 400;           // Partial Fixed Points TP2
input double          InpPartialFixedPoints3 = 600;           // Partial Fixed Points TP3
input double          InpPartialATR_Mult1 = 1.0;              // Partial ATR Multiple TP1
input double          InpPartialATR_Mult2 = 2.0;              // Partial ATR Multiple TP2
input double          InpPartialATR_Mult3 = 3.0;              // Partial ATR Multiple TP3
input double          InpTP3_Percent = 30.0;                  // TP3 Close Percent (Remainder)
input double          InpTP3_RR = 3.0;                        // TP3 Risk:Reward
input bool            InpShowDR_TargetLines = true;           // Show DR Target Lines on Chart
input color           InpDR_TargetLineColor = clrGold;        // DR Target Line Color

//+------------------------------------------------------------------+
//|              TRADE FILTERS                                         |
//+------------------------------------------------------------------+
input group "══════════════ TRADE FILTERS ══════════════"
input bool            InpUseDayFilter = true;                 // Use Day Filter
input bool            InpTradeMonday = true;                  // Trade Monday
input bool            InpTradeTuesday = true;                 // Trade Tuesday
input bool            InpTradeWednesday = true;               // Trade Wednesday
input bool            InpTradeThursday = true;                // Trade Thursday
input bool            InpTradeFriday = true;                  // Trade Friday
input bool            InpUseSpreadFilter = true;              // Use Spread Filter
input int             InpMaxSpread = 30;                      // Max Spread (Points)
input bool            InpUseMaxTrades = true;                 // Limit Daily Trades
input int             InpMaxDailyTrades = 5;                  // Max Daily Trades
input bool            InpUseMaxLoss = true;                   // Use Daily Loss Limit
input double          InpMaxDailyLossPercent = 3.0;           // Max Daily Loss (%)
input bool            InpAvoidNews = false;                   // Avoid News Events
input int             InpNewsMinutesBefore = 30;              // News Avoid Before (Min)
input int             InpNewsMinutesAfter = 30;               // News Avoid After (Min)

//+------------------------------------------------------------------+
//|              DISPLAY SETTINGS                                      |
//+------------------------------------------------------------------+
input group "══════════════ DISPLAY SETTINGS ══════════════"
input ENUM_DASHBOARD_MODE InpDashboardMode = DASH_FULL;       // Dashboard Mode
input int             InpDashboardX = 20;                     // Dashboard X Position
input int             InpDashboardY = 30;                     // Dashboard Y Position
input ENUM_BASE_CORNER InpDashboardCorner = CORNER_LEFT_UPPER;  // Dashboard Corner
input bool            InpShowDealingRange = true;             // Show Dealing Range
input bool            InpShowCorrectionLines = true;          // Show Correction Lines
input bool            InpShowDR_Origins = true;               // Show DR Origins
input bool            InpShowDR_Externals = true;             // Show External Inducements
input bool            InpShowDR_Internals = true;             // Show Internal Levels
input bool            InpShowDR_Targets = true;               // Show DR Targets
input bool            InpShowEntryZone = true;                // Show Entry Zone
input bool            InpShowEntryArrows = true;              // Show Entry Arrows

input group "══════════════ CL LINE THICKNESS ══════════════"
input int    InpHTF_MainCLWidth = 4;    // HTF Main CL Vertical Width
input int    InpHTF_PB_CLWidth  = 2;    // HTF Pullback CL Vertical Width
input int    InpCTF_MainCLWidth = 3;    // CTF Main CL Vertical Width
input int    InpCTF_PB_CLWidth  = 1;    // CTF Pullback CL Vertical Width
input int    InpLTF_MainCLWidth = 2;    // LTF Main CL Vertical Width
input int    InpLTF_PB_CLWidth  = 1;    // LTF Pullback CL Vertical Width

//+------------------------------------------------------------------+
//|              COLOR SETTINGS                                        |
//+------------------------------------------------------------------+
input group "══════════════ COLORS ══════════════"
input color           InpBullCL_Color = clrLime;              // Bullish CL Color
input color           InpBearCL_Color = clrRed;               // Bearish CL Color
input color           InpOriginChochColor = clrMagenta;       // Origin (ChoCh) Color
input color           InpOriginTargetColor = clrGold;         // Target Color
input color           InpOriginDimColor = clrDimGray;         // Dimmed Level Color
input color           InpExtInducementColor = clrOrange;      // External Inducement Color
input color           InpInternalLevelColor = clrSilver;      // Internal Level Color
input color           InpExternalHighColor = clrRed;           // External Swing High Color
input color           InpExternalLowColor = clrLime;            // External Swing Low Color
input color           InpInternalHighColor = clrSalmon;         // Internal Swing High Color
input color           InpInternalLowColor = clrPaleGreen;       // Internal Swing Low Color
input color           InpBullOB_Color = clrDarkGreen;         // Bullish OB Color
input color           InpBearOB_Color = clrDarkRed;           // Bearish OB Color
input color           InpBreakerColor = clrDarkViolet;        // Breaker Block Color
input color           InpMBColor = clrDarkCyan;               // Mitigation Block Color
input color           InpBullFVG_Color = C'0,100,0';          // Bullish FVG Color
input color           InpBearFVG_Color = C'100,0,0';          // Bearish FVG Color
input color           InpEntryZoneColor = clrYellow;          // Entry Zone Color
input color           InpOTEZoneColor = clrMediumPurple;      // OTE Zone Color


//+------------------------------------------------------------------+
//|              ALERT SETTINGS                                        |
//+------------------------------------------------------------------+
input group "══════════════ ALERTS ══════════════"
input bool            InpAlertSignals = true;                 // Alert on Signals
input bool            InpAlertTrades = true;                  // Alert on Trade Execution
input bool            InpAlertStructure = true;               // Alert on Structure Shifts
input bool            InpPushNotification = false;            // Send Push Notifications
input bool            InpEmailNotification = false;           // Send Email Notifications

//+------------------------------------------------------------------+
//|              GENERAL SETTINGS                                      |
//+------------------------------------------------------------------+
input group "══════════════ GENERAL ══════════════"
input ulong           InpMagicNumber = 20240801;              // Magic Number
input string          InpTradeComment = "ICT_Unified";        // Trade Comment
input int             InpMaxSlippage = 30;                    // Max Slippage (Points)
input ENUM_FILLING_MODE InpFillingMode = FILL_IOC;            // Order Fill Mode
input int             InpMaxBarsBack = 5000;                  // Max Bars Back


//+------------------------------------------------------------------+
//|              ML ENGINE SETTINGS (ENHANCED)                         |
//+------------------------------------------------------------------+
input group "══════════════ ML ENGINE ══════════════"
input ENUM_ML_MODE    InpML_Mode = ML_OFF;                    // ML Mode
input double          InpML_LearningRate = 0.01;              // Learning Rate
input double          InpML_DecayRate = 0.0005;               // Learning Rate Decay (reduced)
input int             InpML_WarmupTrades = 20;                // Warmup Trades (Pure Observation)
input int             InpML_MinSamplesFilter = 50;            // Min Samples Before Filtering
input double          InpML_MinAccuracyFilter = 52.0;         // Min Accuracy Before Filtering (%)
input double          InpML_WeightBound = 3.0;                // Max Weight Magnitude
input double          InpML_RegStrength = 0.001;              // L2 Regularization
input double          InpML_MinProbability = 0.55;            // Min Win Probability to Trade
input bool            InpML_FreezeLearning = false;           // Freeze Learning (Use Current)
input bool            InpML_AutoSave = true;                  // Auto-Save Weights to File
input int             InpML_SaveInterval = 10;                // Save Every N Trades
input string          InpML_SavePath = "ICT_ML_Weights";      // Weight File Name
input bool            InpML_ShowDashboard = true;             // Show ML Dashboard
input int             InpML_DashX = 0;                        // ML Dashboard X (0=Auto Right)
input int             InpML_DashY = 30;                       // ML Dashboard Y Position
input double          InpML_ScoreAdjustMax = 15.0;            // Max Score Adjustment (±)
input bool            InpML_ResetOnStart = false;             // Reset Weights on Init

//+------------------------------------------------------------------+
//|              EXTERNAL PROVIDER SETTINGS                            |
//+------------------------------------------------------------------+
input group "══════════════ EXTERNAL PROVIDERS ══════════════"
input ENUM_PROVIDER_MODE InpProviderMode = PROV_DISABLED;     // Provider Integration Mode
input ENUM_CONFLICT_RESOLUTION InpConflictMode = CONFLICT_INTERNAL_WINS; // Conflict Resolution

input bool            InpProvider1_Enable = false;            // Provider 1 Enable
input string          InpProvider1_Name = "";                 // Provider 1 Indicator Name
input double          InpProvider1_Weight = 1.0;              // Provider 1 Weight
input bool            InpProvider2_Enable = false;            // Provider 2 Enable
input string          InpProvider2_Name = "";                 // Provider 2 Indicator Name
input double          InpProvider2_Weight = 1.0;              // Provider 2 Weight
input bool            InpProvider3_Enable = false;            // Provider 3 Enable
input string          InpProvider3_Name = "";                 // Provider 3 Indicator Name
input double          InpProvider3_Weight = 1.0;              // Provider 3 Weight

input double          InpExternalMinConfidence = 50.0;        // Min External Confidence (0-100)
input int             InpExternalExpirationBars = 20;         // Signal Expiration (Bars)
input bool            InpExternalUseOwnSLTP = false;          // Use External SL/TP
input double          InpInternalWeight = 0.6;                // Internal Score Weight (Blend)
input double          InpExternalWeight = 0.4;                // External Score Weight (Blend)


#endif // ICT_CONFIG_MQH