//+------------------------------------------------------------------+
//|                       ICT_Dashboard.mqh                           |
//|              Complete Unified Dashboard                            |
//|                    ICT Unified Professional EA v8.0                 |
//+------------------------------------------------------------------+
#ifndef ICT_DASHBOARD_MQH
#define ICT_DASHBOARD_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../Trading/ICT_SignalEngine.mqh"
#include "../Trading/ICT_TradeManager.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: DASHBOARD INITIALIZATION                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Dashboard                                              |
//+------------------------------------------------------------------+
bool InitializeDashboard()
  {
   if(InpDashboardMode == DASH_OFF)
      return true;

// Set dimensions based on mode
   switch(InpDashboardMode)
     {
      case DASH_FULL:
         g_dashWidth = 460;
         g_dashMainHeight = 350;
g_dashScoreHeight = 0;
         g_dashPDArrayHeight = 180;
         g_dashLevelsHeight = 160;
         g_dashSignalHeight = 140;
         g_dashStatsHeight = 120;
         g_dashSMHeight = 260;    // NEW
         break;

      case DASH_STANDARD:
         g_dashWidth = 340;
         g_dashMainHeight = 280;
g_dashScoreHeight = 0;
         g_dashPDArrayHeight = 0;
         g_dashLevelsHeight = 0;
         g_dashSignalHeight = 100;
         g_dashStatsHeight = 0;
         g_dashSMHeight = 260;    // NEW
         break;

      case DASH_COMPACT:
         g_dashWidth = 280;
         g_dashMainHeight = 200;
g_dashScoreHeight = 0;
         g_dashPDArrayHeight = 0;
         g_dashLevelsHeight = 0;
         g_dashSignalHeight = 0;
         g_dashStatsHeight = 80;
         g_dashSMHeight = 0;    // NEW
         break;

      case DASH_MINIMAL:
         g_dashWidth = 200;
         g_dashMainHeight = 100;
         g_dashSMHeight = 0;    // NEW
         break;
     }

   g_dashboardInitialized = true;
   Print("Dashboard initialized (Mode: ", DashModeToString(InpDashboardMode), ")");
   return true;
  }

//+------------------------------------------------------------------+
//| Create Dashboard                                                  |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   if(!g_dashboardInitialized || InpDashboardMode == DASH_OFF)
      return;

   CleanupDashboard();

   int x = InpDashboardX;
   int y = InpDashboardY;
   int lastH = 0;   // tracks height of the last-drawn panel

// ── 1. Main Panel (always) ──
   CreateMainPanel(x, y);
   lastH = g_dashMainHeight;


   if(InpDashboardMode == DASH_FULL)
     {
      // PD panel optional in FULL mode as informational only
      if(g_dashPDArrayHeight > 0)
        {
         y += lastH + g_dashPadding;
         CreatePDArrayPanel(x, y);
         lastH = g_dashPDArrayHeight;
        }

      // SM panel always primary engine panel
      if(InpSM_ShowOnDashboard && g_dashSMHeight > 0)
        {
         y += lastH + g_dashPadding;
         CreateSMPanel(x, y);
         lastH = g_dashSMHeight;
        }
      // ── 4. Levels Panel (always in full) ──
      if(g_dashLevelsHeight > 0)
        {
         y += lastH + g_dashPadding;
         CreateLevelsPanel(x, y);
         lastH = g_dashLevelsHeight;
        }

     }

// ── 6. Signal Panel ──
   if(g_dashSignalHeight > 0)
     {
      y += lastH + g_dashPadding;
      CreateSignalPanel(x, y);
      lastH = g_dashSignalHeight;
     }

// ── 7. Stats Panel ──
   if(g_dashStatsHeight > 0)
     {
      y += lastH + g_dashPadding;
      CreateStatsPanel(x, y);
      lastH = g_dashStatsHeight;
     }
  }
//+------------------------------------------------------------------+
//|              SECTION 2: PANEL CREATION                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Main Panel                                                 |
//+------------------------------------------------------------------+
void CreateMainPanel(int x, int y)
  {
   string prefix = g_dashPrefix + "Main_";

// Background
   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashMainHeight,
              g_bgColor, true);

// Border
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashMainHeight,
              g_borderColor, false);

// Title
   int titleY = y + 10;
   CreateLabel(prefix + "Title", "🎯 ICT UNIFIED ENGINE v8.0", x + g_dashWidth / 2, titleY,
               g_textColorBright, 11, ANCHOR_CENTER, "Arial Bold");

// Status line
   int statusY = titleY + 20;
   string status = g_isInitialized ? "● ACTIVE" : "○ INITIALIZING...";
   color statusColor = g_isInitialized ? g_successColor : g_warningColor;
   CreateLabel(prefix + "Status", status, x + g_dashWidth / 2, statusY,
               statusColor, 9, ANCHOR_CENTER, "Arial Bold");

// Direction section
   int dirY = statusY + 25;
   CreateSectionHeader(prefix + "DirHeader", "DIRECTION", x, dirY);

// Direction indicator
   int dirValY = dirY + 18;
   string dirText = DirectionToString(g_currentDirection);
   color dirColor = DirectionToColor(g_currentDirection);

// Direction with box
   CreateRect(prefix + "DirBox", x + 15, dirValY - 5, x + g_dashWidth - 15, dirValY + 20,
              ColorDarken(dirColor, 50), true);
   CreateLabel(prefix + "DirValue", dirText, x + g_dashWidth / 2, dirValY + 5,
               dirColor, 12, ANCHOR_CENTER, "Arial Bold");

// TF Alignment section
   int tfY = dirValY + 35;
   CreateSectionHeader(prefix + "TFHeader", "TIMEFRAME ALIGNMENT", x, tfY);

   int tfValY = tfY + 18;

// HTF
   string htfStatus = g_htfDirection != DIR_NONE ? "✓" : "○";
   color htfColor = g_htfDirection != DIR_NONE ? g_successColor : g_textColorDim;
   CreateLabel(prefix + "HTF", "HTF: " + htfStatus + " " + DirectionToString(g_htfDirection),
               x + 20, tfValY, htfColor, 9, ANCHOR_LEFT);

// CTF
   string ctfStatus = g_ctfDirection != DIR_NONE ? "✓" : "○";
   color ctfColor = g_ctfDirection != DIR_NONE ? g_successColor : g_textColorDim;
   CreateLabel(prefix + "CTF", "CTF: " + ctfStatus + " " + DirectionToString(g_ctfDirection),
               x + 130, tfValY, ctfColor, 9, ANCHOR_LEFT);

// LTF
   string ltfStatus = g_ltfDirection != DIR_NONE ? "✓" : "○";
   color ltfColor = g_ltfDirection != DIR_NONE ? g_successColor : g_textColorDim;
   CreateLabel(prefix + "LTF", "LTF: " + ltfStatus + " " + DirectionToString(g_ltfDirection),
               x + 240, tfValY, ltfColor, 9, ANCHOR_LEFT);

// Alignment status
   int alignY = tfValY + 18;
   string alignText = "";
   if(g_allTFsAligned)
      alignText = "✓ ALL TFs ALIGNED (+25 bonus)";
   else
      if(g_htfCtfAligned)
         alignText = "✓ HTF+CTF Aligned (+20 bonus)";
      else
         alignText = "○ No alignment";

   color alignColor = (g_allTFsAligned || g_htfCtfAligned) ? g_accentCyan : g_textColorDim;
   CreateLabel(prefix + "Align", alignText, x + g_dashWidth / 2, alignY,
               alignColor, 8, ANCHOR_CENTER);

// Killzone section
   int kzY = alignY + 25;
   CreateSectionHeader(prefix + "KZHeader", "CURRENT SESSION", x, kzY);

   int kzValY = kzY + 18;
   string kzText = GetKillzoneDescription();
   color kzColor = g_killzone.isActive ? g_accentGold : g_textColorDim;
   CreateLabel(prefix + "KZValue", kzText, x + g_dashWidth / 2, kzValY,
               kzColor, 9, ANCHOR_CENTER);

// AMD Phase
   if(InpDetectAMD && InpDashboardMode == DASH_FULL)
     {
      int amdY = kzValY + 22;
      string amdText = GetPhaseDescription();
      CreateLabel(prefix + "AMD", "Phase: " + amdText, x + g_dashWidth / 2, amdY,
                  g_accentPurple, 9, ANCHOR_CENTER);
     }
// Framework / SM info (bottom of main panel)
   int smY = kzValY + 40;
   string fwText = "Engine: StateMachine";
if(InpSM_ShowOnDashboard)
     {
      fwText += " | Preset: " + EnumToString(InpSM_Preset);

      // Count active SM instances
      int activeInst = 0;
      for(int si = 0; si < SM_MAX_INSTANCES; si++)
         if(g_smInstances[si].active)
            activeInst++;

      fwText += " | Chains: " + IntegerToString(activeInst);
     }
   CreateLabel(prefix + "SMInfo", fwText, x + g_dashWidth / 2, smY,
               g_textColorDim, 8, ANCHOR_CENTER);
  }



//+------------------------------------------------------------------+
//| Create PD Array Panel                                             |
//+------------------------------------------------------------------+
void CreatePDArrayPanel(int x, int y)
  {
   string prefix = g_dashPrefix + "PD_";

// Background
   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashPDArrayHeight,
              g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashPDArrayHeight,
              g_borderColor, false);

// Header
   CreateLabel(prefix + "Header", "📍 PD ARRAYS IN ZONE", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

// PD Array summary
   int arrY = y + 35;
   string pdSummary = GetEntryZonePDArraySummary();
   CreateLabel(prefix + "Summary", pdSummary, x + g_dashWidth / 2, arrY,
               g_textColor, 8, ANCHOR_CENTER);

// PD Stats
   arrY += 20;
   string pdStats = GetPDArrayStats();
   CreateLabel(prefix + "Stats", pdStats, x + g_dashWidth / 2, arrY,
               g_textColorDim, 8, ANCHOR_CENTER);

// Stacking info
   arrY += 20;
   int bestStack = GetBestStack(g_isBullishActive);
   if(bestStack >= 0)
     {
      string stackInfo = "Best Stack: x" + IntegerToString(g_pdStacks[bestStack].stackCount) +
                         " (" + GetStackDescription(bestStack) + ")";
      CreateLabel(prefix + "Stack", stackInfo, x + g_dashWidth / 2, arrY,
                  g_accentGold, 9, ANCHOR_CENTER);
     }

// OTE Zone
   arrY += 25;
   if(g_oteZone.isValid)
     {
      string oteInfo = "OTE Zone: " + DoubleToString(g_oteZone.ZoneBottom(), _Digits) +
                       " - " + DoubleToString(g_oteZone.ZoneTop(), _Digits);
      color oteColor = IsPriceInOTEZone() ? g_successColor : g_textColorDim;
      CreateLabel(prefix + "OTE", oteInfo, x + g_dashWidth / 2, arrY,
                  oteColor, 8, ANCHOR_CENTER);
     }

// Premium/Discount
   arrY += 20;
   if(InpUsePremiumDiscount)
     {
      string zoneInfo = "Zone: " + ZoneToString(g_rangeInfo.currentZone) +
                        " | Eq: " + DoubleToString(g_rangeInfo.equilibrium, _Digits);
      CreateLabel(prefix + "Zone", zoneInfo, x + g_dashWidth / 2, arrY,
                  g_textColorDim, 8, ANCHOR_CENTER);
     }
  }

//+------------------------------------------------------------------+
//| Create Levels Panel                                               |
//+------------------------------------------------------------------+
void CreateLevelsPanel(int x, int y)
  {
   string prefix = g_dashPrefix + "Levels_";

// Background
   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashLevelsHeight,
              g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashLevelsHeight,
              g_borderColor, false);

// Header
   CreateLabel(prefix + "Header", "📐 KEY LEVELS", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

   int levelY = y + 35;
   int lineHeight = 16;

// Get DR
   SDealingRange* dr = g_isBullishActive ? &g_bullDR : &g_bearDR;

// CL Level
   if(dr.corrLine.isActive)
     {
      string clText = "CL: " + DoubleToString(dr.corrLine.extremePrice, _Digits);
      CreateLabel(prefix + "CL", clText, x + 20, levelY, g_bullColor, 8, ANCHOR_LEFT);
      levelY += lineHeight;
     }

// Origin (ChoCh)
   for(int i = 0; i < dr.originCount && i < 2; i++)
     {
      if(dr.origins[i].role == ROLE_CHOCH)
        {
         string originText = "Origin ★: " + DoubleToString(dr.origins[i].price, _Digits);
         CreateLabel(prefix + "Origin", originText, x + 20, levelY,
                     InpOriginChochColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;
        }
     }

// Target
   for(int i = 0; i < dr.originCount && i < 2; i++)
     {
      if(dr.origins[i].role == ROLE_TARGET)
        {
         string targetText = "Target: " + DoubleToString(dr.origins[i].price, _Digits);
         CreateLabel(prefix + "Target", targetText, x + 20, levelY,
                     InpOriginTargetColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;
        }
     }

// External Inducements
   if(dr.externalCount > 0)
     {
      string extText = "Ext.IDMT: " + DoubleToString(dr.externals[0].price, _Digits);
      if(dr.externalCount > 1)
         extText += " (+" + IntegerToString(dr.externalCount - 1) + " more)";
      CreateLabel(prefix + "Ext", extText, x + 20, levelY,
                  InpExtInducementColor, 8, ANCHOR_LEFT);
      levelY += lineHeight;
     }
// ── PULLBACK SUB-STRUCTURE STATUS (NEW) ──────────────────────────
   if(InpDetectPullbackStructure)
     {
      bool pbBull = !g_isBullishActive;
      string pbDir = pbBull ? "Bull" : "Bear";

      if(dr.pullback.confirmed)
        {
         // PB Active header
         string pbHead = "\x25B6 PB." + pbDir + " Active";
         CreateLabel(prefix + "PB_Head", pbHead, x + 20, levelY,
                     InpPullbackOriginColor, 8, ANCHOR_LEFT, "Arial Bold");
         levelY += lineHeight;

         // PB Origin
         string pbOrgText = "  PB Origin \x2605: " +
                            DoubleToString(dr.pullback.originPrice, _Digits);
         CreateLabel(prefix + "PB_Org", pbOrgText, x + 20, levelY,
                     InpPullbackOriginColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;

         // PB CL
         string pbCLText = "  PB CL: " +
                           DoubleToString(dr.pullback.clPrice, _Digits);
         CreateLabel(prefix + "PB_CL", pbCLText, x + 20, levelY,
                     InpPullbackCLColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;

         // Counter levels remaining
         int activeCnt = 0;
         for(int c = 0; c < dr.pullback.counterCount; c++)
            if(!dr.pullback.counters[c].isConsumed)
               activeCnt++;
         if(activeCnt > 0)
           {
            string cntText = "  PB Counters: " + IntegerToString(activeCnt);
            CreateLabel(prefix + "PB_Cnt", cntText, x + 20, levelY,
                        InpPullbackCounterColor, 8, ANCHOR_LEFT);
            levelY += lineHeight;
           }
        }
      else
         if(dr.pullback.sweepPending)
           {
            string pbSwText = "\x25CB PB." + pbDir + " Sweep @ " +
                              DoubleToString(dr.pullback.sweepExtreme, _Digits);
            CreateLabel(prefix + "PB_Head", pbSwText, x + 20, levelY,
                        g_warningColor, 8, ANCHOR_LEFT);
            levelY += lineHeight;
           }
         else
            if(dr.pullback.counterCount > 0)
              {
               int activeCnt = 0;
               for(int c = 0; c < dr.pullback.counterCount; c++)
                  if(!dr.pullback.counters[c].isConsumed)
                     activeCnt++;
               if(activeCnt > 0)
                 {
                  string pbTrkText = "\x25CB PB." + pbDir + " Tracking (" +
                                     IntegerToString(activeCnt) + " cnt)";
                  CreateLabel(prefix + "PB_Head", pbTrkText, x + 20, levelY,
                              g_textColorDim, 8, ANCHOR_LEFT);
                  levelY += lineHeight;
                 }
              }
     }
// ── END PULLBACK STATUS ──────────────────────────────────────────

// Last Swing Points
   if(g_lastExternalHigh > 0)
     {
      string highText = "Swing High: " + DoubleToString(g_lastExternalHigh, _Digits);
      CreateLabel(prefix + "High", highText, x + 20, levelY, g_bearColor, 8, ANCHOR_LEFT);
      levelY += lineHeight;
     }

   if(g_lastExternalLow > 0)
     {
      string lowText = "Swing Low: " + DoubleToString(g_lastExternalLow, _Digits);
      CreateLabel(prefix + "Low", lowText, x + 20, levelY, g_bullColor, 8, ANCHOR_LEFT);
     }
  }

//+------------------------------------------------------------------+
//| Create Signal Panel                                               |
//+------------------------------------------------------------------+
void CreateSignalPanel(int x, int y)
  {
   string prefix = g_dashPrefix + "Signal_";

// Background
   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashSignalHeight,
              g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashSignalHeight,
              g_borderColor, false);

// Header
   CreateLabel(prefix + "Header", "⚡ SIGNAL STATUS", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

   int sigY = y + 35;

// Check for active position
   ENUM_TRADE_DIRECTION posDir = GetActivePositionDirection();

   if(posDir != DIR_NONE)
     {
      // Show active position
      string posText = (posDir == DIR_BULLISH ? "BUY" : "SELL") +
                       " " + DoubleToString(GetActivePositionVolume(), 2) + " lot";
      CreateLabel(prefix + "Pos", posText, x + 20, sigY, g_successColor, 10, ANCHOR_LEFT);

      sigY += 20;
      string pnlText = "P/L: " + DoubleToString(GetActivePositionProfit(), 2);
      color pnlColor = GetActivePositionProfit() >= 0 ? g_bullColor : g_bearColor;
      CreateLabel(prefix + "PnL", pnlText, x + 20, sigY, pnlColor, 10, ANCHOR_LEFT);

      sigY += 20;
      string sltpText = "SL: " + DoubleToString(GetActivePositionSL(), _Digits) +
                        " | TP: " + DoubleToString(GetActivePositionTP(), _Digits);
      CreateLabel(prefix + "SLTP", sltpText, x + 20, sigY, g_textColorDim, 8, ANCHOR_LEFT);
     }
   else
      if(g_hasValidSignal)
        {
         // Show pending signal
         string sigText = "PENDING: " + GetSignalDescription();
         CreateLabel(prefix + "Pending", sigText, x + 20, sigY, g_accentCyan, 9, ANCHOR_LEFT);

         sigY += 25;
         string entryText = "Entry: " + DoubleToString(g_currentSignal.entryPrice, _Digits) +
                            " | RR: " + DoubleToString(g_currentSignal.riskReward, 1);
         CreateLabel(prefix + "Entry", entryText, x + 20, sigY, g_textColor, 8, ANCHOR_LEFT);

         sigY += 18;
         string slText = "SL: " + DoubleToString(g_currentSignal.slPrice, _Digits);
         CreateLabel(prefix + "SL", slText, x + 20, sigY, g_bearColor, 8, ANCHOR_LEFT);

         string tpText = "TP1: " + DoubleToString(g_currentSignal.tp1Price, _Digits);
         CreateLabel(prefix + "TP1", tpText, x + 150, sigY, g_bullColor, 8, ANCHOR_LEFT);
        }
      else
         if(g_waitingForOTE)
           {
            CreateLabel(prefix + "Wait", "⏳ Waiting for OTE Zone...", x + g_dashWidth / 2, sigY,
                        g_warningColor, 10, ANCHOR_CENTER);
           }
         else
           {
            CreateLabel(prefix + "None", "○ No Active Signal", x + g_dashWidth / 2, sigY,
                        g_textColorDim, 10, ANCHOR_CENTER);

            sigY += 25;
            string reason = GetNoSignalReason();
            CreateLabel(prefix + "Reason", reason, x + g_dashWidth / 2, sigY,
                        g_textColorDim, 8, ANCHOR_CENTER);
           }
  }

//+------------------------------------------------------------------+
//| Create Stats Panel                                                |
//+------------------------------------------------------------------+
void CreateStatsPanel(int x, int y)
  {
   string prefix = g_dashPrefix + "Stats_";

// Background
   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashStatsHeight,
              g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashStatsHeight,
              g_borderColor, false);

// Header
   CreateLabel(prefix + "Header", "📈 STATISTICS", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

   int statY = y + 35;

// Today stats
   string todayText = "Today: " + IntegerToString(g_stats.todayTrades) + " trades | P/L: " +
                      GetTodayPnLString();
   CreateLabel(prefix + "Today", todayText, x + 20, statY, g_textColor, 9, ANCHOR_LEFT);

   statY += 18;

// Overall stats
   string overallText = "Total: " + IntegerToString(g_stats.totalTrades) +
                        " | W/L: " + IntegerToString(g_stats.winTrades) + "/" +
                        IntegerToString(g_stats.lossTrades) +
                        " | WR: " + GetWinRateString();
   CreateLabel(prefix + "Overall", overallText, x + 20, statY, g_textColorDim, 8, ANCHOR_LEFT);

   statY += 16;

// Profit Factor
   string pfText = "PF: " + GetProfitFactorString() +
                   " | Net: " + DoubleToString(g_stats.netProfit, 2);
   CreateLabel(prefix + "PF", pfText, x + 20, statY, g_textColorDim, 8, ANCHOR_LEFT);
  }
//+------------------------------------------------------------------+
//| New - Create State Machine Panel                                        |
//+------------------------------------------------------------------+
void CreateSMPanel(int x, int y)
  {

   string px = g_dashPrefix + "SM_";

   CreateRect(px+"BG", x, y, x+g_dashWidth, y+g_dashSMHeight, g_bgColor, true);
   CreateRect(px+"Bdr", x, y, x+g_dashWidth, y+g_dashSMHeight, g_borderColor, false);

   int cy = y + 8;
   int lx = x + 15;

//────────────────────────────────────────
// HEADER
//────────────────────────────────────────
   CreateLabel(px+"Hdr", "STATE MACHINE ENGINE", x+g_dashWidth/2, cy,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");
   cy += 18;

//────────────────────────────────────────
// ENGINE STATUS
//────────────────────────────────────────
   int activeN = SM_CountActiveInstances();
   string line1 = "Preset: " + EnumToString(InpSM_Preset)
                  + " | Policy: "
                  + (InpSM_InstancePolicy == SM_INSTANCE_COEXIST ? "Coexist" : "Replace");

   string line2 = "Chains: " + IntegerToString(activeN)
                  + "/" + IntegerToString(InpSM_MaxInstances)
                  + " | Timeout: " + IntegerToString(InpSM_GlobalTimeout) + "b"
                  + " | SMBar#: " + IntegerToString(g_smBarCounter);

   CreateLabel(px+"Mode1", line1, lx, cy, g_textColorDim, 8, ANCHOR_LEFT);
   cy += 13;
   CreateLabel(px+"Mode2", line2, lx, cy, g_textColorDim, 8, ANCHOR_LEFT);
   cy += 18;

//────────────────────────────────────────
// STAGE CONFIGURATION
//────────────────────────────────────────
   CreateLabel(px+"CFG", "-- STAGE CONFIG --",
               x+g_dashWidth/2, cy, g_textColorDim, 7, ANCHOR_CENTER);
   cy += 13;

   for(int s=0; s<SM_MAX_STAGES; s++)
     {
      string cfgLine = SM_StageConfigLine(s);
      CreateLabel(px+"SC"+IntegerToString(s),
                  cfgLine, lx, cy, g_textColor, 8, ANCHOR_LEFT);
      cy += 13;
     }
   cy += 5;

//────────────────────────────────────────
// ACTIVE CHAINS
//────────────────────────────────────────
   CreateLabel(px+"AC", "-- ACTIVE CHAINS --",
               x+g_dashWidth/2, cy, g_textColorDim, 7, ANCHOR_CENTER);
   cy += 13;

   if(activeN == 0)
     {
      CreateLabel(px+"NoC", "No active chains",
                  x+g_dashWidth/2, cy, g_textColorDim, 8, ANCHOR_CENTER);
      cy += 14;
     }
   else
     {
      int shown=0;
      for(int i=0;i<SM_MAX_INSTANCES && shown<4;i++)
        {
         if(!g_smInstances[i].active)
            continue;
         string instLine = SM_InstanceStatusLine(i);
         color instClr = DirectionToColor(g_smInstances[i].direction);
         CreateLabel(px+"I"+IntegerToString(shown),
                     instLine, lx, cy, instClr, 8, ANCHOR_LEFT);
         cy+=13;
         shown++;
        }
     }
   cy+=5;

//────────────────────────────────────────
// LAST STRUCTURAL EVENT
//────────────────────────────────────────
   CreateLabel(px+"EVH", "-- LAST EVENT --",
               x+g_dashWidth/2, cy, g_textColorDim, 7, ANCHOR_CENTER);
   cy+=13;

   string evtLine;
   if(g_lastSMEvent.valid)
     {
      string tfName = (g_lastSMEvent.tfLayer==LAYER_HTF?"HTF":
                       (g_lastSMEvent.tfLayer==LAYER_LTF?"LTF":"CTF"));
      string dirName = (g_lastSMEvent.direction==DIR_BULLISH?"BULL":"BEAR");
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;

      evtLine = tfName + " | " + dirName
                + " | Price: " + DoubleToString(g_lastSMEvent.price,_Digits)
                + " | Tag: " + IntegerToString(g_lastSMEvent.tag)
                + " | Age: " + IntegerToString(evAge) + "b";
     }
   else
      evtLine = "No structural event yet";

   CreateLabel(px+"EVL", evtLine, lx, cy, g_accentGold, 8, ANCHOR_LEFT);
  }

//+------------------------------------------------------------------+
//|              SECTION 3: DASHBOARD UPDATE                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Dashboard                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   if(!g_dashboardInitialized || InpDashboardMode == DASH_OFF)
      return;

// Recreate dashboard (simpler than tracking individual updates)
   CreateDashboard();

   g_lastDashboardUpdate = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Update Dashboard Realtime                                         |
//+------------------------------------------------------------------+
void UpdateDashboardRealtime()
  {
   if(!g_dashboardInitialized || InpDashboardMode == DASH_OFF)
      return;

// Update only critical realtime elements
   UpdateRealtimeElements();
  }

//+------------------------------------------------------------------+
//| Update Realtime Elements                                          |
//+------------------------------------------------------------------+
void UpdateRealtimeElements()
  {
   string prefix = g_dashPrefix;

// Update P/L display
   double profit = GetActivePositionProfit();
   string pnlText = "P/L: " + DoubleToString(profit, 2);
   color pnlColor = profit >= 0 ? g_bullColor : g_bearColor;

// Find and update P/L label
   string pnlName = prefix + "Signal_PnL";
   if(ObjectFind(0, pnlName) >= 0)
     {
      ObjectSetString(0, pnlName, OBJPROP_TEXT, pnlText);
      ObjectSetInteger(0, pnlName, OBJPROP_COLOR, pnlColor);
     }
  }

//+------------------------------------------------------------------+
//| Cleanup Dashboard                                                 |
//+------------------------------------------------------------------+
void CleanupDashboard()
  {
   CleanupObjectsWithPrefix(g_dashPrefix);
  }

//+------------------------------------------------------------------+
//|              SECTION 4: UI HELPERS                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Label                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr,
                 int fontSize = 9, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT,
                 string font = "Arial")
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
     }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Create Rectangle                                                  |
//+------------------------------------------------------------------+
void CreateRect(string name, int x1, int y1, int x2, int y2,
                color clr, bool fill = true)
  {
// Convert screen coordinates to time/price for rectangle
// For dashboard, we use relative positioning

   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
     }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, x2 - x1);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, y2 - y1);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, fill ? BORDER_FLAT : BORDER_RAISED);
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);

   if(!fill)
     {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
     }
  }
//+------------------------------------------------------------------+
//| Create Section Header                                             |
//+------------------------------------------------------------------+
void CreateSectionHeader(string name, string text, int x, int y)
  {
   CreateLabel(name, "── " + text + " ──", x + g_dashWidth / 2, y,
               g_textColorDim, 8, ANCHOR_CENTER);
  }


//+------------------------------------------------------------------+
//| Handle Chart Event                                                |
//+------------------------------------------------------------------+
void HandleChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
  {
// Handle button clicks or other interactions if needed
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // Handle dashboard button clicks
      // Not implemented in this version
     }
  }

//+------------------------------------------------------------------+
//|              SECTION 5: HELPER FUNCTIONS                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get No Signal Reason                                              |
//+------------------------------------------------------------------+
string GetNoSignalReason()
{
   if(InpEnableTrading)
   {
      string r = "";
      if(!IsNarrativeTradable(g_currentDirection, r))
         return "Narrative gate: " + r;
   }

   if(g_maxTradesReached)
      return "Max trades reached";

   if(g_dailyLossReached)
      return "Daily loss limit";

   if(!g_killzone.isActive && InpUseKillzoneFilter)
      return "Outside killzone";

   return "Conditions not met";
}

//+------------------------------------------------------------------+
//| Enum to String                                                    |
//+------------------------------------------------------------------+
string DashModeToString(ENUM_DASHBOARD_MODE mode)
  {
   switch(mode)
     {
      case DASH_FULL:
         return "Full";
      case DASH_STANDARD:
         return "Standard";
      case DASH_COMPACT:
         return "Compact";
      case DASH_MINIMAL:
         return "Minimal";
      case DASH_OFF:
         return "Off";
      default:
         return "Unknown";
     }
  }




#endif // ICT_DASHBOARD_MQH
