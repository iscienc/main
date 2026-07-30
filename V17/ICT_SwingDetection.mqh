//+------------------------------------------------------------------+
//|                     ICT_SwingDetection.mqh                        |
//|                Professional Swing Point Detection                 |
//|            "ICT Unified Professional EA v18"                      |
//+------------------------------------------------------------------+
#ifndef ICT_SWINGDETECTION_MQH
#define ICT_SWINGDETECTION_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Swing Detection System                                 |
//+------------------------------------------------------------------+
bool InitializeSwingDetection()
{
   ArrayResize(g_swings, g_maxSwings);
   g_swingsCount = 0;
   
   // Reset quick access variables
   g_lastExternalHigh = 0;
   g_lastExternalLow = 0;
   g_lastExternalHighTime = 0;
   g_lastExternalLowTime = 0;
   g_lastInternalHigh = 0;
   g_lastInternalLow = 0;
   
   Print("Swing Detection System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: MAIN DETECTION FUNCTIONS                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Main Professional Swing Detection - Orchestrator                  |
//+------------------------------------------------------------------+
void DetectProfessionalSwings()
{
   if(!InpShowSwingPoints)
      return;
   
   // Step 1: Cleanup old swings
   CleanupOldSwings();
   
   // Step 2: Delete existing chart objects (will redraw)
   DeleteSwingObjects();
   
   // Step 3: Detect External (Major) Swings
   if(InpShowExternalSwings)
      DetectExternalSwings();
   
   // Step 4: Detect Internal (Minor) Swings
   if(InpShowInternalSwings)
      DetectInternalSwings();
   
   // Step 5: Update swing statuses (protected/unprotected/swept)
   UpdateSwingStatuses();
   
   // Step 6: Determine structure context (HH, HL, LH, LL)
   DetermineStructureContext();
   
   // Step 7: Update quick access variables
   UpdateQuickAccessSwings();
   
   // Step 8: Recalculate visibility
   RecalculateSwingVisibility();
   
   // Step 9: Draw visible swings
   DrawAllSwings();
      // Step 10: Detect Liquidity Pools (Equal Highs/Lows)
   DetectLiquidityPools();
}

//+------------------------------------------------------------------+
//| Detect External (Major) Swings with Alternating Validation        |
//+------------------------------------------------------------------+
void DetectExternalSwings()
{
   int leftBars = InpExtLeftBars;
   int rightBars = InpExtRightBars;
   int barsAvailable = iBars(_Symbol, PERIOD_CURRENT);
   int maxBars = MathMin(InpMaxSwingLookback, barsAvailable - leftBars - 1);
   
   // Temporary storage for candidates
   SPivotPoint candidates[];
   ArrayResize(candidates, 200);
   int candCount = 0;
   
   // Find all pivot candidates
   for(int i = rightBars; i < maxBars && candCount < 200; i++)
   {
      // Check for pivot high
      if(IsPivotHigh(PERIOD_CURRENT, i, leftBars, rightBars))
      {
         candidates[candCount].price = iHigh(_Symbol, PERIOD_CURRENT, i);
         candidates[candCount].time = iTime(_Symbol, PERIOD_CURRENT, i);
         candidates[candCount].barIndex = i;
         candidates[candCount].valid = true;
         candCount++;
      }
      
      // Check for pivot low
      if(IsPivotLow(PERIOD_CURRENT, i, leftBars, rightBars))
      {
         candidates[candCount].price = iLow(_Symbol, PERIOD_CURRENT, i);
         candidates[candCount].time = iTime(_Symbol, PERIOD_CURRENT, i);
         candidates[candCount].barIndex = i;
         candidates[candCount].valid = false; // Use valid field to mark high/low
         candCount++;
      }
   }
   
   if(candCount == 0)
      return;
   
   // Sort by time (oldest first)
   SortCandidatesByTime(candidates, candCount);
   
   // Enforce alternating H-L-H-L sequence
   SPivotPoint validated[];
   ArrayResize(validated, candCount);
   int valCount = 0;
   
   for(int i = 0; i < candCount; i++)
   {
      bool isHigh = candidates[i].valid;
      
      if(valCount == 0)
      {
         validated[valCount] = candidates[i];
         valCount++;
         continue;
      }
      
      bool lastIsHigh = validated[valCount - 1].valid;
      
      if(isHigh != lastIsHigh)
      {
         // Alternating - good, add it
         validated[valCount] = candidates[i];
         valCount++;
      }
      else
      {
         // Same type consecutive - keep the more extreme one
         if(isHigh)
         {
            // Two highs - keep higher
            if(candidates[i].price > validated[valCount - 1].price)
               validated[valCount - 1] = candidates[i];
         }
         else
         {
            // Two lows - keep lower
            if(candidates[i].price < validated[valCount - 1].price)
               validated[valCount - 1] = candidates[i];
         }
      }
   }
   
   // Add validated swings
   for(int i = 0; i < valCount; i++)
   {
      bool isHigh = validated[i].valid;
      ENUM_SWING_TYPE swType = isHigh ? SWING_EXTERNAL_HIGH : SWING_EXTERNAL_LOW;
      
      AddSwingPoint(validated[i].price, validated[i].barIndex, 
                    validated[i].time, isHigh, swType);
   }
}

//+------------------------------------------------------------------+
//| Detect Internal (Minor) Swings                                    |
//+------------------------------------------------------------------+
void DetectInternalSwings()
{
   int leftBars = InpIntLeftBars;
   int rightBars = InpIntRightBars;
   int barsAvailable = iBars(_Symbol, PERIOD_CURRENT);
   int maxBars = MathMin(InpMaxSwingLookback, barsAvailable - leftBars - 1);
   
   // Need at least 2 external swings
   int extCount = CountExternalSwings();
   if(extCount < 2)
      return;
   
   for(int i = rightBars; i < maxBars; i++)
   {
      datetime pivotTime = iTime(_Symbol, PERIOD_CURRENT, i);
      
      // Check for internal swing high
      if(IsPivotHigh(PERIOD_CURRENT, i, leftBars, rightBars))
      {
         double price = iHigh(_Symbol, PERIOD_CURRENT, i);
         
         // Skip if already marked
         if(IsSwingAlreadyMarked(price, true))
            continue;
         
         // Validate as internal
         if(IsValidInternalSwing(pivotTime, true, price))
         {
            AddSwingPoint(price, i, pivotTime, true, SWING_INTERNAL_HIGH);
         }
      }
      
      // Check for internal swing low
      if(IsPivotLow(PERIOD_CURRENT, i, leftBars, rightBars))
      {
         double price = iLow(_Symbol, PERIOD_CURRENT, i);
         
         if(IsSwingAlreadyMarked(price, false))
            continue;
         
         if(IsValidInternalSwing(pivotTime, false, price))
         {
            AddSwingPoint(price, i, pivotTime, false, SWING_INTERNAL_LOW);
         }
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 3: SWING MANAGEMENT                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Add Swing Point to Array                                          |
//+------------------------------------------------------------------+
void AddSwingPoint(double price, int barIndex, datetime time, 
                   bool isHigh, ENUM_SWING_TYPE type)
{
   double tolerance = _Point * 10;
   
   // Check if already exists
   int existIdx = FindExistingSwing(price, isHigh, tolerance);
   if(existIdx >= 0)
   {
      // Handle type upgrade (internal → external)
      bool existingIsInternal = (g_swings[existIdx].type == SWING_INTERNAL_HIGH ||
                                  g_swings[existIdx].type == SWING_INTERNAL_LOW);
      bool newIsExternal = (type == SWING_EXTERNAL_HIGH || type == SWING_EXTERNAL_LOW);
      
      if(existingIsInternal && newIsExternal)
      {
         g_swings[existIdx].type = type;
         g_swings[existIdx].pivotScore = CalculatePivotScore(PERIOD_CURRENT, barIndex, isHigh);
         UpdateSwingSignificance(existIdx);
      }
      return;
   }
   
   // Check minimum bars between same-type swings
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].isHigh == isHigh && g_swings[i].type == type)
      {
         int barDiff = MathAbs(barIndex - g_swings[i].barIndex);
         if(barDiff < InpMinBarsBetweenSwings)
            return;
      }
   }
   
   // Check capacity
   if(g_swingsCount >= g_maxSwings)
      RemoveOldestSwing();
   
   // Add new swing
   int idx = g_swingsCount;
   
   g_swings[idx].Reset();
   g_swings[idx].price = price;
   g_swings[idx].time = time;
   g_swings[idx].barIndex = barIndex;
   g_swings[idx].isHigh = isHigh;
   g_swings[idx].type = type;
   g_swings[idx].status = SWING_PROTECTED;
   g_swings[idx].context = CONTEXT_NONE;
   g_swings[idx].isVisible = true;
   g_swings[idx].objName = GenerateObjectName(g_prefix, "Swing");
   g_swings[idx].labelName = g_swings[idx].objName + "_lbl";
   
   // Calculate pivot score and significance
   g_swings[idx].pivotScore = CalculatePivotScore(PERIOD_CURRENT, barIndex, isHigh);
   UpdateSwingSignificance(idx);
   
   g_swingsCount++;
}

//+------------------------------------------------------------------+
//| Find Existing Swing at Price                                      |
//+------------------------------------------------------------------+
int FindExistingSwing(double price, bool isHigh, double tolerance)
{
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].isHigh == isHigh)
      {
         if(MathAbs(g_swings[i].price - price) <= tolerance)
            return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Check if Swing Already Marked                                     |
//+------------------------------------------------------------------+
bool IsSwingAlreadyMarked(double price, bool isHigh)
{
   return (FindExistingSwing(price, isHigh, _Point * 10) >= 0);
}

//+------------------------------------------------------------------+
//| Remove Oldest Swing                                               |
//+------------------------------------------------------------------+
void RemoveOldestSwing()
{
   if(g_swingsCount == 0)
      return;
   
   int oldestIdx = 0;
   datetime oldestTime = g_swings[0].time;
   
   for(int i = 1; i < g_swingsCount; i++)
   {
      if(g_swings[i].time < oldestTime)
      {
         oldestTime = g_swings[i].time;
         oldestIdx = i;
      }
   }
   
   // Delete objects
   DeleteObject(g_swings[oldestIdx].objName);
   DeleteObject(g_swings[oldestIdx].labelName);
   
   // Shift array
   for(int i = oldestIdx; i < g_swingsCount - 1; i++)
      g_swings[i] = g_swings[i + 1];
   
   g_swingsCount--;
}

//+------------------------------------------------------------------+
//| Cleanup Old Swings (Time-Based)                                   |
//+------------------------------------------------------------------+
void CleanupOldSwings()
{
   int maxBarAge = InpMaxSwingLookback;
   int safeBar = MathMin(maxBarAge, iBars(_Symbol, PERIOD_CURRENT) - 1);
   datetime cutoffTime = iTime(_Symbol, PERIOD_CURRENT, safeBar);
   
   for(int i = g_swingsCount - 1; i >= 0; i--)
   {
      if(g_swings[i].time < cutoffTime)
      {
         DeleteObject(g_swings[i].objName);
         DeleteObject(g_swings[i].labelName);
         
         for(int j = i; j < g_swingsCount - 1; j++)
            g_swings[j] = g_swings[j + 1];
         
         g_swingsCount--;
      }
   }
}

//+------------------------------------------------------------------+
//| Delete All Swing Objects                                          |
//+------------------------------------------------------------------+
void DeleteSwingObjects()
{
   for(int i = 0; i < g_swingsCount; i++)
   {
      DeleteObject(g_swings[i].objName);
      DeleteObject(g_swings[i].labelName);
   }
}

//+------------------------------------------------------------------+
//|              SECTION 4: SWING VALIDATION                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Valid Internal Swing                                     |
//+------------------------------------------------------------------+
bool IsValidInternalSwing(datetime pivotTime, bool isHigh, double price)
{
   bool hasOlder = false;
   bool hasNewer = false;
   double nearestSameSidePrice = 0;
   bool foundSameSide = false;
   
   for(int i = 0; i < g_swingsCount; i++)
   {
      // Only check external swings
      if(g_swings[i].type != SWING_EXTERNAL_HIGH &&
         g_swings[i].type != SWING_EXTERNAL_LOW)
         continue;
      
      if(g_swings[i].time < pivotTime)
         hasOlder = true;
      if(g_swings[i].time > pivotTime)
         hasNewer = true;
      
      // Find nearest same-side external
      if(g_swings[i].isHigh == isHigh)
      {
         if(!foundSameSide)
         {
            nearestSameSidePrice = g_swings[i].price;
            foundSameSide = true;
         }
         else
         {
            if(isHigh && g_swings[i].price > nearestSameSidePrice)
               nearestSameSidePrice = g_swings[i].price;
            if(!isHigh && g_swings[i].price < nearestSameSidePrice)
               nearestSameSidePrice = g_swings[i].price;
         }
      }
   }
   
   // Must be between two external swings
   if(!hasOlder || !hasNewer)
      return false;
   
   // Must not exceed the nearest external on same side
   if(foundSameSide)
   {
      if(isHigh && price >= nearestSameSidePrice)
         return false;
      if(!isHigh && price <= nearestSameSidePrice)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update Swing Significance                                         |
//+------------------------------------------------------------------+
void UpdateSwingSignificance(int index)
{
   if(index >= g_swingsCount)
      return;
   
   bool isExternal = (g_swings[index].type == SWING_EXTERNAL_HIGH ||
                      g_swings[index].type == SWING_EXTERNAL_LOW);
   
   if(isExternal)
   {
      if(g_swings[index].pivotScore >= 4)
         g_swings[index].significance = SIG_MAJOR;
      else if(g_swings[index].pivotScore >= 2)
         g_swings[index].significance = SIG_MODERATE;
      else
         g_swings[index].significance = SIG_MINOR;
   }
   else
   {
      g_swings[index].significance = SIG_MINOR;
   }
}

//+------------------------------------------------------------------+
//|              SECTION 5: STATUS UPDATES                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Swing Statuses (Protected/Unprotected/Swept)               |
//+------------------------------------------------------------------+
void UpdateSwingStatuses()
{
   double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].status == SWING_UNPROTECTED)
         continue;
      
      if(g_swings[i].isHigh)
      {
         // Swing High - check if broken or swept
         if(currentClose > g_swings[i].price)
         {
            g_swings[i].status = SWING_UNPROTECTED;
         }
         else if(currentHigh > g_swings[i].price && currentClose < g_swings[i].price)
         {
            g_swings[i].status = SWING_SWEPT;
         }
      }
      else
      {
         // Swing Low - check if broken or swept
         if(currentClose < g_swings[i].price)
         {
            g_swings[i].status = SWING_UNPROTECTED;
         }
         else if(currentLow < g_swings[i].price && currentClose > g_swings[i].price)
         {
            g_swings[i].status = SWING_SWEPT;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Determine Structure Context (HH, HL, LH, LL)                      |
//+------------------------------------------------------------------+
void DetermineStructureContext()
{
   // Reset all contexts
   for(int i = 0; i < g_swingsCount; i++)
      g_swings[i].context = CONTEXT_NONE;
   
   // Collect external swing indices sorted by time
   int sortedIdx[];
   int sortedCount = 0;
   
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].type == SWING_EXTERNAL_HIGH ||
         g_swings[i].type == SWING_EXTERNAL_LOW)
      {
         ArrayResize(sortedIdx, sortedCount + 1);
         sortedIdx[sortedCount] = i;
         sortedCount++;
      }
   }
   
   if(sortedCount < 2)
      return;
   
   // Sort by time (oldest first)
   for(int i = 0; i < sortedCount - 1; i++)
   {
      for(int j = 0; j < sortedCount - i - 1; j++)
      {
         if(g_swings[sortedIdx[j]].time > g_swings[sortedIdx[j + 1]].time)
         {
            int temp = sortedIdx[j];
            sortedIdx[j] = sortedIdx[j + 1];
            sortedIdx[j + 1] = temp;
         }
      }
   }
   
   // Walk through and assign context
   double prevExtHigh = 0;
   double prevExtLow = 0;
   
   for(int i = 0; i < sortedCount; i++)
   {
      int idx = sortedIdx[i];
      
      if(g_swings[idx].isHigh)
      {
         if(prevExtHigh > 0)
         {
            g_swings[idx].context = (g_swings[idx].price > prevExtHigh) ? 
                                     CONTEXT_HH : CONTEXT_LH;
         }
         prevExtHigh = g_swings[idx].price;
      }
      else
      {
         if(prevExtLow > 0)
         {
            g_swings[idx].context = (g_swings[idx].price > prevExtLow) ? 
                                     CONTEXT_HL : CONTEXT_LL;
         }
         prevExtLow = g_swings[idx].price;
      }
   }
}

//+------------------------------------------------------------------+
//| Update Quick Access Swing Variables                               |
//+------------------------------------------------------------------+
void UpdateQuickAccessSwings()
{
   g_lastExternalHigh = 0;
   g_lastExternalLow = 0;
   g_lastExternalHighTime = 0;
   g_lastExternalLowTime = 0;
   g_lastInternalHigh = 0;
   g_lastInternalLow = 0;
   
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].type == SWING_EXTERNAL_HIGH)
      {
         if(g_lastExternalHighTime == 0 || g_swings[i].time > g_lastExternalHighTime)
         {
            g_lastExternalHigh = g_swings[i].price;
            g_lastExternalHighTime = g_swings[i].time;
         }
      }
      else if(g_swings[i].type == SWING_EXTERNAL_LOW)
      {
         if(g_lastExternalLowTime == 0 || g_swings[i].time > g_lastExternalLowTime)
         {
            g_lastExternalLow = g_swings[i].price;
            g_lastExternalLowTime = g_swings[i].time;
         }
      }
      else if(g_swings[i].type == SWING_INTERNAL_HIGH)
      {
         if(g_lastInternalHigh == 0 || g_swings[i].price > g_lastInternalHigh)
            g_lastInternalHigh = g_swings[i].price;
      }
      else if(g_swings[i].type == SWING_INTERNAL_LOW)
      {
         if(g_lastInternalLow == 0 || g_swings[i].price < g_lastInternalLow)
            g_lastInternalLow = g_swings[i].price;
      }
   }
}

//+------------------------------------------------------------------+
//| Recalculate Swing Visibility                                      |
//+------------------------------------------------------------------+
void RecalculateSwingVisibility()
{
   // First hide all
   for(int i = 0; i < g_swingsCount; i++)
      g_swings[i].isVisible = false;
   
   // Show most recent N swings
   int visibleCount = 0;
   int maxVisible = InpMaxSwingsDisplay;
   
   while(visibleCount < maxVisible)
   {
      int bestIdx = -1;
      datetime bestTime = 0;
      
      for(int i = 0; i < g_swingsCount; i++)
      {
         if(!g_swings[i].isVisible && g_swings[i].time > bestTime)
         {
            bestTime = g_swings[i].time;
            bestIdx = i;
         }
      }
      
      if(bestIdx < 0)
         break;
      
      g_swings[bestIdx].isVisible = true;
      visibleCount++;
   }
}

//+------------------------------------------------------------------+
//|              SECTION 6: DRAWING FUNCTIONS                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw All Visible Swings                                           |
//+------------------------------------------------------------------+
void DrawAllSwings()
{
   double atr = GetATRSafe();
   if(atr <= 0) return;
   
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].isVisible)
      {
         DrawSwingPoint(g_swings[i].objName, g_swings[i].time, g_swings[i].price,
                        g_swings[i].isHigh, g_swings[i].type, g_swings[i].status,
                        g_swings[i].context, atr);
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 7: HELPER FUNCTIONS                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sort Candidates by Time (Oldest First)                            |
//+------------------------------------------------------------------+
void SortCandidatesByTime(SPivotPoint &arr[], int count)
{
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = 0; j < count - i - 1; j++)
      {
         if(arr[j].time > arr[j + 1].time)
         {
            SPivotPoint temp = arr[j];
            arr[j] = arr[j + 1];
            arr[j + 1] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count External Swings                                             |
//+------------------------------------------------------------------+
int CountExternalSwings()
{
   int count = 0;
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].type == SWING_EXTERNAL_HIGH ||
         g_swings[i].type == SWING_EXTERNAL_LOW)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get Last Protected Swing                                          |
//+------------------------------------------------------------------+
double GetLastProtectedSwing(bool getHigh)
{
   double result = 0;
   datetime mostRecentTime = 0;
   
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].status != SWING_PROTECTED)
         continue;
      
      if(g_swings[i].isHigh == getHigh)
      {
         if(g_swings[i].time > mostRecentTime)
         {
            mostRecentTime = g_swings[i].time;
            result = g_swings[i].price;
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Get Swing at Price                                                |
//+------------------------------------------------------------------+
int GetSwingAtPrice(double price, double tolerance)
{
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(MathAbs(g_swings[i].price - price) <= tolerance)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Count Protected Swings of Type                                    |
//+------------------------------------------------------------------+
int CountProtectedSwings(bool countHighs)
{
   int count = 0;
   for(int i = 0; i < g_swingsCount; i++)
   {
      if(g_swings[i].status == SWING_PROTECTED && g_swings[i].isHigh == countHighs)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get ChoCh Level (ICT Concept)                                     |
//+------------------------------------------------------------------+
double GetChochLevel(bool findBullish)
{
   // For Bullish ChoCh: Find swing high that created the last swing low
   // For Bearish ChoCh: Find swing low that created the last swing high
   
   if(findBullish)
   {
      // Find last external swing low
      int lastLowIdx = -1;
      datetime lastLowTime = 0;
      
      for(int i = 0; i < g_swingsCount; i++)
      {
         if(g_swings[i].type == SWING_EXTERNAL_LOW && 
            g_swings[i].status == SWING_PROTECTED)
         {
            if(g_swings[i].time > lastLowTime)
            {
               lastLowTime = g_swings[i].time;
               lastLowIdx = i;
            }
         }
      }
      
      if(lastLowIdx < 0)
         return 0;
      
      // Find external swing high before this low
      int creatingHighIdx = -1;
      datetime creatingHighTime = 0;
      
      for(int i = 0; i < g_swingsCount; i++)
      {
         if(g_swings[i].type == SWING_EXTERNAL_HIGH)
         {
            if(g_swings[i].time < g_swings[lastLowIdx].time &&
               g_swings[i].time > creatingHighTime)
            {
               creatingHighTime = g_swings[i].time;
               creatingHighIdx = i;
            }
         }
      }
      
      if(creatingHighIdx >= 0)
         return g_swings[creatingHighIdx].price;
   }
   else
   {
      // Find last external swing high
      int lastHighIdx = -1;
      datetime lastHighTime = 0;
      
      for(int i = 0; i < g_swingsCount; i++)
      {
         if(g_swings[i].type == SWING_EXTERNAL_HIGH && 
            g_swings[i].status == SWING_PROTECTED)
         {
            if(g_swings[i].time > lastHighTime)
            {
               lastHighTime = g_swings[i].time;
               lastHighIdx = i;
            }
         }
      }
      
      if(lastHighIdx < 0)
         return 0;
      
      // Find external swing low before this high
      int creatingLowIdx = -1;
      datetime creatingLowTime = 0;
      
      for(int i = 0; i < g_swingsCount; i++)
      {
         if(g_swings[i].type == SWING_EXTERNAL_LOW)
         {
            if(g_swings[i].time < g_swings[lastHighIdx].time &&
               g_swings[i].time > creatingLowTime)
            {
               creatingLowTime = g_swings[i].time;
               creatingLowIdx = i;
            }
         }
      }
      
      if(creatingLowIdx >= 0)
         return g_swings[creatingLowIdx].price;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Analyze Current Structure (Returns Direction)                     |
//+------------------------------------------------------------------+
ENUM_TRADE_DIRECTION AnalyzeSwingStructure()
{
   // Find most recent HH/HL or LH/LL patterns
   int hhCount = 0;
   int hlCount = 0;
   int lhCount = 0;
   int llCount = 0;
   
   // Only look at recent swings (last 10)
   int checked = 0;
   
   for(int i = g_swingsCount - 1; i >= 0 && checked < 10; i--)
   {
      switch(g_swings[i].context)
      {
         case CONTEXT_HH: hhCount++; break;
         case CONTEXT_HL: hlCount++; break;
         case CONTEXT_LH: lhCount++; break;
         case CONTEXT_LL: llCount++; break;
      }
      checked++;
   }
   
   // Bullish structure: HH + HL
   // Bearish structure: LH + LL
   
   int bullishScore = hhCount + hlCount;
   int bearishScore = lhCount + llCount;
   
   if(bullishScore > bearishScore + 1)
      return DIR_BULLISH;
   else if(bearishScore > bullishScore + 1)
      return DIR_BEARISH;
   
   return DIR_NONE;
}


//+------------------------------------------------------------------+
//| Detect Liquidity Pools (Equal Highs/Lows)                        |
//+------------------------------------------------------------------+
void DetectLiquidityPools()
{
   double atr = GetATR();
   if(atr <= 0) return;
   
   double equalTolerance = atr * 0.05;  // 5% ATR tolerance for "equal"
   
   g_lpCount = 0;  // Reset each scan
   
   // Compare each swing high with other swing highs for EQH
   for(int i = 0; i < g_swingsCount && g_lpCount < g_maxLPs; i++)
   {
      if(!g_swings[i].isHigh) continue;
      if(g_swings[i].type != SWING_EXTERNAL_HIGH) continue;
      
      int touches = 1;
      
      for(int j = i + 1; j < g_swingsCount; j++)
      {
         if(!g_swings[j].isHigh) continue;
         if(g_swings[j].type != SWING_EXTERNAL_HIGH) continue;
         
         if(MathAbs(g_swings[i].price - g_swings[j].price) <= equalTolerance)
         {
            touches++;
         }
      }
      
      if(touches >= 2)
      {
         // Check if already added
         bool exists = false;
         for(int k = 0; k < g_lpCount; k++)
         {
            if(g_liquidityPools[k].type == LQ_EQUAL_HIGHS &&
               MathAbs(g_liquidityPools[k].price - g_swings[i].price) <= equalTolerance)
            { exists = true; break; }
         }
         if(exists) continue;
         
         int idx = g_lpCount;
         g_liquidityPools[idx].Reset();
         g_liquidityPools[idx].type = LQ_EQUAL_HIGHS;
         g_liquidityPools[idx].price = g_swings[i].price;
         g_liquidityPools[idx].time = g_swings[i].time;
         g_liquidityPools[idx].barIndex = g_swings[i].barIndex;
         g_liquidityPools[idx].touchCount = touches;
         
         // Check if already swept
         double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
         g_liquidityPools[idx].isSwept = (currentHigh > g_swings[i].price + equalTolerance);
         
         g_liquidityPools[idx].objName = GenerateObjectName(g_prefix, "LP_EQH");
         g_liquidityPools[idx].labelName = g_liquidityPools[idx].objName + "_lbl";
         g_lpCount++;
      }
   }
   
   // Compare each swing low with other swing lows for EQL
   for(int i = 0; i < g_swingsCount && g_lpCount < g_maxLPs; i++)
   {
      if(g_swings[i].isHigh) continue;
      if(g_swings[i].type != SWING_EXTERNAL_LOW) continue;
      
      int touches = 1;
      
      for(int j = i + 1; j < g_swingsCount; j++)
      {
         if(g_swings[j].isHigh) continue;
         if(g_swings[j].type != SWING_EXTERNAL_LOW) continue;
         
         if(MathAbs(g_swings[i].price - g_swings[j].price) <= equalTolerance)
         {
            touches++;
         }
      }
      
      if(touches >= 2)
      {
         bool exists = false;
         for(int k = 0; k < g_lpCount; k++)
         {
            if(g_liquidityPools[k].type == LQ_EQUAL_LOWS &&
               MathAbs(g_liquidityPools[k].price - g_swings[i].price) <= equalTolerance)
            { exists = true; break; }
         }
         if(exists) continue;
         
         int idx = g_lpCount;
         g_liquidityPools[idx].Reset();
         g_liquidityPools[idx].type = LQ_EQUAL_LOWS;
         g_liquidityPools[idx].price = g_swings[i].price;
         g_liquidityPools[idx].time = g_swings[i].time;
         g_liquidityPools[idx].barIndex = g_swings[i].barIndex;
         g_liquidityPools[idx].touchCount = touches;
         
         double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
         g_liquidityPools[idx].isSwept = (currentLow < g_swings[i].price - equalTolerance);
         
         g_liquidityPools[idx].objName = GenerateObjectName(g_prefix, "LP_EQL");
         g_liquidityPools[idx].labelName = g_liquidityPools[idx].objName + "_lbl";
         g_lpCount++;
      }
   }
   
   // Draw liquidity pools
   for(int i = 0; i < g_lpCount; i++)
   {
      datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      DrawLiquidityPool(g_liquidityPools[i].objName,
                        g_liquidityPools[i].time,
                        g_liquidityPools[i].price,
                        endTime,
                        g_liquidityPools[i].type,
                        g_liquidityPools[i].touchCount,
                        g_liquidityPools[i].isSwept);
   }
}

#endif // ICT_SWINGDETECTION_MQH