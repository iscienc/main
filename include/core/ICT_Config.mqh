//+------------------------------------------------------------------+
//|                         ICT_Config.mqh                            |
//|                    Input Parameters Configuration                 |
//+------------------------------------------------------------------+
#ifndef ICT_CONFIG_MQH
#define ICT_CONFIG_MQH

//+------------------------------------------------------------------+
//|              MULTI-TIMEFRAME CONFIGURATION                        |
//+------------------------------------------------------------------+
input group "══════════════ MULTI-TIMEFRAME SETTINGS ══════════════"
input ENUM_TIMEFRAMES InpHTF_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES InpLTF_Timeframe = PERIOD_M1;
input bool            InpEnableHTF = true;
input bool            InpEnableLTF = true;

//+------------------------------------------------------------------+
//|              DEALING RANGE STRUCTURE SETTINGS                     |
//+------------------------------------------------------------------+
input group "══════════════ DEALING RANGE STRUCTURE ══════════════"
input int               InpCL_PivotLeftBars = 3;
input int               InpCL_PivotRightBars = 3;
input int               InpDR_ExtPivotLeftBars = 5;
input int               InpDR_ExtPivotRightBars = 3;
input int               InpDR_IntPivotLeftBars = 3;
input int               InpDR_IntPivotRightBars = 2;
input int               InpInitScanBars = 200;
input int               InpMinBarsBetweenOrigins = 5;
input ENUM_SWEEP_METHOD InpSweepMethod = SWEEP_WICK_CLOSE_BACK;
input ENUM_BREAK_METHOD InpBreakMethod = BREAK_CANDLE_CLOSE;
input int               InpMaxOriginsTrack = 5;
input int               InpMaxExtInducements = 10;
input double            InpExtMinDepthATR = 0.3;
input int               InpExtMinPivotScore = 1;
input double            InpExtMinDistanceATR = 0.2;
input bool              InpExtRequireBOS = false;
input double            InpExtBOS_MoveATR = 0.5;
input bool              InpUseDistanceDim = true;
input double            InpDimDistanceATR = 5.0;

enum ENUM_CL_UPDATE_MODE
  {
   CL_PULLBACK_REQUIRED = 0,
   CL_IMMEDIATE_EXTREME = 1,
   CL_PIVOT_CONFIRMED   = 2
  };

input ENUM_CL_UPDATE_MODE InpCL_UpdateMode = CL_PIVOT_CONFIRMED;
input int                 InpCL_ForceUpdateBars = 30;
input double              InpCL_PullbackMinATR = 0.2;

input group "══════════════ PULLBACK STRUCTURE DETECTION ══════════════"
input bool  InpDetectPullbackStructure = true;
input int   InpMaxPullbackCounters = 10;
input bool  InpShowPullbackOrigin = true;
input bool  InpShowPullbackCL = true;
input bool  InpShowPullbackCounters = true;
input color InpPullbackOriginColor = clrDeepPink;
input color InpPullbackCLColor = clrDodgerBlue;
input color InpPullbackCounterColor = clrDarkKhaki;

//+------------------------------------------------------------------+
//|              SWING DETECTION SETTINGS                             |
//+------------------------------------------------------------------+
input group "══════════════ SWING DETECTION ══════════════"
input bool InpShowSwingPoints = true;
input bool InpShowExternalSwings = true;
input bool InpShowInternalSwings = false;
input int  InpExtLeftBars = 15;
input int  InpExtRightBars = 10;
input int  InpIntLeftBars = 3;
input int  InpIntRightBars = 3;
input int  InpMaxSwingLookback = 300;
input int  InpMinBarsBetweenSwings = 3;
input int  InpMaxSwingsDisplay = 20;

//+------------------------------------------------------------------+
//|              ORDER BLOCK SETTINGS                                 |
//+------------------------------------------------------------------+
input group "══════════════ ORDER BLOCKS ══════════════"
input int    InpOB_Lookback = 20;
input double InpOB_MinDisplacementATR = 1.5;
input bool   InpOB_RequireInstitutional = false;
input double InpOB_InstitutionalMultiple = 2.0;
input int    InpOB_MaxTestCount = 2;
input double InpOB_MinBodyRatio = 0.5;
input bool   InpOB_RequireConsecDisplacement = false;
input int    InpOB_DisplacementCandles = 1;
input bool   InpOB_ZoneIncludeWicks = true;
input double InpOB_MaxAge_Hours = 72.0;
input bool   InpBreaker_RequirePriorTest = true;
input double InpBreaker_MinDisplacementATR = 1.0;

//+------------------------------------------------------------------+
//|              FAIR VALUE GAP SETTINGS                              |
//+------------------------------------------------------------------+
input group "══════════════ FAIR VALUE GAPS ══════════════"
input int    InpFVG_Lookback = 30;
input double InpFVG_MinSizeATR = 0.2;
input double InpVoid_MinSizeATR = 1.0;
input bool   InpFVG_RequireMiddleCandleDir = false;
input bool   InpFVG_DetectInverse = false;
input double InpFVG_MinBodyRangeRatio = 0.3;

//+------------------------------------------------------------------+
//|              OTE SETTINGS                                         |
//+------------------------------------------------------------------+
input group "══════════════ OTE SETTINGS ══════════════"
input bool   InpUseOTE = true;
input double InpOTE_Fib618 = 61.8;
input double InpOTE_Fib705 = 70.5;
input double InpOTE_Fib79 = 79.0;

//+------------------------------------------------------------------+
//|              MARKET PHASE SETTINGS                                |
//+------------------------------------------------------------------+
input group "══════════════ MARKET PHASE (AMD) ══════════════"
input int    InpAccumulationBars = 20;
input double InpAccumulationRangeATR = 1.5;
input double InpManipulationSweepATR = 0.3;
input int    InpJudasLookback = 10;

//+------------------------------------------------------------------+
//|              KILLZONE SETTINGS                                    |
//+------------------------------------------------------------------+
input group "══════════════ KILLZONES & SESSIONS ══════════════"
input bool   InpUseKillzoneFilter = true;
input bool   InpTradeAsianKZ = false;
input int    InpAsianStart = 0;
input int    InpAsianEnd = 6;
input bool   InpTradeLondonKZ = true;
input int    InpLondonOpenStart = 7;
input int    InpLondonOpenEnd = 10;
input int    InpLondonCloseStart = 15;
input int    InpLondonCloseEnd = 17;
input bool   InpTradeNYKZ = true;
input int    InpNYOpenStart = 12;
input int    InpNYOpenEnd = 15;
input double InpKZ_ScoreMultiplier = 1.25;

//+------------------------------------------------------------------+
//|              SMT DIVERGENCE SETTINGS                              |
//+------------------------------------------------------------------+
input group "══════════════ SMT DIVERGENCE ══════════════"
input ENUM_SMT_PAIR InpSMT_Pair = SMT_PAIR_DXY;
input int           InpSMT_SwingLookback = 15;
input int           InpSMT_TimeTolerance = 3;

input group "══════════════ DISPLACEMENT DETECTION ══════════════"
input int    InpDisp_MinConsecutive = 1;
input double InpDisp_MinBodyPercent = 60.0;
input bool   InpDisp_RequireFVGCreated = false;

//+------------------------------------------------------------------+
//|              ENTRY SETTINGS                                       |
//+------------------------------------------------------------------+
input group "══════════════ ENTRY CRITERIA ══════════════"
input bool   InpEnableTrading = true;
input double InpDisplacementMultiplier = 1.5;

//+------------------------------------------------------------------+
//|              STATE MACHINE ENGINE                                 |
//+------------------------------------------------------------------+
input group "══════════════ STATE MACHINE ENGINE ══════════════"
input ENUM_SM_PRESET          InpSM_Preset = SM_PRESET_CHOCH_RETRACE;
input ENUM_SM_INSTANCE_POLICY InpSM_InstancePolicy = SM_INSTANCE_COEXIST;
input int                     InpSM_MaxInstances = 4;
input int                     InpSM_GlobalTimeout = 80;
input bool                    InpSM_ShowOnChart = true;
input bool                    InpSM_ShowOnDashboard = true;
input bool                    InpSM_ShowLoadedElementsOnChart = true; // Single chart-visibility input
input bool                    InpSM_ShowPerformanceTelemetry = true;
input int                     InpSM_PerfWarnThresholdUs = 6000; // auto-warn threshold per tick (microseconds)

// Stage 1
input ENUM_SM_ELEMENT          InpSM_Trig_Primary = SM_ELEM_CHOCH_BREAK;
input ENUM_TF_LAYER            InpSM_Trig_PrimaryTF = LAYER_CTF;
input ENUM_SM_ELEMENT          InpSM_Trig_Secondary = SM_ELEM_EXT_SWEEP;
input ENUM_TF_LAYER            InpSM_Trig_SecondaryTF = LAYER_CTF;
input ENUM_SM_LOGIC            InpSM_Trig_Logic = SM_LOGIC_OR;
input bool                     InpSM_Trig_Causal = false;
input bool                     InpSM_Trig_Required = true;
input int                      InpSM_Trig_Timeout = 0;
input ENUM_SM_DIRECTION_POLICY InpSM_Trig_DirPolicy = SM_DIR_FROM_DR;

// Stage 2
input ENUM_SM_ELEMENT          InpSM_Conf_Primary = SM_ELEM_DISPLACEMENT;
input ENUM_TF_LAYER            InpSM_Conf_PrimaryTF = LAYER_CTF;
input ENUM_SM_ELEMENT          InpSM_Conf_Secondary = SM_ELEM_BOS;
input ENUM_TF_LAYER            InpSM_Conf_SecondaryTF = LAYER_CTF;
input ENUM_SM_LOGIC            InpSM_Conf_Logic = SM_LOGIC_AND;
input bool                     InpSM_Conf_Causal = true;
input bool                     InpSM_Conf_Required = true;
input int                      InpSM_Conf_Timeout = 20;
input ENUM_SM_DIRECTION_POLICY InpSM_Conf_DirPolicy = SM_DIR_FROM_TRIGGER;

// Stage 3
input ENUM_SM_ELEMENT          InpSM_Val_Primary = SM_ELEM_BOS;
input ENUM_TF_LAYER            InpSM_Val_PrimaryTF = LAYER_LTF;
input ENUM_SM_ELEMENT          InpSM_Val_Secondary = SM_ELEM_NONE;
input ENUM_TF_LAYER            InpSM_Val_SecondaryTF = LAYER_CTF;
input ENUM_SM_LOGIC            InpSM_Val_Logic = SM_LOGIC_AND;
input bool                     InpSM_Val_Causal = false;
input bool                     InpSM_Val_Required = false;
input int                      InpSM_Val_Timeout = 15;
input ENUM_SM_DIRECTION_POLICY InpSM_Val_DirPolicy = SM_DIR_FROM_TRIGGER;

// Stage 4
input ENUM_SM_ELEMENT          InpSM_Ent_Primary = SM_ELEM_ORDER_BLOCK;
input ENUM_TF_LAYER            InpSM_Ent_PrimaryTF = LAYER_CTF;
input ENUM_SM_ELEMENT          InpSM_Ent_Secondary = SM_ELEM_FVG;
input ENUM_TF_LAYER            InpSM_Ent_SecondaryTF = LAYER_CTF;
input ENUM_SM_LOGIC            InpSM_Ent_Logic = SM_LOGIC_OR;
input bool                     InpSM_Ent_Causal = true;
input bool                     InpSM_Ent_Required = true;
input int                      InpSM_Ent_Timeout = 20;
input ENUM_SM_DIRECTION_POLICY InpSM_Ent_DirPolicy = SM_DIR_FROM_TRIGGER;

//+------------------------------------------------------------------+
//|              RISK MANAGEMENT SETTINGS                             |
//+------------------------------------------------------------------+
input group "══════════════ RISK MANAGEMENT ══════════════"
input ENUM_LOT_MODE InpLotMode = LOT_RISK_PERCENT;
input double        InpFixedLot = 0.1;
input double        InpRiskPercent = 1.0;
input ENUM_SL_MODE  InpSlMode = SL_STRUCTURE;
input int           InpFixedSlPoints = 500;
input double        InpAtrSlMultiplier = 1.5;
input int           InpSlBufferPoints = 30;
input ENUM_TP_MODE  InpTpMode = TP_STRUCTURE;
input double        InpRiskReward = 3.0;
input bool          InpUsePartialClose = true;
input double        InpAtrTpMultiplier = 3.0;
input bool          InpUseMultipleTP = true;
input double        InpTP1_Percent = 40.0;
input double        InpTP1_RR = 1.0;
input double        InpTP2_Percent = 30.0;
input double        InpTP2_RR = 2.0;
input bool          InpMoveToBreakeven = true;
input double        InpBreakevenAt_RR = 1.0;
input bool          InpUseTrailingStop = true;
input int           InpTrailingStart = 200;
input int           InpTrailingStep = 100;

input group "══════════════ ENHANCED SL METHODS ══════════════"
input double InpFibSL_Level = 127.2;
input int    InpFibSL_SwingLookback = 30;
input double InpMaxLossAmount = 100.0;
input double InpSL_MinDistanceATR = 0.3;
input double InpSL_MaxDistanceATR = 5.0;

input group "══════════════ ENHANCED TP / PARTIAL CLOSE ══════════════"
input ENUM_PARTIAL_MODE InpPartialMode = PARTIAL_RR_BASED;
input double InpPartialFixedPoints1 = 200;
input double InpPartialFixedPoints2 = 400;
input double InpPartialFixedPoints3 = 600;
input double InpPartialATR_Mult1 = 1.0;
input double InpPartialATR_Mult2 = 2.0;
input double InpPartialATR_Mult3 = 3.0;
input double InpTP3_Percent = 30.0;
input double InpTP3_RR = 3.0;
input bool   InpShowDR_TargetLines = true;
input color  InpDR_TargetLineColor = clrGold;

//+------------------------------------------------------------------+
//|              TRADE FILTERS                                        |
//+------------------------------------------------------------------+
input group "══════════════ TRADE FILTERS ══════════════"
input bool   InpUseDayFilter = true;
input bool   InpTradeMonday = true;
input bool   InpTradeTuesday = true;
input bool   InpTradeWednesday = true;
input bool   InpTradeThursday = true;
input bool   InpTradeFriday = true;
input bool   InpUseSpreadFilter = true;
input int    InpMaxSpread = 30;
input bool   InpUseMaxTrades = true;
input int    InpMaxDailyTrades = 5;
input bool   InpUseMaxLoss = true;
input double InpMaxDailyLossPercent = 3.0;
input bool   InpAvoidNews = false;
input int    InpNewsMinutesBefore = 30;
input int    InpNewsMinutesAfter = 30;

//+------------------------------------------------------------------+
//|              DISPLAY SETTINGS                                     |
//+------------------------------------------------------------------+
input group "══════════════ DISPLAY SETTINGS ══════════════"
input ENUM_DASHBOARD_MODE InpDashboardMode = DASH_FULL;
input int                 InpDashboardX = 20;
input int                 InpDashboardY = 30;
input ENUM_BASE_CORNER    InpDashboardCorner = CORNER_LEFT_UPPER;
input bool                InpShowDealingRange = true;
input bool                InpShowCorrectionLines = true;
input bool                InpShowDR_Origins = true;
input bool                InpShowDR_Externals = true;
input bool                InpShowDR_Internals = true;
input bool                InpShowDR_Targets = true;
input bool                InpShowEntryZone = true;
input bool                InpShowEntryArrows = true;

input group "══════════════ CL LINE THICKNESS ══════════════"
input int InpHTF_MainCLWidth = 4;
input int InpHTF_PB_CLWidth  = 2;
input int InpCTF_MainCLWidth = 3;
input int InpCTF_PB_CLWidth  = 1;
input int InpLTF_MainCLWidth = 2;
input int InpLTF_PB_CLWidth  = 1;

//+------------------------------------------------------------------+
//|              COLOR SETTINGS                                       |
//+------------------------------------------------------------------+
input group "══════════════ COLORS ══════════════"
input color InpBullCL_Color = clrLime;
input color InpBearCL_Color = clrRed;
input color InpOriginChochColor = clrMagenta;
input color InpOriginTargetColor = clrGold;
input color InpOriginDimColor = clrDimGray;
input color InpExtInducementColor = clrOrange;
input color InpInternalLevelColor = clrSilver;
input color InpExternalHighColor = clrRed;
input color InpExternalLowColor = clrLime;
input color InpInternalHighColor = clrSalmon;
input color InpInternalLowColor = clrPaleGreen;
input color InpBullOB_Color = clrDarkGreen;
input color InpBearOB_Color = clrDarkRed;
input color InpBreakerColor = clrDarkViolet;
input color InpMBColor = clrDarkCyan;
input color InpBullFVG_Color = C'0,100,0';
input color InpBearFVG_Color = C'100,0,0';
input color InpEntryZoneColor = clrYellow;
input color InpOTEZoneColor = clrMediumPurple;

//+------------------------------------------------------------------+
//|              ALERT SETTINGS                                       |
//+------------------------------------------------------------------+
input group "══════════════ ALERTS ══════════════"
input bool InpAlertSignals = true;
input bool InpAlertTrades = true;
input bool InpAlertStructure = true;
input bool InpPushNotification = false;
input bool InpEmailNotification = false;

//+------------------------------------------------------------------+
//|              GENERAL SETTINGS                                     |
//+------------------------------------------------------------------+
input group "══════════════ GENERAL ══════════════"
input ulong             InpMagicNumber = 20240801;
input string            InpTradeComment = "ICT_Unified";
input int               InpMaxSlippage = 30;
input ENUM_FILLING_MODE InpFillingMode = FILL_IOC;
input int               InpMaxBarsBack = 5000;

//+------------------------------------------------------------------+
//|              ML ENGINE SETTINGS                                   |
//+------------------------------------------------------------------+
input group "══════════════ ML ENGINE ══════════════"
input ENUM_ML_MODE InpML_Mode = ML_OFF;
input double       InpML_LearningRate = 0.01;
input double       InpML_DecayRate = 0.0005;
input int          InpML_WarmupTrades = 20;
input int          InpML_MinSamplesFilter = 50;
input double       InpML_MinAccuracyFilter = 52.0;
input double       InpML_WeightBound = 3.0;
input double       InpML_RegStrength = 0.001;
input double       InpML_MinProbability = 0.55;
input bool         InpML_FreezeLearning = false;
input bool         InpML_AutoSave = true;
input int          InpML_SaveInterval = 10;
input string       InpML_SavePath = "ICT_ML_Weights";
input bool         InpML_ShowDashboard = true;
input int          InpML_DashX = 0;
input int          InpML_DashY = 30;
input double       InpML_ScoreAdjustMax = 15.0;
input bool         InpML_ResetOnStart = false;

//+------------------------------------------------------------------+
//|              EXTERNAL PROVIDER SETTINGS                           |
//+------------------------------------------------------------------+
input group "══════════════ EXTERNAL PROVIDERS ══════════════"
input ENUM_PROVIDER_MODE      InpProviderMode = PROV_DISABLED;
input ENUM_CONFLICT_RESOLUTION InpConflictMode = CONFLICT_INTERNAL_WINS;

input bool   InpProvider1_Enable = false;
input string InpProvider1_Name = "";
input double InpProvider1_Weight = 1.0;
input bool   InpProvider2_Enable = false;
input string InpProvider2_Name = "";
input double InpProvider2_Weight = 1.0;
input bool   InpProvider3_Enable = false;
input string InpProvider3_Name = "";
input double InpProvider3_Weight = 1.0;

input double InpExternalMinConfidence = 50.0;
input int    InpExternalExpirationBars = 20;
input bool   InpExternalUseOwnSLTP = false;
input double InpInternalWeight = 0.6;
input double InpExternalWeight = 0.4;



#endif // ICT_CONFIG_MQH
//+------------------------------------------------------------------+
