//+------------------------------------------------------------------+
//|                     ICT_TradeManager.mqh                          |
//|              Trade Execution and Management                       |
//|             "ICT Unified Professional EA v15"                     |
//+------------------------------------------------------------------+
#ifndef ICT_TRADEMANAGER_MQH
#define ICT_TRADEMANAGER_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "ICT_SignalEngine.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Trade Manager                                          |
//+------------------------------------------------------------------+
bool InitializeTradeManager()
{
   // Initialize stats
   g_stats.Reset();
   
   Print("Trade Manager initialized");
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 2: TRADE EXECUTION                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Execute Trade (FIXED - proper TP and position tracking)           |
//+------------------------------------------------------------------+
bool ExecuteTrade()
  {
   if(!g_hasValidSignal || !g_currentSignal.isValid) return false;
   if(!PreTradeChecks()) return false;

   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   request.symbol       = _Symbol;
   request.volume       = g_currentSignal.lotSize;
   request.deviation    = InpMaxSlippage;
   request.magic        = InpMagicNumber;
   request.comment = InpTradeComment + "#" + IntegerToString(g_currentSignal.chainId);
   request.type_filling = GetFillingType();

   // Broker TP: TP3 when using partials+multiTP, else TP1 (unchanged logic)
   double brokerTP = (InpUseMultipleTP && InpUsePartialClose)
                     ? g_currentSignal.tp3Price : g_currentSignal.tp1Price;

   bool isBuy = (g_currentSignal.type == SIGNAL_BUY);

   //================================================================
   // PENDING PATH (LIMIT / STOP)
   //================================================================
   if(g_currentSignal.isPending)
     {
      request.action = TRADE_ACTION_PENDING;
      request.type   = g_currentSignal.pendingType;
      request.price  = NormalizePrice(g_currentSignal.pendingPrice);
      request.sl     = g_currentSignal.slPrice;
      request.tp     = brokerTP;

      if(g_currentSignal.pendingExpiry > 0)
        {
         request.type_time  = ORDER_TIME_SPECIFIED;
         request.expiration = g_currentSignal.pendingExpiry;
        }
      else
         request.type_time = ORDER_TIME_GTC;

      if(!OrderSend(request, result))
        {
         Print("Pending order failed! Error: ", GetLastError(), " Retcode: ", result.retcode);
         return false;
        }

      // Track the RESTING order; fill-time tracking is finalized on trigger (see note)
      g_posTracking.Reset();
      g_posTracking.ticket        = result.order;   // pending ticket
      g_posTracking.entryPrice    = request.price;
      g_posTracking.initialSL     = g_currentSignal.slPrice;
      g_posTracking.initialLotSize= g_currentSignal.lotSize;
      g_posTracking.tp1Price      = g_currentSignal.tp1Price;
      g_posTracking.tp2Price      = g_currentSignal.tp2Price;
      g_posTracking.tp3Price      = g_currentSignal.tp3Price;
      g_posTracking.tp1Done       = false;
      g_posTracking.tp2Done       = false;
      g_posTracking.tp3Done       = false;
      g_posTracking.breakEvenDone = false;
      g_posTracking.direction     = g_currentSignal.type;
      g_posTracking.tpMode        = InpTpMode;
      g_posTracking.partialMode   = InpPartialMode;
      g_posTracking.openTime      = TimeCurrent();

      g_currentSignal.isExecuted = true;
      g_currentSignal.ticket     = result.order;
      g_stats.todayTrades++;
      g_stats.totalTrades++;
      AddSignalToHistory(g_currentSignal);
      PrintTradeExecuted(result.order);
      ClearSignal();
      return true;
     }

   //================================================================
   // MARKET PATH (original behavior, unchanged)
   //================================================================
   request.action = TRADE_ACTION_DEAL;
   if(isBuy)
     {
      request.type  = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      request.sl    = g_currentSignal.slPrice;
      request.tp    = brokerTP;
     }
   else
     {
      request.type  = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      request.sl    = g_currentSignal.slPrice;
      request.tp    = brokerTP;
     }

   if(!OrderSend(request, result))
     {
      Print("Order failed! Error: ", GetLastError(), " Retcode: ", result.retcode);
      return false;
     }

   g_posTracking.Reset();
   g_posTracking.ticket        = result.order;
   g_posTracking.entryPrice    = request.price;
   g_posTracking.initialSL     = g_currentSignal.slPrice;
   g_posTracking.initialLotSize= g_currentSignal.lotSize;
   g_posTracking.tp1Price      = g_currentSignal.tp1Price;
   g_posTracking.tp2Price      = g_currentSignal.tp2Price;
   g_posTracking.tp3Price      = g_currentSignal.tp3Price;
   g_posTracking.tp1Done       = false;
   g_posTracking.tp2Done       = false;
   g_posTracking.tp3Done       = false;
   g_posTracking.breakEvenDone = false;
   g_posTracking.direction     = g_currentSignal.type;
   g_posTracking.tpMode        = InpTpMode;
   g_posTracking.partialMode   = InpPartialMode;
   g_posTracking.openTime      = TimeCurrent();

   g_currentSignal.isExecuted = true;
   g_currentSignal.ticket     = result.order;
   g_stats.todayTrades++;
   g_stats.totalTrades++;
   AddSignalToHistory(g_currentSignal);
   PrintTradeExecuted(result.order);
   ClearSignal();
   return true;
  }

//+------------------------------------------------------------------+
//| Pre-Trade Checks                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| True if a live position OR pending order already exists for this  |
//| SM chain (matched by magic + "#<chainId>" in the comment).        |
//+------------------------------------------------------------------+
bool HasOrderForChain(int chainId)
  {
   if(chainId <= 0) return false;
   string tag = "#" + IntegerToString(chainId);

   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)       continue;
      if(PositionGetInteger(POSITION_MAGIC)  != InpMagicNumber) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), tag) >= 0) return true;
     }
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)       continue;
      if(OrderGetInteger(ORDER_MAGIC)  != InpMagicNumber) continue;
      if(StringFind(OrderGetString(ORDER_COMMENT), tag) >= 0) return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
bool PreTradeChecks()
{
   // Terminal checks
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("Trading not allowed by terminal");
      return false;
   }
   
   // Expert advisor checks
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Trading not allowed by EA");
      return false;
   }
   
   // Account checks
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      Print("Trading not allowed by account");
      return false;
   }
   // new add pending check
   if(HasOrderForChain(g_currentSignal.chainId))
     { Print("Chain #", g_currentSignal.chainId, " already has an order"); return false; }
     
   // Daily trade limit
   if(InpUseMaxTrades && g_stats.todayTrades >= InpMaxDailyTrades)
   {
      Print("Max daily trades reached");
      g_maxTradesReached = true;
      return false;
   }
   
   // Daily loss limit
   if(InpUseMaxLoss && g_dailyLossReached)
   {
      Print("Max daily loss reached");
      return false;
   }
   
   // Spread check
   if(InpUseSpreadFilter)
   {
      int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpread)
      {
         Print("Spread too high: ", spread, " > ", InpMaxSpread);
         return false;
      }
   }
   
   // Session check
   if(!CheckSessionFilter())
   {
      Print("Outside trading session");
      return false;
   }
   
   // Day check
   if(!IsTradingDay())
   {
      Print("Not a trading day");
      return false;
   }
   
   // Check for open positions with same magic
   if(HasOpenPosition())
   {
      Print("Already have open position");
      return false;
   }
   
   return true;
}



//+------------------------------------------------------------------+
//| Has Open Position                                                 |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Print Trade Executed                                              |
//+------------------------------------------------------------------+
void PrintTradeExecuted(ulong ticket)
{
   string dir = (g_currentSignal.type == SIGNAL_BUY) ? "BUY" : "SELL";
   
   Print("══════════════════════════════════════════════════════");
   Print("  TRADE EXECUTED: ", dir, " #", ticket);
   Print("  Entry: ", DoubleToString(g_currentSignal.entryPrice, _Digits));
   Print("  SL: ", DoubleToString(g_currentSignal.slPrice, _Digits));
   Print("  TP1: ", DoubleToString(g_currentSignal.tp1Price, _Digits));
   Print("  TP2: ", DoubleToString(g_currentSignal.tp2Price, _Digits));
   Print("  TP3: ", DoubleToString(g_currentSignal.tp3Price, _Digits));
   Print("  Lot: ", DoubleToString(g_currentSignal.lotSize, 2));
   Print("  RR: ", DoubleToString(g_currentSignal.riskReward, 2));
   Print("══════════════════════════════════════════════════════");
   
   if(InpAlertTrades)
   {
      string msg = dir + " Executed #" + IntegerToString(ticket);
      SendAlert(msg, false, InpPushNotification, InpEmailNotification);
   }
}

//+------------------------------------------------------------------+
//|              SECTION 3: TRADE MANAGEMENT                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage Open Positions (Main Function)                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Manage Open Positions (ENHANCED)                                  |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   bool hasPosition = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ManageSinglePosition(ticket);
            hasPosition = true;
         }
      }
   }
   
   // Reset tracking when position is gone
   if(!hasPosition && g_posTracking.IsActive())
   {
      g_posTracking.Reset();
   }
}
//+------------------------------------------------------------------+
//| Manage Single Position (FIXED - proper order of operations)       |
//+------------------------------------------------------------------+
void ManageSinglePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return;
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double profit = PositionGetDouble(POSITION_PROFIT);
   double volume = PositionGetDouble(POSITION_VOLUME);
   
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   bool isBuy = (posType == POSITION_TYPE_BUY);
   
   // Sync position tracking if needed
   if(g_posTracking.ticket != ticket)
   {
      SyncPositionTracking(ticket, posType, openPrice, currentSL);
   }
   
   // Calculate actual distance from entry
   double distance = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
   
   // Use ACTUAL risk for RR calculations (FIX BUG #1 & #3)
   double actualRisk = g_posTracking.InitialRisk();
   if(actualRisk <= 0) actualRisk = MathAbs(openPrice - currentSL);
   if(actualRisk <= 0) actualRisk = GetATR(); // Last fallback
   
   // 1. Partial Close (MUST be checked before BE/Trailing)
   if(InpUsePartialClose && InpUseMultipleTP)
   {
      CheckPartialCloseEnhanced(ticket, posType, volume, currentPrice, openPrice, actualRisk);
   }
   
   // 2. Breakeven (after partials, so we don't interfere)
   if(InpMoveToBreakeven)
   {
      CheckMoveToBreakevenFixed(ticket, posType, openPrice, currentSL, distance, actualRisk);
   }
   
   // 3. Trailing Stop (FIX BUG #4: won't move behind BE)
   if(InpUseTrailingStop)
   {
      CheckTrailingStopFixed(ticket, posType, currentPrice, currentSL, openPrice);
   }
}

//+------------------------------------------------------------------+
//| Sync Position Tracking (when tracking lost, e.g., EA restart)     |
//+------------------------------------------------------------------+
void SyncPositionTracking(ulong ticket, ENUM_POSITION_TYPE posType, 
                          double openPrice, double currentSL)
{
   g_posTracking.Reset();
   g_posTracking.ticket = ticket;
   g_posTracking.entryPrice = openPrice;
   g_posTracking.initialSL = currentSL;
   g_posTracking.initialLotSize = PositionGetDouble(POSITION_VOLUME);
   g_posTracking.direction = (posType == POSITION_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL;
   g_posTracking.tpMode = InpTpMode;
   g_posTracking.partialMode = InpPartialMode;
   g_posTracking.openTime = (datetime)PositionGetInteger(POSITION_TIME);
   
   // Reconstruct TPs from current settings
   double risk = MathAbs(openPrice - currentSL);
   bool isBuy = (posType == POSITION_TYPE_BUY);
   
   g_posTracking.tp1Price = isBuy ? openPrice + risk * InpTP1_RR : openPrice - risk * InpTP1_RR;
   g_posTracking.tp2Price = isBuy ? openPrice + risk * InpTP2_RR : openPrice - risk * InpTP2_RR;
   g_posTracking.tp3Price = isBuy ? openPrice + risk * InpTP3_RR : openPrice - risk * InpTP3_RR;
   
   // Detect already-done partials from volume
   double currentVol = PositionGetDouble(POSITION_VOLUME);
   double tp1Vol = g_posTracking.initialLotSize * (1.0 - InpTP1_Percent / 100.0);
   double tp2Vol = tp1Vol * (1.0 - InpTP2_Percent / (100.0 - InpTP1_Percent) );
   
   if(currentVol <= tp1Vol + SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))
      g_posTracking.tp1Done = true;
   if(currentVol <= tp2Vol + SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))
      g_posTracking.tp2Done = true;
   
   // Detect BE done
   if(isBuy && currentSL >= openPrice - _Point * 10)
      g_posTracking.breakEvenDone = true;
   if(!isBuy && currentSL <= openPrice + _Point * 10)
      g_posTracking.breakEvenDone = true;
   
   Print("Position tracking synced for ticket #", ticket);
}
//+------------------------------------------------------------------+
//| Check Move to Breakeven (FIXED - uses actual risk, not ATR)       |
//+------------------------------------------------------------------+
void CheckMoveToBreakevenFixed(ulong ticket, ENUM_POSITION_TYPE posType, double openPrice, 
                               double currentSL, double distance, double actualRisk)
{
   if(g_posTracking.breakEvenDone)
      return;
   
   // FIX BUG #3: Use actual risk for BE calculation
   double beDistance = actualRisk * InpBreakevenAt_RR;
   
   if(distance < beDistance)
      return;
   
   double spreadBuffer = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double beLevel;
   
   if(posType == POSITION_TYPE_BUY)
   {
      beLevel = openPrice + spreadBuffer;
      if(currentSL >= beLevel)
         return; // Already at BE or better
      
      if(ModifyPositionSL(ticket, beLevel))
      {
         g_posTracking.breakEvenDone = true;
         Print("✅ Breakeven set at ", DoubleToString(beLevel, _Digits));
      }
   }
   else
   {
      beLevel = openPrice - spreadBuffer;
      if(currentSL <= beLevel)
         return;
      
      if(ModifyPositionSL(ticket, beLevel))
      {
         g_posTracking.breakEvenDone = true;
         Print("✅ Breakeven set at ", DoubleToString(beLevel, _Digits));
      }
   }
}
//+------------------------------------------------------------------+
//| Check Trailing Stop (FIXED - won't move behind breakeven)         |
//+------------------------------------------------------------------+
void CheckTrailingStopFixed(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, 
                            double currentSL, double openPrice)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trailStart = InpTrailingStart * point;
   double trailStep = InpTrailingStep * point;
   
   // FIX BUG #4: Calculate minimum SL (never go behind breakeven if BE was done)
   double minSL = 0;
   if(g_posTracking.breakEvenDone)
   {
      double spreadBuffer = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      minSL = (posType == POSITION_TYPE_BUY) ? openPrice + spreadBuffer 
                                              : openPrice - spreadBuffer;
   }
   
   if(posType == POSITION_TYPE_BUY)
   {
      double distance = currentPrice - openPrice;
      if(distance < trailStart) return; // Not enough profit to trail
      
      double newSL = currentPrice - trailStart;
      
      // Ensure new SL doesn't go behind BE
      if(minSL > 0 && newSL < minSL)
         newSL = minSL;
      
      // Only move forward
      if(newSL > currentSL + trailStep)
      {
         ModifyPositionSL(ticket, NormalizePrice(newSL));
      }
   }
   else
   {
      double distance = openPrice - currentPrice;
      if(distance < trailStart) return;
      
      double newSL = currentPrice + trailStart;
      
      if(minSL > 0 && newSL > minSL)
         newSL = minSL;
      
      if(newSL < currentSL - trailStep)
      {
         ModifyPositionSL(ticket, NormalizePrice(newSL));
      }
   }
}

//+------------------------------------------------------------------+
//| Enhanced Partial Close (FIXED - all bugs, all modes)              |
//+------------------------------------------------------------------+
void CheckPartialCloseEnhanced(ulong ticket, ENUM_POSITION_TYPE posType, double volume,
                                double currentPrice, double openPrice, double actualRisk)
{
   // FIX BUG #2: Check if partials already done
   bool isBuy = (posType == POSITION_TYPE_BUY);
   
   // Choose trigger mode
   switch(InpPartialMode)
   {
      case PARTIAL_RR_BASED:
         CheckPartial_RR(ticket, posType, volume, currentPrice, openPrice, actualRisk);
         break;
         
      case PARTIAL_DR_TARGETS:
         CheckPartial_DRTargets(ticket, posType, volume, currentPrice);
         break;
         
      case PARTIAL_ATR_DISTANCE:
         CheckPartial_ATRDistance(ticket, posType, volume, currentPrice, openPrice);
         break;
         
      case PARTIAL_FIXED_POINTS:
         CheckPartial_FixedPoints(ticket, posType, volume, currentPrice, openPrice);
         break;
   }
}

//+------------------------------------------------------------------+
//| Partial Close: RR-Based (FIXED)                                   |
//+------------------------------------------------------------------+
void CheckPartial_RR(ulong ticket, ENUM_POSITION_TYPE posType, double volume,
                     double currentPrice, double openPrice, double actualRisk)
{
   if(actualRisk <= 0) return;
   
   bool isBuy = (posType == POSITION_TYPE_BUY);
   double distance = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
   double rrAchieved = distance / actualRisk;
   
   // TP1 partial
   if(!g_posTracking.tp1Done && rrAchieved >= InpTP1_RR)
   {
      double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP1_Percent / 100.0);
      if(closeVol > 0 && closeVol <= volume)
      {
         if(ClosePartialPosition(ticket, closeVol, "TP1 @" + DoubleToString(InpTP1_RR, 1) + "R"))
         {
            g_posTracking.tp1Done = true;
            Print("✅ TP1 partial closed at ", DoubleToString(rrAchieved, 2), "R");
         }
      }
   }
   
   // TP2 partial
   if(g_posTracking.tp1Done && !g_posTracking.tp2Done && rrAchieved >= InpTP2_RR)
   {
      double remainVol = volume;
      double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP2_Percent / 100.0);
      if(closeVol > 0 && closeVol <= remainVol)
      {
         if(ClosePartialPosition(ticket, closeVol, "TP2 @" + DoubleToString(InpTP2_RR, 1) + "R"))
         {
            g_posTracking.tp2Done = true;
            Print("✅ TP2 partial closed at ", DoubleToString(rrAchieved, 2), "R");
         }
      }
   }
   
   // TP3: handled by broker's TP (set to TP3 level in ExecuteTrade)
}

//+------------------------------------------------------------------+
//| Partial Close: DR Target Lines (NEW)                              |
//| Closes partial when price hits actual DR target line prices       |
//+------------------------------------------------------------------+
void CheckPartial_DRTargets(ulong ticket, ENUM_POSITION_TYPE posType, 
                            double volume, double currentPrice)
{
   bool isBuy = (posType == POSITION_TYPE_BUY);
   
   // TP1
   if(!g_posTracking.tp1Done && g_posTracking.tp1Price > 0)
   {
      bool hit = isBuy ? (currentPrice >= g_posTracking.tp1Price) 
                       : (currentPrice <= g_posTracking.tp1Price);
      
      if(hit)
      {
         double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP1_Percent / 100.0);
         if(closeVol > 0 && closeVol <= volume)
         {
            if(ClosePartialPosition(ticket, closeVol, "DRT-TP1 @" + DoubleToString(g_posTracking.tp1Price, _Digits)))
            {
               g_posTracking.tp1Done = true;
               Print("🎯 DR Target TP1 HIT: ", DoubleToString(g_posTracking.tp1Price, _Digits));
            }
         }
      }
   }
   
   // TP2
   if(g_posTracking.tp1Done && !g_posTracking.tp2Done && g_posTracking.tp2Price > 0)
   {
      bool hit = isBuy ? (currentPrice >= g_posTracking.tp2Price)
                       : (currentPrice <= g_posTracking.tp2Price);
      
      if(hit)
      {
         double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP2_Percent / 100.0);
         double remainVol = volume;
         if(closeVol > 0 && closeVol <= remainVol)
         {
            if(ClosePartialPosition(ticket, closeVol, "DRT-TP2 @" + DoubleToString(g_posTracking.tp2Price, _Digits)))
            {
               g_posTracking.tp2Done = true;
               Print("🎯 DR Target TP2 HIT: ", DoubleToString(g_posTracking.tp2Price, _Digits));
            }
         }
      }
   }
   
   // TP3: handled by broker TP (or close remainder here)
   if(g_posTracking.tp1Done && g_posTracking.tp2Done && !g_posTracking.tp3Done && g_posTracking.tp3Price > 0)
   {
      bool hit = isBuy ? (currentPrice >= g_posTracking.tp3Price)
                       : (currentPrice <= g_posTracking.tp3Price);
      
      if(hit)
      {
         // Close remaining position
         if(ClosePosition(ticket))
         {
            g_posTracking.tp3Done = true;
            Print("🎯 DR Target TP3 HIT (Full Close): ", DoubleToString(g_posTracking.tp3Price, _Digits));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Partial Close: ATR Distance Intervals                             |
//+------------------------------------------------------------------+
void CheckPartial_ATRDistance(ulong ticket, ENUM_POSITION_TYPE posType,
                             double volume, double currentPrice, double openPrice)
{
   double atr = GetATR();
   if(atr <= 0) return;
   
   bool isBuy = (posType == POSITION_TYPE_BUY);
   double distance = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
   
   if(!g_posTracking.tp1Done && distance >= atr * InpPartialATR_Mult1)
   {
      double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP1_Percent / 100.0);
      if(closeVol > 0 && closeVol <= volume)
      {
         if(ClosePartialPosition(ticket, closeVol, "ATR-TP1"))
            g_posTracking.tp1Done = true;
      }
   }
   
   if(g_posTracking.tp1Done && !g_posTracking.tp2Done && distance >= atr * InpPartialATR_Mult2)
   {
      double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP2_Percent / 100.0);
      if(closeVol > 0 && closeVol <= volume)
      {
         if(ClosePartialPosition(ticket, closeVol, "ATR-TP2"))
            g_posTracking.tp2Done = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Partial Close: Fixed Points Intervals                             |
//+------------------------------------------------------------------+
void CheckPartial_FixedPoints(ulong ticket, ENUM_POSITION_TYPE posType,
                              double volume, double currentPrice, double openPrice)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   bool isBuy = (posType == POSITION_TYPE_BUY);
   double distPoints = isBuy ? (currentPrice - openPrice) / point 
                             : (openPrice - currentPrice) / point;
   
   if(!g_posTracking.tp1Done && distPoints >= InpPartialFixedPoints1)
   {
      double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP1_Percent / 100.0);
      if(closeVol > 0 && closeVol <= volume)
      {
         if(ClosePartialPosition(ticket, closeVol, "PTS-TP1"))
            g_posTracking.tp1Done = true;
      }
   }
   
   if(g_posTracking.tp1Done && !g_posTracking.tp2Done && distPoints >= InpPartialFixedPoints2)
   {
      double closeVol = NormalizeVolume(g_posTracking.initialLotSize * InpTP2_Percent / 100.0);
      if(closeVol > 0 && closeVol <= volume)
      {
         if(ClosePartialPosition(ticket, closeVol, "PTS-TP2"))
            g_posTracking.tp2Done = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Modify Position SL (FIXED - ensures position selected)            |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, double newSL)
{
   if(!PositionSelectByTicket(ticket))  // FIX BUG #6
   {
      Print("ModifyPositionSL: Cannot select position #", ticket);
      return false;
   }
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = _Symbol;
   request.sl = NormalizePrice(newSL);
   request.tp = PositionGetDouble(POSITION_TP);
   
   if(!OrderSend(request, result))
   {
      if(result.retcode != TRADE_RETCODE_NO_CHANGES)
         Print("Failed to modify SL: ", RetcodeToString(result.retcode));
      return false;
   }
   
   return (result.retcode == TRADE_RETCODE_DONE);
}
//+------------------------------------------------------------------+
//| Close Partial Position                                            |
//+------------------------------------------------------------------+
bool ClosePartialPosition(ulong ticket, double volume, string comment)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.volume = NormalizeVolume(volume);
   request.deviation = InpMaxSlippage;
   request.comment = comment;
   
   if(posType == POSITION_TYPE_BUY)
   {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   
   if(!OrderSend(request, result))
   {
      Print("Failed to close partial: ", GetLastError());
      return false;
   }
   
   Print("Partial close executed: ", comment, " Vol: ", volume);
   return true;
}

//+------------------------------------------------------------------+
//| Normalize Volume                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   volume = MathFloor(volume / lotStep) * lotStep;
   volume = MathMax(minLot, MathMin(maxLot, volume));
   
   return NormalizeDouble(volume, 2);
}

//+------------------------------------------------------------------+
//| Close Position                                                    |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   if(!PositionSelectByTicket(ticket))
      return false;
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.deviation = InpMaxSlippage;
   request.comment = "Manual Close";
   
   if(posType == POSITION_TYPE_BUY)
   {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }
   
   if(!OrderSend(request, result))
   {
      Print("Failed to close position: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 4: STATISTICS                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Trade Statistics                                          |
//+------------------------------------------------------------------+
void UpdateTradeStatistics()
{
   // Reset daily stats if needed
   CheckDailyReset();
   
   // Get history deals
   datetime from = g_lastStatsUpdate > 0 ? g_lastStatsUpdate : TimeCurrent() - 86400 * 30;
   datetime to = TimeCurrent();
   
   if(!HistorySelect(from, to))
      return;
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      
      if(dealTicket == 0)
         continue;
      
      // Check magic number
      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic != InpMagicNumber)
         continue;
      
      // Check symbol
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      if(dealSymbol != _Symbol)
         continue;
      
      // Get deal info
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      double netProfit = dealProfit + dealSwap + dealCommission;
      
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      
      // Only count closing deals
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY)
         continue;
      
      // Skip if already counted
      if(dealTime <= g_lastStatsUpdate)
         continue;
      
            // ML Learning: Add training sample
    // ╔══════════════════════════════════════════════════════════╗
      // ║  FIX: Use features from SIGNAL TIME, not close time     ║
      // ╚══════════════════════════════════════════════════════════╝
      if(g_mlInitialized && InpML_Mode != ML_OFF)
      {
         SMLFeatureVector fv;
         if(g_posTracking.hasSignalFeatures)
         {
            fv = g_posTracking.signalFeatures;  // Use correct features
         }
         else
         {
            fv = ExtractFeatures();  // Fallback (EA restart case)
         }
         
         ENUM_SIGNAL_TYPE sigType = (netProfit > 0) ? SIGNAL_BUY : SIGNAL_SELL;
         AddTrainingSample(fv, netProfit, sigType, 0);
         UpdatePredictionOutcome(netProfit > 0, netProfit);
         g_mlClosedTradeCount++;
      }
      
      // Update stats
      g_stats.totalTrades++;
      
      if(netProfit > 0)
      {
         g_stats.winTrades++;
         g_stats.totalProfit += netProfit;
         g_stats.consecutiveWins++;
         g_stats.consecutiveLosses = 0;
         
         if(netProfit > g_stats.bestTrade)
            g_stats.bestTrade = netProfit;
         
         if(g_stats.consecutiveWins > g_stats.maxConsecutiveWins)
            g_stats.maxConsecutiveWins = g_stats.consecutiveWins;
      }
      else
      {
         g_stats.lossTrades++;
         g_stats.totalLoss += MathAbs(netProfit);
         g_stats.consecutiveLosses++;
         g_stats.consecutiveWins = 0;
         
         if(netProfit < g_stats.worstTrade)
            g_stats.worstTrade = netProfit;
         
         if(g_stats.consecutiveLosses > g_stats.maxConsecutiveLosses)
            g_stats.maxConsecutiveLosses = g_stats.consecutiveLosses;
      }
      
      // Today stats
      MqlDateTime tm;
      TimeToStruct(dealTime, tm);
      
      datetime todayStart = StringToTime(IntegerToString(tm.year) + "." + 
                                          IntegerToString(tm.mon) + "." + 
                                          IntegerToString(tm.day));
      
      if(dealTime >= todayStart)
      {
         g_stats.todayPnL += netProfit;
      }
   }
   
   // Calculate derived stats
   g_stats.netProfit = g_stats.totalProfit - g_stats.totalLoss;
   g_stats.Calculate();
   
   // Check daily loss
   if(InpUseMaxLoss)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double maxLoss = balance * InpMaxDailyLossPercent / 100.0;
      
      if(g_stats.todayPnL <= -maxLoss)
      {
         g_dailyLossReached = true;
         Print("Max daily loss reached: ", g_stats.todayPnL);
      }
   }
   
   g_lastStatsUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Add Signal to History                                             |
//+------------------------------------------------------------------+
void AddSignalToHistory(STradeSignal &signal)
{
   // Shift history
   if(g_signalHistoryCount >= g_maxSignalHistory)
   {
      for(int i = 0; i < g_signalHistoryCount - 1; i++)
      {
         g_signalHistory[i] = g_signalHistory[i + 1];
      }
      g_signalHistoryCount = g_maxSignalHistory - 1;
   }
   
   // Add new entry
   if(g_signalHistoryCount < g_maxSignalHistory)
   {
      g_signalHistory[g_signalHistoryCount].time = signal.time;
      g_signalHistory[g_signalHistoryCount].type = signal.type;
      g_signalHistory[g_signalHistoryCount].trigger = signal.trigger;
      g_signalHistory[g_signalHistoryCount].price = signal.entryPrice;
      g_signalHistory[g_signalHistoryCount].score = 0;
      g_signalHistory[g_signalHistoryCount].pnl = 0; // Will be updated later
      g_signalHistory[g_signalHistoryCount].isWin = false;
      g_signalHistory[g_signalHistoryCount].description = GetSignalDescription();
      
      g_signalHistoryCount++;
   }
}

//+------------------------------------------------------------------+
//| Get Win Rate String                                               |
//+------------------------------------------------------------------+
string GetWinRateString()
{
   if(g_stats.totalTrades == 0)
      return "N/A";
   
   return DoubleToString(g_stats.winRate, 1) + "%";
}

//+------------------------------------------------------------------+
//| Get Profit Factor String                                          |
//+------------------------------------------------------------------+
string GetProfitFactorString()
{
   if(g_stats.totalLoss == 0)
      return g_stats.totalProfit > 0 ? "∞" : "0";
   
   return DoubleToString(g_stats.profitFactor, 2);
}

//+------------------------------------------------------------------+
//| Get Today PnL String                                              |
//+------------------------------------------------------------------+
string GetTodayPnLString()
{
   string prefix = g_stats.todayPnL >= 0 ? "+" : "";
   return prefix + DoubleToString(g_stats.todayPnL, 2);
}

//+------------------------------------------------------------------+
//| Get Stats Summary                                                 |
//+------------------------------------------------------------------+
string GetStatsSummary()
{
   string summary = "";
   
   summary += "Trades: " + IntegerToString(g_stats.totalTrades);
   summary += " | W/L: " + IntegerToString(g_stats.winTrades) + "/" + IntegerToString(g_stats.lossTrades);
   summary += " | WR: " + GetWinRateString();
   summary += " | PF: " + GetProfitFactorString();
   summary += " | P/L: " + DoubleToString(g_stats.netProfit, 2);
   
   return summary;
}

//+------------------------------------------------------------------+
//| Get Today Summary                                                 |
//+------------------------------------------------------------------+
string GetTodaySummary()
{
   string summary = "";
   
   summary += "Today: " + IntegerToString(g_stats.todayTrades) + " trades";
   summary += " | P/L: " + GetTodayPnLString();
   
   if(g_maxTradesReached)
      summary += " [MAX TRADES]";
   
   if(g_dailyLossReached)
      summary += " [MAX LOSS]";
   
   return summary;
}

//+------------------------------------------------------------------+
//| Get Position Summary                                              |
//+------------------------------------------------------------------+
string GetPositionSummary()
{
   int posCount = 0;
   double totalProfit = 0;
   double totalVolume = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            posCount++;
            totalProfit += PositionGetDouble(POSITION_PROFIT);
            totalVolume += PositionGetDouble(POSITION_VOLUME);
         }
      }
   }
   
   if(posCount == 0)
      return "No open positions";
   
   string dir = "";
   if(totalProfit >= 0)
      dir = "+";
   
   return IntegerToString(posCount) + " position(s) | " +
          DoubleToString(totalVolume, 2) + " lot | P/L: " + 
          dir + DoubleToString(totalProfit, 2);
}

//+------------------------------------------------------------------+
//|              SECTION 5: POSITION INFO                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Active Position Direction                                     |
//+------------------------------------------------------------------+
ENUM_TRADE_DIRECTION GetActivePositionDirection()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            return (posType == POSITION_TYPE_BUY) ? DIR_BULLISH : DIR_BEARISH;
         }
      }
   }
   
   return DIR_NONE;
}

//+------------------------------------------------------------------+
//| Get Active Position Profit                                        |
//+------------------------------------------------------------------+
double GetActivePositionProfit()
{
   double profit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   
   return profit;
}

//+------------------------------------------------------------------+
//| Get Active Position Volume                                        |
//+------------------------------------------------------------------+
double GetActivePositionVolume()
{
   double volume = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            volume += PositionGetDouble(POSITION_VOLUME);
         }
      }
   }
   
   return volume;
}

//+------------------------------------------------------------------+
//| Get Active Position SL                                            |
//+------------------------------------------------------------------+
double GetActivePositionSL()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return PositionGetDouble(POSITION_SL);
         }
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Active Position TP                                            |
//+------------------------------------------------------------------+
double GetActivePositionTP()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return PositionGetDouble(POSITION_TP);
         }
      }
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Count Open Positions                                              |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   
   return count;
}

#endif // ICT_TRADEMANAGER_MQH
