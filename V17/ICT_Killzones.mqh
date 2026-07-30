//+------------------------------------------------------------------+
//|                       ICT_Killzones.mqh                           |
//|              Trading Sessions & Killzone Detection                |
//|            "ICT Unified Professional EA v18"                      |
//+------------------------------------------------------------------+
#ifndef ICT_KILLZONES_MQH
#define ICT_KILLZONES_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Killzones                                              |
//+------------------------------------------------------------------+
bool InitializeKillzones()
{
   g_killzone.Reset();
   
   Print("Killzone System initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: KILLZONE DETECTION                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Killzone Status (Main Function)                            |
//+------------------------------------------------------------------+
void UpdateKillzoneStatus()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   
   int hour = tm.hour;
   int minute = tm.min;
   int totalMinutes = hour * 60 + minute;
   
   ENUM_KILLZONE previousKZ = g_killzone.current;
   
   // Reset
   g_killzone.current = KZ_NONE;
   g_killzone.isActive = false;
   g_killzone.multiplier = 1.0;
   
   // === ASIAN KILLZONE ===
   if(InpTradeAsianKZ)
   {
      int asianStartMin = InpAsianStart * 60;
      int asianEndMin = InpAsianEnd * 60;
      
      if(totalMinutes >= asianStartMin && totalMinutes < asianEndMin)
      {
         g_killzone.current = KZ_ASIAN;
         g_killzone.startTime = TimeCurrent() - (totalMinutes - asianStartMin) * 60;
         g_killzone.endTime = g_killzone.startTime + (InpAsianEnd - InpAsianStart) * 3600;
         g_killzone.isActive = true;
         g_killzone.multiplier = 1.0; // Base multiplier
      }
   }
   
   // === LONDON OPEN KILLZONE ===
   if(InpTradeLondonKZ && g_killzone.current == KZ_NONE)
   {
      int londonOpenStartMin = InpLondonOpenStart * 60;
      int londonOpenEndMin = InpLondonOpenEnd * 60;
      
      if(totalMinutes >= londonOpenStartMin && totalMinutes < londonOpenEndMin)
      {
         g_killzone.current = KZ_LONDON_OPEN;
         g_killzone.startTime = TimeCurrent() - (totalMinutes - londonOpenStartMin) * 60;
         g_killzone.endTime = g_killzone.startTime + (InpLondonOpenEnd - InpLondonOpenStart) * 3600;
         g_killzone.isActive = true;
         g_killzone.multiplier = InpKZ_ScoreMultiplier; // 1.25x bonus
      }
   }
   
   // === LONDON/NY OVERLAP ===
   // This is the highest probability window
   if(InpTradeLondonKZ && InpTradeNYKZ && g_killzone.current == KZ_NONE)
   {
      // Overlap typically 13:00 - 16:00 server time
      int overlapStartMin = 13 * 60;
      int overlapEndMin = 16 * 60;
      
      if(totalMinutes >= overlapStartMin && totalMinutes < overlapEndMin)
      {
         g_killzone.current = KZ_LONDON_NY_OVERLAP;
         g_killzone.startTime = TimeCurrent() - (totalMinutes - overlapStartMin) * 60;
         g_killzone.endTime = g_killzone.startTime + 3 * 3600;
         g_killzone.isActive = true;
         g_killzone.multiplier = InpKZ_ScoreMultiplier * 1.1; // Extra bonus
      }
   }
   
   // === NY OPEN KILLZONE ===
   if(InpTradeNYKZ && g_killzone.current == KZ_NONE)
   {
      int nyOpenStartMin = InpNYOpenStart * 60;
      int nyOpenEndMin = InpNYOpenEnd * 60;
      
      if(totalMinutes >= nyOpenStartMin && totalMinutes < nyOpenEndMin)
      {
         g_killzone.current = KZ_NY_OPEN;
         g_killzone.startTime = TimeCurrent() - (totalMinutes - nyOpenStartMin) * 60;
         g_killzone.endTime = g_killzone.startTime + (InpNYOpenEnd - InpNYOpenStart) * 3600;
         g_killzone.isActive = true;
         g_killzone.multiplier = InpKZ_ScoreMultiplier;
      }
   }
   
   // === LONDON CLOSE ===
   if(InpTradeLondonKZ && g_killzone.current == KZ_NONE)
   {
      int londonCloseStartMin = InpLondonCloseStart * 60;
      int londonCloseEndMin = InpLondonCloseEnd * 60;
      
      if(totalMinutes >= londonCloseStartMin && totalMinutes < londonCloseEndMin)
      {
         g_killzone.current = KZ_LONDON_CLOSE;
         g_killzone.startTime = TimeCurrent() - (totalMinutes - londonCloseStartMin) * 60;
         g_killzone.endTime = g_killzone.startTime + (InpLondonCloseEnd - InpLondonCloseStart) * 3600;
         g_killzone.isActive = true;
         g_killzone.multiplier = 1.1;
      }
   }
   
   // If not in any killzone
   if(g_killzone.current == KZ_NONE)
   {
      g_killzone.current = KZ_OFF_HOURS;
      g_killzone.isActive = false;
      g_killzone.multiplier = 0.7; // Penalty outside killzones
   }
   
   // Update session statistics
   if(g_killzone.current != previousKZ)
   {
      UpdateSessionStats();
   }
}

//+------------------------------------------------------------------+
//| Update Session Statistics                                         |
//+------------------------------------------------------------------+
void UpdateSessionStats()
{
   // Track session high/low/open
   if(g_killzone.isActive)
   {
      if(g_killzone.sessionHigh == 0)
      {
         g_killzone.sessionHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
         g_killzone.sessionLow = iLow(_Symbol, PERIOD_CURRENT, 0);
         g_killzone.openPrice = iOpen(_Symbol, PERIOD_CURRENT, 0);
      }
      else
      {
         double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
         double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
         
         if(currentHigh > g_killzone.sessionHigh)
            g_killzone.sessionHigh = currentHigh;
         if(currentLow < g_killzone.sessionLow)
            g_killzone.sessionLow = currentLow;
      }
   }
   else
   {
      // Reset when leaving killzone
      g_killzone.sessionHigh = 0;
      g_killzone.sessionLow = 0;
      g_killzone.openPrice = 0;
   }
}

//+------------------------------------------------------------------+
//|              SECTION 3: KILLZONE CHECKS                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Is In Killzone                                                    |
//+------------------------------------------------------------------+
bool IsInKillzone()
{
   if(!InpUseKillzoneFilter)
      return true; // Filter disabled
   
   return g_killzone.isActive;
}

//+------------------------------------------------------------------+
//| Get Killzone Score Multiplier                                     |
//+------------------------------------------------------------------+
double GetKillzoneScoreMultiplier()
{
   if(!InpUseKillzoneFilter)
      return 1.0;
   
   return g_killzone.multiplier;
}

//+------------------------------------------------------------------+
//| Get Killzone Score Bonus                                          |
//+------------------------------------------------------------------+
int GetKillzoneScoreBonus()
{
   if(!InpUseKillzoneFilter)
      return 0;
   
   if(!g_killzone.isActive)
      return 0;
   
   switch(g_killzone.current)
   {
      case KZ_LONDON_NY_OVERLAP:
         return 10; // Best window
      case KZ_LONDON_OPEN:
      case KZ_NY_OPEN:
         return 8;
      case KZ_LONDON_CLOSE:
         return 6;
      case KZ_ASIAN:
         return 4;
      default:
         return 0;
   }
}

//+------------------------------------------------------------------+
//| Is High Probability Window                                        |
//+------------------------------------------------------------------+
bool IsHighProbabilityWindow()
{
   return (g_killzone.current == KZ_LONDON_OPEN ||
           g_killzone.current == KZ_NY_OPEN ||
           g_killzone.current == KZ_LONDON_NY_OVERLAP);
}

//+------------------------------------------------------------------+
//| Check Session Filter                                              |
//+------------------------------------------------------------------+
/*bool CheckSessionFilter()
{
   if(!InpUseKillzoneFilter)
      return true;
   
   return g_killzone.isActive;
}
*/
//+------------------------------------------------------------------+
//|              SECTION 4: ICT MACROS (Specific Times)                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check ICT Macro Times                                             |
//+------------------------------------------------------------------+
bool IsAtICTMacro()
{
   // ICT Macros are specific times where moves often start
   // Examples: 9:50 AM, 10:10 AM, 2:00 PM NY time
   
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   
   int hour = tm.hour;
   int minute = tm.min;
   
   // Convert to approximate NY time (assuming server is GMT)
   // Adjust this based on your broker's server time
   int nyHour = (hour + 17) % 24; // Rough conversion
   
   // Silver Bullet windows (10-11 AM and 2-3 PM NY)
   if((nyHour >= 10 && nyHour < 11) || (nyHour >= 14 && nyHour < 15))
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Minutes Until Next Killzone                                   |
//+------------------------------------------------------------------+
int GetMinutesUntilNextKillzone()
{
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   
   int currentMinutes = tm.hour * 60 + tm.min;
   
   // Find next killzone start
   int nextStart = -1;
   
   // Check London Open
   int londonStart = InpLondonOpenStart * 60;
   if(currentMinutes < londonStart)
   {
      if(nextStart < 0 || londonStart < nextStart)
         nextStart = londonStart;
   }
   
   // Check NY Open
   int nyStart = InpNYOpenStart * 60;
   if(currentMinutes < nyStart)
   {
      if(nextStart < 0 || nyStart < nextStart)
         nextStart = nyStart;
   }
   
   if(nextStart < 0)
      return -1; // No more killzones today
   
   return nextStart - currentMinutes;
}

//+------------------------------------------------------------------+
//| Get Session Range                                                 |
//+------------------------------------------------------------------+
void GetSessionRange(double &high, double &low)
{
   high = g_killzone.sessionHigh;
   low = g_killzone.sessionLow;
}

//+------------------------------------------------------------------+
//| Get Killzone Description                                          |
//+------------------------------------------------------------------+
string GetKillzoneDescription()
{
   string desc = KillzoneToString(g_killzone.current);
   
   if(g_killzone.isActive)
   {
      desc += " (×" + DoubleToString(g_killzone.multiplier, 2) + ")";
   }
   
   return desc;
}

#endif // ICT_KILLZONES_MQH