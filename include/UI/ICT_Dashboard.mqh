//+------------------------------------------------------------------+
//|                       ICT_Dashboard.mqh                           |
//|              Complete Unified Dashboard                           |
//|                    ICT Unified Professional EA v9.0              |
//+------------------------------------------------------------------+
#ifndef ICT_DASHBOARD_MQH
#define ICT_DASHBOARD_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../Trading/ICT_SignalEngine.mqh"
#include "../Trading/ICT_TradeManager.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: DASHBOARD INITIALIZATION                  |
//+------------------------------------------------------------------+
bool InitializeDashboard()
{
   if(InpDashboardMode == DASH_OFF)
      return true;

   switch(InpDashboardMode)
   {
      case DASH_FULL:
         g_dashWidth = 460;
         g_dashMainHeight = 350;
         g_dashScoreHeight = 0;
         g_dashNarrativeHeight = 180;
         g_dashLevelsHeight = 160;
         g_dashSignalHeight = 140;
         g_dashStatsHeight = 120;
         g_dashSMHeight = 260;
         break;

      case DASH_STANDARD:
         g_dashWidth = 340;
         g_dashMainHeight = 280;
         g_dashScoreHeight = 0;
         g_dashNarrativeHeight = 0;
         g_dashLevelsHeight = 0;
         g_dashSignalHeight = 100;
         g_dashStatsHeight = 0;
         g_dashSMHeight = 260;
         break;

      case DASH_COMPACT:
         g_dashWidth = 280;
         g_dashMainHeight = 200;
         g_dashScoreHeight = 0;
         g_dashNarrativeHeight = 0;
         g_dashLevelsHeight = 0;
         g_dashSignalHeight = 0;
         g_dashStatsHeight = 80;
         g_dashSMHeight = 0;
         break;

      case DASH_MINIMAL:
         g_dashWidth = 200;
         g_dashMainHeight = 100;
         g_dashSMHeight = 0;
         break;

      default:
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
   int lastH = 0;

   // 1) Main panel
   CreateMainPanel(x, y);
   lastH = g_dashMainHeight;

   if(InpDashboardMode == DASH_FULL)
   {
      // 2) Narrative panel (legacy function name kept for compatibility)
      if(g_dashNarrativeHeight > 0)
      {
         y += lastH + g_dashPadding;
         CreateNarrativeArrayPanel(x, y);
         lastH = g_dashNarrativeHeight;
      }

      // 3) SM panel
      if(InpSM_ShowOnDashboard && g_dashSMHeight > 0)
      {
         y += lastH + g_dashPadding;
         CreateSMPanel(x, y);
         lastH = g_dashSMHeight;
      }

      // 4) Levels panel
      if(g_dashLevelsHeight > 0)
      {
         y += lastH + g_dashPadding;
         CreateLevelsPanel(x, y);
         lastH = g_dashLevelsHeight;
      }
   }

   // 5) Signal panel
   if(g_dashSignalHeight > 0)
   {
      y += lastH + g_dashPadding;
      CreateSignalPanel(x, y);
      lastH = g_dashSignalHeight;
   }

   // 6) Stats panel
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
void CreateMainPanel(int x, int y)
{
   string prefix = g_dashPrefix + "Main_";

   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashMainHeight, g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashMainHeight, g_borderColor, false);

   int titleY = y + 10;
   CreateLabel(prefix + "Title", "ICT UNIFIED ENGINE v9.0", x + g_dashWidth / 2, titleY,
               g_textColorBright, 11, ANCHOR_CENTER, "Arial Bold");

   int statusY = titleY + 20;
   string status = g_isInitialized ? "ACTIVE" : "INITIALIZING";
   color statusColor = g_isInitialized ? g_successColor : g_warningColor;
   CreateLabel(prefix + "Status", status, x + g_dashWidth / 2, statusY,
               statusColor, 9, ANCHOR_CENTER, "Arial Bold");

   int dirY = statusY + 25;
   CreateSectionHeader(prefix + "DirHeader", "DIRECTION", x, dirY);

   int dirValY = dirY + 18;
   string dirText = DirectionToString(g_currentDirection);
   color dirColor = DirectionToColor(g_currentDirection);

   CreateRect(prefix + "DirBox", x + 15, dirValY - 5, x + g_dashWidth - 15, dirValY + 20,
              ColorDarken(dirColor, 50), true);
   CreateLabel(prefix + "DirValue", dirText, x + g_dashWidth / 2, dirValY + 5,
               dirColor, 12, ANCHOR_CENTER, "Arial Bold");

   int tfY = dirValY + 35;
   CreateSectionHeader(prefix + "TFHeader", "TIMEFRAME ALIGNMENT", x, tfY);

   int tfValY = tfY + 18;

   string htfStatus = g_htfDirection != DIR_NONE ? "Y" : "N";
   color htfColor = g_htfDirection != DIR_NONE ? g_successColor : g_textColorDim;
   CreateLabel(prefix + "HTF", "HTF: " + htfStatus + " " + DirectionToString(g_htfDirection),
               x + 20, tfValY, htfColor, 9, ANCHOR_LEFT);

   string ctfStatus = g_ctfDirection != DIR_NONE ? "Y" : "N";
   color ctfColor = g_ctfDirection != DIR_NONE ? g_successColor : g_textColorDim;
   CreateLabel(prefix + "CTF", "CTF: " + ctfStatus + " " + DirectionToString(g_ctfDirection),
               x + 130, tfValY, ctfColor, 9, ANCHOR_LEFT);

   string ltfStatus = g_ltfDirection != DIR_NONE ? "Y" : "N";
   color ltfColor = g_ltfDirection != DIR_NONE ? g_successColor : g_textColorDim;
   CreateLabel(prefix + "LTF", "LTF: " + ltfStatus + " " + DirectionToString(g_ltfDirection),
               x + 240, tfValY, ltfColor, 9, ANCHOR_LEFT);

   int alignY = tfValY + 18;
   string alignText = "";
   if(g_allTFsAligned)
      alignText = "ALL TFs ALIGNED";
   else if(g_htfCtfAligned)
      alignText = "HTF + CTF ALIGNED";
   else
      alignText = "NO TF ALIGNMENT";

   color alignColor = (g_allTFsAligned || g_htfCtfAligned) ? g_accentCyan : g_textColorDim;
   CreateLabel(prefix + "Align", alignText, x + g_dashWidth / 2, alignY, alignColor, 8, ANCHOR_CENTER);

   int kzY = alignY + 25;
   CreateSectionHeader(prefix + "KZHeader", "CURRENT SESSION", x, kzY);

   int kzValY = kzY + 18;
   string kzText = GetKillzoneDescription();
   color kzColor = g_killzone.isActive ? g_accentGold : g_textColorDim;
   CreateLabel(prefix + "KZValue", kzText, x + g_dashWidth / 2, kzValY, kzColor, 9, ANCHOR_CENTER);

   if(g_needDetectAMD && InpDashboardMode == DASH_FULL)
   {
      int amdY = kzValY + 22;
      string amdText = GetPhaseDescription();
      CreateLabel(prefix + "AMD", "Phase: " + amdText, x + g_dashWidth / 2, amdY,
                  g_accentPurple, 9, ANCHOR_CENTER);
   }

   int smY = kzValY + 40;
   string fwText = "Engine: StateMachine";

   if(InpSM_ShowOnDashboard)
   {
      fwText += " | Preset: " + EnumToString(InpSM_Preset);

      int activeInst = 0;
      for(int si = 0; si < SM_MAX_INSTANCES; si++)
         if(g_smInstances[si].active)
            activeInst++;

      fwText += " | Chains: " + IntegerToString(activeInst);
   }

   CreateLabel(prefix + "SMInfo", fwText, x + g_dashWidth / 2, smY, g_textColorDim, 8, ANCHOR_CENTER);
}

//+------------------------------------------------------------------+
//| Legacy name kept: now Narrative panel                             |
//+------------------------------------------------------------------+
void CreateNarrativeArrayPanel(int x, int y)
{
   string prefix = g_dashPrefix + "NZ_";

   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashNarrativeHeight, g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashNarrativeHeight, g_borderColor, false);

   CreateLabel(prefix + "Header", "NARRATIVE ZONES", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

   int arrY = y + 35;

   string summary = GetEntryZoneNarrativeSummary();
   CreateLabel(prefix + "Summary", summary, x + g_dashWidth / 2, arrY, g_textColor, 8, ANCHOR_CENTER);

   arrY += 20;
   string stats = GetNarrativeStats();
   CreateLabel(prefix + "Stats", stats, x + g_dashWidth / 2, arrY, g_textColorDim, 8, ANCHOR_CENTER);

   arrY += 22;
   if(g_oteZone.isValid)
   {
      string oteInfo = "OTE: " + DoubleToString(g_oteZone.ZoneBottom(), _Digits) +
                       " - " + DoubleToString(g_oteZone.ZoneTop(), _Digits);
      color oteColor = IsPriceInOTEZone() ? g_successColor : g_textColorDim;
      CreateLabel(prefix + "OTE", oteInfo, x + g_dashWidth / 2, arrY, oteColor, 8, ANCHOR_CENTER);
   }
   else
   {
      CreateLabel(prefix + "OTE", "OTE: not active", x + g_dashWidth / 2, arrY, g_textColorDim, 8, ANCHOR_CENTER);
   }

   arrY += 20;
   string zoneInfo = "Price Zone: " + ZoneToString(g_rangeInfo.currentZone);
   CreateLabel(prefix + "Zone", zoneInfo, x + g_dashWidth / 2, arrY, g_textColorDim, 8, ANCHOR_CENTER);
}

void CreateLevelsPanel(int x, int y)
{
   string prefix = g_dashPrefix + "Levels_";

   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashLevelsHeight, g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashLevelsHeight, g_borderColor, false);

   CreateLabel(prefix + "Header", "KEY LEVELS", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

   int levelY = y + 35;
   int lineHeight = 16;

   SDealingRange* dr = g_isBullishActive ? &g_bullDR : &g_bearDR;

   if(dr.corrLine.isActive)
   {
      string clText = "CL: " + DoubleToString(dr.corrLine.extremePrice, _Digits);
      CreateLabel(prefix + "CL", clText, x + 20, levelY, g_bullColor, 8, ANCHOR_LEFT);
      levelY += lineHeight;
   }

   for(int i = 0; i < dr.originCount && i < 2; i++)
   {
      if(dr.origins[i].role == ROLE_CHOCH)
      {
         string originText = "Origin: " + DoubleToString(dr.origins[i].price, _Digits);
         CreateLabel(prefix + "Origin", originText, x + 20, levelY, InpOriginChochColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;
      }
   }

   for(int j = 0; j < dr.originCount && j < 2; j++)
   {
      if(dr.origins[j].role == ROLE_TARGET)
      {
         string targetText = "Target: " + DoubleToString(dr.origins[j].price, _Digits);
         CreateLabel(prefix + "Target", targetText, x + 20, levelY, InpOriginTargetColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;
      }
   }

   if(dr.externalCount > 0)
   {
      string extText = "Ext.IDMT: " + DoubleToString(dr.externals[0].price, _Digits);
      if(dr.externalCount > 1)
         extText += " (+" + IntegerToString(dr.externalCount - 1) + " more)";
      CreateLabel(prefix + "Ext", extText, x + 20, levelY, InpExtInducementColor, 8, ANCHOR_LEFT);
      levelY += lineHeight;
   }

   if(InpDetectPullbackStructure)
   {
      bool pbBull = !g_isBullishActive;
      string pbDir = pbBull ? "Bull" : "Bear";

      if(dr.pullback.confirmed)
      {
         string pbHead = "PB." + pbDir + " Active";
         CreateLabel(prefix + "PB_Head", pbHead, x + 20, levelY, InpPullbackOriginColor, 8, ANCHOR_LEFT, "Arial Bold");
         levelY += lineHeight;

         string pbOrgText = "  PB Origin: " + DoubleToString(dr.pullback.originPrice, _Digits);
         CreateLabel(prefix + "PB_Org", pbOrgText, x + 20, levelY, InpPullbackOriginColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;

         string pbCLText = "  PB CL: " + DoubleToString(dr.pullback.clPrice, _Digits);
         CreateLabel(prefix + "PB_CL", pbCLText, x + 20, levelY, InpPullbackCLColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;

         int activeCnt = 0;
         for(int c = 0; c < dr.pullback.counterCount; c++)
            if(!dr.pullback.counters[c].isConsumed)
               activeCnt++;

         if(activeCnt > 0)
         {
            string cntText = "  PB Counters: " + IntegerToString(activeCnt);
            CreateLabel(prefix + "PB_Cnt", cntText, x + 20, levelY, InpPullbackCounterColor, 8, ANCHOR_LEFT);
            levelY += lineHeight;
         }
      }
      else if(dr.pullback.sweepPending)
      {
         string pbSwText = "PB." + pbDir + " Sweep @ " + DoubleToString(dr.pullback.sweepExtreme, _Digits);
         CreateLabel(prefix + "PB_Head", pbSwText, x + 20, levelY, g_warningColor, 8, ANCHOR_LEFT);
         levelY += lineHeight;
      }
      else if(dr.pullback.counterCount > 0)
      {
         int activeCnt2 = 0;
         for(int c2 = 0; c2 < dr.pullback.counterCount; c2++)
            if(!dr.pullback.counters[c2].isConsumed)
               activeCnt2++;

         if(activeCnt2 > 0)
         {
            string pbTrkText = "PB." + pbDir + " Tracking (" + IntegerToString(activeCnt2) + " cnt)";
            CreateLabel(prefix + "PB_Head", pbTrkText, x + 20, levelY, g_textColorDim, 8, ANCHOR_LEFT);
            levelY += lineHeight;
         }
      }
   }

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

void CreateSignalPanel(int x, int y)
{
   string prefix = g_dashPrefix + "Signal_";

   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashSignalHeight, g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashSignalHeight, g_borderColor, false);

   CreateLabel(prefix + "Header", "SIGNAL STATUS", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

   int sigY = y + 35;
   ENUM_TRADE_DIRECTION posDir = GetActivePositionDirection();

   if(posDir != DIR_NONE)
   {
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
   else if(g_hasValidSignal)
   {
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
   else if(g_waitingForOTE)
   {
      CreateLabel(prefix + "Wait", "Waiting for OTE Zone...", x + g_dashWidth / 2, sigY,
                  g_warningColor, 10, ANCHOR_CENTER);
   }
   else
   {
      CreateLabel(prefix + "None", "No Active Signal", x + g_dashWidth / 2, sigY,
                  g_textColorDim, 10, ANCHOR_CENTER);

      sigY += 25;
      string reason = GetNoSignalReason();
      CreateLabel(prefix + "Reason", reason, x + g_dashWidth / 2, sigY,
                  g_textColorDim, 8, ANCHOR_CENTER);
   }
}

void CreateStatsPanel(int x, int y)
{
   string prefix = g_dashPrefix + "Stats_";

   CreateRect(prefix + "BG", x, y, x + g_dashWidth, y + g_dashStatsHeight, g_bgColor, true);
   CreateRect(prefix + "Border", x, y, x + g_dashWidth, y + g_dashStatsHeight, g_borderColor, false);

   CreateLabel(prefix + "Header", "STATISTICS", x + g_dashWidth / 2, y + 10,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");

   int statY = y + 35;

   string todayText = "Today: " + IntegerToString(g_stats.todayTrades) + " trades | P/L: " + GetTodayPnLString();
   CreateLabel(prefix + "Today", todayText, x + 20, statY, g_textColor, 9, ANCHOR_LEFT);

   statY += 18;

   string overallText = "Total: " + IntegerToString(g_stats.totalTrades) +
                        " | W/L: " + IntegerToString(g_stats.winTrades) + "/" +
                        IntegerToString(g_stats.lossTrades) +
                        " | WR: " + GetWinRateString();
   CreateLabel(prefix + "Overall", overallText, x + 20, statY, g_textColorDim, 8, ANCHOR_LEFT);

   statY += 16;

   string pfText = "PF: " + GetProfitFactorString() + " | Net: " + DoubleToString(g_stats.netProfit, 2);
   CreateLabel(prefix + "PF", pfText, x + 20, statY, g_textColorDim, 8, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| State Machine Panel                                               |
//+------------------------------------------------------------------+
void CreateSMPanel(int x, int y)
{
   string px = g_dashPrefix + "SM_";

   CreateRect(px + "BG", x, y, x + g_dashWidth, y + g_dashSMHeight, g_bgColor, true);
   CreateRect(px + "Bdr", x, y, x + g_dashWidth, y + g_dashSMHeight, g_borderColor, false);

   int cy = y + 8;
   int lx = x + 15;

   CreateLabel(px + "Hdr", "STATE MACHINE ENGINE", x + g_dashWidth / 2, cy,
               g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");
   cy += 18;

   int activeN = SM_CountActiveInstances();
   string line1 = "Preset: " + EnumToString(InpSM_Preset) + " | Policy: " +
                  (InpSM_InstancePolicy == SM_INSTANCE_COEXIST ? "Coexist" : "Replace");

   string line2 = "Chains: " + IntegerToString(activeN) +
                  "/" + IntegerToString(InpSM_MaxInstances) +
                  " | Timeout: " + IntegerToString(InpSM_GlobalTimeout) + "b" +
                  " | SMBar#: " + IntegerToString(g_smBarCounter);

   CreateLabel(px + "Mode1", line1, lx, cy, g_textColorDim, 8, ANCHOR_LEFT);
   cy += 13;
   CreateLabel(px + "Mode2", line2, lx, cy, g_textColorDim, 8, ANCHOR_LEFT);
   cy += 18;

   // Loaded family status (SM-driven runtime gates)
   string loadedLine =
      "Loaded: "
      + string(g_needDetectOB ? "OB " : "")
      + string(g_needDetectFVG ? "FVG " : "")
      + string(g_needDetectOTE ? "OTE " : "")
      + string(g_needDetectAMD ? "AMD " : "")
      + string(g_needDetectJudas ? "JUDAS " : "")
      + string(g_needDetectSMT ? "SMT " : "")
      + string(g_needDetectKillzone ? "KZ " : "");

   if(loadedLine == "Loaded: ")
      loadedLine = "Loaded: none";

   CreateLabel(px + "LoadedSet", loadedLine, lx, cy, g_accentCyan, 8, ANCHOR_LEFT);
   cy += 14;

if(InpSM_ShowPerformanceTelemetry)
{
   string perf1 = "Perf(us): T=" + IntegerToString((int)g_perf.totalUs) +
                  " S=" + IntegerToString((int)g_perf.structUs) +
                  " N=" + IntegerToString((int)g_perf.narrativeUs) +
                  " SM=" + IntegerToString((int)g_perf.smUs);

   string perf2 = "Trade=" + IntegerToString((int)g_perf.tradeUs) +
                  " Dash=" + IntegerToString((int)g_perf.dashUs) +
                  " | Loaded=" + IntegerToString(g_perf.loadedFamilies) +
                  " SkippedFam=" + IntegerToString(g_perf.skippedFamilies) +
                  " SkipDet=" + IntegerToString(g_perf.skippedDetectors);

   CreateLabel(px + "Perf1", perf1, lx, cy, g_textColorDim, 8, ANCHOR_LEFT);
   cy += 13;
   CreateLabel(px + "Perf2", perf2, lx, cy, g_textColorDim, 8, ANCHOR_LEFT);
   cy += 13;
}

   string visLine = "Chart Render: " + string(InpSM_ShowLoadedElementsOnChart ? "ON" : "OFF");
   CreateLabel(px + "LoadedVis", visLine, lx, cy, g_textColorDim, 8, ANCHOR_LEFT);
   cy += 14;
   
   CreateLabel(px + "CFG", "-- STAGE CONFIG --", x + g_dashWidth / 2, cy, g_textColorDim, 7, ANCHOR_CENTER);
   cy += 13;

   for(int s = 0; s < SM_MAX_STAGES; s++)
   {
      string cfgLine = SM_StageConfigLine(s);
      CreateLabel(px + "SC" + IntegerToString(s), cfgLine, lx, cy, g_textColor, 8, ANCHOR_LEFT);
      cy += 13;
   }
   cy += 5;

   CreateLabel(px + "AC", "-- ACTIVE CHAINS --", x + g_dashWidth / 2, cy, g_textColorDim, 7, ANCHOR_CENTER);
   cy += 13;

   if(activeN == 0)
   {
      CreateLabel(px + "NoC", "No active chains", x + g_dashWidth / 2, cy, g_textColorDim, 8, ANCHOR_CENTER);
      cy += 14;
   }
   else
   {
      int shown = 0;
      for(int i = 0; i < SM_MAX_INSTANCES && shown < 4; i++)
      {
         if(!g_smInstances[i].active)
            continue;

         string instLine = SM_InstanceStatusLine(i);
         color instClr = DirectionToColor(g_smInstances[i].direction);
         CreateLabel(px + "I" + IntegerToString(shown), instLine, lx, cy, instClr, 8, ANCHOR_LEFT);
         cy += 13;
         shown++;
      }
   }

   cy += 5;
   CreateLabel(px + "EVH", "-- LAST EVENT --", x + g_dashWidth / 2, cy, g_textColorDim, 7, ANCHOR_CENTER);
   cy += 13;

   string evtLine;
   if(g_lastSMEvent.valid)
   {
      string tfName = (g_lastSMEvent.tfLayer == LAYER_HTF ? "HTF" :
                      (g_lastSMEvent.tfLayer == LAYER_LTF ? "LTF" : "CTF"));
      string dirName = (g_lastSMEvent.direction == DIR_BULLISH ? "BULL" : "BEAR");
      int evAge = g_smBarCounter - g_lastSMEvent.barCounter;

      evtLine = tfName + " | " + dirName +
                " | Price: " + DoubleToString(g_lastSMEvent.price, _Digits) +
                " | Tag: " + IntegerToString(g_lastSMEvent.tag) +
                " | Age: " + IntegerToString(evAge) + "b";
   }
   else
   {
      evtLine = "No structural event yet";
   }

   CreateLabel(px + "EVL", evtLine, lx, cy, g_accentGold, 8, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//|              SECTION 3: DASHBOARD UPDATE                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_dashboardInitialized || InpDashboardMode == DASH_OFF)
      return;

   CreateDashboard();
   g_lastDashboardUpdate = TimeCurrent();
}

void UpdateDashboardRealtime()
{
   if(!g_dashboardInitialized || InpDashboardMode == DASH_OFF)
      return;

   UpdateRealtimeElements();
}

void UpdateRealtimeElements()
{
   string prefix = g_dashPrefix;

   double profit = GetActivePositionProfit();
   string pnlText = "P/L: " + DoubleToString(profit, 2);
   color pnlColor = profit >= 0 ? g_bullColor : g_bearColor;

   string pnlName = prefix + "Signal_PnL";
   if(ObjectFind(0, pnlName) >= 0)
   {
      ObjectSetString(0, pnlName, OBJPROP_TEXT, pnlText);
      ObjectSetInteger(0, pnlName, OBJPROP_COLOR, pnlColor);
   }
}

void CleanupDashboard()
{
   CleanupObjectsWithPrefix(g_dashPrefix);
}

//+------------------------------------------------------------------+
//|              SECTION 4: UI HELPERS                                |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr,
                 int fontSize = 9, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT,
                 string font = "Arial")
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

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

void CreateRect(string name, int x1, int y1, int x2, int y2, color clr, bool fill = true)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

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

void CreateSectionHeader(string name, string text, int x, int y)
{
   CreateLabel(name, "-- " + text + " --", x + g_dashWidth / 2, y, g_textColorDim, 8, ANCHOR_CENTER);
}

void HandleChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Reserved for future dashboard interactions
   }
}

//+------------------------------------------------------------------+
//|              SECTION 5: HELPER FUNCTIONS                          |
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

string DashModeToString(ENUM_DASHBOARD_MODE mode)
{
   switch(mode)
   {
      case DASH_FULL:     return "Full";
      case DASH_STANDARD: return "Standard";
      case DASH_COMPACT:  return "Compact";
      case DASH_MINIMAL:  return "Minimal";
      case DASH_OFF:      return "Off";
      default:            return "Unknown";
   }
}

#endif // ICT_DASHBOARD_MQH