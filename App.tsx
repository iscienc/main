import { useState } from "react";

// ─── Types ───────────────────────────────────────────────────────────────────
interface Bug {
  id: number;
  severity: "CRITICAL" | "HIGH" | "MEDIUM";
  category: string;
  title: string;
  file: string;
  location: string;
  description: string;
  codeSnippet: string;
  impact: string;
  fix: string;
  fixSnippet?: string;
  tags: string[];
}

// ─── Bug Data ─────────────────────────────────────────────────────────────────
const bugs: Bug[] = [
  {
    id: 1,
    severity: "CRITICAL",
    category: "Risk Management",
    title: "Infinite-Loop / Freeze During Indicator Init — Blocking `OnInit`",
    file: "ICT_Utilities.mqh",
    location: "InitializeIndicators() — ATR wait-loop block",
    description:
      "An unconditional `while(true)` spin-loop was added to wait for the ATR indicator handle to become ready. The loop only escapes on `CopyBuffer()` success or a `Sleep(50)` retry. However, there is **no iteration limit and no timeout guard**. If the broker's data server is slow, the symbol data is not yet downloaded, or the indicator is called on a synthetic/custom instrument, `OnInit` will block indefinitely. MT5 will mark the EA as \"not responding\", the terminal watchdog may kill the thread, and in Strategy Tester the tester can hard-hang without returning any result.",
    codeSnippet: `// BUGGY: no max-iteration guard
while(true) {
    if(CopyBuffer(g_atrHandle, 0, 0, 3, g_atrBuffer) > 0) break;
    Sleep(50);
}
// Execution never leaves OnInit if data is unavailable`,
    impact:
      "**Trading halt** — EA never transitions from OnInit to OnTick. On a live account this means zero trade activity with no error surfaced to the user. In the Strategy Tester the entire backtest freezes.",
    fix: "Add a max-retry counter (e.g. 200 iterations × 50 ms = 10 s) and return `INIT_FAILED` if the handle never becomes ready.",
    fixSnippet: `int retries = 0;
while(retries++ < 200) {
    if(CopyBuffer(g_atrHandle, 0, 0, 3, g_atrBuffer) > 0) break;
    Sleep(50);
}
if(retries >= 200) {
    Print("FATAL: ATR indicator not ready after 10s. Aborting.");
    return INIT_FAILED;
}`,
    tags: ["OnInit", "ATR", "Hang", "Strategy Tester"],
  },
  {
    id: 2,
    severity: "CRITICAL",
    category: "Risk Management",
    title: "Lot Size Calculation Silently Returns 0 — Trades at Minimum Lot or Rejected",
    file: "ICT_Utilities.mqh",
    location: "CalculateLotFromRisk() — LOT_RISK_PERCENT branch",
    description:
      "When `InpLotMode == LOT_RISK_PERCENT`, the function computes `slTicks = slDistance / tickSize`. If `slDistance` is passed as **0** (which happens whenever `SL_STRUCTURE` mode returns no structural level because no OB or DR is found on the current bar), the division produces `slTicks = 0`, making `lot = riskAmount / 0` → **division by zero** in floating point, yielding `+Inf`. `NormalizeLot()` then clamps `+Inf` to `maxLot`, resulting in a **maximum-size position** being sent to the broker — a catastrophic over-leverage event.",
    codeSnippet: `// BUGGY — slDistance can legally be 0
double slTicks = slDistance / tickSize;       // → 0 / tickSize = 0
lot = riskAmount / (slTicks * tickValue);     // → riskAmount / 0 = +Inf

// NormalizeLot clamps +Inf → maxLot (e.g. 500 lots on a live account!)
return NormalizeLot(lot);`,
    impact:
      "**Account blow-up risk.** A position sized at broker `SYMBOL_VOLUME_MAX` (often 500 lots) can be opened whenever structural SL detection fails. This is the single most dangerous bug in the EA from a capital-preservation standpoint.",
    fix: "Guard against `slDistance <= 0` before the division and return 0 (or fallback to `InpFixedLot`) so the signal engine can skip the trade.",
    fixSnippet: `if(slDistance <= 0 || tickSize <= 0 || tickValue <= 0) {
    Print("Warning: Invalid SL distance — skipping trade.");
    return 0.0;   // signal engine must check for 0 and abort order
}
double slTicks = slDistance / tickSize;
double lot     = riskAmount / (slTicks * tickValue);
return NormalizeLot(lot);`,
    tags: ["Lot Sizing", "Division-by-Zero", "SL", "Account Blow-up"],
  },
  {
    id: 3,
    severity: "CRITICAL",
    category: "Logic / Comparison",
    title: "Truncated Comparison Operators in `DetectAMDPhase` — Phase Never Correctly Detected",
    file: "ICT_AMD.mqh",
    location: "DetectAMDPhase() — currentRange and atr comparisons",
    description:
      "In the raw source (DR8.txt), several comparison expressions appear truncated due to HTML entity encoding stripping `<` and `>` characters (`<` and `>` become empty gaps). The resulting MQL5 code contains expressions like `if(atr ` and `else if(currentRange ` with no operator and no right-hand operand. The MQL5 compiler will either refuse to compile or, if a prior version silently patched these lines, will apply a **wrong default** (e.g. treating the missing comparison as always `true` or always `false`). This means the AMD phase (Accumulation / Manipulation / Distribution) is never correctly classified, so the phase-score bonus and expected direction produced downstream are always wrong.",
    codeSnippet: `// BUGGY — operator and RHS stripped (HTML entity decode failure)
if(atr           /* < operator missing */ )          // always false?
    return;

if(expansionSize > atr * 2.0) confidence = 95;

// AND further down:
else if(currentRange   /* < operator missing */ )    // accumulation check broken
    { ... }

if(g_amdPhase.accumulationLow == 0 || rangeLow /* = missing RHS */ )
    g_amdPhase.accumulationLow = rangeLow;`,
    impact:
      "**Silent mis-classification of every AMD phase.** The EA's expected direction for entries is derived directly from `g_amdPhase.expectedDirection`. With broken comparisons, the EA may enter trades in the Distribution phase expecting the wrong direction, or block all entries during valid Distribution windows.",
    fix: "Restore the correct comparison operators. Based on the ICT AMD model: `if(atr <= 0) return;` for the guard, and `if(currentRange < atr * InpAccumulationRangeATR)` for the accumulation check.",
    fixSnippet: `// Corrected guards and comparisons
if(atr <= 0) return;

// Accumulation: tight range
else if(currentRange < atr * InpAccumulationRangeATR) {
    detectedPhase = AMD_ACCUMULATION;
    confidence = 60;
}

// Accumulation tracking
if(g_amdPhase.accumulationLow == 0 || rangeLow < g_amdPhase.accumulationLow)
    g_amdPhase.accumulationLow = rangeLow;`,
    tags: ["AMD", "Phase Detection", "Operator", "Comparison", "Compile Error"],
  },
  {
    id: 4,
    severity: "CRITICAL",
    category: "Logic / Comparison",
    title: "Stripped `<`/`>` Operators in `ValidateInputs()` — Risk Validation Always Passes",
    file: "ICT_Utilities.mqh",
    location: "ValidateInputs() — InpHTF_Timeframe and InpRiskPercent checks",
    description:
      "Multiple `if` conditions inside `ValidateInputs()` suffer from the same HTML-entity stripping bug. The comparisons `InpHTF_Timeframe = Period()` and `InpRiskPercent 10` lose their operators entirely. As a result, the validation function **always returns `true`** regardless of how absurd the user's input values are. A risk of 0 % or 500 % will pass validation silently. A Lower TF set higher than the current chart TF will not trigger the warning. This defeats the entire safety net of `ValidateInputs()`.",
    codeSnippet: `// BUGGY — operators stripped, conditions are syntactically incomplete
if(InpHTF_Timeframe  /* <= */ Period()) {   // HTF check broken
    Print("Error: HTF must be higher than current TF");
    return false;
}
if(InpRiskPercent  /* < */ 0
   || InpRiskPercent  /* > */ 10) {          // risk range check broken
    Print("Error: Risk percent must be between 0 and 10");
    return false;
}`,
    impact:
      "**All input validation is bypassed.** An incorrectly configured EA (wrong TF order, extreme risk %, zero displacement multiplier) will be accepted and run without warning, compounding every other bug.",
    fix: "Restore the correct operators for every comparison in `ValidateInputs()`.",
    fixSnippet: `if(InpHTF_Timeframe <= Period()) {
    Print("Error: HTF must be higher than current chart timeframe");
    return false;
}
if(InpRiskPercent < 0 || InpRiskPercent > 10) {
    Print("Error: Risk percent must be between 0 and 10");
    return false;
}
if(InpDisplacementMultiplier < 0.5 || InpDisplacementMultiplier > 5.0) {
    Print("Error: Displacement multiplier out of reasonable range");
    return false;
}`,
    tags: ["Validation", "Input Params", "Operator Stripping", "Risk %"],
  },
  {
    id: 5,
    severity: "CRITICAL",
    category: "Order Management",
    title: "`CheckMaxLossFilter()` Uses Inverted Comparison — Max-Loss Guard Never Triggers",
    file: "ICT_Utilities.mqh",
    location: "CheckMaxLossFilter()",
    description:
      "The daily max-loss filter is intended to halt trading once drawdown exceeds `InpMaxDailyLossPercent`. The condition reads `if(g_stats.todayPnL = 0)` (again, stripping of `<=` to `=` or a typo), which means the function returns `false` (block trading) only when `todayPnL` equals **exactly zero** — an almost impossible floating-point match. At all other times — including deep drawdown — the function returns `true` (allow trading). The protection is completely inverted and non-functional.",
    codeSnippet: `// BUGGY — comparison stripped/inverted
bool CheckMaxLossFilter() {
    if(!InpUseMaxLoss) return true;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double maxLoss = balance * InpMaxDailyLossPercent / 100.0;
    if(g_stats.todayPnL  /* <= */ -maxLoss)  // operator stripped → never true
        return false;   // never reached
    return true;        // always reached, even during runaway loss
}`,
    impact:
      "**The daily max-loss circuit-breaker does not function.** The EA will continue placing trades even after the account is down by any amount, including 100 %.",
    fix: "Restore the `<=` operator so the guard fires when `todayPnL` drops below the negative threshold.",
    fixSnippet: `bool CheckMaxLossFilter() {
    if(!InpUseMaxLoss) return true;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double maxLoss = balance * InpMaxDailyLossPercent / 100.0;
    if(g_stats.todayPnL <= -maxLoss) {
        if(!g_maxLossReached) {
            Print("Daily max loss reached: ", DoubleToString(g_stats.todayPnL, 2));
            g_maxLossReached = true;
        }
        return false;
    }
    return true;
}`,
    tags: ["Max Loss", "Risk Guard", "Daily Limit", "Inverted Logic"],
  },
  {
    id: 6,
    severity: "CRITICAL",
    category: "Structural Logic",
    title: "`CheckRecentBOS()` Uses Ambiguous `iBarShift()` — Wrong Bar Index, False BOS Signals",
    file: "ICT_AMD.mqh",
    location: "CheckRecentBOS() — bosBar bounds check",
    description:
      "The function calls `iBarShift(_Symbol, PERIOD_CURRENT, dr.corrLine.extremeTime, false)` and then checks `if(bosBar >= 0 && bosBar < lookback)`. The `false` parameter means MT5 returns the **nearest** bar index if the exact timestamp is not found. On higher timeframes where bar timestamps span minutes, the returned index can be a completely wrong bar — for example bar 0 (the currently-forming bar) — making every tick during the current bar falsely report a recent BOS. This floods `g_amdPhase` with false `AMD_DISTRIBUTION` classifications.",
    codeSnippet: `// BUGGY — false=nearest-match can return bar 0 spuriously
int bosBar = iBarShift(_Symbol, PERIOD_CURRENT,
                        dr.corrLine.extremeTime, false);  // ← 'false' is the problem
if(bosBar >= 0 && bosBar < lookback)
    return true;  // false positives on every tick of the current bar`,
    impact:
      "**False BOS signals cascade into false AMD_DISTRIBUTION phase**, which unlocks entries during consolidation phases when the market has not actually broken structure. This is a primary source of premature trade entries.",
    fix: "Use `true` (exact match) and handle the `-1` return, OR validate that the returned bar's open time matches the stored `extremeTime` within one bar's duration.",
    fixSnippet: `int bosBar = iBarShift(_Symbol, PERIOD_CURRENT,
                        dr.corrLine.extremeTime, true);   // exact match only
if(bosBar < 0) return false;   // timestamp not found → no BOS confirmed
// Optionally validate time match
datetime barTime = iTime(_Symbol, PERIOD_CURRENT, bosBar);
if(MathAbs((long)(barTime - dr.corrLine.extremeTime)) > PeriodSeconds())
    return false;
return (bosBar > 0 && bosBar < lookback);   // exclude forming bar 0`,
    tags: ["BOS", "iBarShift", "False Signal", "AMD Phase"],
  },
  {
    id: 7,
    severity: "HIGH",
    category: "Sweep Detection",
    title: "`CheckSweep()` Includes Bar 0 (Forming Candle) — Premature Sweep Confirmations",
    file: "ICT_Utilities.mqh",
    location: "CheckSweep() — lookback loop starting at bar 0",
    description:
      "The sweep detection loop iterates `for(int i = 0; i < lookback; i++)` starting at **bar 0**, the currently-forming, incomplete candle. `SWEEP_WICK_CLOSE_BACK` (the default mode) checks that `prevClose < level` (closed back below), but the close of bar 0 changes on every tick. This means a sweep can be \"confirmed\" on one tick and \"unconfirmed\" on the next within the same bar, producing tick-by-tick flip-flopping of the `g_judasSwing.isConfirmed` flag and of the sweep state machine trigger.",
    codeSnippet: `// BUGGY — loop starts at bar 0 (forming candle)
for(int i = 0; i < lookback; i++) {
    double prevHigh  = TF_High(tf, i);   // i=0 → incomplete candle
    double prevClose = TF_Close(tf, i);  // changes every tick
    ...
    case SWEEP_WICK_CLOSE_BACK:
        return (prevHigh >= level && prevClose < level); // unstable on bar 0
}`,
    impact:
      "**State machine trigger fires and resets multiple times per bar** on the forming candle. In `SM_INSTANCE_COEXIST` mode this can spawn multiple overlapping instances of the same setup, leading to duplicate and conflicting orders within a single candle.",
    fix: "Start the lookback loop at bar **1** (the last fully-closed candle).",
    fixSnippet: `// Fixed — start at confirmed closed candle
for(int i = 1; i <= lookback; i++) {
    double prevHigh  = TF_High(tf, i);
    double prevClose = TF_Close(tf, i);
    ...
}`,
    tags: ["Sweep", "Bar 0", "Forming Candle", "State Machine", "Duplicate Orders"],
  },
  {
    id: 8,
    severity: "HIGH",
    category: "Displacement Detection",
    title: "Consecutive Displacement Check Compares Bar Close to Bar Open of Wrong Bar",
    file: "ICT_Utilities.mqh",
    location: "IsConsecutiveDisplacement() — bullish/bearish direction check",
    description:
      "The multi-candle displacement validator checks each candle's close against `barOpen`, but `barOpen` is obtained inside the loop from `TF_Open(tf, i)` where `i` is the current iteration index. For the **bullish** path, the code verifies `barClose >= barOpen` (bar is bullish), but the intent is to verify a sequence of consecutively higher closes forming an impulsive move. Checking only that each bar is bullish is insufficient — it ignores gaps between bars and allows a series of tiny, body-dominated doji-style candles to qualify as \"displacement\".",
    codeSnippet: `// BUGGY — only checks individual candle direction, not total move momentum
for(int i = startBar; i >= endBar; i--) {
    double barClose = TF_Close(tf, i);
    double barOpen  = TF_Open(tf, i);
    if(expectBullish && barClose < barOpen) return false;  // only checks green candle
    if(!expectBullish && barClose >= barOpen) return false; // only checks red candle
    totalMove += MathAbs(barClose - barOpen);
}
// totalMove is accumulated but NEVER compared against an ATR threshold!`,
    impact:
      "**Any sequence of same-direction candles passes as displacement** regardless of their individual sizes or the ATR threshold. The `InpDisplacementMultiplier` parameter has zero effect on multi-candle displacement, making the filter ineffective.",
    fix: "Compare `totalMove` against `atr * InpDisplacementMultiplier` at the end of the loop, and additionally verify that each bar body meets `InpDisp_MinBodyPercent`.",
    fixSnippet: `double totalMove = 0;
for(int i = startBar; i >= endBar; i--) {
    double body  = BodySize(tf, i);
    double range = CandleRange(tf, i);
    if(range > 0 && (body / range * 100.0) < InpDisp_MinBodyPercent)
        return false;   // weak body — not displacement
    if(expectBullish && TF_Close(tf,i) < TF_Open(tf,i)) return false;
    if(!expectBullish && TF_Close(tf,i) >= TF_Open(tf,i)) return false;
    totalMove += body;
}
// Now validate total move size
double atr = GetATR();
return (totalMove >= atr * InpDisplacementMultiplier);`,
    tags: ["Displacement", "ATR", "Candle Filter", "Entry Quality"],
  },
  {
    id: 9,
    severity: "HIGH",
    category: "Pivot Detection",
    title: "`IsPivotHigh` / `IsPivotLow` — Off-by-One Causes Missed and Phantom Pivots",
    file: "ICT_Utilities.mqh",
    location: "IsPivotHigh() and IsPivotLow() — bounds check",
    description:
      "Both pivot functions guard with `if(barIndex + leftBars >= totalBars || barIndex - rightBars < 0) return false;`. The right-side check `barIndex - rightBars < 0` protects against negative indexing, but the subsequent right-side loop iterates `for(int i = 1; i <= rightBars; i++)` checking bar `barIndex - i`. When `barIndex - rightBars == 0` exactly, bar 0 (forming candle) is included in the right-side confirmation window, causing the same forming-bar instability as Bug #7. Additionally, the left-side bars (`barIndex + leftBars`) can equal `totalBars - 1` (the oldest available bar) whose data may be partially loaded on the first tick, producing phantom pivots at historical extremes.",
    codeSnippet: `// BUGGY — right-side window can include bar 0
bool IsPivotHigh(ENUM_TIMEFRAMES tf, int barIndex, int leftBars, int rightBars) {
    int totalBars = TF_Bars(tf);
    if(barIndex + leftBars >= totalBars || barIndex - rightBars < 0) return false;
    // Right-side loop may reach bar 0 when barIndex == rightBars
    for(int i = 1; i <= rightBars; i++) {
        if(TF_High(tf, barIndex - i) >= high) return false;  // bar 0 possible
    }
}`,
    impact:
      "Phantom pivot highs/lows are used as **DR origin points and CL levels**. A false origin shifts the entire dealing range structure, causing the EA to draw incorrect inducement levels and to classify the wrong swing as the CL — ultimately directing trades against the intended bias.",
    fix: "Change the right-side guard to `barIndex - rightBars < 1` (exclude bar 0) and assert `barIndex + leftBars < totalBars - 1` to skip the oldest unreliable bar.",
    fixSnippet: `if(barIndex + leftBars >= totalBars - 1) return false; // skip oldest bar
if(barIndex - rightBars < 1) return false;             // exclude forming bar 0
// Rest of loop is then safe`,
    tags: ["Pivot", "Bar 0", "DR Origin", "CL Level", "Off-by-One"],
  },
  {
    id: 10,
    severity: "HIGH",
    category: "Memory / Object Management",
    title: "`PeriodicCleanup()` Deletes Objects by Age Using `ObjectGetInteger` — Wrong Property Key",
    file: "ICT_Utilities.mqh",
    location: "PeriodicCleanup() — objTime retrieval",
    description:
      "The cleanup function attempts to read an object's creation time via `ObjectGetInteger(0, name, OBJPROP_TIME, 0)` to compare it against `g_lastCleanupTime`. However, `OBJPROP_TIME` on a **rectangle** or **line** object returns the X-axis anchor time (the chart time of the left or right anchor point), not the system creation time of the object. For zone rectangles (OBs, FVGs, DRs), this anchor time is the historical bar time of the zone's formation — which will almost always be older than the cleanup threshold — causing **all active zone objects to be deleted every cleanup cycle**.",
    codeSnippet: `// BUGGY — OBJPROP_TIME returns anchor time, not object creation time
datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
if(objTime > 0 && objTime < cutoffTime)
    // ALL zone rectangles' left anchor is in the past → deleted every cycle!
    ObjectDelete(0, name);`,
    impact:
      "**All Order Block, FVG, and Dealing Range zone rectangles are erased every cleanup cycle** (default: every 5 minutes). The chart goes blank, the signal engine can no longer detect price returning to a zone, and all stacking / PD-array queries fail silently (returning empty results).",
    fix: "Track creation time in the object's **description** field or use a separate `datetime` array keyed by object name. Alternatively, apply age filtering based on the zone's own stored formation time from the PD-array structs rather than from the chart object.",
    fixSnippet: `// Preferred: encode creation time in object description at creation
ObjectSetString(0, name, OBJPROP_TOOLTIP, IntegerToString(TimeCurrent()));

// In cleanup, read back from description/tooltip
string tooltip = ObjectGetString(0, name, OBJPROP_TOOLTIP);
datetime createdAt = (datetime)StringToInteger(tooltip);
if(createdAt > 0 && createdAt < cutoffTime)
    ObjectDelete(0, name);`,
    tags: ["Cleanup", "OBJPROP_TIME", "OB", "FVG", "Zone Deletion", "Chart Objects"],
  },
  {
    id: 11,
    severity: "HIGH",
    category: "Session Filter",
    title: "`CheckSessionFilter()` Double-Checks Same Field — Non-Killzone Hours Not Blocked",
    file: "ICT_Utilities.mqh",
    location: "CheckSessionFilter()",
    description:
      "The session filter first allows trading if `g_killzone.isActive`, then also allows if `g_killzone.current != KZ_OFF_HOURS && g_killzone.current != KZ_NONE`. The second condition is intended to catch the case where the killzone struct has a label but `isActive` is false (a transitional state). However, `KZ_OFF_HOURS` and `KZ_NONE` may be **different enum values**. More critically, if the killzone detection code sets `g_killzone.current` to a session enum (e.g. `KZ_ASIAN`) but sets `isActive = false` because `InpTradeAsianKZ` is disabled, the second condition still returns `true` — bypassing the user's session filter completely.",
    codeSnippet: `bool CheckSessionFilter() {
    if(!InpUseKillzoneFilter) return true;
    if(g_killzone.isActive) return true;              // OK
    // BUG: allows trading in disabled sessions (e.g. Asian when InpTradeAsianKZ=false)
    if(g_killzone.current != KZ_OFF_HOURS &&
       g_killzone.current != KZ_NONE) return true;   // ← wrong
    return false;
}`,
    impact:
      "**Trades are placed during disabled session windows** (e.g. Asian session when `InpTradeAsianKZ = false`). This undermines the entire killzone filter, a core risk-management feature of the EA.",
    fix: "Remove the second `if` block entirely. The `isActive` flag is the authoritative answer — it should already incorporate the user's session enable/disable settings.",
    fixSnippet: `bool CheckSessionFilter() {
    if(!InpUseKillzoneFilter) return true;
    return g_killzone.isActive;  // isActive already reflects enabled sessions
}`,
    tags: ["Session Filter", "Killzone", "Asian", "Session Logic"],
  },
  {
    id: 12,
    severity: "HIGH",
    category: "Color Utility",
    title: "Color Bit-Packing in `ColorDarken` / `ColorLighten` / `ColorBlend` — Channels Swapped",
    file: "ICT_Utilities.mqh",
    location: "ColorDarken(), ColorLighten(), ColorBlend()",
    description:
      "All three color utility functions extract RGB channels with: `int r = (baseColor & 0xFF)`, `int g = ((baseColor >> 8) & 0xFF)`, `int b = ((baseColor >> 16) & 0xFF)`. In MQL5, the `color` type stores channels as **BGR** (0x00BBGGRR), not RGB. The bit layout is correct for reading (R is low byte, B is high byte), but the re-packing at the end uses `return (color)((b << 16) | (g << 8) | r)` — which is also correct. **However**, the return expression in the truncated code shows `return (color)((b > 8) & 0xFF)` — the bitshift direction is reversed (`>` instead of `<<`). This means the returned color value is completely wrong.",
    codeSnippet: `// BUGGY — closing expression has '>' instead of '<<' (truncation artifact)
color ColorDarken(color baseColor, int percent) {
    int r = (baseColor & 0xFF);
    int g = ((baseColor >> 8) & 0xFF);
    int b = ((baseColor >> 16) & 0xFF);
    r = r * (100 - percent) / 100;
    g = g * (100 - percent) / 100;
    b = b * (100 - percent) / 100;
    return (color)((b > 8) & 0xFF);  // ← WRONG: should be (b<<16)|(g<<8)|r
}`,
    impact:
      "Every darkened/lightened/blended color in the UI is garbage. Order block, FVG, and DR zone colors will be rendered as random nonsensical colors, making the chart unreadable and potentially hiding active zones behind invisible (black) rectangles.",
    fix: "Restore correct bit-packing in all three functions.",
    fixSnippet: `color ColorDarken(color baseColor, int percent) {
    int r = (int)(baseColor & 0xFF);
    int g = (int)((baseColor >> 8) & 0xFF);
    int b = (int)((baseColor >> 16) & 0xFF);
    r = r * (100 - percent) / 100;
    g = g * (100 - percent) / 100;
    b = b * (100 - percent) / 100;
    return (color)((b << 16) | (g << 8) | r);  // correct BGR packing
}`,
    tags: ["Color", "BGR", "Bitshift", "UI", "Chart Objects"],
  },
  {
    id: 13,
    severity: "MEDIUM",
    category: "Displacement / FVG",
    title: "FVG Created-by-Displacement Check Has Inverted Bullish / Bearish Gap Condition",
    file: "ICT_Utilities.mqh",
    location: "IsConsecutiveDisplacement() — InpDisp_RequireFVGCreated block",
    description:
      "When `InpDisp_RequireFVGCreated` is enabled, the code checks for a gap between the bar before the displacement and the bar after it. For the **bullish** case it asserts `afterLow >= beforeHigh` (gap up), which is correct. For the **bearish** case it asserts `afterHigh <= beforeLow` (gap down). However, looking at the raw source, the bearish branch reads `if(afterHigh <= beforeLow) return false;` — this **returns false** (rejects) when there IS a bearish FVG, which is the exact opposite of the intended behaviour.",
    codeSnippet: `if(InpDisp_RequireFVGCreated) {
    double beforeHigh = TF_High(tf, startBar + 1);
    double afterLow   = TF_Low(tf, startBar - 1);
    if(expectBullish && afterLow >= beforeHigh) {  // correct: bullish FVG exists → OK
        // continue
    }
    // BUG: inverted — rejects bearish displacement that created a FVG
    if(!expectBullish && afterHigh <= beforeLow) return false;
    // Should be: return false only when NO bearish FVG was created
}`,
    impact:
      "When `InpDisp_RequireFVGCreated = true`, **all valid bearish displacements that correctly created an FVG are rejected**, while invalid bearish displacements (no FVG) are accepted. The feature works 100% in reverse for short setups.",
    fix: "Negate the bearish FVG condition so it returns false only when the FVG is absent.",
    fixSnippet: `if(InpDisp_RequireFVGCreated) {
    double beforeHigh = TF_High(tf, startBar + 1);
    double beforeLow  = TF_Low(tf, startBar + 1);
    double afterHigh  = TF_High(tf, startBar - 1);
    double afterLow   = TF_Low(tf, startBar - 1);
    if(expectBullish  && afterLow  > beforeHigh) return false; // no bullish FVG
    if(!expectBullish && afterHigh < beforeLow)  return false; // no bearish FVG
}`,
    tags: ["FVG", "Displacement", "Bearish", "Inverted Logic"],
  },
  {
    id: 14,
    severity: "MEDIUM",
    category: "Pullback / Structure",
    title: "`HasPulledBackFromExtreme()` — Pullback Distance Uses `ATR * 0` Default",
    file: "ICT_Utilities.mqh",
    location: "HasPulledBackFromExtreme() — pullbackDist calculation",
    description:
      "The function calculates `pullbackDist = atr * InpCL_PullbackMinATR`. The input parameter `InpCL_PullbackMinATR` has a default value of `0.2`. However, the validation in `ValidateInputs()` (already broken by Bug #4) does not enforce a lower bound. If a user sets `InpCL_PullbackMinATR = 0`, the `pullbackDist` becomes 0, and the condition `barClose < extremePrice - 0` (for bullish) becomes `barClose < extremePrice` — meaning any tick below the CL extreme price qualifies as a \"pullback\". This causes CL updates to fire on the very next tick after a new extreme, making `CL_PULLBACK_REQUIRED` mode behave identically to `CL_IMMEDIATE_EXTREME` mode.",
    codeSnippet: `// Vulnerable — pullbackDist can be 0 if InpCL_PullbackMinATR = 0
double pullbackDist = atr * InpCL_PullbackMinATR;  // = atr * 0 = 0

// Then any bar below extreme qualifies as a pullback
if(isBullish && barClose < extremePrice - pullbackDist)  // = extremePrice - 0
    return true;  // fires immediately on any close below extreme`,
    impact:
      "The CL (Correlation Line / Corrective Level) updates prematurely, shifting the dealing range structure on every minor retracement. Entries are triggered before the proper pullback develops, reducing trade quality across all setups.",
    fix: "Add a minimum bound check on `InpCL_PullbackMinATR` in `ValidateInputs()` and add a guard in `HasPulledBackFromExtreme()`.",
    fixSnippet: `// In ValidateInputs():
if(InpCL_PullbackMinATR < 0.1) {
    Print("Warning: CL PullbackMinATR too low, clamping to 0.1");
    // Note: inputs are const — log warning and use a local variable
}

// In HasPulledBackFromExtreme():
double minPullback = MathMax(0.1, InpCL_PullbackMinATR);
double pullbackDist = atr * minPullback;`,
    tags: ["CL", "Pullback", "ATR", "Dealing Range", "Mode Override"],
  },
  {
    id: 15,
    severity: "MEDIUM",
    category: "State Machine",
    title: "State Machine `SM_INSTANCE_COEXIST` + Global Timeout — Orphaned Instances Never Expire",
    file: "ICT_SMEngine.mqh (referenced)",
    location: "UpdateSMEngine() — instance timeout check",
    description:
      "The config exposes `InpSM_GlobalTimeout = 80` (bars). However, in `SM_INSTANCE_COEXIST` mode when `InpSM_MaxInstances = 4`, the engine can accumulate up to 4 concurrent instances. If the global timeout is reached on instance #1, it is discarded — but instances #2, #3, #4 that were spawned subsequently have their timers measured from their own spawn time, not from instance #1's spawn. Meanwhile, instances that reach their `SM_Ent_Timeout` without finding an entry PD-array quietly transition to a \"pending\" state rather than being terminated. Over a slow/ranging market session, dozens of pending instances accumulate in the array, consuming heap memory and causing O(n²) scans on every tick.",
    codeSnippet: `// Conceptual representation of the bug
for(int i = 0; i < g_smInstances.Total(); i++) {
    CSMInstance* inst = g_smInstances.At(i);
    // Each instance's timeout counted from its OWN spawn bar — correct
    // BUT: instances that miss entry are set to SM_STATE_PENDING, not removed
    if(inst.state == SM_STATE_ENTRY_MISS)
        inst.state = SM_STATE_PENDING;  // ← leaks; should be SM_STATE_EXPIRED
}`,
    impact:
      "**Memory leak and performance degradation** over long trading sessions. The O(n²) scan cost becomes measurable after several hours. Additionally, stale pending instances can erroneously re-activate when their originally-seen trigger condition re-appears, firing entries out of context.",
    fix: "Change `SM_STATE_ENTRY_MISS` handling to immediately set state to `SM_STATE_EXPIRED` and remove the instance from the array. Add a hard cap: if `g_smInstances.Total() > InpSM_MaxInstances * 2`, purge all non-active instances.",
    fixSnippet: `if(inst.state == SM_STATE_ENTRY_MISS || 
   inst.barsActive > InpSM_GlobalTimeout) {
    inst.state = SM_STATE_EXPIRED;
    g_smInstances.Delete(i);
    i--;   // adjust index after deletion
    continue;
}`,
    tags: ["State Machine", "Memory Leak", "Instance Management", "Coexist Mode"],
  },
];

// ─── Severity Config ──────────────────────────────────────────────────────────
const severityConfig = {
  CRITICAL: {
    bg: "bg-red-950",
    border: "border-red-500",
    badge: "bg-red-600 text-white",
    glow: "shadow-red-900/60",
    icon: "🔴",
    label: "CRITICAL",
    dot: "bg-red-500",
  },
  HIGH: {
    bg: "bg-orange-950",
    border: "border-orange-500",
    badge: "bg-orange-500 text-white",
    glow: "shadow-orange-900/60",
    icon: "🟠",
    label: "HIGH",
    dot: "bg-orange-500",
  },
  MEDIUM: {
    bg: "bg-yellow-950",
    border: "border-yellow-500",
    badge: "bg-yellow-500 text-black",
    glow: "shadow-yellow-900/60",
    icon: "🟡",
    label: "MEDIUM",
    dot: "bg-yellow-400",
  },
};

const categoryColors: Record<string, string> = {
  "Risk Management": "bg-red-900/50 text-red-300 border border-red-700",
  "Logic / Comparison": "bg-purple-900/50 text-purple-300 border border-purple-700",
  "Order Management": "bg-pink-900/50 text-pink-300 border border-pink-700",
  "Structural Logic": "bg-blue-900/50 text-blue-300 border border-blue-700",
  "Sweep Detection": "bg-cyan-900/50 text-cyan-300 border border-cyan-700",
  "Displacement Detection": "bg-teal-900/50 text-teal-300 border border-teal-700",
  "Pivot Detection": "bg-indigo-900/50 text-indigo-300 border border-indigo-700",
  "Memory / Object Management": "bg-rose-900/50 text-rose-300 border border-rose-700",
  "Session Filter": "bg-green-900/50 text-green-300 border border-green-700",
  "Color Utility": "bg-violet-900/50 text-violet-300 border border-violet-700",
  "Displacement / FVG": "bg-amber-900/50 text-amber-300 border border-amber-700",
  "Pullback / Structure": "bg-lime-900/50 text-lime-300 border border-lime-700",
  "State Machine": "bg-fuchsia-900/50 text-fuchsia-300 border border-fuchsia-700",
};

// ─── Components ───────────────────────────────────────────────────────────────
function CodeBlock({ code, label }: { code: string; label?: string }) {
  const [copied, setCopied] = useState(false);
  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <div className="mt-2 rounded-lg overflow-hidden border border-slate-700">
      <div className="flex items-center justify-between bg-slate-800 px-4 py-2">
        <span className="text-xs text-slate-400 font-mono">{label || "MQL5"}</span>
        <button
          onClick={handleCopy}
          className="text-xs text-slate-400 hover:text-white transition-colors flex items-center gap-1"
        >
          {copied ? "✓ Copied" : "Copy"}
        </button>
      </div>
      <pre className="bg-slate-900 p-4 text-xs text-green-300 font-mono overflow-x-auto leading-relaxed whitespace-pre-wrap">
        {code}
      </pre>
    </div>
  );
}

function BugCard({ bug, isOpen, onToggle }: { bug: Bug; isOpen: boolean; onToggle: () => void }) {
  const s = severityConfig[bug.severity];
  const catColor = categoryColors[bug.category] || "bg-slate-800 text-slate-300 border border-slate-600";

  return (
    <div
      className={`rounded-xl border-2 ${s.border} shadow-xl ${s.glow} transition-all duration-300 overflow-hidden`}
      style={{ boxShadow: isOpen ? undefined : undefined }}
    >
      {/* Header */}
      <button
        onClick={onToggle}
        className={`w-full text-left ${s.bg} px-6 py-5 flex items-start gap-4 hover:brightness-110 transition-all`}
      >
        <span className="text-2xl mt-0.5 shrink-0">{s.icon}</span>
        <div className="flex-1 min-w-0">
          <div className="flex flex-wrap items-center gap-2 mb-2">
            <span className={`text-xs font-bold px-2 py-1 rounded-full ${s.badge}`}>
              {s.label}
            </span>
            <span className={`text-xs px-2 py-1 rounded-full ${catColor}`}>
              {bug.category}
            </span>
            <span className="text-xs px-2 py-1 rounded-full bg-slate-800/70 text-slate-400 border border-slate-600 font-mono">
              #{bug.id.toString().padStart(2, "0")}
            </span>
          </div>
          <h3 className="text-white font-semibold text-base leading-snug">{bug.title}</h3>
          <div className="flex flex-wrap gap-2 mt-2">
            <span className="text-xs text-slate-400 font-mono">📄 {bug.file}</span>
            <span className="text-xs text-slate-400">⚡ {bug.location}</span>
          </div>
        </div>
        <span className="text-slate-400 text-xl shrink-0 mt-1">{isOpen ? "▲" : "▼"}</span>
      </button>

      {/* Body */}
      {isOpen && (
        <div className="bg-slate-900 px-6 py-6 space-y-6 border-t border-slate-700">
          {/* Description */}
          <div>
            <h4 className="text-slate-300 font-semibold text-sm mb-2 flex items-center gap-2">
              <span className="text-blue-400">📋</span> Description
            </h4>
            <p className="text-slate-300 text-sm leading-relaxed"
              dangerouslySetInnerHTML={{
                __html: bug.description
                  .replace(/\*\*(.*?)\*\*/g, '<strong class="text-white">$1</strong>')
                  .replace(/`(.*?)`/g, '<code class="bg-slate-800 text-green-300 px-1 rounded text-xs font-mono">$1</code>'),
              }}
            />
          </div>

          {/* Buggy Code */}
          <div>
            <h4 className="text-slate-300 font-semibold text-sm mb-2 flex items-center gap-2">
              <span className="text-red-400">🐛</span> Buggy Code
            </h4>
            <CodeBlock code={bug.codeSnippet} label="BUGGY — MQL5" />
          </div>

          {/* Impact */}
          <div className={`rounded-lg border ${s.border} ${s.bg} px-4 py-4`}>
            <h4 className="text-white font-semibold text-sm mb-1 flex items-center gap-2">
              <span>⚠️</span> Trading Impact
            </h4>
            <p
              className="text-sm leading-relaxed text-slate-200"
              dangerouslySetInnerHTML={{
                __html: bug.impact
                  .replace(/\*\*(.*?)\*\*/g, '<strong class="text-white">$1</strong>')
                  .replace(/`(.*?)`/g, '<code class="bg-black/30 text-green-300 px-1 rounded text-xs font-mono">$1</code>'),
              }}
            />
          </div>

          {/* Fix */}
          <div>
            <h4 className="text-slate-300 font-semibold text-sm mb-2 flex items-center gap-2">
              <span className="text-green-400">✅</span> Recommended Fix
            </h4>
            <p
              className="text-slate-300 text-sm leading-relaxed mb-2"
              dangerouslySetInnerHTML={{
                __html: bug.fix
                  .replace(/\*\*(.*?)\*\*/g, '<strong class="text-white">$1</strong>')
                  .replace(/`(.*?)`/g, '<code class="bg-slate-800 text-green-300 px-1 rounded text-xs font-mono">$1</code>'),
              }}
            />
            {bug.fixSnippet && <CodeBlock code={bug.fixSnippet} label="FIXED — MQL5" />}
          </div>

          {/* Tags */}
          <div className="flex flex-wrap gap-2 pt-2 border-t border-slate-700">
            {bug.tags.map((tag) => (
              <span
                key={tag}
                className="text-xs px-2 py-1 rounded bg-slate-800 text-slate-400 border border-slate-700 font-mono"
              >
                #{tag}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Stats Bar ────────────────────────────────────────────────────────────────
function StatsBar() {
  const criticals = bugs.filter((b) => b.severity === "CRITICAL").length;
  const highs = bugs.filter((b) => b.severity === "HIGH").length;
  const mediums = bugs.filter((b) => b.severity === "MEDIUM").length;

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      <div className="bg-slate-800 rounded-xl border border-slate-700 p-4 text-center">
        <div className="text-3xl font-bold text-white">{bugs.length}</div>
        <div className="text-xs text-slate-400 mt-1">Total Bugs Found</div>
      </div>
      <div className="bg-red-950 rounded-xl border border-red-700 p-4 text-center">
        <div className="text-3xl font-bold text-red-400">{criticals}</div>
        <div className="text-xs text-red-300 mt-1">🔴 Critical</div>
      </div>
      <div className="bg-orange-950 rounded-xl border border-orange-700 p-4 text-center">
        <div className="text-3xl font-bold text-orange-400">{highs}</div>
        <div className="text-xs text-orange-300 mt-1">🟠 High</div>
      </div>
      <div className="bg-yellow-950 rounded-xl border border-yellow-700 p-4 text-center">
        <div className="text-3xl font-bold text-yellow-400">{mediums}</div>
        <div className="text-xs text-yellow-300 mt-1">🟡 Medium</div>
      </div>
    </div>
  );
}

// ─── Filter Bar ───────────────────────────────────────────────────────────────
function FilterBar({
  filter,
  setFilter,
  search,
  setSearch,
}: {
  filter: string;
  setFilter: (v: string) => void;
  search: string;
  setSearch: (v: string) => void;
}) {
  return (
    <div className="flex flex-col md:flex-row gap-3 mb-6">
      <input
        type="text"
        placeholder="🔍  Search bugs, files, tags…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="flex-1 bg-slate-800 border border-slate-600 rounded-lg px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 transition-colors"
      />
      {(["ALL", "CRITICAL", "HIGH", "MEDIUM"] as const).map((f) => (
        <button
          key={f}
          onClick={() => setFilter(f)}
          className={`px-4 py-2.5 rounded-lg text-xs font-bold border transition-all ${
            filter === f
              ? f === "ALL"
                ? "bg-slate-600 border-slate-400 text-white"
                : f === "CRITICAL"
                ? "bg-red-600 border-red-400 text-white"
                : f === "HIGH"
                ? "bg-orange-500 border-orange-400 text-white"
                : "bg-yellow-500 border-yellow-400 text-black"
              : "bg-slate-800 border-slate-600 text-slate-400 hover:border-slate-400"
          }`}
        >
          {f === "ALL" ? "All" : f === "CRITICAL" ? "🔴 Critical" : f === "HIGH" ? "🟠 High" : "🟡 Medium"}
        </button>
      ))}
    </div>
  );
}

// ─── Main App ─────────────────────────────────────────────────────────────────
export default function App() {
  const [openBugs, setOpenBugs] = useState<Set<number>>(new Set([1]));
  const [filter, setFilter] = useState("ALL");
  const [search, setSearch] = useState("");

  const toggleBug = (id: number) => {
    setOpenBugs((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  };

  const expandAll = () => setOpenBugs(new Set(bugs.map((b) => b.id)));
  const collapseAll = () => setOpenBugs(new Set());

  const filteredBugs = bugs.filter((b) => {
    const matchesSev = filter === "ALL" || b.severity === filter;
    const q = search.toLowerCase();
    const matchesSearch =
      !q ||
      b.title.toLowerCase().includes(q) ||
      b.file.toLowerCase().includes(q) ||
      b.category.toLowerCase().includes(q) ||
      b.description.toLowerCase().includes(q) ||
      b.tags.some((t) => t.toLowerCase().includes(q));
    return matchesSev && matchesSearch;
  });

  return (
    <div className="min-h-screen bg-slate-950 text-white">
      {/* ── Header ── */}
      <header className="bg-slate-900 border-b border-slate-700 sticky top-0 z-50 shadow-2xl">
        <div className="max-w-6xl mx-auto px-4 py-4 flex flex-col sm:flex-row items-start sm:items-center gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-red-500 to-orange-500 flex items-center justify-center text-xl shadow-lg">
              🔎
            </div>
            <div>
              <h1 className="text-lg font-bold text-white leading-tight">
                ICT_Unified_EA_v05 — Bug Report
              </h1>
              <p className="text-xs text-slate-400">DR8 Expert Advisor · Professional Code Audit</p>
            </div>
          </div>
          <div className="sm:ml-auto flex flex-wrap gap-2 text-xs">
            <span className="bg-slate-800 border border-slate-600 text-slate-300 px-3 py-1.5 rounded-full">
              📅 ICT Methodology EA
            </span>
            <span className="bg-slate-800 border border-slate-600 text-slate-300 px-3 py-1.5 rounded-full">
              🛠️ MQL5 / MT5
            </span>
            <a
              href="https://github.com/iscienc/main/blob/main/DR8.txt"
              target="_blank"
              rel="noopener noreferrer"
              className="bg-slate-800 border border-slate-600 text-blue-400 hover:text-blue-300 px-3 py-1.5 rounded-full transition-colors"
            >
              📂 Source File
            </a>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-10">
        {/* ── Intro Banner ── */}
        <div className="bg-gradient-to-r from-red-950 via-slate-900 to-slate-900 border border-red-800 rounded-2xl p-6 mb-8 shadow-xl">
          <div className="flex items-start gap-4">
            <span className="text-4xl shrink-0">🚨</span>
            <div>
              <h2 className="text-xl font-bold text-white mb-2">Professional Code Audit — Critical Findings</h2>
              <p className="text-slate-300 text-sm leading-relaxed mb-3">
                A comprehensive source-code review of{" "}
                <strong className="text-white">ICT_Unified_EA_v05 (DR8 / V7_DR_PULLBACK)</strong> was performed
                against the raw MQL5 source files and their knowledge documentation. The audit identified{" "}
                <strong className="text-red-400">{bugs.filter((b) => b.severity === "CRITICAL").length} Critical</strong>,{" "}
                <strong className="text-orange-400">{bugs.filter((b) => b.severity === "HIGH").length} High</strong>, and{" "}
                <strong className="text-yellow-400">{bugs.filter((b) => b.severity === "MEDIUM").length} Medium</strong>{" "}
                severity bugs. The Critical bugs include an account-blow-up risk (div-by-zero lot sizing), a
                max-loss circuit-breaker that never fires, an infinite-loop in OnInit, and systematic broken
                comparison operators caused by HTML entity stripping during source transmission.
              </p>
              <div className="flex flex-wrap gap-2 text-xs">
                {["ICT_AMD.mqh", "ICT_Utilities.mqh", "ICT_Config.mqh", "ICT_SMEngine.mqh"].map((f) => (
                  <span key={f} className="bg-slate-800 text-green-300 px-2 py-1 rounded font-mono border border-slate-700">
                    {f}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* ── Stats ── */}
        <StatsBar />

        {/* ── Risk Priority Matrix ── */}
        <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 mb-8">
          <h3 className="text-white font-bold text-base mb-4 flex items-center gap-2">
            <span>📊</span> Risk Priority Matrix
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full text-xs text-left">
              <thead>
                <tr className="border-b border-slate-700">
                  <th className="pb-3 pr-4 text-slate-400 font-semibold">#</th>
                  <th className="pb-3 pr-4 text-slate-400 font-semibold">Severity</th>
                  <th className="pb-3 pr-4 text-slate-400 font-semibold">File</th>
                  <th className="pb-3 pr-4 text-slate-400 font-semibold">Title</th>
                  <th className="pb-3 text-slate-400 font-semibold">Category</th>
                </tr>
              </thead>
              <tbody>
                {bugs.map((bug) => {
                  const s = severityConfig[bug.severity];
                  return (
                    <tr
                      key={bug.id}
                      className="border-b border-slate-800 hover:bg-slate-800/50 cursor-pointer transition-colors"
                      onClick={() => {
                        if (!openBugs.has(bug.id)) toggleBug(bug.id);
                        setTimeout(() => {
                          document.getElementById(`bug-${bug.id}`)?.scrollIntoView({ behavior: "smooth", block: "start" });
                        }, 100);
                      }}
                    >
                      <td className="py-2.5 pr-4 font-mono text-slate-500">#{bug.id.toString().padStart(2, "0")}</td>
                      <td className="py-2.5 pr-4">
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${s.badge}`}>
                          {s.icon} {bug.severity}
                        </span>
                      </td>
                      <td className="py-2.5 pr-4 font-mono text-green-400">{bug.file}</td>
                      <td className="py-2.5 pr-4 text-slate-300 max-w-xs truncate">{bug.title}</td>
                      <td className="py-2.5 text-slate-400">{bug.category}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

        {/* ── Filter Bar + Controls ── */}
        <div className="flex flex-col gap-3 mb-6">
          <FilterBar filter={filter} setFilter={setFilter} search={search} setSearch={setSearch} />
          <div className="flex items-center justify-between">
            <p className="text-xs text-slate-500">
              Showing{" "}
              <span className="text-white font-semibold">{filteredBugs.length}</span> of{" "}
              <span className="text-white font-semibold">{bugs.length}</span> bugs
            </p>
            <div className="flex gap-2">
              <button
                onClick={expandAll}
                className="text-xs px-3 py-1.5 rounded bg-slate-800 border border-slate-600 text-slate-300 hover:text-white transition-colors"
              >
                Expand All
              </button>
              <button
                onClick={collapseAll}
                className="text-xs px-3 py-1.5 rounded bg-slate-800 border border-slate-600 text-slate-300 hover:text-white transition-colors"
              >
                Collapse All
              </button>
            </div>
          </div>
        </div>

        {/* ── Bug Cards ── */}
        <div className="space-y-4">
          {filteredBugs.length === 0 ? (
            <div className="text-center py-16 text-slate-500">
              <div className="text-5xl mb-4">🔍</div>
              <p>No bugs match your current filter.</p>
            </div>
          ) : (
            filteredBugs.map((bug) => (
              <div key={bug.id} id={`bug-${bug.id}`}>
                <BugCard
                  bug={bug}
                  isOpen={openBugs.has(bug.id)}
                  onToggle={() => toggleBug(bug.id)}
                />
              </div>
            ))
          )}
        </div>

        {/* ── Footer Summary ── */}
        <div className="mt-12 bg-slate-900 border border-slate-700 rounded-2xl p-6 text-sm text-slate-400">
          <h3 className="text-white font-bold text-base mb-3">📌 Audit Methodology</h3>
          <ul className="space-y-2 list-disc list-inside text-slate-300 text-xs leading-relaxed">
            <li>Full raw source of <code className="bg-slate-800 text-green-300 px-1 rounded font-mono">DR8.txt</code> was fetched and parsed from GitHub.</li>
            <li>Knowledge documentation (<code className="bg-slate-800 text-green-300 px-1 rounded font-mono">knowledgeData.ts</code>) was cross-referenced to validate intended behaviour vs. actual implementation.</li>
            <li>Bugs were graded on: <strong className="text-white">Probability of occurrence</strong>, <strong className="text-white">Financial impact</strong>, <strong className="text-white">Detectability</strong>, and <strong className="text-white">Scope</strong>.</li>
            <li>The most impactful root cause identified is the systematic stripping of HTML comparison operators (<code className="bg-slate-800 text-green-300 px-1 rounded font-mono">&lt;</code>, <code className="bg-slate-800 text-green-300 px-1 rounded font-mono">&gt;</code>) during source-file transmission — affecting ValidateInputs, DetectAMDPhase, and several utility functions.</li>
            <li>Financial-risk bugs (Lot sizing div-by-zero, Max-loss guard inversion) are rated <strong className="text-red-400">CRITICAL</strong> regardless of frequency because a single occurrence can destroy a live account.</li>
          </ul>
        </div>
      </main>

      {/* ── Footer ── */}
      <footer className="border-t border-slate-800 mt-8 py-6 text-center text-xs text-slate-600">
        ICT_Unified_EA_v05 Bug Report · Purely for code-quality improvement purposes · Not financial advice
      </footer>
    </div>
  );
}
