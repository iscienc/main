//+------------------------------------------------------------------+
//|                         ICT_Drawing.mqh                           |
//|                    Chart Drawing Functions                         |
//|                    ICT Unified Professional EA                     |
//+------------------------------------------------------------------+
#ifndef ICT_DRAWING_MQH
#define ICT_DRAWING_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: BASIC DRAWING FUNCTIONS                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Horizontal Line                                              |
//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color clr, int width = 1,
               ENUM_LINE_STYLE style = STYLE_SOLID)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }

//+------------------------------------------------------------------+
//| Draw Vertical Line                                                |
//+------------------------------------------------------------------+
void DrawVLine(string name, datetime time, color clr, int width = 1,
               ENUM_LINE_STYLE style = STYLE_DOT)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_VLINE, 0, time, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }

//+------------------------------------------------------------------+
//| Draw Trend Line (Two Points)                                      |
//+------------------------------------------------------------------+
void DrawTrendLine(string name, datetime t1, double p1, datetime t2, double p2,
                   color clr, int width = 1, ENUM_LINE_STYLE style = STYLE_SOLID,
                   bool rayRight = false)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, rayRight);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
  }

//+------------------------------------------------------------------+
//| Draw Rectangle                                                    |
//+------------------------------------------------------------------+
void DrawRectangle(string name, datetime t1, double p1, datetime t2, double p2,
                   color clr, bool fill = true, int width = 1)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//| Draw Text Label (On Chart)                                        |
//+------------------------------------------------------------------+
void DrawText(string name, datetime time, double price, string text,
              color clr, int fontSize = 8, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT,
              string font = "Arial")
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//| Draw Arrow                                                        |
//+------------------------------------------------------------------+
void DrawArrow(string name, datetime time, double price, int arrowCode,
               color clr, int width = 2)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Draw Label (Fixed Position)                                       |
//+------------------------------------------------------------------+
void DrawLabel(string name, int x, int y, string text, color clr,
               int fontSize = 9, string font = "Arial",
               ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| Draw Rectangle Label (Panel Background)                           |
//+------------------------------------------------------------------+
void DrawRectLabel(string name, int x, int y, int width, int height,
                   color bgColor, color borderColor,
                   ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER)
  {
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//|              SECTION 2: ICT-SPECIFIC DRAWING FUNCTIONS             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Dealing Range Level (Origin/External/Internal)               |
//+------------------------------------------------------------------+
void DrawDRLevel(string name, datetime startTime, double price, datetime endTime,
                 color clr, int width, ENUM_LINE_STYLE style,
                 string labelText, double atr)
  {
   string lineName = name;
   string labelName = name + "_lbl";
   string priceName = name + "_price";

// Draw line
   DrawTrendLine(lineName, startTime, price, endTime, price, clr, width, style, false);

// Draw label
   datetime labelTime = startTime + (endTime - startTime) / 3;
   double labelOffset = atr * 0.1;
   DrawText(labelName, labelTime, price + labelOffset, labelText, clr, 8, ANCHOR_LEFT, "Arial Bold");

// Draw price label at end
   DrawText(priceName, endTime, price, "  " + DoubleToString(price, _Digits), clr, 7, ANCHOR_LEFT);
  }

//+------------------------------------------------------------------+
//| Draw Correction Line (Vertical + Horizontal)                      |
//+------------------------------------------------------------------+
void DrawCorrectionLine(string prefix, datetime vertTime, double horizPrice,
                        datetime horizEndTime, color clr, bool isBullish, double atr)
  {
   string vertName = prefix + "_vert";
   string horizName = prefix + "_horiz";
   string labelName = prefix + "_label";

// Vertical line
   DrawVLine(vertName, vertTime, clr, 1, STYLE_DOT);

// Horizontal line
   DrawTrendLine(horizName, vertTime, horizPrice, horizEndTime, horizPrice, clr, 2, STYLE_SOLID, false);

// Label
   double labelOffset = isBullish ? atr * 0.15 : -atr * 0.15;
   string labelText = isBullish ? "Bull CL" : "Bear CL";
   DrawText(labelName, vertTime, horizPrice + labelOffset, labelText, clr, 9, ANCHOR_LEFT, "Arial Bold");
  }

//+------------------------------------------------------------------+
//| Draw Order Block Zone                                             |
//+------------------------------------------------------------------+
void DrawOrderBlock(string name, datetime time, double top, double bottom,
                    datetime endTime, ENUM_OB_TYPE type, ENUM_OB_STATUS status,
                    bool isInstitutional, string labelOverride = "")
  {
   color fillColor = (type == OB_BULLISH) ? InpBullOB_Color : InpBearOB_Color;

   string labelText;
   if(labelOverride != "")
      labelText = labelOverride;
   else
      labelText = (type == OB_BULLISH) ? "OB+" : "OB-";

   if(status == OB_TESTED)
     {  fillColor = ColorDarken(fillColor, 30); labelText += " (T)"; }
   else
      if(status == OB_MITIGATED)
        {  fillColor = ColorDarken(fillColor, 60); labelText += " (M)"; }

   if(isInstitutional)
      labelText += " \x2605";

   DrawRectangle(name, time, top, endTime, bottom, fillColor, true);

   string labelName = name + "_lbl";
   double labelPrice = (top + bottom) / 2.0;
   DrawText(labelName, time, labelPrice, labelText, clrWhite, 8, ANCHOR_LEFT, "Arial Bold");
  }

//+------------------------------------------------------------------+
//| Draw Breaker Block Zone                                           |
//+------------------------------------------------------------------+
void DrawBreakerBlock(string name, datetime time, double top, double bottom,
                      datetime endTime, ENUM_BREAKER_TYPE type,
                      string labelOverride = "")
  {
   color fillColor = InpBreakerColor;
   string labelText;
   if(labelOverride != "")
      labelText = labelOverride;
   else
      labelText = (type == BREAKER_BULLISH) ? "BRK+" : "BRK-";

   DrawRectangle(name, time, top, endTime, bottom, fillColor, true);

   string labelName = name + "_lbl";
   double labelPrice = (top + bottom) / 2.0;
   DrawText(labelName, time, labelPrice, labelText, clrWhite, 8, ANCHOR_LEFT, "Arial Bold");
  }

//+------------------------------------------------------------------+
//| Draw Mitigation Block Zone                                        |
//+------------------------------------------------------------------+
void DrawMitigationBlock(string name, datetime time, double top, double bottom,
                         datetime endTime, ENUM_MB_TYPE type,
                         string labelOverride = "")
  {
   color fillColor = InpMBColor;
   string labelText;
   if(labelOverride != "")
      labelText = labelOverride;
   else
      labelText = (type == MB_BULLISH) ? "MB+" : "MB-";

   DrawRectangle(name, time, top, endTime, bottom, fillColor, true);

   string labelName = name + "_lbl";
   double labelPrice = (top + bottom) / 2.0;
   DrawText(labelName, time, labelPrice, labelText, clrWhite, 8, ANCHOR_LEFT, "Arial Bold");
  }

//+------------------------------------------------------------------+
//| Draw Fair Value Gap Zone                                          |
//+------------------------------------------------------------------+
void DrawFVG(string name, datetime time, double top, double bottom,
             datetime endTime, ENUM_FVG_TYPE type, ENUM_FVG_STATUS status,
             double ceLevel, string labelOverride = "")
  {
   color fillColor = (type == FVG_BULLISH) ? InpBullFVG_Color : InpBearFVG_Color;

   string labelText;
   if(labelOverride != "")
      labelText = labelOverride;
   else
      labelText = (type == FVG_BULLISH) ? "FVG+" : "FVG-";

   if(status == FVG_PARTIALLY_FILLED)
     {  fillColor = ColorDarken(fillColor, 30); labelText += " CE"; }
   else
      if(status == FVG_FULLY_FILLED)
        {  fillColor = ColorDarken(fillColor, 60); labelText += " \x2713"; }

   DrawRectangle(name, time, top, endTime, bottom, fillColor, true);

   if(status == FVG_OPEN && ShouldDrawNarrativeElement(NZ_FVG_CE))
     {
      string ceName = name + "_ce";
      DrawTrendLine(ceName, time, ceLevel, endTime, ceLevel,
                    ColorLighten(fillColor, 50), 1, STYLE_DOT, false);
     }

   string labelName = name + "_lbl";
   double labelPrice = (top + bottom) / 2.0;
   DrawText(labelName, time, labelPrice, labelText, clrWhite, 7, ANCHOR_LEFT, "Arial Bold");
  }
//+------------------------------------------------------------------+
//| Draw OTE Zone                                                     |
//+------------------------------------------------------------------+
void DrawOTEZone(string name, datetime time, double fib618, double fib705,
                 double fib79, datetime endTime, bool isBullish)
  {
   color zoneColor = InpOTEZoneColor;

// Draw main OTE zone (61.8 - 79)
   double zoneTop = isBullish ? fib618 : fib79;
   double zoneBottom = isBullish ? fib79 : fib618;

   DrawRectangle(name, time, zoneTop, endTime, zoneBottom, ColorDarken(zoneColor, 50), true);

// Draw optimal line (70.5%)
   string optimalName = name + "_optimal";
   DrawTrendLine(optimalName, time, fib705, endTime, fib705, zoneColor, 2, STYLE_SOLID, false);

// Draw fib labels
   string lbl618 = name + "_618";
   string lbl705 = name + "_705";
   string lbl79 = name + "_79";

   DrawText(lbl618, endTime, fib618, "61.8%", zoneColor, 7, ANCHOR_LEFT);
   DrawText(lbl705, endTime, fib705, "70.5%", zoneColor, 7, ANCHOR_LEFT);
   DrawText(lbl79, endTime, fib79, "79%", zoneColor, 7, ANCHOR_LEFT);
  }



//+------------------------------------------------------------------+
//| Draw Entry Zone                                                   |
//+------------------------------------------------------------------+
void DrawEntryZone(string name, datetime startTime, double upper, double lower,
                   datetime endTime, ENUM_TRADE_DIRECTION direction)
  {
   if(!InpShowEntryZone)
      return;

   color zoneColor = InpEntryZoneColor;

// Draw semi-transparent rectangle
   DrawRectangle(name, startTime, upper, endTime, lower, ColorDarken(zoneColor, 70), true);

// Draw border
   string borderTop = name + "_top";
   string borderBottom = name + "_bottom";
   DrawTrendLine(borderTop, startTime, upper, endTime, upper, zoneColor, 1, STYLE_DASH, false);
   DrawTrendLine(borderBottom, startTime, lower, endTime, lower, zoneColor, 1, STYLE_DASH, false);

// Draw label
   string labelName = name + "_lbl";
   string labelText = (direction == DIR_BULLISH) ? "BUY ZONE" : "SELL ZONE";
   double labelPrice = (upper + lower) / 2.0;
   DrawText(labelName, startTime, labelPrice, labelText, zoneColor, 8, ANCHOR_LEFT, "Arial Bold");
  }

//+------------------------------------------------------------------+
//| Draw Entry Arrow                                                  |
//+------------------------------------------------------------------+
void DrawEntryArrow(string name, datetime time, double price, bool isBuy, double atr)
  {
   if(!InpShowEntryArrows)
      return;

   int arrowCode = isBuy ? 233 : 234;  // Up/Down arrows
   color arrowColor = isBuy ? g_bullColorBright : g_bearColorBright;
   double offset = isBuy ? -atr * 0.3 : atr * 0.3;

   DrawArrow(name, time, price + offset, arrowCode, arrowColor, 3);
  }

//+------------------------------------------------------------------+
//| Draw Swing Point                                                  |
//+------------------------------------------------------------------+
void DrawSwingPoint(string name, datetime time, double price, bool isHigh,
                    ENUM_SWING_TYPE type, ENUM_SWING_STATUS status,
                    ENUM_SWING_CONTEXT context, double atr)
  {
   bool isExternal = (type == SWING_EXTERNAL_HIGH || type == SWING_EXTERNAL_LOW);

// Determine colors
   color mainColor;
   if(isExternal)
      mainColor = isHigh ? InpExternalHighColor : InpExternalLowColor;
   else
      mainColor = isHigh ? InpInternalHighColor : InpInternalLowColor;

// Adjust for status
   if(status == SWING_UNPROTECTED)
      mainColor = ColorDarken(mainColor, 50);
   else
      if(status == SWING_SWEPT)
         mainColor = clrYellow;

// Determine arrow code and size
   int arrowCode = isExternal ? (isHigh ? 217 : 218) : 159;  // Triangle or diamond
   int arrowSize = isExternal ? 4 : 2;

// Draw marker
   DrawArrow(name, time, price, arrowCode, mainColor, arrowSize);

// Build label
   string labelText = "";

// Type indicator
   labelText += isExternal ? "●" : "○";

// Context
   switch(context)
     {
      case CONTEXT_HH:
         labelText += "HH";
         break;
      case CONTEXT_HL:
         labelText += "HL";
         break;
      case CONTEXT_LH:
         labelText += "LH";
         break;
      case CONTEXT_LL:
         labelText += "LL";
         break;
      default:
         labelText += isHigh ? "SH" : "SL";
     }

// Status indicator
   switch(status)
     {
      case SWING_PROTECTED:
         labelText += "🛡";
         break;
      case SWING_UNPROTECTED:
         labelText += "✗";
         break;
      case SWING_SWEPT:
         labelText += "💧";
         break;
     }

// Draw label
   string labelName = name + "_lbl";
   double labelOffset = isHigh ? atr * 0.2 : -atr * 0.2;
   ENUM_ANCHOR_POINT anchor = isHigh ? ANCHOR_LOWER : ANCHOR_UPPER;
   DrawText(labelName, time, price + labelOffset, labelText, mainColor,
            isExternal ? 9 : 7, anchor, "Arial Bold");
  }

//+------------------------------------------------------------------+
//| Draw Liquidity Pool                                               |
//+------------------------------------------------------------------+
void DrawLiquidityPool(string name, datetime time, double price, datetime endTime,
                       ENUM_LIQUIDITY_TYPE type, int touchCount, bool isSwept)
  {
   color poolColor;
   string labelText;

   switch(type)
     {
      case LQ_EQUAL_HIGHS:
         poolColor = clrOrangeRed;
         labelText = "EQH x" + IntegerToString(touchCount);
         break;
      case LQ_EQUAL_LOWS:
         poolColor = clrLimeGreen;
         labelText = "EQL x" + IntegerToString(touchCount);
         break;
      case LQ_BSL:
         poolColor = clrRed;
         labelText = "BSL";
         break;
      case LQ_SSL:
         poolColor = clrGreen;
         labelText = "SSL";
         break;
      default:
         poolColor = clrGray;
         labelText = "LQ";
     }

   if(isSwept)
     {
      poolColor = clrGray;
      labelText += " ✓";
     }

// Draw line
   ENUM_LINE_STYLE style = isSwept ? STYLE_DOT : STYLE_DASHDOT;
   DrawTrendLine(name, time, price, endTime, price, poolColor, 2, style, !isSwept);

// Draw label
   string labelName = name + "_lbl";
   double atr = GetATR();
   double offset = (type == LQ_EQUAL_HIGHS || type == LQ_BSL) ? atr * 0.1 : -atr * 0.1;
   DrawText(labelName, time, price + offset, labelText, poolColor, 8, ANCHOR_LEFT, "Arial Bold");
  }

//+------------------------------------------------------------------+
//| Draw Judas Swing                                                  |
//+------------------------------------------------------------------+
void DrawJudasSwing(string name, datetime sweepTime, double sweepLevel,
                    datetime reversalTime, double reversalPrice,
                    ENUM_JUDAS_TYPE type)
  {
   color judasColor = clrYellow;
   string labelText = "JUDAS";

// Draw sweep marker
   int arrowCode = (type == JUDAS_BULLISH) ? 218 : 217;
   DrawArrow(name + "_sweep", sweepTime, sweepLevel, arrowCode, judasColor, 4);

// Draw reversal arrow
   int revArrow = (type == JUDAS_BULLISH) ? 233 : 234;
   color revColor = (type == JUDAS_BULLISH) ? g_bullColor : g_bearColor;
   DrawArrow(name + "_rev", reversalTime, reversalPrice, revArrow, revColor, 3);

// Draw connecting line
   DrawTrendLine(name + "_line", sweepTime, sweepLevel, reversalTime, reversalPrice,
                 judasColor, 1, STYLE_DOT, false);

// Draw label
   double atr = GetATR();
   double labelOffset = (type == JUDAS_BULLISH) ? -atr * 0.15 : atr * 0.15;
   DrawText(name + "_lbl", sweepTime, sweepLevel + labelOffset, labelText,
            judasColor, 9, ANCHOR_CENTER, "Arial Bold");
  }

//+------------------------------------------------------------------+
//|              SECTION 3: OBJECT UPDATE FUNCTIONS                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Extend Line to Current Time                                       |
//+------------------------------------------------------------------+
void ExtendLineToCurrent(string name)
  {
   if(ObjectFind(0, name) >= 0)
     {
      datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, currentTime);
     }
  }

//+------------------------------------------------------------------+
//| Extend Rectangle to Current Time                                  |
//+------------------------------------------------------------------+
void ExtendRectangleToCurrent(string name)
  {
   if(ObjectFind(0, name) >= 0)
     {
      datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, currentTime);
     }
  }

//+------------------------------------------------------------------+
//| Update Object Color                                               |
//+------------------------------------------------------------------+
void UpdateObjectColor(string name, color newColor)
  {
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_COLOR, newColor);
  }

//+------------------------------------------------------------------+
//| Update Object Text                                                |
//+------------------------------------------------------------------+
void UpdateObjectText(string name, string newText)
  {
   if(ObjectFind(0, name) >= 0)
      ObjectSetString(0, name, OBJPROP_TEXT, newText);
  }

//+------------------------------------------------------------------+
//| Update Label Position                                             |
//+------------------------------------------------------------------+
void UpdateLabelPosition(string name, int x, int y)
  {
   if(ObjectFind(0, name) >= 0)
     {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
     }
  }

//+------------------------------------------------------------------+
//| Set Object Visibility                                             |
//+------------------------------------------------------------------+
void SetObjectVisibility(string name, bool visible)
  {
   if(ObjectFind(0, name) >= 0)
     {
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
     }
  }

//+------------------------------------------------------------------+
//|              SECTION 4: HELPER FUNCTIONS                           |
//+------------------------------------------------------------------+
string GenerateNarrativeObjectName(string type)
  {
   g_objCount++;
   return g_prefix + "NZ_" + type + "_" + IntegerToString(g_objCount);
  }
//+------------------------------------------------------------------+
//| Generate Unique Object Name                                       |
//+------------------------------------------------------------------+
string GenerateObjectName(string prefix, string type)
  {
   g_objCount++;
   return prefix + type + "_" + IntegerToString(g_objCount);
  }

//+------------------------------------------------------------------+
//| Generate DR Object Name                                           |
//+------------------------------------------------------------------+
string GenerateDRObjectName(string type)
  {
   g_drObjCount++;
   return g_drPrefix + type + "_" + IntegerToString(g_drObjCount);
  }

//+------------------------------------------------------------------+
//| Generate PD Array Object Name                                     |
//+------------------------------------------------------------------+
string GeneratePDObjectName(string type)
  {
   return GenerateNarrativeObjectName(type);
  }


//+------------------------------------------------------------------+
//| Delete Objects with Prefix and Type                               |
//+------------------------------------------------------------------+
void DeleteObjectsOfType(string prefix, string type)
  {
   string searchPrefix = prefix + type;
   int total = ObjectsTotal(0);

   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, searchPrefix) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| Force Chart Redraw                                                |
//+------------------------------------------------------------------+
void ForceChartRedraw()
  {
   ChartRedraw(0);
  }

#endif // ICT_DRAWING_MQH
//+------------------------------------------------------------------+
