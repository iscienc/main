//+------------------------------------------------------------------+
//|                          ICT_Types.mqh                            |
//|              All Enumerations and Structure Definitions            |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_TYPES_MQH
#define ICT_TYPES_MQH

#define SM_MAX_STAGES     4
#define SM_MAX_INSTANCES  8
//+------------------------------------------------------------------+
//|                     SECTION 1: CORE ENUMERATIONS                   |
//+------------------------------------------------------------------+

//--- Trading Direction
enum ENUM_TRADE_DIRECTION
  {
   DIR_NONE = 0,
   DIR_BULLISH = 1,
   DIR_BEARISH = 2
  };

//--- Trend State
enum ENUM_TREND_STATE
  {
   TREND_NONE = 0,
   TREND_BULLISH = 1,
   TREND_BEARISH = 2,
   TREND_CONSOLIDATION = 3
  };

//--- Entry Style


//--- Entry Framework Mode (Stack vs State Machine)
enum ENUM_ENTRY_FRAMEWORK_MODE
  {
   FRAMEWORK_NARRATIVE_SM = 0,   // Pure Narrative SM
   FRAMEWORK_STATE_MACHINE = 1   // Backward compatibility
  };

//--- State Machine Element Types (what each stage looks for)
enum ENUM_SM_ELEMENT
  {
   SM_ELEM_NONE = 0,
   SM_ELEM_CHOCH_BREAK,         // Origin (ChoCh) break
   SM_ELEM_BOS,                 // CL BOS
   SM_ELEM_EXT_SWEEP,           // External inducement swept
   SM_ELEM_JUDAS_SWING,         // Judas detected
   SM_ELEM_DISPLACEMENT,        // Displacement candle(s)
   SM_ELEM_ORDER_BLOCK,         // OB zone
   SM_ELEM_FVG,                 // FVG zone
   SM_ELEM_IFVG,
   SM_ELEM_FVG_CE,              // Consequence Encroachment (FVG has CE level + CE reached state)
   SM_ELEM_VOLUME_IMBALANCE,    // VOLUME_IMBALANCE (FVG VI list + status updates).
   SM_ELEM_LIQUIDITY_VOID,      // LIQUIDITY_VOID (FVG void list + status)
   SM_ELEM_BREAKER,             // Breaker block
   SM_ELEM_MITIGATION,          // Mitigation block
   SM_ELEM_OTE_ZONE,            // Price in OTE
   SM_ELEM_BODY_CLOSE,          // Body close confirmation candle
   SM_ELEM_RETRACE_TO_EZ,       // Retrace to Entry Zone
   SM_ELEM_SMT_DIVERGENCE,      // SMT confirmed
   SM_ELEM_DR_TARGET_AREA,      // Near DR target line
   SM_ELEM_KILLZONE,            // Inside allowed killzone
   SM_ELEM_AMD_DISTRIBUTION,
   SM_ELEM_AMD_MANIPULATION,
   SM_ELEM_AMD_ACCUMULATION,
   SM_ELEM_PROVIDER1_SIGNAL,
   SM_ELEM_PROVIDER2_SIGNAL,
   SM_ELEM_PROVIDER3_SIGNAL
  };

//--- Stage logic between primary and secondary element
enum ENUM_SM_LOGIC
  {
   SM_LOGIC_SINGLE = 0,   // Only primary element checked
   SM_LOGIC_AND    = 1,   // Primary AND secondary required
   SM_LOGIC_OR     = 2    // Primary OR secondary sufficient
  };

//--- Stage roles
enum ENUM_SM_STAGE_ROLE
  {
   SM_STAGE_TRIGGER = 0,
   SM_STAGE_CONFIRMATION = 1,
   SM_STAGE_VALIDATION = 2,
   SM_STAGE_ENTRY = 3
  };

//--- Direction policy per stage
enum ENUM_SM_DIRECTION_POLICY
  {
   SM_DIR_FROM_TRIGGER = 0, // Use direction inherited from Trigger stage
   SM_DIR_FROM_DR = 1, // Use current DR direction
   SM_DIR_FROM_AMD = 2, // Use AMD expectedDirection
   SM_DIR_COUNTER_TRIGGER = 3, // ★ NEW: Opposite of Trigger direction
   SM_DIR_INVERT_TRIGGER = 4, // ★ NEW: Flip Trigger direction (alias)
   SM_DIR_FIXED_BULL = 5, // ★ NEW: Always DIR_BULLISH
   SM_DIR_FIXED_BEAR = 6 // ★ NEW: Always DIR_BEARISH
  };

//--- Instance coexist policy
enum ENUM_SM_INSTANCE_POLICY
  {
   SM_INSTANCE_REPLACE = 0,  // New Trigger replaces all existing instances
   SM_INSTANCE_COEXIST = 1   // Multiple instances allowed
  };

//--- Preset patterns
enum ENUM_SM_PRESET
  {
   SM_PRESET_CUSTOM         = 0,
   SM_PRESET_CHOCH_RETRACE  = 1,
   SM_PRESET_SWEEP_BOS_FVG  = 2,
   SM_PRESET_JUDAS_REVERSAL = 3,
   SM_PRESET_OTE_PULLBACK   = 4,
   SM_PRESET_SMT_REVERSAL   = 5,
   SM_PRESET_MTF_NARRATIVE  = 6,    // NEW: Full cross-TF narrative
   SM_PRESET_BEARISH_SWEEP_BULLISH_ENTRY = 7, // ★ NEW
   SM_PRESET_BULLISH_SWEEP_BEARISH_ENTRY = 8 // ★ NEW
  };
//--- Lot Sizing Mode
enum ENUM_LOT_MODE
  {
   LOT_FIXED = 0,             // Fixed Lot Size
   LOT_RISK_PERCENT = 1,      // Risk Percentage
   LOT_BALANCE_PERCENT = 2    // Balance Percentage
  };

//--- Stop Loss Mode
enum ENUM_SL_MODE
  {
   SL_FIXED_POINTS = 0,       // Fixed Points
   SL_ATR_BASED = 1,          // ATR Multiplier
   SL_STRUCTURE = 2,          // Structure Based (DR Origin)
   SL_SWING = 3,              // Recent Swing
   SL_FVG_CANDLE = 4,         // Behind FVG First Candle
   SL_FIB_EXTENSION = 5,      // Fibonacci Extension Beyond Swing
   SL_MAX_LOSS_AMOUNT = 6,    // Fixed Dollar/Currency Amount
   SL_COMPOSITE = 7           // Tightest Valid of All Methods
  };

//--- Take Profit Mode
enum ENUM_TP_MODE
  {
   TP_FIXED_RR = 0,           // Fixed Risk:Reward (Single TP)
   TP_STRUCTURE = 1,          // DR Structure Targets
   TP_ATR_BASED = 2,          // ATR Multiplier
   TP_MULTIPLE_RR = 3,        // Multiple TPs (RR-based)
   TP_DR_TARGETS = 4          // DR Reclassified Target Lines
  };

//--- Dashboard Mode
enum ENUM_DASHBOARD_MODE
  {
   DASH_FULL = 0,             // Full (All Panels)
   DASH_STANDARD = 1,         // Standard (Main + Scores)
   DASH_COMPACT = 2,          // Compact (Essential Only)
   DASH_MINIMAL = 3,          // Minimal (Text Only)
   DASH_OFF = 4               // Off
  };

//--- Order Filling Mode
enum ENUM_FILLING_MODE
  {
   FILL_FOK = 0,              // Fill or Kill
   FILL_IOC = 1,              // Immediate or Cancel
   FILL_RETURN = 2            // Return
  };

//+------------------------------------------------------------------+
//|                 SECTION 2: TIMEFRAME ENUMERATIONS                  |
//+------------------------------------------------------------------+

enum ENUM_TF_LAYER
  {
   LAYER_HTF = 0,             // Higher Timeframe
   LAYER_CTF = 1,             // Current Timeframe
   LAYER_LTF = 2              // Lower Timeframe
  };

//+------------------------------------------------------------------+
//|                SECTION 3: DEALING RANGE ENUMERATIONS               |
//+------------------------------------------------------------------+

//--- Sweep Detection Method
enum ENUM_SWEEP_METHOD
  {
   SWEEP_ANY_TOUCH = 0,       // Any Wick Touch
   SWEEP_WICK_CLOSE_BACK = 1, // Wick Through + Close Back
   SWEEP_BODY_CLOSE = 2       // Body Closes Through
  };

//--- Break Detection Method
enum ENUM_BREAK_METHOD
  {
   BREAK_ANY_TOUCH = 0,       // Any Touch
   BREAK_CANDLE_CLOSE = 1,    // Candle Close Beyond
   BREAK_FULL_BODY = 2        // Full Body Beyond
  };

//--- Origin Role
enum ENUM_ORIGIN_ROLE
  {
   ROLE_CHOCH = 0,            // Active ChoCh Level
   ROLE_TARGET = 1,           // Price Target
   ROLE_INVALID = 2           // Broken/Invalid
  };

//--- DR Level Status
enum ENUM_DR_LEVEL_STATUS
  {
   DR_ACTIVE = 0,             // Active Level
   DR_SWEPT = 1,              // Swept (Liquidity Taken)
   DR_BROKEN = 2,             // Broken
   DR_DIMMED = 3,             // Far Away (Dimmed)
   DR_REACHED = 4             // Target Reached
  };

//+------------------------------------------------------------------+
//|                 SECTION 4: SWING ENUMERATIONS                      |
//+------------------------------------------------------------------+

enum ENUM_SWING_TYPE
  {
   SWING_NONE = 0,
   SWING_EXTERNAL_HIGH = 1,   // Major Swing High
   SWING_EXTERNAL_LOW = 2,    // Major Swing Low
   SWING_INTERNAL_HIGH = 3,   // Minor Swing High
   SWING_INTERNAL_LOW = 4     // Minor Swing Low
  };

enum ENUM_SWING_STATUS
  {
   SWING_PROTECTED = 0,       // Not Broken
   SWING_UNPROTECTED = 1,     // Broken
   SWING_SWEPT = 2            // Swept (Liquidity Grab)
  };

enum ENUM_SWING_CONTEXT
  {
   CONTEXT_NONE = 0,
   CONTEXT_HH = 1,            // Higher High
   CONTEXT_HL = 2,            // Higher Low
   CONTEXT_LH = 3,            // Lower High
   CONTEXT_LL = 4             // Lower Low
  };

enum ENUM_SWING_SIGNIFICANCE
  {
   SIG_MINOR = 0,             // Small Swing
   SIG_MODERATE = 1,          // Medium Swing
   SIG_MAJOR = 2              // Large Swing
  };

//+------------------------------------------------------------------+
//|                SECTION 5:  ARRAY ENUMERATIONS                    |
//+------------------------------------------------------------------+

//--- Order Block Type
enum ENUM_OB_TYPE
  {
   OB_NONE = 0,
   OB_BULLISH = 1,            // Bullish Order Block
   OB_BEARISH = 2             // Bearish Order Block
  };

//--- Order Block Status
enum ENUM_OB_STATUS
  {
   OB_FRESH = 0,              // Never Tested
   OB_TESTED = 1,             // Tested Once
   OB_MITIGATED = 2,          // Fully Mitigated
   OB_FAILED = 3              // Became Breaker
  };

//--- Breaker Block Type
enum ENUM_BREAKER_TYPE
  {
   BREAKER_NONE = 0,
   BREAKER_BULLISH = 1,       // Failed Bearish OB → Bullish Support
   BREAKER_BEARISH = 2        // Failed Bullish OB → Bearish Resistance
  };

//--- Mitigation Block Type
enum ENUM_MB_TYPE
  {
   MB_NONE = 0,
   MB_BULLISH = 1,            // Bullish Mitigation Block
   MB_BEARISH = 2             // Bearish Mitigation Block
  };

//--- Fair Value Gap Type
enum ENUM_FVG_TYPE
  {
   FVG_NONE = 0,
   FVG_BULLISH = 1,           // Bullish Imbalance
   FVG_BEARISH = 2            // Bearish Imbalance
  };

//--- FVG Status
enum ENUM_FVG_STATUS
  {
   FVG_OPEN = 0,              // Not Filled
   FVG_PARTIALLY_FILLED = 1,  // Filled to CE (50%)
   FVG_FULLY_FILLED = 2       // Completely Filled
  };

//--- Volume Imbalance Type
enum ENUM_VI_TYPE
  {
   VI_NONE = 0,
   VI_BULLISH = 1,            // Bullish Gap
   VI_BEARISH = 2             // Bearish Gap
  };

//--- Liquidity Void Type
enum ENUM_VOID_TYPE
  {
   VOID_NONE = 0,
   VOID_BULLISH = 1,          // Void from Bullish Move
   VOID_BEARISH = 2           // Void from Bearish Move
  };

//---  Array Combined Type (for stacking)
enum ENUM_NARRATIVE_ZONE_TYPE
  {
   NZ_NONE = 0,
   NZ_ORDER_BLOCK,
   NZ_BREAKER_BLOCK,
   NZ_MITIGATION_BLOCK,
   NZ_FVG,
   NZ_IFVG,
   NZ_FVG_CE,
   NZ_OTE_ZONE,
   NZ_VOLUME_IMBALANCE,
   NZ_LIQUIDITY_VOID
  };

//+------------------------------------------------------------------+
//|               SECTION 6: MARKET PHASE ENUMERATIONS                 |
//+------------------------------------------------------------------+

//--- AMD Phase
enum ENUM_AMD_PHASE
  {
   AMD_UNKNOWN = 0,
   AMD_ACCUMULATION = 1,      // Smart Money Accumulating
   AMD_MANIPULATION = 2,      // Liquidity Engineering
   AMD_DISTRIBUTION = 3       // Expansion Toward Target
  };

//--- Killzone Type
enum ENUM_KILLZONE
  {
   KZ_NONE = 0,
   KZ_ASIAN = 1,              // Asian Session
   KZ_LONDON_OPEN = 2,        // London Open
   KZ_LONDON = 3,             // London Session
   KZ_NY_OPEN = 4,            // New York Open
   KZ_NY = 5,                 // New York Session
   KZ_LONDON_NY_OVERLAP = 6,  // Overlap
   KZ_LONDON_CLOSE = 7,       // London Close
   KZ_OFF_HOURS = 8           // Outside Sessions
  };

//--- Judas Swing Type
enum ENUM_JUDAS_TYPE
  {
   JUDAS_NONE = 0,
   JUDAS_BULLISH = 1,         // False Break Down → Up Move
   JUDAS_BEARISH = 2          // False Break Up → Down Move
  };

//--- SMT Status
enum ENUM_SMT_STATUS
  {
   SMT_NONE = 0,
   SMT_BULLISH_DIV = 1,       // Bullish Divergence
   SMT_BEARISH_DIV = 2        // Bearish Divergence
  };

//--- SMT Correlation Pair
enum ENUM_SMT_PAIR
  {
   SMT_PAIR_NONE = 0,
   SMT_PAIR_DXY = 1,          // US Dollar Index
   SMT_PAIR_EURUSD = 2,       // EURUSD
   SMT_PAIR_GBPUSD = 3,       // GBPUSD
   SMT_PAIR_USDJPY = 4,       // USDJPY
   SMT_PAIR_XAUUSD = 5,       // Gold
   SMT_PAIR_ES = 6,           // S&P 500 Futures
   SMT_PAIR_NQ = 7            // Nasdaq Futures
  };

//+------------------------------------------------------------------+
//|               SECTION 7: LIQUIDITY ENUMERATIONS                    |
//+------------------------------------------------------------------+

enum ENUM_LIQUIDITY_TYPE
  {
   LQ_NONE = 0,
   LQ_EQUAL_HIGHS = 1,        // Equal Highs (EQH)
   LQ_EQUAL_LOWS = 2,         // Equal Lows (EQL)
   LQ_OLD_HIGH = 3,           // Previous Day/Week High
   LQ_OLD_LOW = 4,            // Previous Day/Week Low
   LQ_BSL = 5,                // Buy-Side Liquidity
   LQ_SSL = 6                 // Sell-Side Liquidity
  };

//+------------------------------------------------------------------+
//|                SECTION 8: ZONE ENUMERATIONS                        |
//+------------------------------------------------------------------+

enum ENUM_ZONE_TYPE
  {
   ZONE_NONE = 0,
   ZONE_PREMIUM = 1,          // Above Equilibrium (Sell Zone)
   ZONE_EQUILIBRIUM = 2,      // Fair Value
   ZONE_DISCOUNT = 3          // Below Equilibrium (Buy Zone)
  };

//+------------------------------------------------------------------+
//|                SECTION 9: SIGNAL ENUMERATIONS                      |
//+------------------------------------------------------------------+

enum ENUM_SIGNAL_TYPE
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY = 1,
   SIGNAL_SELL = 2
  };

enum ENUM_SIGNAL_TRIGGER
  {
   TRIGGER_NONE = 0,
   TRIGGER_OB_ENTRY = 1,      // Order Block Touch
   TRIGGER_BREAKER_ENTRY = 2, // Breaker Block Touch
   TRIGGER_MB_ENTRY = 3,      // Mitigation Block Touch
   TRIGGER_FVG_ENTRY = 4,     // FVG Fill
   TRIGGER_OTE_ENTRY = 5,     // OTE Zone Entry
   TRIGGER_DISPLACEMENT = 7   // Displacement Confirmation
  };

//+------------------------------------------------------------------+
//|                                                                    |
//|              SECTION 10: STRUCTURE DEFINITIONS                     |
//|                                                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Core Pivot Structure                                              |
//+------------------------------------------------------------------+
struct SPivotPoint
  {
   double            price;
   int               barIndex;
   datetime          time;
   bool              valid;

   void              Reset()
     {
      price = 0;
      barIndex = 0;
      time = 0;
      valid = false;
     }
  };

//+------------------------------------------------------------------+
//| Professional Swing Point Structure                                |
//+------------------------------------------------------------------+
struct SSwingPoint
  {
   double               price;
   datetime             time;
   int                  barIndex;
   bool                 isHigh;
   ENUM_SWING_TYPE      type;
   ENUM_SWING_STATUS    status;
   ENUM_SWING_SIGNIFICANCE significance;
   ENUM_SWING_CONTEXT   context;
   int                  pivotScore;
   bool                 isVisible;
   string               objName;
   string               labelName;

   void              Reset()
     {
      price = 0;
      time = 0;
      barIndex = 0;
      isHigh = false;
      type = SWING_NONE;
      status = SWING_PROTECTED;
      significance = SIG_MINOR;
      context = CONTEXT_NONE;
      pivotScore = 0;
      isVisible = false;
      objName = "";
      labelName = "";
     }
  };

//+------------------------------------------------------------------+
//| Correction Line Structure                                         |
//+------------------------------------------------------------------+
struct SCorrectionLine
  {
   datetime          verticalTime;
   double            extremePrice;
   datetime          extremeTime;
   bool              isActive;
   bool              needsUpdate;
   double            pendingExtreme;
   datetime          pendingExtremeTime;
   string            vertObjName;
   string            horizObjName;
   string            labelObjName;

   void              Reset()
     {
      verticalTime = 0;
      extremePrice = 0;
      extremeTime = 0;
      isActive = false;
      needsUpdate = false;
      pendingExtreme = 0;
      pendingExtremeTime = 0;
      vertObjName = "";
      horizObjName = "";
      labelObjName = "";
     }
  };

//+------------------------------------------------------------------+
//| DR Origin Structure                                               |
//+------------------------------------------------------------------+
struct SDR_Origin
  {
   double            price;
   datetime          time;
   ENUM_ORIGIN_ROLE  role;
   bool              isFromSweep;
   bool              isDimmed;
   bool              isReached;
   datetime          reachedTime;
   string            lineObjName;
   string            labelObjName;

   void              Reset()
     {
      price = 0;
      time = 0;
      role = ROLE_INVALID;
      isFromSweep = false;
      isDimmed = false;
      isReached = false;
      reachedTime = 0;
      lineObjName = "";
      labelObjName = "";
     }
  };

//+------------------------------------------------------------------+
//| DR External Inducement Structure                                  |
//+------------------------------------------------------------------+
struct SDR_External
  {
   double               price;
   datetime             time;
   int                  barIndex;
   ENUM_DR_LEVEL_STATUS status;
   double               swingDepth;
   int                  pivotScore;
   bool                 isReached;
   datetime             reachedTime;
   string               lineObjName;
   string               labelObjName;

   void              Reset()
     {
      price = 0;
      time = 0;
      barIndex = 0;
      status = DR_ACTIVE;
      swingDepth = 0;
      pivotScore = 0;
      isReached = false;
      reachedTime = 0;
      lineObjName = "";
      labelObjName = "";
     }
  };

//+------------------------------------------------------------------+
//| DR Internal Level Structure                                       |
//+------------------------------------------------------------------+
struct SDR_Internal
  {
   double            price;
   datetime          time;
   int               barIndex;
   bool              isBroken;
   datetime          brokenTime;
   string            lineObjName;
   string            labelObjName;

   void              Reset()
     {
      price = 0;
      time = 0;
      barIndex = 0;
      isBroken = false;
      brokenTime = 0;
      lineObjName = "";
      labelObjName = "";
     }
  };
//+------------------------------------------------------------------+
//| Pullback Counter-Level Structure (NEW) |
//+------------------------------------------------------------------+
struct SDR_PullbackCounter
  {
   double            price;
   datetime          time;
   int               barIndex;
   bool              isConsumed;
   datetime          consumedTime;
   string            lineObjName;
   string            labelObjName;

   void              Reset()
     {
      price = 0;
      time = 0;
      barIndex = 0;
      isConsumed = false;
      consumedTime = 0;
      lineObjName = "";
      labelObjName = "";
     }
  };

//+------------------------------------------------------------------+
//| Pullback Sub-Structure (NEW) |
//+------------------------------------------------------------------+
struct SPullbackStructure
  {
   SDR_PullbackCounter counters[];
   int               counterCount;

   bool              sweepPending;
   double            sweepExtreme;
   datetime          sweepTime;

   bool              confirmed;
   bool              active;

   double            originPrice;
   datetime          originTime;
   string            originLineObj;
   string            originLabelObj;

   double            clPrice;
   datetime          clTime;
   string            clVertObj;
   string            clHorizObj;
   string            clLabelObj;

   void              Reset()
     {
      ArrayResize(counters, 0);
      counterCount = 0;
      sweepPending = false;
      sweepExtreme = 0;
      sweepTime = 0;
      confirmed = false;
      active = false;
      originPrice = 0;
      originTime = 0;
      originLineObj = "";
      originLabelObj = "";
      clPrice = 0;
      clTime = 0;
      clVertObj = "";
      clHorizObj = "";
      clLabelObj = "";
     }
  };
//+------------------------------------------------------------------+
//| Complete Dealing Range Structure                                  |
//+------------------------------------------------------------------+
class SDealingRange
  {
public:
   SCorrectionLine   corrLine;
   SDR_Origin        origins[];
   int               originCount;
   SDR_External      externals[];
   int               externalCount;
   SDR_Internal      internals[];
   int               internalCount;

   bool              externalSwept;
   double            extremeReached;
   datetime          sweepTime;

   bool              isActive;
   bool              isDominant;

   ENUM_TF_LAYER     tfLayer;
   ENUM_TIMEFRAMES   timeframe;
   SPullbackStructure pullback; // ← NEW

   void              Reset()
     {
      corrLine.Reset();
      ArrayResize(origins, 0);
      originCount = 0;
      ArrayResize(externals, 0);
      externalCount = 0;
      ArrayResize(internals, 0);
      internalCount = 0;
      externalSwept = false;
      extremeReached = 0;
      sweepTime = 0;
      isActive = false;
      isDominant = false;
      tfLayer = LAYER_CTF;
      timeframe = PERIOD_CURRENT;
      pullback.Reset(); // ← NEW
     }
  };

//+------------------------------------------------------------------+
//| Entry Zone Structure (Defined by DR for Array search)          |
//+------------------------------------------------------------------+
struct SEntryZone
  {
   double            upperBound;
   double            lowerBound;
   datetime          startTime;
   bool              isValid;
   ENUM_TRADE_DIRECTION direction;
   ENUM_TF_LAYER     definedBy;

   void              Reset()
     {
      upperBound = 0;
      lowerBound = 0;
      startTime = 0;
      isValid = false;
      direction = DIR_NONE;
      definedBy = LAYER_CTF;
     }

   double            Width() { return MathAbs(upperBound - lowerBound); }
   double            Mid()   { return (upperBound + lowerBound) / 2.0; }

   bool              Contains(double price)
     {
      return (price >= lowerBound && price <= upperBound);
     }
  };

//+------------------------------------------------------------------+
//| Order Block Structure                                             |
//+------------------------------------------------------------------+
struct SOrderBlock
  {
   ENUM_OB_TYPE      type;
   ENUM_OB_STATUS    status;
   double            top;
   double            bottom;
   double            midpoint;
   datetime          time;
   int               barIndex;
   double            bodyTop;
   double            bodyBottom;
   bool              isInstitutional;
   int               testCount;
   datetime          lastTestTime;
   datetime          mitigatedTime;
   string            objName;
   string            labelName;
   ENUM_TRADE_DIRECTION bornDirection;  // Direction of the move that created this OB
   int                  birthBar;       // Bar index when OB was created
   int                  causalTag;      // Link to last structural event / SM sequence

   void              Reset()
     {
      type = OB_NONE;
      status = OB_FRESH;
      top = 0;
      bottom = 0;
      midpoint = 0;
      time = 0;
      barIndex = 0;
      bodyTop = 0;
      bodyBottom = 0;
      isInstitutional = false;
      testCount = 0;
      lastTestTime = 0;
      mitigatedTime = 0;
      objName = "";
      labelName = "";
      bornDirection = DIR_NONE;
      birthBar = -1;
      causalTag = -1;
     }

   double            Height() { return MathAbs(top - bottom); }
  };

//+------------------------------------------------------------------+
//| Breaker Block Structure                                           |
//+------------------------------------------------------------------+
struct SBreakerBlock
  {
   ENUM_BREAKER_TYPE type;
   double            top;
   double            bottom;
   datetime          time;
   datetime          breakTime;
   int               barIndex;
   double            originalOBTop;
   double            originalOBBottom;
   bool              isTested;
   datetime          testedTime;
   string            objName;
   string            labelName;

   void              Reset()
     {
      type = BREAKER_NONE;
      top = 0;
      bottom = 0;
      time = 0;
      breakTime = 0;
      barIndex = 0;
      originalOBTop = 0;
      originalOBBottom = 0;
      isTested = false;
      testedTime = 0;
      objName = "";
      labelName = "";
     }
  };

//+------------------------------------------------------------------+
//| Mitigation Block Structure                                        |
//+------------------------------------------------------------------+
struct SMitigationBlock
  {
   ENUM_MB_TYPE      type;
   double            top;
   double            bottom;
   datetime          time;
   int               barIndex;
   datetime          bosTime;
   double            bosLevel;
   bool              isTested;
   string            objName;
   string            labelName;

   void              Reset()
     {
      type = MB_NONE;
      top = 0;
      bottom = 0;
      time = 0;
      barIndex = 0;
      bosTime = 0;
      bosLevel = 0;
      isTested = false;
      objName = "";
      labelName = "";
     }
  };

//+------------------------------------------------------------------+
//| Fair Value Gap Structure                                          |
//+------------------------------------------------------------------+
struct SFairValueGap
  {
   ENUM_FVG_TYPE     type;
   ENUM_FVG_STATUS   status;
   double            top;
   double            bottom;
   double            ce;             // Consequent Encroachment (50%)
   datetime          time;
   int               barIndex;
   double            fillPercent;
   datetime          ceReachedTime;
   datetime          filledTime;
   string            objName;
   string            labelName;
   ENUM_TRADE_DIRECTION bornDirection;  // Direction of imbalance
   int                  birthBar;       // Bar index of FVG's middle candle
   int                  causalTag;      // Link to structural event

   void              Reset()
     {
      type = FVG_NONE;
      status = FVG_OPEN;
      top = 0;
      bottom = 0;
      ce = 0;
      time = 0;
      barIndex = 0;
      fillPercent = 0;
      ceReachedTime = 0;
      filledTime = 0;
      objName = "";
      labelName = "";
      bornDirection = DIR_NONE;
      birthBar = -1;
      causalTag = -1;
     }

   double            Height() { return MathAbs(top - bottom); }
  };

//+------------------------------------------------------------------+
//| Volume Imbalance Structure                                        |
//+------------------------------------------------------------------+
struct SVolumeImbalance
  {
   ENUM_VI_TYPE      type;
   double            top;
   double            bottom;
   datetime          time;
   int               barIndex;
   bool              isFilled;
   string            objName;
   ENUM_TRADE_DIRECTION bornDirection;
   int               birthBar;
   int               causalTag;

   void              Reset()
     {
      type = VI_NONE;
      top = 0;
      bottom = 0;
      time = 0;
      barIndex = 0;
      isFilled = false;
      objName = "";
      bornDirection = DIR_NONE;
      birthBar = -1;
      causalTag = -1;
     }
  };

//+------------------------------------------------------------------+
//| Liquidity Void Structure                                          |
//+------------------------------------------------------------------+
struct SLiquidityVoid
  {
   ENUM_VOID_TYPE    type;
   double            top;
   double            bottom;
   datetime          startTime;
   datetime          endTime;
   int               startBar;
   int               endBar;
   bool              isFilled;
   string            objName;
   ENUM_TRADE_DIRECTION bornDirection;
   int               birthBar;
   int               causalTag;

   void              Reset()
     {
      type = VOID_NONE;
      top = 0;
      bottom = 0;
      startTime = 0;
      endTime = 0;
      startBar = 0;
      endBar = 0;
      isFilled = false;
      objName = "";
      bornDirection = DIR_NONE;
      birthBar = -1;
      causalTag = -1;
     }
  };

//+------------------------------------------------------------------+
//| OTE Zone Structure                                                |
//+------------------------------------------------------------------+
struct SOTEZone
  {
   double            fib618;         // 61.8% level
   double            fib70;          // 70.5% level (sweet spot)
   double            fib79;          // 79% level
   double            swingHigh;
   double            swingLow;
   datetime          time;
   bool              isValid;
   bool              isBullish;
   string            objName;

   void              Reset()
     {
      fib618 = 0;
      fib70 = 0;
      fib79 = 0;
      swingHigh = 0;
      swingLow = 0;
      time = 0;
      isValid = false;
      isBullish = false;
      objName = "";
     }

   double            OptimalEntry() { return fib70; }
   double            ZoneTop()      { return isBullish ? fib618 : fib79; }
   double            ZoneBottom()   { return isBullish ? fib79 : fib618; }
  };

//+------------------------------------------------------------------+
//| Rejection Block Structure                                         |
//+------------------------------------------------------------------+
struct SRejectionBlock
  {
   ENUM_TRADE_DIRECTION direction;
   double            wickTop;
   double            wickBottom;
   double            bodyTop;
   double            bodyBottom;
   datetime          time;
   int               barIndex;
   double            rejectionRatio;    // Wick size / Body size
   string            objName;

   void              Reset()
     {
      direction = DIR_NONE;
      wickTop = 0;
      wickBottom = 0;
      bodyTop = 0;
      bodyBottom = 0;
      time = 0;
      barIndex = 0;
      rejectionRatio = 0;
      objName = "";
     }
  };



//+------------------------------------------------------------------+
//| Temporary Structure for Narrative Candidate Collection            |
//+------------------------------------------------------------------+
struct SNarrativeZoneCandidate
  {
   ENUM_NARRATIVE_ZONE_TYPE type;
   int               index;
   double            top;
   double            bottom;
   datetime          time;
   int               priority;
   bool              isFresh;
  };

//+------------------------------------------------------------------+
//| Liquidity Pool Structure                                          |
//+------------------------------------------------------------------+
struct SLiquidityPool
  {
   ENUM_LIQUIDITY_TYPE type;
   double            price;
   datetime          time;
   int               barIndex;
   int               touchCount;
   bool              isSwept;
   datetime          sweptTime;
   string            objName;
   string            labelName;

   void              Reset()
     {
      type = LQ_NONE;
      price = 0;
      time = 0;
      barIndex = 0;
      touchCount = 0;
      isSwept = false;
      sweptTime = 0;
      objName = "";
      labelName = "";
     }
  };

//+------------------------------------------------------------------+
//| AMD Phase Structure                                               |
//+------------------------------------------------------------------+
struct SAMDPhase
  {
   ENUM_AMD_PHASE    currentPhase;
   datetime          phaseStartTime;
   double            accumulationHigh;
   double            accumulationLow;
   double            manipulationExtreme;
   ENUM_TRADE_DIRECTION expectedDirection;
   int               confidence;      // 0-100

   void              Reset()
     {
      currentPhase = AMD_UNKNOWN;
      phaseStartTime = 0;
      accumulationHigh = 0;
      accumulationLow = 0;
      manipulationExtreme = 0;
      expectedDirection = DIR_NONE;
      confidence = 0;
     }
  };

//+------------------------------------------------------------------+
//| Judas Swing Structure                                             |
//+------------------------------------------------------------------+
struct SJudasSwing
  {
   ENUM_JUDAS_TYPE   type;
   double            falseBreakLevel;
   double            sweptLevel;
   datetime          sweepTime;
   datetime          reversalTime;
   double            reversalPrice;
   bool              isConfirmed;
   ENUM_TRADE_DIRECTION tradeDirection;
   string            objName;

   void              Reset()
     {
      type = JUDAS_NONE;
      falseBreakLevel = 0;
      sweptLevel = 0;
      sweepTime = 0;
      reversalTime = 0;
      reversalPrice = 0;
      isConfirmed = false;
      tradeDirection = DIR_NONE;
      objName = "";
     }
  };

//+------------------------------------------------------------------+
//| SMT Divergence Structure                                          |
//+------------------------------------------------------------------+
struct SSMTDivergence
  {
   ENUM_SMT_STATUS   status;
   ENUM_SMT_PAIR     correlatedPair;
   datetime          time;
   double            mainPrice;
   double            correlatedPrice;
   bool              isConfirmed;
   int               strength;        // 1-3

   void              Reset()
     {
      status = SMT_NONE;
      correlatedPair = SMT_PAIR_NONE;
      time = 0;
      mainPrice = 0;
      correlatedPrice = 0;
      isConfirmed = false;
      strength = 0;
     }
  };

//+------------------------------------------------------------------+
//| Killzone Status Structure                                         |
//+------------------------------------------------------------------+
struct SKillzoneStatus
  {
   ENUM_KILLZONE     current;
   datetime          startTime;
   datetime          endTime;
   bool              isActive;
   double            sessionHigh;
   double            sessionLow;
   double            openPrice;
   double            multiplier;      // Score multiplier

   void              Reset()
     {
      current = KZ_NONE;
      startTime = 0;
      endTime = 0;
      isActive = false;
      sessionHigh = 0;
      sessionLow = 0;
      openPrice = 0;
      multiplier = 1.0;
     }
  };

//+------------------------------------------------------------------+
//| Range Info Structure (Premium/Discount)                           |
//+------------------------------------------------------------------+
struct SRangeInfo
  {
   double            high;
   double            low;
   double            equilibrium;
   double            premiumLevel;
   double            discountLevel;
   ENUM_ZONE_TYPE    currentZone;
   datetime          rangeStart;

   void              Reset()
     {
      high = 0;
      low = 0;
      equilibrium = 0;
      premiumLevel = 0;
      discountLevel = 0;
      currentZone = ZONE_NONE;
      rangeStart = 0;
     }
  };




//+------------------------------------------------------------------+
//| Trade Signal Structure                                            |
//+------------------------------------------------------------------+

struct SNarrativeSnapshot
  {
   int               activeChains;
   int               stageCompleted;
   int               causalTag;
   ENUM_TRADE_DIRECTION direction;

   void              Reset()
     {
      activeChains = 0;
      stageCompleted = 0;
      causalTag = -1;
      direction = DIR_NONE;
     }
  };

struct STradeSignal
  {
   ENUM_SIGNAL_TYPE  type;
   ENUM_SIGNAL_TRIGGER trigger;
   datetime          time;
   double            entryPrice;
   double            slPrice;
   double            tp1Price;
   double            tp2Price;
   double            tp3Price;
   double            lotSize;
   double            riskReward;
   SNarrativeSnapshot narrative;
   bool              isValid;
   bool              isExecuted;
   ulong             ticket;

   void              Reset()
     {
      type = SIGNAL_NONE;
      trigger = TRIGGER_NONE;
      time = 0;
      entryPrice = 0;
      slPrice = 0;
      tp1Price = 0;
      tp2Price = 0;
      tp3Price = 0;
      lotSize = 0;
      riskReward = 0;
      narrative.Reset();
      isValid = false;
      isExecuted = false;
      ticket = 0;
     }
  };

//+------------------------------------------------------------------+
//| Trade Statistics Structure                                        |
//+------------------------------------------------------------------+
struct STradeStats
  {
   int               totalTrades;
   int               winTrades;
   int               lossTrades;
   double            totalProfit;
   double            totalLoss;
   double            netProfit;
   double            winRate;
   double            profitFactor;
   double            maxDrawdown;
   double            bestTrade;
   double            worstTrade;
   double            avgWin;
   double            avgLoss;
   int               todayTrades;
   double            todayPnL;
   int               consecutiveWins;
   int               consecutiveLosses;
   int               maxConsecutiveWins;
   int               maxConsecutiveLosses;

   void              Reset()
     {
      totalTrades = 0;
      winTrades = 0;
      lossTrades = 0;
      totalProfit = 0;
      totalLoss = 0;
      netProfit = 0;
      winRate = 0;
      profitFactor = 0;
      maxDrawdown = 0;
      bestTrade = 0;
      worstTrade = 0;
      avgWin = 0;
      avgLoss = 0;
      todayTrades = 0;
      todayPnL = 0;
      consecutiveWins = 0;
      consecutiveLosses = 0;
      maxConsecutiveWins = 0;
      maxConsecutiveLosses = 0;
     }

   void              Calculate()
     {
      if(totalTrades > 0)
         winRate = (double)winTrades / (double)totalTrades * 100.0;
      if(totalLoss > 0)
         profitFactor = totalProfit / totalLoss;
      netProfit = totalProfit - totalLoss;
      if(winTrades > 0)
         avgWin = totalProfit / winTrades;
      if(lossTrades > 0)
         avgLoss = totalLoss / lossTrades;
     }
  };

//+------------------------------------------------------------------+
//| Signal History Entry                                              |
//+------------------------------------------------------------------+
struct SSignalHistory
  {
   datetime          time;
   ENUM_SIGNAL_TYPE  type;
   ENUM_SIGNAL_TRIGGER trigger;
   double            price;
   int               score;
   double            pnl;
   bool              isWin;
   string            description;

   void              Reset()
     {
      time = 0;
      type = SIGNAL_NONE;
      trigger = TRIGGER_NONE;
      price = 0;
      score = 0;
      pnl = 0;
      isWin = false;
      description = "";
     }
  };

//+------------------------------------------------------------------+
//| MTF Visual Configuration                                          |
//+------------------------------------------------------------------+
struct SMTFVisual
  {
   int               lineWidth;
   ENUM_LINE_STYLE   lineStyle;
   int               labelSize;
   color             bullCL;
   color             bearCL;
   color             originColor;
   color             extColor;
   color             intColor;
   color             targetColor;
   string            prefix;
   string            tfLabel;
  };

//+------------------------------------------------------------------+
//| MTF Layer Configuration                                           |
//+------------------------------------------------------------------+
class SMTFLayer
  {
public:
   ENUM_TIMEFRAMES   timeframe;
   ENUM_TF_LAYER     layer;
   SMTFVisual        visual;
   SDealingRange     bullDR;
   SDealingRange     bearDR;
   bool              isBullishActive;
   bool              isEnabled;
   bool              isInitialized;
   int               atrHandle;
   double            atrBuffer[];

   void              Reset()
     {
      timeframe = PERIOD_CURRENT;
      layer = LAYER_CTF;
      bullDR.Reset();
      bearDR.Reset();
      isBullishActive = true;
      isEnabled = false;
      isInitialized = false;
      atrHandle = INVALID_HANDLE;
      ArrayResize(atrBuffer, 0);
     }
  };


//+------------------------------------------------------------------+
//|           SECTION 12: ML ENGINE TYPES                              |
//+------------------------------------------------------------------+

#define ML_FEATURE_COUNT    36
#define ML_MAX_SAMPLES      500
#define ML_MAX_HISTORY      50
#define PROVIDER_BUFFER_COUNT 8
#define MAX_PROVIDERS       3
#define EA_STATE_VAR_COUNT  70

enum ENUM_ML_MODE
  {
   ML_OFF = 0,                 // Disabled
   ML_ADAPTIVE = 1,            // Adaptive Weight Adjustment
   ML_LOGISTIC = 2,            // Online Logistic Regression
   ML_COMBINED = 3             // Adaptive + Logistic (Recommended)
  };

enum ENUM_ML_STATUS
  {
   ML_STATUS_OFF = 0,
   ML_STATUS_WARMUP = 1,       // Collecting initial samples, NO filtering
   ML_STATUS_OBSERVING = 2,    // Has some data, adjusts scores but does NOT block
   ML_STATUS_FILTERING = 3,    // Enough data + accuracy > 50%, CAN block trades
   ML_STATUS_FROZEN = 4,       // Weights locked
   ML_STATUS_ERROR = 5
  };

enum ENUM_PROVIDER_MODE
  {
   PROV_DISABLED = 0,          // External providers disabled
   PROV_OVERRIDE = 1,          // External replaces internal
   PROV_ADDITIVE = 2,          // External score adds to internal
   PROV_FILTER = 3,            // External must agree with internal
   PROV_WEIGHTED = 4           // Weighted ensemble blend
  };

enum ENUM_SIGNAL_LIFECYCLE
  {
   SLC_NONE = 0,
   SLC_FORMING = 1,
   SLC_CONFIRMED = 2,
   SLC_EXECUTED = 3,
   SLC_EXPIRED = 4,
   SLC_CANCELLED = 5
  };

enum ENUM_CONFLICT_RESOLUTION
  {
   CONFLICT_INTERNAL_WINS = 0,
   CONFLICT_EXTERNAL_WINS = 1,
   CONFLICT_AGREEMENT_REQUIRED = 2,
   CONFLICT_HIGHEST_CONFIDENCE = 3
  };

enum ENUM_ML_FEATURE
  {
   MLF_HTF_ALIGNED = 3,
   MLF_ALL_TF_ALIGNED = 4,
   MLF_KZ_ACTIVE = 5,
   MLF_KZ_MULTIPLIER = 6,
   MLF_AMD_PHASE = 7,
   MLF_HAS_OB = 8,
   MLF_HAS_FVG = 9,
   MLF_HAS_CONFLUENCE = 10,      // reserved slot, stack removed
   MLF_CONFLUENCE_COUNT = 11,    // reserved slot, stack removed
   MLF_OTE_IN_ZONE = 12,
   MLF_ZONE_ALIGNED = 13,
   MLF_SMT_CONFIRMED = 14,
   MLF_JUDAS_ACTIVE = 15,
   MLF_EXT_SWEPT = 16,
   MLF_RR_RATIO = 17,
   MLF_DISPLACEMENT = 18,
   MLF_BODY_CLOSE = 19,
   MLF_LTF_BOS = 20,
   MLF_ORIGIN_EXISTS = 21,
   MLF_SPREAD_NORM = 22,
   MLF_HOUR_NORM = 23,

// ── NEW: STATE MACHINE NARRATIVE FEATURES ──
   MLF_SM_TRIGGER_TYPE   = 24, // Encoded primary Trigger element type
   MLF_SM_BARS_TO_CONFIRM= 25, // Bars Trigger→Confirm (normalized)
   MLF_SM_BARS_TO_ENTRY  = 26, // Bars Trigger→Entry (normalized)
   MLF_SM_CAUSAL_USED    = 27, // 1 if causal OB/FVG used at Entry
   MLF_SM_STAGES_COMPLETE= 28, // fraction of stages completed (0-1)
   MLF_SM_STAGES_SKIPPED = 29, // fraction of stages skipped   (0-1)
   MLF_SM_TRIGGER_STRENGTH=30, // general strength of trigger leg
   MLF_SM_RETRACE_DEPTH  = 31, // retrace depth into leg (0-1)
   MLF_SM_PRESET_ID      = 32, // preset index normalized (0-1)
   MLF_SM_ENTRY_HOUR     = 33, // local hour at current bar (0-1)
   MLF_SM_CHAIN_SPEED    = 34, // how fast chain is progressing (0-1)
   MLF_SM_LTF_CONFIRMED  = 35  // 1 if LTF BOS used in chain
  };

//--- ML Feature Vector
struct SMLFeatureVector
  {
   double            features[ML_FEATURE_COUNT];

   void              Reset()
     {
      ArrayInitialize(features, 0.0);
     }

   double            Get(int idx) { return (idx >= 0 && idx < ML_FEATURE_COUNT) ? features[idx] : 0; }
   void              Set(int idx, double val) { if(idx >= 0 && idx < ML_FEATURE_COUNT) features[idx] = val; }
  };

//--- ML Training Sample
struct SMLTrainingSample
  {
   SMLFeatureVector  featureVec;
   double            label;        // 1.0 = win, 0.0 = loss
   double            pnl;
   datetime          time;
   int               signalQuality;
   ENUM_SIGNAL_TYPE  signalType;

   void              Reset()
     {
      featureVec.Reset();
      label = 0;
      pnl = 0;
      time = 0;
      signalQuality = 0;
      signalType = SIGNAL_NONE;
     }
  };

//--- ML Weight Vector
struct SMLWeights
  {
   double            weights[ML_FEATURE_COUNT];
   double            bias;
   double            defaults[ML_FEATURE_COUNT];
   int               updateCount;

   void              Reset()
     {
      ArrayInitialize(weights, 0.0);
      ArrayInitialize(defaults, 0.0);
      bias = 0.0;
      updateCount = 0;
     }

   void              InitDefaults()
     {
      for(int i = 0; i < ML_FEATURE_COUNT; i++)
        {
         weights[i] = 0.0;
         defaults[i] = 0.0;
        }
      bias = 0.0;
     }
  };

//--- ML Prediction
struct SMLPrediction
  {
   double            probability;     // 0.0 - 1.0
   bool              recommend;       // true = take trade
   double            confidence;      // how confident (based on sample count)
   double            adjustedBias;   // score after ML adjustment
   string            reason;

   void              Reset()
     {
      probability = 0.5;
      recommend = false;
      confidence = 0;
      adjustedBias = 0;
      reason = "";
     }
  };

//--- ML Prediction History Entry
struct SMLPredictionHistory
  {
   datetime          time;
   double            predictedProb;
   bool              actualWin;
   bool              tradeTaken;
   double            pnl;
   int               originalQuality;

   void              Reset()
     {
      time = 0;
      predictedProb = 0.5;
      actualWin = false;
      tradeTaken = false;
      pnl = 0;
      originalQuality = 0;
     }
  };

//--- ML Statistics
struct SMLStats
  {
   int               totalSamples;
   int               totalPredictions;
   int               correctPredictions;
   double            predictionAccuracy;
   double            recentAccuracy;      // last N predictions
   double            avgWinProb;
   double            avgLossProb;
   double            featureImportance[ML_FEATURE_COUNT];
   int               warmupRemaining;

   void              Reset()
     {
      totalSamples = 0;
      totalPredictions = 0;
      correctPredictions = 0;
      predictionAccuracy = 0;
      recentAccuracy = 0;
      avgWinProb = 0;
      avgLossProb = 0;
      ArrayInitialize(featureImportance, 0.0);
      warmupRemaining = 0;
     }

   void              Calculate()
     {
      if(totalPredictions > 0)
         predictionAccuracy = (double)correctPredictions / totalPredictions * 100.0;
     }
  };

//--- External Signal Contract
struct SExternalSignal
  {
   string               providerName;
   int                  providerIndex;
   ENUM_SIGNAL_TYPE     direction;
   ENUM_SIGNAL_LIFECYCLE lifecycle;
   datetime             signalTime;
   int                  barIndex;
   double               entryLow;
   double               entryHigh;
   double               stopLoss;
   double               takeProfit1;
   double               takeProfit2;
   double               confidence;
   double               signalID;
   bool                 isValid;
   bool                 isStale;
   int                  barsSinceSignal;
   int                  expirationBars;

   void              Reset()
     {
      providerName = "";
      providerIndex = -1;
      direction = SIGNAL_NONE;
      lifecycle = SLC_NONE;
      signalTime = 0;
      barIndex = 0;
      entryLow = 0;
      entryHigh = 0;
      stopLoss = 0;
      takeProfit1 = 0;
      takeProfit2 = 0;
      confidence = 0;
      signalID = 0;
      isValid = false;
      isStale = false;
      barsSinceSignal = 0;
      expirationBars = 20;
     }

   double            EntryMid() { return (entryLow + entryHigh) / 2.0; }
  };

//--- Provider Info
struct SProviderInfo
  {
   string            name;
   int               handle;
   bool              enabled;
   bool              connected;
   int               signalCount;
   int               winCount;
   double            winRate;
   double            weight;
   double            lastSignalID;
   SExternalSignal   currentSignal;

   void              Reset()
     {
      name = "";
      handle = INVALID_HANDLE;
      enabled = false;
      connected = false;
      signalCount = 0;
      winCount = 0;
      winRate = 0;
      weight = 1.0;
      lastSignalID = 0;
      currentSignal.Reset();
     }
  };

//--- Ensemble Result
struct SEnsembleResult
  {
   ENUM_SIGNAL_TYPE     direction;
   double               consensusConfidence;
   double               entryPrice;
   double               stopLoss;
   double               takeProfit1;
   double               takeProfit2;
   int                  agreeCount;
   int                  disagreeCount;
   bool                 unanimousDirection;
   bool                 isValid;
   string               description;

   void              Reset()
     {
      direction = SIGNAL_NONE;
      consensusConfidence = 0;
      entryPrice = 0;
      stopLoss = 0;
      takeProfit1 = 0;
      takeProfit2 = 0;
      agreeCount = 0;
      disagreeCount = 0;
      unanimousDirection = false;
      isValid = false;
      description = "";
     }
  };

//--- Feature Name Helper
string MLFeatureName(int idx)
  {
   switch(idx)
     {
      case MLF_HTF_ALIGNED:
         return "HTF Align";
      case MLF_ALL_TF_ALIGNED:
         return "All TF";
      case MLF_KZ_ACTIVE:
         return "KZ Active";
      case MLF_KZ_MULTIPLIER:
         return "KZ Multi";
      case MLF_AMD_PHASE:
         return "AMD Phase";
      case MLF_HAS_OB:
         return "Has OB";
      case MLF_HAS_FVG:
         return "Has FVG";
      case MLF_HAS_CONFLUENCE:
         return "Confluence";
      case MLF_CONFLUENCE_COUNT:
         return "Confl Cnt";
      case MLF_OTE_IN_ZONE:
         return "In OTE";
      case MLF_ZONE_ALIGNED:
         return "Zone Algn";
      case MLF_SMT_CONFIRMED:
         return "SMT Conf";
      case MLF_JUDAS_ACTIVE:
         return "Judas";
      case MLF_EXT_SWEPT:
         return "Ext Swept";
      case MLF_RR_RATIO:
         return "RR Ratio";
      case MLF_DISPLACEMENT:
         return "Displace";
      case MLF_BODY_CLOSE:
         return "Body Cls";
      case MLF_LTF_BOS:
         return "LTF BOS";
      case MLF_ORIGIN_EXISTS:
         return "Origin";
      case MLF_SPREAD_NORM:
         return "Spread";
      case MLF_HOUR_NORM:
         return "Hour";

      // NEW SM narrative features
      case MLF_SM_TRIGGER_TYPE:
         return "SM TrigType";
      case MLF_SM_BARS_TO_CONFIRM:
         return "SM Bars→Conf";
      case MLF_SM_BARS_TO_ENTRY:
         return "SM Bars→Entry";
      case MLF_SM_CAUSAL_USED:
         return "SM Causal";
      case MLF_SM_STAGES_COMPLETE:
         return "SM StgDone";
      case MLF_SM_STAGES_SKIPPED:
         return "SM StgSkip";
      case MLF_SM_TRIGGER_STRENGTH:
         return "SM TrigStr";
      case MLF_SM_RETRACE_DEPTH:
         return "SM Retrace";
      case MLF_SM_PRESET_ID:
         return "SM Preset";
      case MLF_SM_ENTRY_HOUR:
         return "SM Hour";
      case MLF_SM_CHAIN_SPEED:
         return "SM Speed";
      case MLF_SM_LTF_CONFIRMED:
         return "SM LTF BOS";

      default:
         return "F" + IntegerToString(idx);
     }
  }
//+------------------------------------------------------------------+
//| ============ NEW/MODIFIED ENUMS FOR SL/TP ENHANCEMENT ============|
//+------------------------------------------------------------------+

//--- Partial Close Trigger Mode (NEW)
enum ENUM_PARTIAL_MODE
  {
   PARTIAL_RR_BASED = 0,      // Trigger at Risk:Reward Levels
   PARTIAL_DR_TARGETS = 1,    // Trigger at DR Target Line Hits
   PARTIAL_ATR_DISTANCE = 2,  // Trigger at ATR Distance Intervals
   PARTIAL_FIXED_POINTS = 3   // Trigger at Fixed Point Intervals
  };

//--- DR Target Source (NEW)
enum ENUM_TARGET_SOURCE
  {
   TARGET_FROM_ORIGIN = 0,       // From Origin demotion
   TARGET_FROM_EXT_IDMT = 1,     // From External IDMT reclassification
   TARGET_FROM_INTERNAL = 2      // From Internal level promotion
  };

//+------------------------------------------------------------------+
//| DR Target Line Structure (NEW - for reclassified targets)         |
//+------------------------------------------------------------------+
struct SDR_TargetLine
  {
   double               price;
   datetime             time;
   ENUM_TARGET_SOURCE   source;
   ENUM_TRADE_DIRECTION forDirection;    // Which trade direction benefits
   bool                 isReached;
   datetime             reachedTime;
   double               distanceFromEntry; // Calculated at signal time
   string               lineObjName;
   string               labelObjName;

   void              Reset()
     {
      price = 0;
      time = 0;
      source = TARGET_FROM_ORIGIN;
      forDirection = DIR_NONE;
      isReached = false;
      reachedTime = 0;
      distanceFromEntry = 0;
      lineObjName = "";
      labelObjName = "";
     }
  };

//+------------------------------------------------------------------+
//| Position Tracking Structure (NEW - for multi-TP management)       |
//+------------------------------------------------------------------+
struct SPositionTracking
  {
   ulong                ticket;
   double               entryPrice;
   double               initialSL;
   double               initialLotSize;
   double               tp1Price;
   double               tp2Price;
   double               tp3Price;
   bool                 tp1Done;
   bool                 tp2Done;
   bool                 tp3Done;
   bool                 breakEvenDone;
   ENUM_SIGNAL_TYPE     direction;
   ENUM_TP_MODE         tpMode;
   ENUM_PARTIAL_MODE    partialMode;
   datetime             openTime;
   // In SPositionTracking, add these fields:
   SMLFeatureVector  signalFeatures;    // Features captured at signal time
   bool              hasSignalFeatures; // Whether features were captured

   void              Reset()
     {
      ticket = 0;
      entryPrice = 0;
      initialSL = 0;
      initialLotSize = 0;
      tp1Price = 0;
      tp2Price = 0;
      tp3Price = 0;
      tp1Done = false;
      tp2Done = false;
      tp3Done = false;
      breakEvenDone = false;
      direction = SIGNAL_NONE;
      tpMode = TP_FIXED_RR;
      partialMode = PARTIAL_RR_BASED;
      openTime = 0;
      // In Reset():
      signalFeatures.Reset();
      hasSignalFeatures = false;

     }

   bool              IsActive() { return (ticket > 0); }

   double            InitialRisk()
     {
      if(direction == SIGNAL_BUY)
         return entryPrice - initialSL;
      else
         return initialSL - entryPrice;
     }
  };

//+------------------------------------------------------------------+
//|         ML ENGINE TYPES - ENHANCED (ADD/REPLACE)                   |
//+------------------------------------------------------------------+


//--- ML Adaptive Statistics (NEW - for ADAPTIVE mode)
struct SMLAdaptiveStats
  {
   double            winFeatureSum[ML_FEATURE_COUNT];
   double            lossFeatureSum[ML_FEATURE_COUNT];
   int               winCount;
   int               lossCount;
   double            featureEffect[ML_FEATURE_COUNT]; // winAvg - lossAvg per feature

   void              Reset()
     {
      ArrayInitialize(winFeatureSum, 0.0);
      ArrayInitialize(lossFeatureSum, 0.0);
      ArrayInitialize(featureEffect, 0.0);
      winCount = 0;
      lossCount = 0;
     }

   void              UpdateEffects()
     {
      for(int i = 0; i < ML_FEATURE_COUNT; i++)
        {
         double winAvg = (winCount > 0) ? winFeatureSum[i] / winCount : 0.5;
         double lossAvg = (lossCount > 0) ? lossFeatureSum[i] / lossCount : 0.5;
         featureEffect[i] = winAvg - lossAvg;
        }
     }
  };

//--- ML Diagnostic Info (NEW - for dashboard)
struct SMLDiagnostic
  {
   string            lastBlockReason;
   int               tradesAllowed;
   int               tradesBlocked;
   int               samplesFromTrades;
   double            lastLinearZ;
   bool              hasEnoughSamples;
   bool              hasGoodAccuracy;

   void              Reset()
     {
      lastBlockReason = "";
      tradesAllowed = 0;
      tradesBlocked = 0;
      samplesFromTrades = 0;
      lastLinearZ = 0;
      hasEnoughSamples = false;
      hasGoodAccuracy = false;
     }
  };

//+------------------------------------------------------------------+
//|           STATE MACHINE TYPES                                      |
//+------------------------------------------------------------------+

//--- Stage configuration (static, from inputs/preset)
class SSMStageConfig
  {
public:
   ENUM_SM_STAGE_ROLE          role;
   ENUM_SM_ELEMENT             primaryElem;
   ENUM_TF_LAYER               primaryTF;       // NEW
   ENUM_SM_ELEMENT             secondaryElem;
   ENUM_TF_LAYER               secondaryTF;     // NEW
   ENUM_SM_LOGIC               logic;
   bool                        causalLink;
   bool                        required;
   int                         timeoutBars;
   ENUM_SM_DIRECTION_POLICY    dirPolicy;

   void              Reset()
     {
      role          = SM_STAGE_TRIGGER;
      primaryElem   = SM_ELEM_NONE;
      primaryTF     = LAYER_CTF;     // NEW
      secondaryElem = SM_ELEM_NONE;
      secondaryTF   = LAYER_CTF;     // NEW
      logic         = SM_LOGIC_SINGLE;
      causalLink    = false;
      required      = true;
      timeoutBars   = 0;
      dirPolicy     = SM_DIR_FROM_TRIGGER;
     }
  };

//--- Runtime instance of a pattern (a running "chain")
class SSMInstance
  {
public:
   bool                  active;
   int                   id;
   ENUM_TRADE_DIRECTION direction; // Set by Trigger
   ENUM_TRADE_DIRECTION resolvedEntryDir; // ★ NEW: Resolved at Entry stage
   bool              isCounterDirPreset;   // NEW: true when resolvedEntryDir != inst.direction
   datetime              stageTime[SM_MAX_STAGES];
   int                   stageBarCtr[SM_MAX_STAGES];   // NEW: monotonic bar counter
   bool                  stageDone[SM_MAX_STAGES];
   bool                  stageSkipped[SM_MAX_STAGES];
   int                   currentStage;
   int                   birthEventTag;
   int                   triggerEventTag;               // NEW: guard against re-spawn
   double                triggerPrice;
   double                confirmPrice;
   double                entryZoneTop;
   double                entryZoneBottom;
   int                   causalTagUsed;
   int                   barsToConfirm;
   int                   barsToEntry;
   int                   totalBarsInChain;


   void              Reset()
     {
      active = false;
      id = -1;
      direction = DIR_NONE;
      resolvedEntryDir = DIR_NONE; // ★ NEW: initialize
      isCounterDirPreset = false;
      ArrayInitialize(stageTime, 0);
      ArrayInitialize(stageBarCtr, 0);    // NEW
      ArrayInitialize(stageDone, false);
      ArrayInitialize(stageSkipped, false);
      currentStage = 0;
      birthEventTag = -1;
      triggerEventTag = -1;               // NEW
      triggerPrice = 0;
      confirmPrice = 0;
      entryZoneTop = 0;
      entryZoneBottom = 0;
      causalTagUsed = -1;
      barsToConfirm = 0;
      barsToEntry = 0;
      totalBarsInChain = 0;
     }
  };

//--- Structural event (for causal tagging)
//--- Structural event type
enum ENUM_SM_EVENT_TYPE
  {
   SM_EVENT_CHOCH = 0,
   SM_EVENT_BOS   = 1,
   SM_EVENT_SWEEP = 2
  };

//--- Enhanced Structural event (replaces old SSMStructuralEvent)
struct SSMStructuralEvent
  {
   datetime             time;
   double               price;
   ENUM_TRADE_DIRECTION direction;
   int                  tag;
   int                  barIndex;
   int                  barCounter;      // NEW: monotonic counter (not iBarShift)
   ENUM_TF_LAYER        tfLayer;         // NEW: which TF layer triggered this
   bool                 valid;

   void              Reset()
     {
      time = 0;
      price = 0;
      direction = DIR_NONE;
      tag = -1;
      barIndex = -1;
      barCounter = 0;        // NEW
      tfLayer = LAYER_CTF;   // NEW
      valid = false;
     }
  };
#endif // ICT_TYPES_MQH
//+------------------------------------------------------------------+
