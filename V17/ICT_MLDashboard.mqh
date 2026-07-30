//+------------------------------------------------------------------+
//|                    ICT_MLDashboard.mqh                            |
//|              ML Engine Visual Dashboard (Enhanced)                |
//|                 "ICT Unified Professional EA v15"                 |
//+------------------------------------------------------------------+
#ifndef ICT_MLDASHBOARD_MQH
#define ICT_MLDASHBOARD_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Config.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../UI/ICT_Drawing.mqh"
#include "ICT_MLEngine.mqh"


bool InitializeMLDashboard()
{
   if(!InpML_ShowDashboard || InpML_Mode == ML_OFF)
      return true;
   
   g_mlDashWidth = 290;
   g_mlDashboardInitialized = true;
   Print("ML Dashboard v2.0 initialized");
   return true;
}

void UpdateMLDashboard()
{
   if(!g_mlDashboardInitialized || !InpML_ShowDashboard || InpML_Mode == ML_OFF)
      return;
   
   CleanupObjectsWithPrefix(g_mlDashPrefix);
   
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int x = (InpML_DashX > 0) ? InpML_DashX : chartW - g_mlDashWidth - 20;
   int y = InpML_DashY;
   int w = g_mlDashWidth;
   string p = g_mlDashPrefix;
   int rowH = 15;
   
   // ═══ HEADER + STATUS ═══
   int panelH = 110;
   CreateMLRect(p + "S_BG", x, y, w, panelH, g_bgColor);
   CreateMLRect(p + "S_BR", x, y, w, panelH, g_borderColor, false);
   
   int cy = y + 6;
   CreateMLLabel(p + "S_T", "🧠 ML ENGINE v2.0", x + w/2, cy, g_textColorBright, 10, ANCHOR_CENTER, "Arial Bold");
   cy += 18;
   
   // Status with color
   color statColor = clrGray;
   string statusIcon = "●";
   switch(g_mlStatus)
   {
      case ML_STATUS_FILTERING: statColor = g_successColor; statusIcon = "◆"; break;
      case ML_STATUS_OBSERVING: statColor = g_accentCyan; statusIcon = "◇"; break;
      case ML_STATUS_WARMUP:    statColor = g_warningColor; statusIcon = "○"; break;
      case ML_STATUS_FROZEN:    statColor = g_accentPurple; statusIcon = "■"; break;
   }
   
   CreateMLLabel(p + "S_St", statusIcon + " " + MLStatusToString(g_mlStatus),
                 x + 12, cy, statColor, 10, ANCHOR_LEFT, "Arial Bold");
   CreateMLLabel(p + "S_Md", EnumToString(InpML_Mode),
                 x + w - 12, cy, g_textColorDim, 8, ANCHOR_RIGHT);
   cy += rowH + 2;
   
   // Mode description
   CreateMLLabel(p + "S_Desc", MLModeDescription(),
                 x + 12, cy, g_textColorDim, 7, ANCHOR_LEFT);
   cy += rowH;
   
   // Status description
   CreateMLLabel(p + "S_StD", MLStatusDescription(),
                 x + 12, cy, g_textColor, 7, ANCHOR_LEFT);
   cy += rowH;
   
   // Data counters
   CreateMLLabel(p + "S_Dt", "Trades: " + IntegerToString(g_mlClosedTradeCount) + 
                 " | Updates: " + IntegerToString(g_mlWeights.updateCount) +
                 " | Allowed: " + IntegerToString(g_mlDiag.tradesAllowed) + 
                 " Blocked: " + IntegerToString(g_mlDiag.tradesBlocked),
                 x + 12, cy, g_textColorDim, 7, ANCHOR_LEFT);
   
   y += panelH + 4;
   
   // ═══ PREDICTION PANEL ═══
   panelH = 82;
   CreateMLRect(p + "P_BG", x, y, w, panelH, g_bgColor);
   CreateMLRect(p + "P_BR", x, y, w, panelH, g_borderColor, false);
   
   cy = y + 6;
   CreateMLLabel(p + "P_T", "📊 CURRENT PREDICTION", x + w/2, cy, g_textColorBright, 9, ANCHOR_CENTER, "Arial Bold");
   cy += 18;
   
   double prob = g_mlPrediction.probability;
   color probColor = (prob >= 0.65) ? g_successColor : 
                     (prob >= InpML_MinProbability) ? g_warningColor : g_dangerColor;
   
   CreateMLLabel(p + "P_Pr", "P(Win) = " + DoubleToString(prob * 100.0, 1) + "%",
                 x + w/2, cy, probColor, 12, ANCHOR_CENTER, "Arial Bold");
   cy += 18;
   
   // Probability bar
   int barW = w - 30;
   int barH = 10;
   int barX = x + 15;
   CreateMLRect(p + "P_BB", barX, cy, barW, barH, ColorDarken(probColor, 70));
   int fillW = (int)(barW * Clamp(prob, 0, 1));
   if(fillW > 0) CreateMLRect(p + "P_BF", barX, cy, fillW, barH, probColor);
   // Threshold marker
   int threshX = barX + (int)(barW * InpML_MinProbability);
   CreateMLRect(p + "P_TH", threshX, cy - 2, 2, barH + 4, clrWhite);
   
   cy += barH + 6;
   
   // Recommendation
   string recText = g_mlPrediction.recommend ? "✓ ALLOW TRADE" : "✗ BLOCK";
   color recColor = g_mlPrediction.recommend ? g_successColor : g_dangerColor;
   CreateMLLabel(p + "P_Rc", recText, x + 12, cy, recColor, 8, ANCHOR_LEFT, "Arial Bold");
   
   string adjText = "Adj: " + (g_mlPrediction.adjustedBias >= 0 ? "+" : "") +
                    DoubleToString(g_mlPrediction.adjustedBias, 1);
   CreateMLLabel(p + "P_Aj", adjText, x + w - 12, cy, g_textColor, 8, ANCHOR_RIGHT);
   
   y += panelH + 4;
   
   // ═══ DIAGNOSTIC PANEL (shows WHY) ═══
   panelH = 48;
   CreateMLRect(p + "D_BG", x, y, w, panelH, C'30,20,20');
   CreateMLRect(p + "D_BR", x, y, w, panelH, g_borderColor, false);
   
   cy = y + 6;
   CreateMLLabel(p + "D_T", "🔍 DIAGNOSTIC", x + w/2, cy, g_textColorBright, 8, ANCHOR_CENTER, "Arial Bold");
   cy += 14;
   
   string diagText = g_mlPrediction.reason;
   if(g_mlDiag.lastBlockReason != "" && !g_mlPrediction.recommend)
      diagText = g_mlDiag.lastBlockReason;
   
   color diagColor = g_mlPrediction.recommend ? g_successColor : g_warningColor;
   CreateMLLabel(p + "D_R", diagText, x + 12, cy, diagColor, 7, ANCHOR_LEFT);
   cy += 12;
   
   string gateText = "Samples: " + (g_mlDiag.hasEnoughSamples ? "✓" : "✗ " + 
                     IntegerToString(MathMax(0, InpML_MinSamplesFilter - g_mlClosedTradeCount)) + " more") +
                     " | Accuracy: " + (g_mlDiag.hasGoodAccuracy ? "✓" : "✗ " + 
                     DoubleToString(g_mlStats.predictionAccuracy, 0) + "/<" + 
                     DoubleToString(InpML_MinAccuracyFilter, 0) + "%");
   CreateMLLabel(p + "D_G", gateText, x + 12, cy, g_textColorDim, 6, ANCHOR_LEFT);
   
   y += panelH + 4;
   
   // ═══ TOP FEATURES ═══
   panelH = 120;
   CreateMLRect(p + "W_BG", x, y, w, panelH, g_bgColor);
   CreateMLRect(p + "W_BR", x, y, w, panelH, g_borderColor, false);
   
   cy = y + 6;
   CreateMLLabel(p + "W_T", "⚖ TOP FEATURES", x + w/2, cy, g_textColorBright, 9, ANCHOR_CENTER, "Arial Bold");
   cy += 16;
   
   // Sort features by importance
   int sortedIdx[ML_FEATURE_COUNT];
   double sortedImp[ML_FEATURE_COUNT];
   for(int i = 0; i < ML_FEATURE_COUNT; i++) { sortedIdx[i] = i; sortedImp[i] = g_mlStats.featureImportance[i]; }
   for(int i = 0; i < ML_FEATURE_COUNT - 1; i++)
      for(int j = 0; j < ML_FEATURE_COUNT - i - 1; j++)
         if(sortedImp[j] < sortedImp[j+1])
         { double t = sortedImp[j]; sortedImp[j] = sortedImp[j+1]; sortedImp[j+1] = t;
           int ti = sortedIdx[j]; sortedIdx[j] = sortedIdx[j+1]; sortedIdx[j+1] = ti; }
   
   int showCount = MathMin(8, ML_FEATURE_COUNT);
   for(int i = 0; i < showCount; i++)
   {
      int fi = sortedIdx[i];
      double weight = g_mlWeights.weights[fi];
      double effect = g_mlAdaptive.featureEffect[fi];
      string name = MLFeatureName(fi);
      
      color wColor = (weight >= 0) ? g_bullColor : g_bearColor;
      string sign = (weight >= 0) ? "+" : "";
      
      CreateMLLabel(p + "W_N" + IntegerToString(i), name, x + 12, cy, g_textColor, 7, ANCHOR_LEFT);
      
      int miniBarW = (int)(70 * sortedImp[i]);
      if(miniBarW > 0) CreateMLRect(p + "W_B" + IntegerToString(i), x + 90, cy + 1, miniBarW, 7, wColor);
      
      string valStr = sign + DoubleToString(weight, 3);
      if(g_mlAdaptive.winCount > 0)
         valStr += " E:" + DoubleToString(effect, 2);
      
      CreateMLLabel(p + "W_V" + IntegerToString(i), valStr,
                    x + w - 12, cy, wColor, 6, ANCHOR_RIGHT);
      cy += 12;
   }
   
   y += panelH + 4;
   
   // ═══ PERFORMANCE ═══
   panelH = 75;
   CreateMLRect(p + "F_BG", x, y, w, panelH, g_bgColor);
   CreateMLRect(p + "F_BR", x, y, w, panelH, g_borderColor, false);
   
   cy = y + 6;
   CreateMLLabel(p + "F_T", "📈 ACCURACY", x + w/2, cy, g_textColorBright, 9, ANCHOR_CENTER, "Arial Bold");
   cy += 16;
   
   color accColor = (g_mlStats.predictionAccuracy >= 60) ? g_successColor : 
                    (g_mlStats.predictionAccuracy >= 50) ? g_warningColor : g_dangerColor;
   CreateMLLabel(p + "F_Ac", "All: " + DoubleToString(g_mlStats.predictionAccuracy, 1) + "% (" +
                 IntegerToString(g_mlStats.correctPredictions) + "/" + 
                 IntegerToString(g_mlStats.totalPredictions) + ")",
                 x + 12, cy, accColor, 9, ANCHOR_LEFT);
   cy += rowH;
   CreateMLLabel(p + "F_RA", "Recent 20: " + DoubleToString(g_mlStats.recentAccuracy, 1) + "%",
                 x + 12, cy, g_textColor, 8, ANCHOR_LEFT);
   cy += rowH;
   CreateMLLabel(p + "F_WP", "Win P̄:" + DoubleToString(g_mlStats.avgWinProb, 3),
                 x + 12, cy, g_bullColor, 7, ANCHOR_LEFT);
   CreateMLLabel(p + "F_LP", "Loss P̄:" + DoubleToString(g_mlStats.avgLossProb, 3),
                 x + w/2, cy, g_bearColor, 7, ANCHOR_LEFT);
   
   y += panelH + 4;
   
   // ═══ RECENT PREDICTIONS ═══
   int histShow = MathMin(5, g_mlPredHistCount);
   if(histShow > 0)
   {
      panelH = 22 + histShow * 13;
      CreateMLRect(p + "H_BG", x, y, w, panelH, g_bgColor);
      CreateMLRect(p + "H_BR", x, y, w, panelH, g_borderColor, false);
      
      cy = y + 6;
      CreateMLLabel(p + "H_T", "📋 RECENT", x + w/2, cy, g_textColorBright, 8, ANCHOR_CENTER, "Arial Bold");
      cy += 14;
      
      for(int i = 0; i < histShow; i++)
      {
         int idx = (g_mlPredHistWriteIdx - 1 - i + ML_MAX_HISTORY) % ML_MAX_HISTORY;
         if(idx < 0 || idx >= ML_MAX_HISTORY) continue;
         
         SMLPredictionHistory hist = g_mlPredHistory[idx];
         
         string dir = hist.tradeTaken ? "▶" : "▷";
         string probStr = DoubleToString(hist.predictedProb * 100.0, 0) + "%";
         color lineColor = g_textColorDim;
         string result = "";
         
         if(hist.pnl != 0)
         {
            result = hist.actualWin ? " ✓" : " ✗";
            lineColor = hist.actualWin ? g_bullColor : g_bearColor;
            result += " $" + DoubleToString(hist.pnl, 1);
         }
         
         string line = dir + " P:" + probStr + result;
         
         CreateMLLabel(p + "H_L" + IntegerToString(i), line, x + 12, cy, lineColor, 7, ANCHOR_LEFT);
         cy += 13;
      }
   }
   
   ChartRedraw(0);
}

void CreateMLLabel(string name, string text, int xp, int yp, color clr,
                   int fontSize = 9, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT,
                   string font = "Arial")
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xp);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yp);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void CreateMLRect(string name, int xp, int yp, int width, int height,
                  color clr, bool fill = true)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xp);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yp);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, fill ? BORDER_FLAT : BORDER_RAISED);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, fill);
   
   if(!fill)
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   }
}

void CleanupMLDashboard()
{
   CleanupObjectsWithPrefix(g_mlDashPrefix);
}

#endif // ICT_MLDASHBOARD_MQH