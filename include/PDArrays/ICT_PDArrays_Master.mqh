//+------------------------------------------------------------------+
//|                    ICT_PDArrays_Master.mqh                        |
//|              Master Orchestrator for All PD Arrays                  |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_PDARRAYS_MASTER_MQH
#define ICT_PDARRAYS_MASTER_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "ICT_OrderBlocks.mqh"
#include "ICT_FairValueGaps.mqh"
#include "ICT_OTE.mqh"
#include "ICT_PDStacking.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize All PD Arrays                                          |
//+------------------------------------------------------------------+
bool InitializePDArrays()
{
   // Initialize subsystems
   if(!InitializePDArrays_OB())
      return false;
   
   if(!InitializePDArrays_FVG())
      return false;
   
   if(!InitializeOTE())
      return false;
   
   if(!InitializePDStacking())
      return false;
   
   g_pdArraysInitialized = true;
   Print("PD Arrays Master System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: MAIN DETECTION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect All PD Arrays (Main Orchestrator)                          |
//+------------------------------------------------------------------+
void DetectAllPDArrays()
{
   if(!g_pdArraysInitialized)
      return;
   
   // Detect Order Blocks (includes Breakers and Mitigation)
   DetectAllOrderBlocks();
   
   // Detect FVGs (includes VI and Void)
   DetectAllFVGs();
   
   // Update OTE and Premium/Discount
   UpdateOTESystem();
   
   // Calculate PD Stacking (must be last - depends on others)
   CalculatePDStacking();
   
   // Extend all rectangles
   ExtendAllPDRectangles();
}

//+------------------------------------------------------------------+
//| Extend All PD Rectangles                                          |
//+------------------------------------------------------------------+
void ExtendAllPDRectangles()
{
   ExtendOrderBlockRectangles();
   ExtendFVGRectangles();
   ExtendStackRectangles();
}

//+------------------------------------------------------------------+
//|              SECTION 3: UNIFIED CHECK FUNCTIONS                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Price at Any PD Array                                    |
//+------------------------------------------------------------------+
bool IsPriceAtAnyPDArray(bool isBullish, ENUM_PD_ARRAY_TYPE &outType, int &outIndex)
{
   // Priority: OB > Breaker > MB > Stack > FVG > OTE
   
   int idx;
   
   // 1. Check Order Blocks
   if(IsPriceAtOrderBlock(isBullish, idx))
   {
      outType = PD_ORDER_BLOCK;
      outIndex = idx;
      return true;
   }
   
   // 2. Check Breaker Blocks
   if(IsPriceAtBreakerBlock(isBullish, idx))
   {
      outType = PD_BREAKER_BLOCK;
      outIndex = idx;
      return true;
   }
   
   // 3. Check Mitigation Blocks
   if(IsPriceAtMitigationBlock(isBullish, idx))
   {
      outType = PD_MITIGATION_BLOCK;
      outIndex = idx;
      return true;
   }
   
   // 4. Check Stacked Levels
   if(IsPriceAtStackedLevel(isBullish, idx))
   {
      outType = PD_NONE; // Use stack count instead
      outIndex = idx;
      return true;
   }
   
   // 5. Check FVGs
   if(IsPriceInFVG(isBullish, idx))
   {
      outType = PD_FVG;
      outIndex = idx;
      return true;
   }
   
   // 6. Check OTE Zone
   if(IsPriceInOTEZone())
   {
      outType = PD_OTE_ZONE;
      outIndex = -1;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get PD Array Entry Score                                          |
//+------------------------------------------------------------------+
int GetPDArrayEntryScore(bool isBullish)
{
   int score = 0;
   int idx;
   
   // Check Stacks first (highest priority)
   idx = GetBestStack(isBullish);
   if(idx >= 0)
   {
      score = MathMax(score, g_pdStacks[idx].stackStrength);
   }
   
   // Check OBs
   idx = GetBestOrderBlock(isBullish);
   if(idx >= 0)
   {
      int obScore = 15;
      if(g_orderBlocks[idx].isInstitutional)
         obScore += 5;
      if(g_orderBlocks[idx].status == OB_FRESH)
         obScore += 5;
      score = MathMax(score, obScore);
   }
   
   // Check FVGs
   if(IsPriceInFVG(isBullish, idx))
   {
      int fvgScore = 10;
      if(g_fvgList[idx].status == FVG_OPEN)
         fvgScore += 3;
      score = MathMax(score, fvgScore);
   }
   
   // OTE Zone bonus
   if(IsPriceInOTEZone())
   {
      score += 10;
   }
   
   return score;
}

//+------------------------------------------------------------------+
//| Get PD Array Description                                          |
//+------------------------------------------------------------------+
string GetPDArrayDescription(ENUM_PD_ARRAY_TYPE type, int index)
{
   switch(type)
   {
      case PD_ORDER_BLOCK:
         if(index >= 0 && index < g_obCount)
         {
            string status = (g_orderBlocks[index].status == OB_FRESH) ? "Fresh" : "Tested";
            string inst = g_orderBlocks[index].isInstitutional ? " ★" : "";
            return status + " " + 
                   (g_orderBlocks[index].type == OB_BULLISH ? "Bullish" : "Bearish") + 
                   " OB" + inst;
         }
         break;
         
      case PD_BREAKER_BLOCK:
         if(index >= 0 && index < g_breakerCount)
         {
            return (g_breakerBlocks[index].type == BREAKER_BULLISH ? "Bullish" : "Bearish") + 
                   " Breaker";
         }
         break;
         
      case PD_MITIGATION_BLOCK:
         if(index >= 0 && index < g_mbCount)
         {
            return (g_mitigationBlocks[index].type == MB_BULLISH ? "Bullish" : "Bearish") + 
                   " Mitigation";
         }
         break;
         
      case PD_FVG:
         if(index >= 0 && index < g_fvgCount)
         {
            string fillStatus = "";
            if(g_fvgList[index].status == FVG_PARTIALLY_FILLED)
               fillStatus = " (CE Hit)";
            return (g_fvgList[index].type == FVG_BULLISH ? "Bullish" : "Bearish") + 
                   " FVG" + fillStatus;
         }
         break;
         
      case PD_OTE_ZONE:
         return "OTE Zone (Optimal Entry)";
   }
   
   // Check stacks
   if(index >= 0 && index < g_stackCount)
   {
      return "Stack x" + IntegerToString(g_pdStacks[index].stackCount) + 
             " (" + GetStackDescription(index) + ")";
   }
   
   return "Unknown";
}

//+------------------------------------------------------------------+
//|              SECTION 4: ENTRY ZONE PD ARRAY COUNT                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Count PD Arrays in Entry Zone                                     |
//+------------------------------------------------------------------+
int CountPDArraysInEntryZone(bool isBullish)
{
   if(!g_entryZone.isValid)
      return 0;
   
   int count = 0;
   double atr = GetATR();
   
   // Count OBs
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status == OB_FAILED)
         continue;
      
      bool isBullishOB = (g_orderBlocks[i].type == OB_BULLISH);
      if(isBullish != isBullishOB)
         continue;
      
      if(ZonesOverlap(g_orderBlocks[i].top, g_orderBlocks[i].bottom,
                       g_entryZone.upperBound, g_entryZone.lowerBound))
         count++;
   }
   
   // Count FVGs
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status == FVG_FULLY_FILLED)
         continue;
      
      bool isBullishFVG = (g_fvgList[i].type == FVG_BULLISH);
      if(isBullish != isBullishFVG)
         continue;
      
      if(ZonesOverlap(g_fvgList[i].top, g_fvgList[i].bottom,
                       g_entryZone.upperBound, g_entryZone.lowerBound))
         count++;
   }
   
   // Count Stacks
   count += CountStacks(isBullish);
   
   return count;
}

//+------------------------------------------------------------------+
//| Get Entry Zone PD Array Summary                                   |
//+------------------------------------------------------------------+
string GetEntryZonePDArraySummary()
{
   if(!g_entryZone.isValid)
      return "No Entry Zone";
   
   bool isBullish = (g_entryZone.direction == DIR_BULLISH);
   
   int obCount = 0;
   int fvgCount = 0;
   int stackCount = 0;
   
   // Count OBs
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status == OB_FAILED)
         continue;
      
      bool isBullishOB = (g_orderBlocks[i].type == OB_BULLISH);
      if(isBullish == isBullishOB)
      {
         if(ZonesOverlap(g_orderBlocks[i].top, g_orderBlocks[i].bottom,
                          g_entryZone.upperBound, g_entryZone.lowerBound))
            obCount++;
      }
   }
   
   // Count FVGs
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status == FVG_FULLY_FILLED)
         continue;
      
      bool isBullishFVG = (g_fvgList[i].type == FVG_BULLISH);
      if(isBullish == isBullishFVG)
      {
         if(ZonesOverlap(g_fvgList[i].top, g_fvgList[i].bottom,
                          g_entryZone.upperBound, g_entryZone.lowerBound))
            fvgCount++;
      }
   }
   
   // Count Stacks
   stackCount = CountStacks(isBullish);
   
   string summary = "";
   if(obCount > 0) summary += IntegerToString(obCount) + " OB | ";
   if(fvgCount > 0) summary += IntegerToString(fvgCount) + " FVG | ";
   if(stackCount > 0) summary += IntegerToString(stackCount) + " Stack | ";
   
   // OTE check
   if(IsPriceInOTEZone())
      summary += "OTE ✓ | ";
   
   // Zone check
   if(InpUsePremiumDiscount)
   {
      if(IsZoneAligned(isBullish))
         summary += "Zone ✓";
   }
   
   if(summary == "")
      summary = "No PD Arrays";
   
   return summary;
}

//+------------------------------------------------------------------+
//|              SECTION 5: CLEANUP                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Cleanup All PD Array Objects                                      |
//+------------------------------------------------------------------+
void CleanupAllPDArrayObjects()
{
   // Cleanup Order Blocks
   for(int i = 0; i < g_obCount; i++)
   {
      DeleteObject(g_orderBlocks[i].objName);
      DeleteObject(g_orderBlocks[i].labelName);
   }
   
   // Cleanup Breakers
   for(int i = 0; i < g_breakerCount; i++)
   {
      DeleteObject(g_breakerBlocks[i].objName);
      DeleteObject(g_breakerBlocks[i].labelName);
   }
   
   // Cleanup MBs
   for(int i = 0; i < g_mbCount; i++)
   {
      DeleteObject(g_mitigationBlocks[i].objName);
      DeleteObject(g_mitigationBlocks[i].labelName);
   }
   
   // Cleanup FVGs
   for(int i = 0; i < g_fvgCount; i++)
   {
      DeleteObject(g_fvgList[i].objName);
      DeleteObject(g_fvgList[i].labelName);
   }
   
   // Cleanup Stacks
   for(int i = 0; i < g_stackCount; i++)
   {
      DeleteObject(g_pdStacks[i].objName);
   }
   
   // Cleanup OTE
   DeleteObject(g_oteZone.objName);
   
   // Cleanup Range Lines
   DeleteObject(g_prefix + "Range_Premium");
   DeleteObject(g_prefix + "Range_EQ");
   DeleteObject(g_prefix + "Range_Discount");
}

//+------------------------------------------------------------------+
//|              SECTION 6: STATISTICS                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get PD Array Statistics                                           |
//+------------------------------------------------------------------+
string GetPDArrayStats()
{
   string stats = "";
   
   int freshOBs = CountFreshOrderBlocks(true) + CountFreshOrderBlocks(false);
   int openFVGs = GetOpenFVGCount(true) + GetOpenFVGCount(false);
   int stacks = g_stackCount;
   
   stats = "OBs:" + IntegerToString(g_obCount) + 
           " (Fresh:" + IntegerToString(freshOBs) + ") | " +
           "FVGs:" + IntegerToString(g_fvgCount) + 
           " (Open:" + IntegerToString(openFVGs) + ") | " +
           "Stacks:" + IntegerToString(stacks);
   
   return stats;
}

//+------------------------------------------------------------------+
//| Check if Price at Causal OB (by tag)                              |
//+------------------------------------------------------------------+
bool IsPriceAtCausalOB(bool lookForBullish, int causalTag, int &outIndex)
{
   outIndex = -1;
   if(causalTag < 0) return false;
   
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double bestDist = DBL_MAX;
   int bestIdx = -1;
   
   for(int i = 0; i < g_obCount; i++)
   {
      if(g_orderBlocks[i].status == OB_FAILED) continue;
      if(g_orderBlocks[i].causalTag != causalTag) continue;
      
      bool isBullOB = (g_orderBlocks[i].type == OB_BULLISH);
      if(isBullOB != lookForBullish) continue;
      
      if(price >= g_orderBlocks[i].bottom && price <= g_orderBlocks[i].top)
      {
         double mid = g_orderBlocks[i].midpoint;
         double dist = MathAbs(price - mid);
         if(dist < bestDist)
         {
            bestDist = dist;
            bestIdx = i;
         }
      }
   }
   
   if(bestIdx >= 0)
   {
      outIndex = bestIdx;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if Price in Causal FVG (by tag)                             |
//+------------------------------------------------------------------+
bool IsPriceInCausalFVG(bool lookForBullish, int causalTag, int &outIndex)
{
   outIndex = -1;
   if(causalTag < 0) return false;
   
   double price = iClose(_Symbol, PERIOD_CURRENT, 0);
   double bestDist = DBL_MAX;
   int bestIdx = -1;
   
   for(int i = 0; i < g_fvgCount; i++)
   {
      if(g_fvgList[i].status == FVG_FULLY_FILLED) continue;
      if(g_fvgList[i].causalTag != causalTag) continue;
      
      bool isBullFVG = (g_fvgList[i].type == FVG_BULLISH);
      if(isBullFVG != lookForBullish) continue;
      
      if(price >= g_fvgList[i].bottom && price <= g_fvgList[i].top)
      {
         double mid = (g_fvgList[i].top + g_fvgList[i].bottom) * 0.5;
         double dist = MathAbs(price - mid);
         if(dist < bestDist)
         {
            bestDist = dist;
            bestIdx = i;
         }
      }
   }
   
   if(bestIdx >= 0)
   {
      outIndex = bestIdx;
      return true;
   }
   return false;
}

#endif // ICT_PDARRAYS_MASTER_MQH