//+------------------------------------------------------------------+
//|                    ICT_PDArrays_Master.mqh                        |
//|      Narrative Zone Orchestrator (OB/FVG/OTE, no stack)          |
//+------------------------------------------------------------------+
#ifndef ICT_PDARRAYS_MASTER_MQH
#define ICT_PDARRAYS_MASTER_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "ICT_OrderBlocks.mqh"
#include "ICT_FairValueGaps.mqh"
#include "ICT_OTE.mqh"

// Local init state to avoid legacy global dependency
static bool s_narrativeZonesInitialized = false;

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                            |
//+------------------------------------------------------------------+
bool InitializeNarrativeZones()
{
   if(!InitializeNarrative_OB())
      return false;

   if(!InitializeNarrative_FVG())
      return false;

   if(!InitializeOTE())
      return false;

   s_narrativeZonesInitialized = true;
   Print("Narrative Zone Master System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: MAIN DETECTION                            |
//+------------------------------------------------------------------+
void DetectAllNarrativeZones()
{
   DetectAllNarrativeZonesLoadedOnly();
}

void ExtendAllNarrativeRectangles()
{
   ExtendOrderBlockRectangles();
   ExtendFVGRectangles();
}

//+------------------------------------------------------------------+
//|              SECTION 3: UNIFIED CHECK FUNCTIONS                   |
//+------------------------------------------------------------------+
bool IsPriceAtAnyNarrativeZone(bool isBullish, ENUM_NARRATIVE_ZONE_TYPE &outType, int &outIndex)
{
   outType = NZ_NONE;
   outIndex = -1;

   int idx = -1;

   if(IsPriceAtOrderBlock(isBullish, idx))
   {
      outType = NZ_ORDER_BLOCK;
      outIndex = idx;
      return true;
   }

   if(IsPriceAtBreakerBlock(isBullish, idx))
   {
      outType = NZ_BREAKER_BLOCK;
      outIndex = idx;
      return true;
   }

   if(IsPriceAtMitigationBlock(isBullish, idx))
   {
      outType = NZ_MITIGATION_BLOCK;
      outIndex = idx;
      return true;
   }

   if(IsPriceInFVG(isBullish, idx))
   {
      outType = NZ_FVG;
      outIndex = idx;
      return true;
   }

   if(IsPriceInOTEZone())
   {
      outType = NZ_OTE_ZONE;
      outIndex = -1;
      return true;
   }

   return false;
}

int GetNarrativeEntryScore(bool isBullish)
{
   int score = 0;
   int idx = -1;

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

   if(IsPriceInFVG(isBullish, idx))
   {
      int fvgScore = 10;
      if(g_fvgList[idx].status == FVG_OPEN)
         fvgScore += 3;
      score = MathMax(score, fvgScore);
   }

   if(IsPriceInOTEZone())
      score += 10;

   return score;
}

string GetNarrativeDescription(ENUM_NARRATIVE_ZONE_TYPE type, int index)
{
   switch(type)
   {
      case NZ_ORDER_BLOCK:
         if(index >= 0 && index < g_obCount)
         {
            string status = (g_orderBlocks[index].status == OB_FRESH) ? "Fresh" : "Tested";
            string inst = g_orderBlocks[index].isInstitutional ? " *" : "";
            return status + " " +
                   (g_orderBlocks[index].type == OB_BULLISH ? "Bullish" : "Bearish") +
                   " OB" + inst;
         }
         break;

      case NZ_BREAKER_BLOCK:
         if(index >= 0 && index < g_breakerCount)
         {
            return (g_breakerBlocks[index].type == BREAKER_BULLISH ? "Bullish" : "Bearish") +
                   " Breaker";
         }
         break;

      case NZ_MITIGATION_BLOCK:
         if(index >= 0 && index < g_mbCount)
         {
            return (g_mitigationBlocks[index].type == MB_BULLISH ? "Bullish" : "Bearish") +
                   " Mitigation";
         }
         break;

      case NZ_FVG:
         if(index >= 0 && index < g_fvgCount)
         {
            string fillStatus = "";
            if(g_fvgList[index].status == FVG_PARTIALLY_FILLED)
               fillStatus = " (CE Hit)";
            return (g_fvgList[index].type == FVG_BULLISH ? "Bullish" : "Bearish") +
                   " FVG" + fillStatus;
         }
         break;

      case NZ_OTE_ZONE:
         return "OTE Zone (Optimal Entry)";

      default:
         break;
   }

   return "Unknown";
}

//+------------------------------------------------------------------+
//|              SECTION 4: ENTRY ZONE ARRAY COUNT                    |
//+------------------------------------------------------------------+
int CountNarrativeZonesInEntryZone(bool isBullish)
{
   if(!g_entryZone.isValid)
      return 0;

   int count = 0;

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

   for(int j = 0; j < g_fvgCount; j++)
   {
      if(g_fvgList[j].status == FVG_FULLY_FILLED)
         continue;

      bool isBullishFVG = (g_fvgList[j].type == FVG_BULLISH);
      if(isBullish != isBullishFVG)
         continue;

      if(ZonesOverlap(g_fvgList[j].top, g_fvgList[j].bottom,
                      g_entryZone.upperBound, g_entryZone.lowerBound))
         count++;
   }

   return count;
}

string GetEntryZoneNarrativeSummary()
{
   if(!g_entryZone.isValid)
      return "No Entry Zone";

   bool isBullish = (g_entryZone.direction == DIR_BULLISH);

   int obCount = 0;
   int fvgCount = 0;

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

   for(int j = 0; j < g_fvgCount; j++)
   {
      if(g_fvgList[j].status == FVG_FULLY_FILLED)
         continue;

      bool isBullishFVG = (g_fvgList[j].type == FVG_BULLISH);
      if(isBullish == isBullishFVG)
      {
         if(ZonesOverlap(g_fvgList[j].top, g_fvgList[j].bottom,
                         g_entryZone.upperBound, g_entryZone.lowerBound))
            fvgCount++;
      }
   }

   string summary = "";
   if(obCount > 0) summary += IntegerToString(obCount) + " OB | ";
   if(fvgCount > 0) summary += IntegerToString(fvgCount) + " FVG | ";
   if(IsPriceInOTEZone()) summary += "OTE | ";

   if(summary == "")
      summary = "No Narrative Zones";
   else
      summary = StringSubstr(summary, 0, StringLen(summary) - 3);

   return summary;
}

//+------------------------------------------------------------------+
//|              SECTION 5: CLEANUP                                   |
//+------------------------------------------------------------------+
void CleanupAllNarrativeObjects()
{
   for(int i = 0; i < g_obCount; i++)
   {
      DeleteObject(g_orderBlocks[i].objName);
      DeleteObject(g_orderBlocks[i].labelName);
   }

   for(int j = 0; j < g_breakerCount; j++)
   {
      DeleteObject(g_breakerBlocks[j].objName);
      DeleteObject(g_breakerBlocks[j].labelName);
   }

   for(int k = 0; k < g_mbCount; k++)
   {
      DeleteObject(g_mitigationBlocks[k].objName);
      DeleteObject(g_mitigationBlocks[k].labelName);
   }

   for(int m = 0; m < g_fvgCount; m++)
   {
      DeleteObject(g_fvgList[m].objName);
      DeleteObject(g_fvgList[m].labelName);
   }

   DeleteObject(g_oteZone.objName);

   // Legacy cleanup (safe no-op if objects don't exist)
   DeleteObject(g_prefix + "Range_Premium");
   DeleteObject(g_prefix + "Range_EQ");
   DeleteObject(g_prefix + "Range_Discount");
}

//+------------------------------------------------------------------+
//|              SECTION 6: STATISTICS                                |
//+------------------------------------------------------------------+
string GetNarrativeStats()
{
   int freshOBs = CountFreshOrderBlocks(true) + CountFreshOrderBlocks(false);
   int openFVGs = GetOpenFVGCount(true) + GetOpenFVGCount(false);

   string stats = "OBs:" + IntegerToString(g_obCount) +
                  " (Fresh:" + IntegerToString(freshOBs) + ") | " +
                  "FVGs:" + IntegerToString(g_fvgCount) +
                  " (Open:" + IntegerToString(openFVGs) + ")";

   return stats;
}

//+------------------------------------------------------------------+
//| Causal helpers for SM detectors                                   |
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


void DetectAllNarrativeZonesLoadedOnly()
{
   if(!s_narrativeZonesInitialized)
      return;

   if(g_needDetectOB)
      DetectAllOrderBlocks();

   if(g_needDetectFVG)
      DetectAllFVGs();

   if(g_needDetectOTE)
      UpdateOTESystem();

   // Extension/update only for loaded families
   if(g_needDetectOB)
      ExtendOrderBlockRectangles();

   if(g_needDetectFVG)
      ExtendFVGRectangles();
}

#endif // ICT_PDARRAYS_MASTER_MQH