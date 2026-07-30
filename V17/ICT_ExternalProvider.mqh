//+-------------------------------------------------------------------------+
//|                ICT_ExternalProvider.mqh                                 |
//|External Indicator Provider Adapter  "ICT Unified Professional EA v15"   |
//+-------------------------------------------------------------------------+
#ifndef ICT_EXTERNAL_PROVIDER_MQH
#define ICT_EXTERNAL_PROVIDER_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Config.mqh"
#include "../Core/ICT_Globals.mqh"

//+------------------------------------------------------------------+
//| Initialize Provider                                               |
//+------------------------------------------------------------------+
bool InitializeProvider(int providerIdx, string indicatorName, double weight)
{
   if(providerIdx < 0 || providerIdx >= MAX_PROVIDERS) return false;
   if(indicatorName == "") return false;
   
   g_providers[providerIdx].Reset();
   g_providers[providerIdx].name = indicatorName;
   g_providers[providerIdx].weight = weight;
   g_providers[providerIdx].enabled = true;
   
   // Create indicator handle
   g_providers[providerIdx].handle = iCustom(_Symbol, PERIOD_CURRENT, indicatorName);
   
   if(g_providers[providerIdx].handle == INVALID_HANDLE)
   {
      Print("Provider ", providerIdx, ": Failed to load '", indicatorName, "' Error: ", GetLastError());
      g_providers[providerIdx].connected = false;
      g_providers[providerIdx].enabled = false;
      return false;
   }
   
   g_providers[providerIdx].connected = true;
   g_activeProviderCount++;
   
   Print("Provider ", providerIdx, ": '", indicatorName, "' loaded (Weight: ", weight, ")");
   return true;
}

//+------------------------------------------------------------------+
//| Read Signal from Provider                                         |
//+------------------------------------------------------------------+
SExternalSignal ReadProviderSignal(int providerIdx)
{
   SExternalSignal signal;
   signal.Reset();
   
   if(providerIdx < 0 || providerIdx >= MAX_PROVIDERS) return signal;
   if(!g_providers[providerIdx].enabled || !g_providers[providerIdx].connected) return signal;
   if(g_providers[providerIdx].handle == INVALID_HANDLE) return signal;
   
   int handle = g_providers[providerIdx].handle;
   double buf[1];
   
   // Buffer 0: Direction (0=None, 1=Buy, 2=Sell)
   double direction = 0;
   if(CopyBuffer(handle, 0, 0, 1, buf) > 0) direction = buf[0];
   if(direction != 1.0 && direction != 2.0) return signal; // No signal
   
   signal.direction = (direction == 1.0) ? SIGNAL_BUY : SIGNAL_SELL;
   signal.providerIndex = providerIdx;
   signal.providerName = g_providers[providerIdx].name;
   
   // Buffer 1: Entry Low
   if(CopyBuffer(handle, 1, 0, 1, buf) > 0 && IsValidValue(buf[0]))
      signal.entryLow = buf[0];
   
   // Buffer 2: Entry High
   if(CopyBuffer(handle, 2, 0, 1, buf) > 0 && IsValidValue(buf[0]))
      signal.entryHigh = buf[0];
   else
      signal.entryHigh = signal.entryLow; // Point entry
   
   // Buffer 3: Stop Loss
   if(CopyBuffer(handle, 3, 0, 1, buf) > 0 && IsValidValue(buf[0]))
      signal.stopLoss = buf[0];
   
   // Buffer 4: Take Profit 1
   if(CopyBuffer(handle, 4, 0, 1, buf) > 0 && IsValidValue(buf[0]))
      signal.takeProfit1 = buf[0];
   
   // Buffer 5: Take Profit 2
   if(CopyBuffer(handle, 5, 0, 1, buf) > 0 && IsValidValue(buf[0]))
      signal.takeProfit2 = buf[0];
   
   // Buffer 6: Score (0-100)
   if(CopyBuffer(handle, 6, 0, 1, buf) > 0 && IsValidValue(buf[0]))
      signal.confidence = buf[0];
   
   // Buffer 7: Signal ID
   if(CopyBuffer(handle, 7, 0, 1, buf) > 0 && IsValidValue(buf[0]))
      signal.signalID = buf[0];
   
   // Validate
   signal.signalTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   signal.barIndex = 0;
   signal.expirationBars = InpExternalExpirationBars;
   
   // Check for duplicate
   if(signal.signalID > 0 && signal.signalID == g_providers[providerIdx].lastSignalID)
   {
      signal.isStale = true;
      return signal;
   }
   
   // Check minimum confidence
   if(signal.confidence < InpExternalMinConfidence)
   {
      signal.isValid = false;
      return signal;
   }
   
   // Validate SL/TP logic
   if(signal.direction == SIGNAL_BUY)
   {
      if(signal.stopLoss > 0 && signal.stopLoss >= signal.entryLow) { signal.isValid = false; return signal; }
      if(signal.takeProfit1 > 0 && signal.takeProfit1 <= signal.entryHigh) { signal.isValid = false; return signal; }
   }
   else
   {
      if(signal.stopLoss > 0 && signal.stopLoss <= signal.entryHigh) { signal.isValid = false; return signal; }
      if(signal.takeProfit1 > 0 && signal.takeProfit1 >= signal.entryLow) { signal.isValid = false; return signal; }
   }
   
   signal.isValid = true;
   signal.lifecycle = SLC_CONFIRMED;
   g_providers[providerIdx].lastSignalID = signal.signalID;
   
   return signal;
}

//+------------------------------------------------------------------+
//| Check if Value is Valid (not EMPTY_VALUE or NaN)                  |
//+------------------------------------------------------------------+
bool IsValidValue(double val)
{
   if(val == EMPTY_VALUE) return false;
   if(val == DBL_MAX) return false;
   if(val != val) return false; // NaN check
   if(val == 0.0) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Release Provider                                                  |
//+------------------------------------------------------------------+
void ReleaseProvider(int providerIdx)
{
   if(providerIdx < 0 || providerIdx >= MAX_PROVIDERS) return;
   
   if(g_providers[providerIdx].handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_providers[providerIdx].handle);
      g_providers[providerIdx].handle = INVALID_HANDLE;
   }
   
   g_providers[providerIdx].connected = false;
}

//+------------------------------------------------------------------+
//| Release All Providers                                             |
//+------------------------------------------------------------------+
void ReleaseAllProviders()
{
   for(int i = 0; i < MAX_PROVIDERS; i++)
      ReleaseProvider(i);
   g_activeProviderCount = 0;
}

#endif // ICT_EXTERNAL_PROVIDER_MQH