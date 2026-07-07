//+------------------------------------------------------------------+
//|                      ICT_PDStacking.mqh                           |
//|              PD Array Stacking & Confluence Detection              |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_PDSTACKING_MQH
#define ICT_PDSTACKING_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize PD Stacking                                            |
//+------------------------------------------------------------------+
bool InitializePDStacking()
{
   ArrayResize(g_pdStacks, g_maxStacks);
   g_stackCount = 0;
   
   Print("PD Stacking System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: STACK DETECTION                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate PD Stacking (Main Function)                             |
//+------------------------------------------------------------------+
void CalculatePDStacking()
{
   // Clear old stacks
   for(int i = 0; i < g_stackCount; i++)
   {
      DeleteObject(g_pdStacks[i].objName);
      g_pdStacks[i].Reset();
   }
   g_stackCount = 0;
   
   // Only calculate if entry zone is valid
   if(!g_entryZone.isValid)
      return;
   
   bool isBullish = (g_entryZone.direction == DIR_BULLISH);
   double atr = GetATR();
   if(atr <= 0) return;
   
   // Collect all PD arrays in entry zone
   SPDZoneCandidate candidates[];
   int candCount = 0;
   ArrayResize(candidates, 100);
   
   // 1. Add Order Blocks
   for(int i = 0; i < g_obCount && candCount < 100; i++)
   {
      if(g_orderBlocks[i].status == OB_FAILED)
         continue;
      
      bool isBullishOB = (g_orderBlocks[i].type == OB_BULLISH);
      if(isBullish != isBullishOB)
         continue;
      
      if(ZonesOverlap(g_orderBlocks[i].top, g_orderBlocks[i].bottom,
                       g_entryZone.upperBound, g_entryZone.lowerBound))
      {
         candidates[candCount].type = PD_ORDER_BLOCK;
         candidates[candCount].index = i;
         candidates[candCount].top = g_orderBlocks[i].top;
         candidates[candCount].bottom = g_orderBlocks[i].bottom;
         candidates[candCount].time = g_orderBlocks[i].time;
         candidates[candCount].priority = g_orderBlocks[i].isInstitutional ? 3 : 2;
         candidates[candCount].isFresh = (g_orderBlocks[i].status == OB_FRESH);
         candCount++;
      }
   }
   
   // 2. Add Breaker Blocks
   for(int i = 0; i < g_breakerCount && candCount < 100; i++)
   {
      if(g_breakerBlocks[i].isTested)
         continue;
      
      bool isBullishBreaker = (g_breakerBlocks[i].type == BREAKER_BULLISH);
      if(isBullish != isBullishBreaker)
         continue;
      
      if(ZonesOverlap(g_breakerBlocks[i].top, g_breakerBlocks[i].bottom,
                       g_entryZone.upperBound, g_entryZone.lowerBound))
      {
         candidates[candCount].type = PD_BREAKER_BLOCK;
         candidates[candCount].index = i;
         candidates[candCount].top = g_breakerBlocks[i].top;
         candidates[candCount].bottom = g_breakerBlocks[i].bottom;
         candidates[candCount].time = g_breakerBlocks[i].time;
         candidates[candCount].priority = 2;
         candidates[candCount].isFresh = true;
         candCount++;
      }
   }
   
   // 3. Add Mitigation Blocks
   for(int i = 0; i < g_mbCount && candCount < 100; i++)
   {
      if(g_mitigationBlocks[i].isTested)
         continue;
      
      bool isBullishMB = (g_mitigationBlocks[i].type == MB_BULLISH);
      if(isBullish != isBullishMB)
         continue;
      
      if(ZonesOverlap(g_mitigationBlocks[i].top, g_mitigationBlocks[i].bottom,
                       g_entryZone.upperBound, g_entryZone.lowerBound))
      {
         candidates[candCount].type = PD_MITIGATION_BLOCK;
         candidates[candCount].index = i;
         candidates[candCount].top = g_mitigationBlocks[i].top;
         candidates[candCount].bottom = g_mitigationBlocks[i].bottom;
         candidates[candCount].time = g_mitigationBlocks[i].time;
         candidates[candCount].priority = 2;
         candidates[candCount].isFresh = true;
         candCount++;
      }
   }
   
   // 4. Add FVGs
   for(int i = 0; i < g_fvgCount && candCount < 100; i++)
   {
      if(g_fvgList[i].status == FVG_FULLY_FILLED)
         continue;
      
      bool isBullishFVG = (g_fvgList[i].type == FVG_BULLISH);
      if(isBullish != isBullishFVG)
         continue;
      
      if(ZonesOverlap(g_fvgList[i].top, g_fvgList[i].bottom,
                       g_entryZone.upperBound, g_entryZone.lowerBound))
      {
         candidates[candCount].type = PD_FVG;
         candidates[candCount].index = i;
         candidates[candCount].top = g_fvgList[i].top;
         candidates[candCount].bottom = g_fvgList[i].bottom;
         candidates[candCount].time = g_fvgList[i].time;
         candidates[candCount].priority = 1;
         candidates[candCount].isFresh = (g_fvgList[i].status == FVG_OPEN);
         candCount++;
      }
   }
   
   // 5. Add OTE Zone
   if(g_oteZone.isValid && candCount < 100)
   {
      bool isBullishOTE = g_oteZone.isBullish;
      if(isBullish == isBullishOTE)
      {
         double oteTop = g_oteZone.ZoneTop();
         double oteBottom = g_oteZone.ZoneBottom();
         
         if(ZonesOverlap(oteTop, oteBottom, g_entryZone.upperBound, g_entryZone.lowerBound))
         {
            candidates[candCount].type = PD_OTE_ZONE;
            candidates[candCount].index = -1;
            candidates[candCount].top = oteTop;
            candidates[candCount].bottom = oteBottom;
            candidates[candCount].time = g_oteZone.time;
            candidates[candCount].priority = 1;
            candidates[candCount].isFresh = true;
            candCount++;
         }
      }
   }
   
   if(candCount < 2)
      return; // No stacking possible
   
   // Find overlapping groups (stacks)
   FindStackGroups(candidates, candCount, isBullish);
}

//+------------------------------------------------------------------+
//| Find Stack Groups (Cluster Overlapping Zones)                     |
//+------------------------------------------------------------------+
void FindStackGroups(SPDZoneCandidate &candidates[], int candCount, bool isBullish)
{
   double atr = GetATR();
   double minOverlap = atr * 0.05; // Minimum 5% ATR overlap
   
   // Mark all as unprocessed
   bool processed[];
   ArrayResize(processed, candCount);
   for(int i = 0; i < candCount; i++)
      processed[i] = false;
   
   // Find clusters
   for(int i = 0; i < candCount && g_stackCount < g_maxStacks; i++)
   {
      if(processed[i])
         continue;
      
      // Start new cluster
      SPDStack stack;
      stack.Reset();
      stack.direction = isBullish ? DIR_BULLISH : DIR_BEARISH;
      stack.time = candidates[i].time;
      
      // Initialize bounds
      stack.zoneTop = candidates[i].top;
      stack.zoneBottom = candidates[i].bottom;
      
      // Add first candidate
      AddCandidateToStack(stack, candidates[i]);
      processed[i] = true;
      
      // Find overlapping candidates
      bool foundNew = true;
      while(foundNew)
      {
         foundNew = false;
         
         for(int j = 0; j < candCount; j++)
         {
            if(processed[j])
               continue;
            
            // Check if overlaps with current cluster
            double overlapTop, overlapBottom;
            if(CalculateZoneOverlap(stack.zoneTop, stack.zoneBottom,
                                    candidates[j].top, candidates[j].bottom,
                                    overlapTop, overlapBottom))
            {
               double overlapSize = overlapTop - overlapBottom;
               if(overlapSize >= minOverlap)
               {
                  AddCandidateToStack(stack, candidates[j]);
                  processed[j] = true;
                  
                  // Update cluster bounds to intersection
                  stack.zoneTop = overlapTop;
                  stack.zoneBottom = overlapBottom;
                  
                  foundNew = true;
               }
            }
         }
      }
      
      // Only save if stack has 2+ PD arrays
      stack.CalculateStackCount();
      
      if(stack.stackCount >= 2)
      {
         stack.stackStrength = CalculatestackStrength(stack);
         stack.objName = GeneratePDObjectName("Stack");
         
         g_pdStacks[g_stackCount] = stack;
         g_stackCount++;
         
         // Draw stack
         if(InpShowOrderBlocks)
            DrawStack(g_stackCount - 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Add Candidate to Stack                                            |
//+------------------------------------------------------------------+
void AddCandidateToStack(SPDStack &stack, SPDZoneCandidate &candidate)
{
   switch(candidate.type)
   {
      case PD_ORDER_BLOCK:
         stack.hasOB = true;
         stack.obIndex = candidate.index;
         break;
      case PD_BREAKER_BLOCK:
         stack.hasBreaker = true;
         stack.breakerIndex = candidate.index;
         break;
      case PD_MITIGATION_BLOCK:
         stack.hasMB = true;
         stack.mbIndex = candidate.index;
         break;
      case PD_FVG:
         stack.hasFVG = true;
         stack.fvgIndex = candidate.index;
         break;
      case PD_OTE_ZONE:
         stack.hasOTE = true;
         break;
   }
}

//+------------------------------------------------------------------+
//| Calculate Stack Score                                             |
//+------------------------------------------------------------------+
int CalculatestackStrength(SPDStack &stack)
{
   int score = 0;
   
   // Base score per array
   if(stack.hasOB) score += 15;
   if(stack.hasBreaker) score += 12;
   if(stack.hasMB) score += 12;
   if(stack.hasFVG) score += 10;
   if(stack.hasOTE) score += 8;
   
   // Stacking bonus
   score += (stack.stackCount - 1) * 10;
   
   // OB + FVG combo (highest probability)
   if(stack.hasOB && stack.hasFVG)
      score += 10;
   
   // OB + Breaker combo
   if(stack.hasOB && stack.hasBreaker)
      score += 8;
   
   // All three major arrays
   if(stack.hasOB && stack.hasFVG && stack.hasOTE)
      score += 15;
   
   return MathMin(100, score);
}

//+------------------------------------------------------------------+
//|              SECTION 3: DRAWING                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Stack                                                        |
//+------------------------------------------------------------------+
void DrawStack(int index)
{
   if(index >= g_stackCount) return;
   // Stacks are PD-mode only (SM uses SM_ELEM_STACKED_PDA on data, not visual)
   if(!SM_IsElementInStages(SM_ELEM_STACKED_PDA)) return;

   bool isBull = (g_pdStacks[index].direction == DIR_BULLISH);
   string label = BuildElementLabel(LAYER_CTF, isBull,
                     "Stack x" + IntegerToString(g_pdStacks[index].stackCount));

   datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   DrawPDStack(g_pdStacks[index].objName,
               g_pdStacks[index].time,
               g_pdStacks[index].zoneTop,
               g_pdStacks[index].zoneBottom,
               endTime,
               g_pdStacks[index].stackCount,
               g_pdStacks[index].direction,
               label);
}

//+------------------------------------------------------------------+
//| Extend Stack Rectangles                                           |
//+------------------------------------------------------------------+
void ExtendStackRectangles()
{
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_stackCount; i++)
   {
      if(ObjectFind(0, g_pdStacks[i].objName) >= 0)
      {
         ObjectSetInteger(0, g_pdStacks[i].objName, OBJPROP_TIME, 1, currentTime);
      }
   }
}

//+------------------------------------------------------------------+
//|              SECTION 4: CHECK FUNCTIONS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Price at Stacked Level                                   |
//+------------------------------------------------------------------+
bool IsPriceAtStackedLevel(bool isBullish, int &outIndex)
{
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   for(int i = 0; i < g_stackCount; i++)
   {
      bool stackIsBullish = (g_pdStacks[i].direction == DIR_BULLISH);
      
      if(isBullish == stackIsBullish)
      {
         if(price >= g_pdStacks[i].zoneBottom && price <= g_pdStacks[i].zoneTop)
         {
            outIndex = i;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Best Stack (Highest Score)                                    |
//+------------------------------------------------------------------+
int GetBestStack(bool isBullish)
{
   int bestIdx = -1;
   int bestScore = 0;
   
   for(int i = 0; i < g_stackCount; i++)
   {
      bool stackIsBullish = (g_pdStacks[i].direction == DIR_BULLISH);
      
      if(isBullish == stackIsBullish)
      {
         if(g_pdStacks[i].stackStrength > bestScore)
         {
            bestScore = g_pdStacks[i].stackStrength;
            bestIdx = i;
         }
      }
   }
   
   return bestIdx;
}

//+------------------------------------------------------------------+
//| Count Stacks in Direction                                         |
//+------------------------------------------------------------------+
int CountStacks(bool isBullish)
{
   int count = 0;
   for(int i = 0; i < g_stackCount; i++)
   {
      bool stackIsBullish = (g_pdStacks[i].direction == DIR_BULLISH);
      if(isBullish == stackIsBullish)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get Stack Description                                             |
//+------------------------------------------------------------------+
string GetStackDescription(int index)
{
   if(index >= g_stackCount)
      return "";
   
   string desc = "";
   
   if(g_pdStacks[index].hasOB) desc += "OB + ";
   if(g_pdStacks[index].hasBreaker) desc += "BRK + ";
   if(g_pdStacks[index].hasMB) desc += "MB + ";
   if(g_pdStacks[index].hasFVG) desc += "FVG + ";
   if(g_pdStacks[index].hasOTE) desc += "OTE + ";
   
   // Remove trailing " + "
   if(StringLen(desc) > 3)
      desc = StringSubstr(desc, 0, StringLen(desc) - 3);
   
   return desc;
}



#endif // ICT_PDSTACKING_MQH