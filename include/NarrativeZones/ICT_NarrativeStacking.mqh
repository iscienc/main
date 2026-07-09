//+------------------------------------------------------------------+
//|                      ICT_PDStacking.mqh                           |
//|              PD Stacking Disabled (Pure Narrative SM)             |
//+------------------------------------------------------------------+
#ifndef ICT_PDSTACKING_MQH
#define ICT_PDSTACKING_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"

//+------------------------------------------------------------------+
//| PD stacking module is intentionally disabled.                      |
//| Keep function signatures for compatibility with existing calls.    |
//+------------------------------------------------------------------+

bool InitializePDStacking()
{
   return true;
}

void CalculatePDStacking()
{
   // Disabled in Pure Narrative SM mode
}

void UpdatePDStacking()
{
   // Disabled in Pure Narrative SM mode
}

void ResetPDStacks()
{
   // Disabled in Pure Narrative SM mode
}

bool DetectPDStacks()
{
   return false;
}

void FindStackGroups(SPDZoneCandidate &candidates[], int candCount, bool isBullish)
{
   // Disabled in Pure Narrative SM mode
}

void AddCandidateToStack(SPDStack &stack, SPDZoneCandidate &candidate)
{
   // Disabled in Pure Narrative SM mode
}

int CalculatestackStrength(SPDStack &stack)
{
   return 0;
}

void DrawStack(int index)
{
   // Disabled in Pure Narrative SM mode
}

void ExtendStackRectangles()
{
   // Disabled in Pure Narrative SM mode
}

bool IsPriceAtStackedLevel(bool isBullish, int &outIndex)
{
   outIndex = -1;
   return false;
}

int GetBestStack(bool isBullish)
{
   return -1;
}

int CountStacks(bool isBullish)
{
   return 0;
}

string GetStackDescription(int index)
{
   return "";
}

// Compatibility helpers used by some builds
bool HasValidPDStack(bool isBullish)
{
   return false;
}

bool IsPriceAtPDStack(bool isBullish, int &stackIndex)
{
   stackIndex = -1;
   return false;
}

int GetBestPDStackScore(bool isBullish)
{
   return 0;
}

#endif // ICT_PDSTACKING_MQH