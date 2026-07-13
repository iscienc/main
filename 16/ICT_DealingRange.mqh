//+------------------------------------------------------------------+
//|                      ICT_DealingRange.mqh                         |
//|          Dealing Range + Pullback Sub-Structure System            |
//|                    "ICT Unified Professional EA v16"              |
//+------------------------------------------------------------------+
#ifndef ICT_DEALINGRANGE_MQH
#define ICT_DEALINGRANGE_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"
#include "ICT_SwingDetection.mqh"

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 1: HELPERS                                              ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Draw a limited-length vertical using OBJ_TREND (NEW)              |
//+------------------------------------------------------------------+
void DrawVerticalSegment(string name, datetime time,
                         double priceTop, double priceBottom,
                         color clr, int width, ENUM_LINE_STYLE style)
{
   int offset = MathMax(1, PeriodSeconds(PERIOD_CURRENT) / 4);
   datetime t2 = time + offset;
   DrawTrendLine(name, time, priceBottom, t2, priceTop,
                 clr, width, style, false);
}

//+------------------------------------------------------------------+
//| Update main CL vertical span  (MODIFIED – width=3)               |
//+------------------------------------------------------------------+
void UpdateMainCLVertical(SDealingRange &dr, bool isBullish)
{
   if(dr.corrLine.vertObjName=="" || ObjectFind(0,dr.corrLine.vertObjName)<0) return;
   double atr=GetATRSafe(); double top,bottom;
   int chochIdx=GetChochOriginIndex(dr);
   if(isBullish)
   {  top=dr.corrLine.extremePrice;
      bottom=(chochIdx>=0)?dr.origins[chochIdx].price:top-atr*3; }
   else
   {  bottom=dr.corrLine.extremePrice;
      top=(chochIdx>=0)?dr.origins[chochIdx].price:bottom+atr*3; }
   int offset=MathMax(1,PeriodSeconds(PERIOD_CURRENT)/4);
   ObjectSetInteger(0,dr.corrLine.vertObjName,OBJPROP_TIME,0,dr.corrLine.verticalTime);
   ObjectSetInteger(0,dr.corrLine.vertObjName,OBJPROP_TIME,1,dr.corrLine.verticalTime+offset);
   ObjectSetDouble(0,dr.corrLine.vertObjName,OBJPROP_PRICE,0,bottom);
   ObjectSetDouble(0,dr.corrLine.vertObjName,OBJPROP_PRICE,1,top);
   ObjectSetInteger(0,dr.corrLine.vertObjName,OBJPROP_WIDTH,GetMainCLWidth(LAYER_CTF));
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 2: INITIALIZATION                                       ║
// ╚══════════════════════════════════════════════════════════════════╝

bool InitializeStructureLayer()
{
   g_bullDR.Reset();
   g_bearDR.Reset();
   g_bullDR.timeframe = PERIOD_CURRENT;  g_bullDR.tfLayer = LAYER_CTF;
   g_bearDR.timeframe = PERIOD_CURRENT;  g_bearDR.tfLayer = LAYER_CTF;

   ArrayResize(g_bullDR.origins,   InpMaxOriginsTrack);
   ArrayResize(g_bullDR.externals, InpMaxExtInducements);
   ArrayResize(g_bullDR.internals, 20);
   ArrayResize(g_bearDR.origins,   InpMaxOriginsTrack);
   ArrayResize(g_bearDR.externals, InpMaxExtInducements);
   ArrayResize(g_bearDR.internals, 20);

   ArrayResize(g_bullDR.pullback.counters, InpMaxPullbackCounters);
   ArrayResize(g_bearDR.pullback.counters, InpMaxPullbackCounters);

   g_entryZone.Reset();
   ScanInitialStructure();
   g_drInitialized = true;
   Print("Dealing Range System initialized (with Pullback Detection)");
   return true;
}

void ScanInitialStructure()
{
   int barsAvailable = iBars(_Symbol, PERIOD_CURRENT);
   int scanBars = MathMin(InpInitScanBars, barsAvailable - 50);
   if(scanBars < 30){ Print("Not enough bars for initial scan"); return; }

   int highestBar = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,scanBars,1);
   int lowestBar  = iLowest (_Symbol,PERIOD_CURRENT,MODE_LOW, scanBars,1);
   double highP = iHigh(_Symbol,PERIOD_CURRENT,highestBar);
   double lowP  = iLow (_Symbol,PERIOD_CURRENT,lowestBar);
   double mid   = (highP + lowP) / 2.0;
   bool initBull = (iClose(_Symbol,PERIOD_CURRENT,0) > mid);

   g_isBullishActive = initBull;
   g_currentDirection = initBull ? DIR_BULLISH : DIR_BEARISH;
   g_ctfDirection     = g_currentDirection;

   if(initBull)
   {
      SetupCorrectionLine(g_bullDR,true, highP,
         iTime(_Symbol,PERIOD_CURRENT,highestBar),highestBar,scanBars);
      CreateFirstOrigin(g_bullDR,true, lowP,
         iTime(_Symbol,PERIOD_CURRENT,lowestBar));
      g_bullDR.isDominant=true;
      g_bearDR.isDominant=false; g_bearDR.isActive=false;
   }
   else
   {
      SetupCorrectionLine(g_bearDR,false, lowP,
         iTime(_Symbol,PERIOD_CURRENT,lowestBar),lowestBar,scanBars);
      CreateFirstOrigin(g_bearDR,false, highP,
         iTime(_Symbol,PERIOD_CURRENT,highestBar));
      g_bearDR.isDominant=true;
      g_bullDR.isDominant=false; g_bullDR.isActive=false;
   }

   Print("Initial structure: ",(initBull?"BULLISH":"BEARISH"),
         " | CL: ",(initBull?highP:lowP));
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 3: CORRECTION LINE MANAGEMENT  (MODIFIED – vertical)    ║
// ╚══════════════════════════════════════════════════════════════════╝

void SetupCorrectionLine(SDealingRange &dr, bool isBullish,
                         double extremePrice, datetime extremeTime,
                         int extremeBar, int scanRange)
{
   dr.corrLine.extremePrice    = extremePrice;
   dr.corrLine.extremeTime     = extremeTime;
   dr.corrLine.verticalTime    = extremeTime;
   dr.corrLine.isActive        = true;
   dr.corrLine.needsUpdate     = false;
   dr.corrLine.pendingExtreme  = 0;
   dr.corrLine.pendingExtremeTime = 0;

   if(InpShowCorrectionLines)
      DrawDR_CorrectionLine(dr, isBullish);

   ScanExternalInducements(dr, isBullish, extremeTime, extremeBar, scanRange);
   dr.isActive = true;

   Print((isBullish?"Bullish":"Bearish")," CL at ",
         DoubleToString(extremePrice,_Digits),
         " | Externals: ",dr.externalCount);
}

//+------------------------------------------------------------------+
//| Draw Correction Line  (MODIFIED – thick vertical + origin span)   |
//+------------------------------------------------------------------+
void DrawDR_CorrectionLine(SDealingRange &dr, bool isBullish)
{
   double atr = GetATRSafe(); if(atr <= 0) return;
   color clColor = isBullish ? InpBullCL_Color : InpBearCL_Color;
   datetime currentTime = iTime(_Symbol,PERIOD_CURRENT,0);

   dr.corrLine.vertObjName  = GenerateDRObjectName("CL_V");
   dr.corrLine.horizObjName = GenerateDRObjectName("CL_H");
   dr.corrLine.labelObjName = GenerateDRObjectName("CL_L");

   double vertTop, vertBottom;
   int chochIdx = GetChochOriginIndex(dr);
   if(isBullish)
   {  vertTop = dr.corrLine.extremePrice;
      vertBottom = (chochIdx>=0) ? dr.origins[chochIdx].price : vertTop-atr*3; }
   else
   {  vertBottom = dr.corrLine.extremePrice;
      vertTop = (chochIdx>=0) ? dr.origins[chochIdx].price : vertBottom+atr*3; }

   DrawVerticalSegment(dr.corrLine.vertObjName,
      dr.corrLine.verticalTime, vertTop, vertBottom,
      clColor, GetMainCLWidth(LAYER_CTF), STYLE_DOT);        // ← configurable

   DrawTrendLine(dr.corrLine.horizObjName,
      dr.corrLine.extremeTime, dr.corrLine.extremePrice,
      currentTime, dr.corrLine.extremePrice,
      clColor, 2, STYLE_SOLID, false);

   double off = isBullish ? atr*0.15 : -atr*0.15;
   string lbl = BuildDRLabel(LAYER_CTF, isBullish, "CL");
   DrawText(dr.corrLine.labelObjName, dr.corrLine.extremeTime,
      dr.corrLine.extremePrice + off, lbl, clColor, 9, ANCHOR_LEFT, "Arial Bold");
}
//+------------------------------------------------------------------+
//| Update Correction Line  (MODIFIED – clears pullback)              |
//+------------------------------------------------------------------+
void UpdateCorrectionLine(SDealingRange &dr, bool isBullish,
                          double newExtreme, datetime newTime)
{
   ReclassifyInternalsToExternals(dr, isBullish, newTime);

   DeleteObject(dr.corrLine.vertObjName);
   DeleteObject(dr.corrLine.horizObjName);
   DeleteObject(dr.corrLine.labelObjName);

   dr.corrLine.extremePrice     = newExtreme;
   dr.corrLine.extremeTime      = newTime;
   dr.corrLine.verticalTime     = newTime;
   dr.corrLine.needsUpdate      = false;
   dr.corrLine.pendingExtreme   = 0;
   dr.corrLine.pendingExtremeTime = 0;

   if(InpShowCorrectionLines)
      DrawDR_CorrectionLine(dr, isBullish);

   ClearAllInternals(dr);

   // ── NEW: Reset pullback on CL update (fresh zone) ──
   ClearPullbackStructure(dr);

   dr.externalSwept  = false;
   dr.extremeReached = 0;
   dr.sweepTime      = 0;

   Print((isBullish?"BULL":"BEAR")," CL updated to ",
         DoubleToString(newExtreme,_Digits));
}

// CheckCorrectionLineUpdate / TrackPendingExtreme — UNCHANGED
void CheckCorrectionLineUpdate(SDealingRange &dr, bool isBullish)
{
   if(!dr.corrLine.needsUpdate) return;
   TrackPendingExtreme(dr, isBullish);
   datetime pivotTime = dr.corrLine.pendingExtremeTime;
   if(pivotTime == 0) return;
   int pivotBar = iBarShift(_Symbol,PERIOD_CURRENT,pivotTime,false);
   if(pivotBar < InpCL_PivotRightBars) return;

   bool isPivot;
   if(isBullish) isPivot = IsPivotHigh(PERIOD_CURRENT,pivotBar,InpCL_PivotLeftBars,InpCL_PivotRightBars);
   else          isPivot = IsPivotLow (PERIOD_CURRENT,pivotBar,InpCL_PivotLeftBars,InpCL_PivotRightBars);

   if(isPivot)
   {  UpdateCorrectionLine(dr,isBullish,dr.corrLine.pendingExtreme,dr.corrLine.pendingExtremeTime); }
   else if(pivotBar > InpCL_ForceUpdateBars)
   {  UpdateCorrectionLine(dr,isBullish,dr.corrLine.pendingExtreme,dr.corrLine.pendingExtremeTime); }
   else if(InpCL_UpdateMode == CL_IMMEDIATE_EXTREME)
   {  UpdateCorrectionLine(dr,isBullish,dr.corrLine.pendingExtreme,dr.corrLine.pendingExtremeTime); }
}

void TrackPendingExtreme(SDealingRange &dr, bool isBullish)
{
   if(isBullish)
   {  double h = iHigh(_Symbol,PERIOD_CURRENT,1);
      if(h > dr.corrLine.pendingExtreme)
      {  dr.corrLine.pendingExtreme = h;
         dr.corrLine.pendingExtremeTime = iTime(_Symbol,PERIOD_CURRENT,1); } }
   else
   {  double l = iLow(_Symbol,PERIOD_CURRENT,1);
      if(dr.corrLine.pendingExtreme==0 || l < dr.corrLine.pendingExtreme)
      {  dr.corrLine.pendingExtreme = l;
         dr.corrLine.pendingExtremeTime = iTime(_Symbol,PERIOD_CURRENT,1); } }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 4: ORIGIN MANAGEMENT  (MODIFIED – CL vertical update)   ║
// ╚══════════════════════════════════════════════════════════════════╝

void CreateFirstOrigin(SDealingRange &dr, bool isBullish,
                       double originPrice, datetime originTime)
{
   int idx = dr.originCount;
   if(idx >= ArraySize(dr.origins)) ArrayResize(dr.origins, idx+3);

   dr.origins[idx].Reset();
   dr.origins[idx].price        = originPrice;
   dr.origins[idx].time         = originTime;
   dr.origins[idx].role         = ROLE_CHOCH;
   dr.origins[idx].isFromSweep  = true;
   dr.origins[idx].lineObjName  = GenerateDRObjectName("Origin");
   dr.origins[idx].labelObjName = dr.origins[idx].lineObjName + "_lbl";
   dr.originCount++;

   if(InpShowDR_Origins) DrawDR_Origin(idx, dr, isBullish);

   // ── NEW: update vertical span to reach origin ──
   UpdateMainCLVertical(dr, isBullish);

   Print("First ",(isBullish?"Bullish":"Bearish"),
         " Origin at ",DoubleToString(originPrice,_Digits));
}

void CreateOrigin(SDealingRange &dr, double price, datetime time, bool isBullish)
{
   for(int i=0;i<dr.originCount;i++)
   {  if(dr.origins[i].role==ROLE_CHOCH)
      {  dr.origins[i].role=ROLE_TARGET;
         UpdateOriginVisual(i,dr,isBullish); } }

   if(dr.originCount >= InpMaxOriginsTrack) RemoveOldestOrigin(dr);

   int idx = dr.originCount;
   if(idx >= ArraySize(dr.origins)) ArrayResize(dr.origins, idx+3);

   dr.origins[idx].Reset();
   dr.origins[idx].price        = price;
   dr.origins[idx].time         = time;
   dr.origins[idx].role         = ROLE_CHOCH;
   dr.origins[idx].isFromSweep  = true;
   dr.origins[idx].lineObjName  = GenerateDRObjectName("Origin");
   dr.origins[idx].labelObjName = dr.origins[idx].lineObjName + "_lbl";
   dr.originCount++;

   if(InpShowDR_Origins) DrawDR_Origin(idx, dr, isBullish);

   // ── NEW: update vertical span ──
   UpdateMainCLVertical(dr, isBullish);

   Print((isBullish?"BULL":"BEAR")," ORIGIN at ",
         DoubleToString(price,_Digits));
}

// RemoveOldestOrigin / GetChochOriginIndex — UNCHANGED
bool RemoveOldestOrigin(SDealingRange &dr)
{
   int oldIdx=-1; datetime oldT=D'2099.01.01';
   for(int i=0;i<dr.originCount;i++)
   {  if(dr.origins[i].role==ROLE_TARGET && dr.origins[i].time<oldT)
      {  oldT=dr.origins[i].time; oldIdx=i; } }
   if(oldIdx<0) return false;
   DeleteObject(dr.origins[oldIdx].lineObjName);
   DeleteObject(dr.origins[oldIdx].labelObjName);
   for(int i=oldIdx;i<dr.originCount-1;i++) dr.origins[i]=dr.origins[i+1];
   dr.originCount--;
   return true;
}

int GetChochOriginIndex(SDealingRange &dr)
{
   for(int i=0;i<dr.originCount;i++)
      if(dr.origins[i].role==ROLE_CHOCH) return i;
   return -1;
}

// DrawDR_Origin / UpdateOriginVisual / ApplyDistanceDimming — UNCHANGED
void DrawDR_Origin(int index, SDealingRange &dr, bool isBullish)
{
   if(index>=dr.originCount) return;
   double atr=GetATRSafe(); if(atr<=0) return;
   color oC; int lw; ENUM_LINE_STYLE ls; string lt;

   switch(dr.origins[index].role)
   {
      case ROLE_CHOCH:
         oC=InpOriginChochColor; lw=3; ls=STYLE_SOLID;
         lt=BuildDRLabel(LAYER_CTF,isBullish,"Origin",
            "\x2605 "+DoubleToString(dr.origins[index].price,_Digits));
         break;
      case ROLE_TARGET:
         if(dr.origins[index].isDimmed)
         {  oC=InpOriginDimColor; lw=1; ls=STYLE_DOT;
            lt=BuildDRLabel(LAYER_CTF,!isBullish,"Target",
               "\x25CB "+DoubleToString(dr.origins[index].price,_Digits)); }
         else
         {  oC=InpOriginTargetColor; lw=2; ls=STYLE_DASH;
            lt=BuildDRLabel(LAYER_CTF,!isBullish,"Target",
               DoubleToString(dr.origins[index].price,_Digits)); }
         break;
      default: return;
   }

   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   DeleteObject(dr.origins[index].lineObjName);
   DrawTrendLine(dr.origins[index].lineObjName,
      dr.origins[index].time, dr.origins[index].price,
      ct, dr.origins[index].price, oC, lw, ls, false);

   double off = isBullish ? -atr*0.12 : atr*0.12;
   DeleteObject(dr.origins[index].labelObjName);
   DrawText(dr.origins[index].labelObjName, dr.origins[index].time,
      dr.origins[index].price+off,
      lt+" "+DoubleToString(dr.origins[index].price,_Digits),
      oC, 9, ANCHOR_LEFT, "Arial Bold");
}

void UpdateOriginVisual(int index, SDealingRange &dr, bool isBullish)
{  DrawDR_Origin(index, dr, isBullish); }

void ApplyDistanceDimming(SDealingRange &dr, bool isBullish)
{
   if(!InpUseDistanceDim) return;
   double atr=GetATRSafe(); if(atr<=0) return;
   double cp=iClose(_Symbol,PERIOD_CURRENT,0);
   double dd=atr*InpDimDistanceATR;
   for(int i=0;i<dr.originCount;i++)
   {  if(dr.origins[i].role!=ROLE_TARGET) continue;
      bool shouldDim=(MathAbs(cp-dr.origins[i].price)>dd);
      if(shouldDim!=dr.origins[i].isDimmed)
      {  dr.origins[i].isDimmed=shouldDim;
         UpdateOriginVisual(i,dr,isBullish); } }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 5: EXTERNAL INDUCEMENT MANAGEMENT  (UNCHANGED)          ║
// ╚══════════════════════════════════════════════════════════════════╝

void ScanExternalInducements(SDealingRange &dr, bool isBullish,
   datetime clTime, int clBar, int maxBars)
{
   int lB = InpDR_ExtPivotLeftBars;                           // ← CHANGED
   int rB = InpDR_ExtPivotRightBars;                          // ← CHANGED
   int barsAvail = iBars(_Symbol, PERIOD_CURRENT);
   double atr = GetATR(); if(atr <= 0) return;

   double cP[]; datetime cT[]; int cB[]; double cS[];
   ArrayResize(cP,50); ArrayResize(cT,50);
   ArrayResize(cB,50); ArrayResize(cS,50);
   int cc = 0;

   for(int i = rB + 1; i < maxBars && cc < 50; i++)
   {
      if(i + lB >= barsAvail) break;
      datetime bT = iTime(_Symbol, PERIOD_CURRENT, i);
      if(bT >= clTime) continue;
      bool isP = false; double pr = 0;
      if(isBullish){ isP = IsPivotLow(PERIOD_CURRENT, i, lB, rB);
                     if(isP) pr = iLow(_Symbol, PERIOD_CURRENT, i); }
      else         { isP = IsPivotHigh(PERIOD_CURRENT, i, lB, rB);
                     if(isP) pr = iHigh(_Symbol, PERIOD_CURRENT, i); }
      if(!isP) continue;
      if(isBullish && pr >= dr.corrLine.extremePrice) continue;
      if(!isBullish && pr <= dr.corrLine.extremePrice) continue;
      if(IsLevelBroken(PERIOD_CURRENT, pr, isBullish, i)) continue;
      double depth = CalculateSwingDepth(PERIOD_CURRENT, i, isBullish, lB, rB);
      if(depth < atr * InpExtMinDepthATR) continue;
      int ps = CalculatePivotScore(PERIOD_CURRENT, i, !isBullish);
      if(ps < InpExtMinPivotScore) continue;
      cP[cc]=pr; cT[cc]=bT; cB[cc]=i; cS[cc]=depth+(ps*atr*0.1); cc++;
   }

   double minD = atr * InpExtMinDistanceATR;
   for(int i = 0; i < cc; i++)
   {  if(cP[i] == 0) continue;
      for(int j = i+1; j < cc; j++)
      {  if(cP[j] == 0) continue;
         if(MathAbs(cP[i] - cP[j]) < minD)
         {  if(cS[i] >= cS[j]) cP[j] = 0;
            else { cP[i] = 0; break; } } } }

   for(int i = 0; i < cc && dr.externalCount < InpMaxExtInducements; i++)
   {  if(cP[i] == 0) continue;
      AddExternalInducement(dr, cP[i], cT[i], cB[i], isBullish); }
}

void AddExternalInducement(SDealingRange &dr, double price, datetime time,
                           int barIndex, bool isBullish)
{
   for(int i=0;i<dr.externalCount;i++)
      if(MathAbs(dr.externals[i].price-price)<_Point*10) return;
   if(dr.externalCount>=InpMaxExtInducements) RemoveOldestExternal(dr,isBullish);

   int idx=dr.externalCount;
   if(idx>=ArraySize(dr.externals)) ArrayResize(dr.externals,idx+5);
   dr.externals[idx].Reset();
   dr.externals[idx].price=price; dr.externals[idx].time=time;
   dr.externals[idx].barIndex=barIndex; dr.externals[idx].status=DR_ACTIVE;
   dr.externals[idx].lineObjName=GenerateDRObjectName("Ext");
   dr.externals[idx].labelObjName=dr.externals[idx].lineObjName+"_lbl";
   dr.externalCount++;
   if(InpShowDR_Externals) DrawDR_External(idx,dr,isBullish);
}

void RemoveOldestExternal(SDealingRange &dr, bool isBullish)
{
   if(dr.externalCount==0) return;
   int oI=0; datetime oT=dr.externals[0].time;
   for(int i=1;i<dr.externalCount;i++)
      if(dr.externals[i].time<oT){ oT=dr.externals[i].time; oI=i; }
   DeleteObject(dr.externals[oI].lineObjName);
   DeleteObject(dr.externals[oI].labelObjName);
   for(int i=oI;i<dr.externalCount-1;i++) dr.externals[i]=dr.externals[i+1];
   dr.externalCount--;
}

void RemoveSweptExternal(SDealingRange &dr, int index)
{
   if(index>=dr.externalCount) return;
   DeleteObject(dr.externals[index].lineObjName);
   DeleteObject(dr.externals[index].labelObjName);
   for(int i=index;i<dr.externalCount-1;i++) dr.externals[i]=dr.externals[i+1];
   dr.externalCount--;
}

void DrawDR_External(int index, SDealingRange &dr, bool isBullish)
{
   if(index>=dr.externalCount) return;
   double atr=GetATRSafe(); if(atr<=0) return;
   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   DrawTrendLine(dr.externals[index].lineObjName,
      dr.externals[index].time, dr.externals[index].price,
      ct, dr.externals[index].price,
      InpExtInducementColor, 1, STYLE_DASHDOT, false);
   double off = isBullish ? -atr*0.1 : atr*0.1;
   string lt=BuildDRLabel(LAYER_CTF,isBullish,"Ext.IDMT",
      DoubleToString(dr.externals[index].price,_Digits));
   DrawText(dr.externals[index].labelObjName, dr.externals[index].time,
      dr.externals[index].price+off, lt, InpExtInducementColor, 8, ANCHOR_LEFT, "Arial Bold");
}

void CheckExternalSweeps(SDealingRange &dr, bool isBullish)
{
   double pH=g_prevBarHigh, pL=g_prevBarLow, pC=g_prevBarClose;
   for(int i=dr.externalCount-1;i>=0;i--)
   {  if(dr.externals[i].status!=DR_ACTIVE) continue;
      bool consumed=false; double eP=dr.externals[i].price;
      if(isBullish)
      {  consumed=((pL<=eP&&pC>eP)||(pC<=eP)); }
      else
      {  consumed=((pH>=eP&&pC<eP)||(pC>=eP)); }
      if(consumed)
      {  dr.externalSwept=true; dr.sweepTime=g_prevBarTime;
         if(isBullish)
         {  int db=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,10,1);
            double dl=iLow(_Symbol,PERIOD_CURRENT,db);
            if(dr.extremeReached==0||dl<dr.extremeReached) dr.extremeReached=dl; }
         else
         {  int hb=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,10,1);
            double hh=iHigh(_Symbol,PERIOD_CURRENT,hb);
            if(dr.extremeReached==0||hh>dr.extremeReached) dr.extremeReached=hh; }
         g_sweepCount++;
         RemoveSweptExternal(dr,i);
         Print((isBullish?"BULL":"BEAR")," External SWEPT at ",DoubleToString(eP,_Digits)); } }
}

void TrackExtremeReached(SDealingRange &dr, bool isBullish)
{
   if(isBullish)
   {  double l=g_prevBarLow;
      if(dr.extremeReached==0||l<dr.extremeReached) dr.extremeReached=l; }
   else
   {  double h=g_prevBarHigh;
      if(dr.extremeReached==0||h>dr.extremeReached) dr.extremeReached=h; }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 6: INTERNAL LEVEL MANAGEMENT  (UNCHANGED)               ║
// ╚══════════════════════════════════════════════════════════════════╝

void AddInternalLevel(SDealingRange &dr, double price, datetime time, bool isBullish)
{
   for(int i=0;i<dr.internalCount;i++)
      if(MathAbs(dr.internals[i].price-price)<_Point*10) return;
   int idx=dr.internalCount;
   if(idx>=ArraySize(dr.internals)) ArrayResize(dr.internals,idx+5);
   dr.internals[idx].Reset();
   dr.internals[idx].price=price; dr.internals[idx].time=time;
   dr.internals[idx].lineObjName=GenerateDRObjectName("Int");
   dr.internals[idx].labelObjName=dr.internals[idx].lineObjName+"_lbl";
   dr.internalCount++;
   if(InpShowDR_Internals) DrawDR_Internal(idx,dr,isBullish);
}

void DetectNewInternalLevels(SDealingRange &dr, bool isBullish)
{
   int cb = InpDR_IntPivotRightBars;                          // ← CHANGED
   if(cb < 1) cb = 1;
   datetime clT = dr.corrLine.verticalTime;

   if(isBullish)
   {
      if(IsPivotLow(PERIOD_CURRENT, cb,
         InpDR_IntPivotLeftBars, InpDR_IntPivotRightBars))    // ← CHANGED
      {
         datetime pt = iTime(_Symbol, PERIOD_CURRENT, cb);
         if(pt > clT)
         {  double p = iLow(_Symbol, PERIOD_CURRENT, cb);
            if(p < dr.corrLine.extremePrice)
               AddInternalLevel(dr, p, pt, isBullish); }
      }
   }
   else
   {
      if(IsPivotHigh(PERIOD_CURRENT, cb,
         InpDR_IntPivotLeftBars, InpDR_IntPivotRightBars))    // ← CHANGED
      {
         datetime pt = iTime(_Symbol, PERIOD_CURRENT, cb);
         if(pt > clT)
         {  double p = iHigh(_Symbol, PERIOD_CURRENT, cb);
            if(p > dr.corrLine.extremePrice)
               AddInternalLevel(dr, p, pt, isBullish); }
      }
   }
}

void UpdateInternalsBrokenStatus(SDealingRange &dr, bool isBullish)
{
   double pL=g_prevBarLow, pH=g_prevBarHigh;
   datetime pT=g_prevBarTime;
   for(int i=0;i<dr.internalCount;i++)
   {  if(dr.internals[i].isBroken) continue;
      bool broken=false;
      if(isBullish){ if(pL<dr.internals[i].price) broken=true; }
      else         { if(pH>dr.internals[i].price) broken=true; }
      if(broken)
      {  dr.internals[i].isBroken=true;
         dr.internals[i].brokenTime=pT;
         if(ObjectFind(0,dr.internals[i].lineObjName)>=0)
         {  ObjectSetInteger(0,dr.internals[i].lineObjName,OBJPROP_TIME,1,pT);
            ObjectSetInteger(0,dr.internals[i].lineObjName,OBJPROP_COLOR,clrDarkSlateGray);
            ObjectSetInteger(0,dr.internals[i].lineObjName,OBJPROP_STYLE,STYLE_DOT); } } }
}

void ClearAllInternals(SDealingRange &dr)
{
   for(int i=0;i<dr.internalCount;i++)
   {  DeleteObject(dr.internals[i].lineObjName);
      DeleteObject(dr.internals[i].labelObjName); }
   dr.internalCount=0;
}

void ReclassifyInternalsToExternals(SDealingRange &dr, bool isBullish, datetime newCLTime)
{
   double atr=GetATR(); double minD=atr*InpExtMinDistanceATR;
   for(int i=dr.internalCount-1;i>=0;i--)
   {  if(dr.internals[i].time>=newCLTime) continue;
      DeleteObject(dr.internals[i].lineObjName);
      DeleteObject(dr.internals[i].labelObjName);
      if(!dr.internals[i].isBroken)
      {  bool tooClose=false;
         for(int k=0;k<dr.externalCount;k++)
            if(MathAbs(dr.externals[k].price-dr.internals[i].price)<minD){ tooClose=true; break; }
         if(!tooClose)
         {  int bi=iBarShift(_Symbol,PERIOD_CURRENT,dr.internals[i].time,false);
            AddExternalInducement(dr,dr.internals[i].price,dr.internals[i].time,bi,isBullish); } }
      for(int j=i;j<dr.internalCount-1;j++) dr.internals[j]=dr.internals[j+1];
      dr.internalCount--; }
}

void DrawDR_Internal(int index, SDealingRange &dr, bool isBullish)
{
   if(index>=dr.internalCount) return;
   double atr=GetATRSafe(); if(atr<=0) return;
   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   DrawTrendLine(dr.internals[index].lineObjName,
      dr.internals[index].time, dr.internals[index].price,
      ct, dr.internals[index].price, InpInternalLevelColor, 1, STYLE_DASH, false);
   double off=isBullish?-atr*0.08:atr*0.08;
   string lt=BuildDRLabel(LAYER_CTF,isBullish,"INT",
      DoubleToString(dr.internals[index].price,_Digits));
   DrawText(dr.internals[index].labelObjName, dr.internals[index].time,
      dr.internals[index].price+off, lt, InpInternalLevelColor, 7, ANCHOR_LEFT);
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 7: PULLBACK SUB-STRUCTURE  (ALL NEW)                    ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Add a pullback counter-level                                      |
//+------------------------------------------------------------------+
void AddPullbackCounter(SDealingRange &dr, double price, datetime time,
                        int barIndex, bool mainIsBullish)
{
   for(int i=0;i<dr.pullback.counterCount;i++)
      if(MathAbs(dr.pullback.counters[i].price-price)<_Point*10) return;
   if(dr.pullback.counterCount>=InpMaxPullbackCounters) return;

   int idx=dr.pullback.counterCount;
   if(idx>=ArraySize(dr.pullback.counters))
      ArrayResize(dr.pullback.counters,idx+5);

   dr.pullback.counters[idx].Reset();
   dr.pullback.counters[idx].price=price;
   dr.pullback.counters[idx].time=time;
   dr.pullback.counters[idx].barIndex=barIndex;
   dr.pullback.counters[idx].lineObjName=GenerateDRObjectName("PB_Cnt");
   dr.pullback.counters[idx].labelObjName=dr.pullback.counters[idx].lineObjName+"_lbl";
   dr.pullback.counterCount++;

   if(InpShowPullbackCounters)
      DrawPullbackCounter(idx, dr, mainIsBullish);
}

//+------------------------------------------------------------------+
//| Detect pullback counter-levels (opposite-side pivots in pullback) |
//+------------------------------------------------------------------+
void DetectPullbackCounterLevels(SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure) return;
   if(!dr.corrLine.isActive) return;

   // Counter-levels are internal-scale pivots within pullback zone
   int cb = InpDR_IntPivotRightBars;                          // ← CHANGED
   if(cb < 1) cb = 1;
   datetime clT = dr.corrLine.verticalTime;

   if(isBullish)
   {
      // Bull main → bear pullback → counter = pivot HIGH
      if(IsPivotHigh(PERIOD_CURRENT, cb,
         InpDR_IntPivotLeftBars, InpDR_IntPivotRightBars))    // ← CHANGED
      {
         datetime pt = iTime(_Symbol, PERIOD_CURRENT, cb);
         if(pt > clT)
         {  double p = iHigh(_Symbol, PERIOD_CURRENT, cb);
            if(p < dr.corrLine.extremePrice)
               AddPullbackCounter(dr, p, pt, cb, isBullish); }
      }
   }
   else
   {
      // Bear main → bull pullback → counter = pivot LOW
      if(IsPivotLow(PERIOD_CURRENT, cb,
         InpDR_IntPivotLeftBars, InpDR_IntPivotRightBars))    // ← CHANGED
      {
         datetime pt = iTime(_Symbol, PERIOD_CURRENT, cb);
         if(pt > clT)
         {  double p = iLow(_Symbol, PERIOD_CURRENT, cb);
            if(p > dr.corrLine.extremePrice)
               AddPullbackCounter(dr, p, pt, cb, isBullish); }
      }
   }
}
//+------------------------------------------------------------------+
//| Check if pullback counter-levels are swept                        |
//+------------------------------------------------------------------+
void CheckPullbackCounterSweeps(SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure) return;

   double pH=g_prevBarHigh, pL=g_prevBarLow, pC=g_prevBarClose;

   for(int i=dr.pullback.counterCount-1; i>=0; i--)
   {
      if(dr.pullback.counters[i].isConsumed) continue;
      bool consumed=false;
      double cP=dr.pullback.counters[i].price;

      if(isBullish)
      {  // Bull main, bear pullback: counter=HIGH → swept above
         consumed = (pH>=cP && pC<cP) || (pC>=cP); }
      else
      {  // Bear main, bull pullback: counter=LOW → swept below
         consumed = (pL<=cP && pC>cP) || (pC<=cP); }

      if(consumed)
      {
         dr.pullback.counters[i].isConsumed=true;
         dr.pullback.counters[i].consumedTime=g_prevBarTime;
         dr.pullback.sweepPending=true;
         dr.pullback.sweepTime=g_prevBarTime;

         // Init sweep extreme from this bar
         if(isBullish)
         {  if(pH>dr.pullback.sweepExtreme) dr.pullback.sweepExtreme=pH; }
         else
         {  if(dr.pullback.sweepExtreme==0||pL<dr.pullback.sweepExtreme)
               dr.pullback.sweepExtreme=pL; }

         // Update visual
         if(ObjectFind(0,dr.pullback.counters[i].lineObjName)>=0)
         {  ObjectSetInteger(0,dr.pullback.counters[i].lineObjName,OBJPROP_TIME,1,g_prevBarTime);
            ObjectSetInteger(0,dr.pullback.counters[i].lineObjName,OBJPROP_COLOR,clrDarkSlateGray);
            ObjectSetInteger(0,dr.pullback.counters[i].lineObjName,OBJPROP_STYLE,STYLE_DOT); }

         Print((isBullish?"BULL":"BEAR")," PB Counter SWEPT at ",
               DoubleToString(cP,_Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Track sweep extreme continuously while pending                    |
//+------------------------------------------------------------------+
void TrackPullbackSweepExtreme(SDealingRange &dr, bool isBullish)
{
   if(!dr.pullback.sweepPending) return;

   if(isBullish)
   {  double h=g_prevBarHigh;
      if(h>dr.pullback.sweepExtreme) dr.pullback.sweepExtreme=h; }
   else
   {  double l=g_prevBarLow;
      if(dr.pullback.sweepExtreme==0||l<dr.pullback.sweepExtreme)
         dr.pullback.sweepExtreme=l; }
}

//+------------------------------------------------------------------+
//| Detect pullback Mode A (counter-sweep + internal broken)          |
//+------------------------------------------------------------------+
void DetectPullbackStructure(SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure) return;
   if(!dr.pullback.sweepPending) return;

   // Check if any internal was broken AFTER the counter-sweep
   for(int i=0; i<dr.internalCount; i++)
   {
      if(!dr.internals[i].isBroken) continue;
      if(dr.internals[i].brokenTime < dr.pullback.sweepTime) continue;

      // ═══ MODE A CONFIRMED ═══
      if(dr.pullback.confirmed)
      {
         // Replace: update origin
         dr.pullback.originPrice = dr.pullback.sweepExtreme;
         dr.pullback.originTime  = dr.pullback.sweepTime;
         dr.pullback.sweepPending = false;
         if(InpShowPullbackOrigin) DrawPullbackOrigin(dr, isBullish);
         Print((isBullish?"BULL":"BEAR")," PB Origin UPDATED → ",
               DoubleToString(dr.pullback.originPrice,_Digits));
      }
      else
      {
         // First confirmation
         dr.pullback.confirmed   = true;
         dr.pullback.active      = true;
         dr.pullback.originPrice = dr.pullback.sweepExtreme;
         dr.pullback.originTime  = dr.pullback.sweepTime;
         dr.pullback.sweepPending = false;

         if(InpShowPullbackOrigin) DrawPullbackOrigin(dr, isBullish);
         if(InpShowPullbackCL)     DrawPullbackCL(dr, isBullish);

         Print("═══ ",(isBullish?"BULL":"BEAR")," PULLBACK MODE A ═══");
         Print("  PB Origin: ",DoubleToString(dr.pullback.originPrice,_Digits));
         Print("  PB CL:     ",DoubleToString(dr.pullback.clPrice,_Digits));
         g_forceDashboardUpdate = true;
      }
      break;
   }
}

//+------------------------------------------------------------------+
//| Track pullback CL (extreme on right side of main CL)              |
//+------------------------------------------------------------------+
void UpdatePullbackCL(SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure) return;
   if(!dr.corrLine.isActive) return;

   double pH=g_prevBarHigh, pL=g_prevBarLow;
   bool updated=false;

   if(isBullish)
   {  // Bull main, bear pullback → track LOWEST LOW
      if(dr.pullback.clPrice==0 || pL<dr.pullback.clPrice)
      {  dr.pullback.clPrice=pL; dr.pullback.clTime=g_prevBarTime; updated=true; }
   }
   else
   {  // Bear main, bull pullback → track HIGHEST HIGH
      if(pH>dr.pullback.clPrice)
      {  dr.pullback.clPrice=pH; dr.pullback.clTime=g_prevBarTime; updated=true; }
   }

   if(updated && dr.pullback.confirmed && InpShowPullbackCL)
      DrawPullbackCL(dr, isBullish);
}

//+------------------------------------------------------------------+
//| Check if pullback origin is broken (A2-a)                         |
//+------------------------------------------------------------------+
void CheckPullbackOriginBreak(SDealingRange &dr, bool isBullish)
{
   if(!dr.pullback.confirmed || !dr.pullback.active) return;

   bool broken=false;
   if(isBullish)
   {  // Bull main, bear pullback: origin=HIGH → break above = pullback over
      broken = CheckBreak(PERIOD_CURRENT, dr.pullback.originPrice, true); }
   else
   {  // Bear main, bull pullback: origin=LOW → break below = pullback over
      broken = CheckBreak(PERIOD_CURRENT, dr.pullback.originPrice, false); }

   if(!broken) return;

   double pbPeak     = dr.pullback.clPrice;
   datetime pbPeakTime = dr.pullback.clTime;

   Print("═══ ",(isBullish?"BULL":"BEAR")," PB ORIGIN BROKEN (A2-a) ═══");
   Print("  PB Peak → Main Origin: ",DoubleToString(pbPeak,_Digits));

   // Pullback peak becomes new Main Origin (immediate)
   CreateOrigin(dr, pbPeak, pbPeakTime, isBullish);
   UpdateMainCLVertical(dr, isBullish);
   ClearPullbackStructure(dr);

   g_forceDashboardUpdate = true;

}

//+------------------------------------------------------------------+
//| Draw pullback counter-level                                       |
//+------------------------------------------------------------------+
void DrawPullbackCounter(int index, SDealingRange &dr, bool mainIsBullish)
{
   if(index>=dr.pullback.counterCount) return;
   double atr=GetATRSafe(); if(atr<=0) return;
   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   bool pbBull = !mainIsBullish;

   DrawTrendLine(dr.pullback.counters[index].lineObjName,
      dr.pullback.counters[index].time, dr.pullback.counters[index].price,
      ct, dr.pullback.counters[index].price,
      InpPullbackCounterColor, 1, STYLE_DOT, false);

   double off = pbBull ? -atr*0.08 : atr*0.08;
   string lt = BuildDRLabel(LAYER_CTF, pbBull, "PB.Cnt",
      DoubleToString(dr.pullback.counters[index].price,_Digits));
   DrawText(dr.pullback.counters[index].labelObjName,
      dr.pullback.counters[index].time,
      dr.pullback.counters[index].price+off,
      lt, InpPullbackCounterColor, 7, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Draw pullback origin                                              |
//+------------------------------------------------------------------+
void DrawPullbackOrigin(SDealingRange &dr, bool mainIsBullish)
{
   double atr=GetATRSafe(); if(atr<=0) return;
   DeleteObject(dr.pullback.originLineObj);
   DeleteObject(dr.pullback.originLabelObj);

   dr.pullback.originLineObj  = GenerateDRObjectName("PB_Org");
   dr.pullback.originLabelObj = dr.pullback.originLineObj+"_lbl";

   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   bool pbBull = !mainIsBullish;

   string lt = BuildDRLabel(LAYER_CTF, pbBull, "PB.Origin",
      "\x2605 "+DoubleToString(dr.pullback.originPrice,_Digits));

   DrawTrendLine(dr.pullback.originLineObj,
      dr.pullback.originTime, dr.pullback.originPrice,
      ct, dr.pullback.originPrice,
      InpPullbackOriginColor, 2, STYLE_SOLID, false);

   double off = pbBull ? -atr*0.12 : atr*0.12;
   DrawText(dr.pullback.originLabelObj, dr.pullback.originTime,
      dr.pullback.originPrice+off, lt,
      InpPullbackOriginColor, 9, ANCHOR_LEFT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Draw pullback CL  (MODIFIED – thin + correct span)               |
//+------------------------------------------------------------------+
void DrawPullbackCL(SDealingRange &dr, bool mainIsBullish)
{
   double atr=GetATRSafe(); if(atr<=0) return;
   DeleteObject(dr.pullback.clVertObj);
   DeleteObject(dr.pullback.clHorizObj);
   DeleteObject(dr.pullback.clLabelObj);
   dr.pullback.clVertObj =GenerateDRObjectName("PB_CLV");
   dr.pullback.clHorizObj=GenerateDRObjectName("PB_CLH");
   dr.pullback.clLabelObj=GenerateDRObjectName("PB_CLL");

   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   bool pbBull=!mainIsBullish;
   color clC=InpPullbackCLColor;
   double vTop,vBot;
   double fallback=dr.corrLine.extremePrice;

   if(pbBull)
   {  vTop=dr.pullback.clPrice;
      vBot=(dr.pullback.originPrice>0)?dr.pullback.originPrice:fallback; }
   else
   {  vBot=dr.pullback.clPrice;
      vTop=(dr.pullback.originPrice>0)?dr.pullback.originPrice:fallback; }

   DrawVerticalSegment(dr.pullback.clVertObj,
      dr.pullback.clTime, vTop, vBot,
      clC, GetPBCLWidth(LAYER_CTF), STYLE_DOT);              // ← configurable

   DrawTrendLine(dr.pullback.clHorizObj,
      dr.pullback.clTime, dr.pullback.clPrice,
      ct, dr.pullback.clPrice, clC, 1, STYLE_DASH, false);

   double off=pbBull?atr*0.12:-atr*0.12;
   string lt=BuildDRLabel(LAYER_CTF,pbBull,"PB.CL");
   DrawText(dr.pullback.clLabelObj, dr.pullback.clTime,
      dr.pullback.clPrice+off, lt, clC, 8, ANCHOR_LEFT, "Arial Bold");
}
//+------------------------------------------------------------------+
//| Clear entire pullback sub-structure                               |
//+------------------------------------------------------------------+
void ClearPullbackStructure(SDealingRange &dr)
{
   for(int i=0;i<dr.pullback.counterCount;i++)
   {  DeleteObject(dr.pullback.counters[i].lineObjName);
      DeleteObject(dr.pullback.counters[i].labelObjName); }
   DeleteObject(dr.pullback.originLineObj);
   DeleteObject(dr.pullback.originLabelObj);
   DeleteObject(dr.pullback.clVertObj);
   DeleteObject(dr.pullback.clHorizObj);
   DeleteObject(dr.pullback.clLabelObj);
   dr.pullback.Reset();
   ArrayResize(dr.pullback.counters, InpMaxPullbackCounters);
}

//+------------------------------------------------------------------+
//| Dashboard helpers                                                 |
//+------------------------------------------------------------------+
string GetPullbackStatusString()
{
   SDealingRange* dr = GetActiveDR();
   if(!InpDetectPullbackStructure) return "PB: Off";
   bool pbBull = !g_isBullishActive;
   string d = pbBull ? "Bull" : "Bear";

   if(dr.pullback.confirmed)
      return "PB."+d+" Active|Org:"+DoubleToString(dr.pullback.originPrice,_Digits)+
             " CL:"+DoubleToString(dr.pullback.clPrice,_Digits);
   if(dr.pullback.sweepPending)
      return "PB."+d+" Sweep|Ext:"+DoubleToString(dr.pullback.sweepExtreme,_Digits);
   if(dr.pullback.counterCount>0)
      return "PB."+d+" Track|Cnt:"+IntegerToString(dr.pullback.counterCount);
   return "PB: Idle";
}

bool   HasActivePullback()    { return GetActiveDR().pullback.confirmed; }
double GetPullbackOriginPrice(){ return GetActiveDR().pullback.originPrice; }
double GetPullbackCLPrice()   { return GetActiveDR().pullback.clPrice; }

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 8: BOS & CHOCH DETECTION  (MODIFIED)                    ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Check for BOS (MODIFIED – pullback fallback)                      |
//+------------------------------------------------------------------+
void CheckDR_BOS(SDealingRange &dr, bool isBullish)
{
   if(dr.corrLine.extremePrice<=0) return;
   if(dr.corrLine.needsUpdate) return;

   datetime pT=g_prevBarTime;
   if(pT<=dr.corrLine.extremeTime) return;

   double atr=GetATRSafe();
   bool pullbackOK=false;
   switch(InpCL_UpdateMode)
   {
      case CL_PULLBACK_REQUIRED:
         pullbackOK=HasPulledBackFromExtreme(PERIOD_CURRENT,dr.corrLine.extremePrice,
                     dr.corrLine.extremeTime,isBullish,atr);
         break;
      case CL_IMMEDIATE_EXTREME:
         pullbackOK=true;
         break;
      case CL_PIVOT_CONFIRMED:
         pullbackOK=HasPulledBackFromExtreme(PERIOD_CURRENT,dr.corrLine.extremePrice,
                     dr.corrLine.extremeTime,isBullish,atr);
         if(!pullbackOK)
         {  int bs=iBarShift(_Symbol,PERIOD_CURRENT,dr.corrLine.extremeTime,false);
            if(bs>InpCL_ForceUpdateBars) pullbackOK=true; }
         break;
   }
   if(!pullbackOK) return;

   bool bosHappened=CheckBreak(PERIOD_CURRENT,dr.corrLine.extremePrice,isBullish);
   if(!bosHappened) return;

   g_bosCount++;
   Print("═══ ",(isBullish?"BULL":"BEAR")," BOS at ",
         DoubleToString(dr.corrLine.extremePrice,_Digits)," ═══");

   // ── PRIORITY 1: External sweep origin ──
   if(dr.externalSwept && dr.extremeReached>0)
   {
      CreateOrigin(dr, dr.extremeReached, dr.sweepTime, isBullish);
   }
   // ── PRIORITY 2: Pullback peak fallback (NEW) ──
   else if(dr.pullback.confirmed && dr.pullback.clPrice>0)
   {
      CreateOrigin(dr, dr.pullback.clPrice, dr.pullback.clTime, isBullish);
      Print("   Origin from PULLBACK PEAK: ",
            DoubleToString(dr.pullback.clPrice,_Digits));
   }

   // Register SM event
   ENUM_TRADE_DIRECTION bosDir = isBullish ? DIR_BULLISH : DIR_BEARISH;
   SM_RegisterStructuralEvent(dr.corrLine.extremePrice, bosDir, 1, LAYER_CTF);

   // Mark CL for update
   dr.corrLine.needsUpdate=true;
   if(isBullish)
   {  dr.corrLine.pendingExtreme=g_prevBarHigh;
      dr.corrLine.pendingExtremeTime=g_prevBarTime; }
   else
   {  dr.corrLine.pendingExtreme=g_prevBarLow;
      dr.corrLine.pendingExtremeTime=g_prevBarTime; }

   dr.externalSwept=false; dr.extremeReached=0; dr.sweepTime=0;
   g_forceDashboardUpdate=true;
}

//+------------------------------------------------------------------+
//| Check for ChoCh (MODIFIED – pullback promotion)                   |
//+------------------------------------------------------------------+
void CheckDR_ChoCh(SDealingRange &dr, bool isBullish)
{
   int chochIdx=GetChochOriginIndex(dr);
   if(chochIdx<0) return;

   datetime pT=g_prevBarTime;
   if(pT<=dr.origins[chochIdx].time) return;

   bool originBroken=false;
   if(isBullish) originBroken=CheckBreak(PERIOD_CURRENT,dr.origins[chochIdx].price,false);
   else          originBroken=CheckBreak(PERIOD_CURRENT,dr.origins[chochIdx].price,true);
   if(!originBroken) return;

   // ═══ CHOCH DETECTED ═══
   double brokenPrice = dr.origins[chochIdx].price;
   string dirLabel    = isBullish ? "BEARISH" : "BULLISH";
   double oldCL       = dr.corrLine.extremePrice;
   datetime oldCLTime = dr.corrLine.extremeTime;
   g_chochCount++;

   Print("═══════════════════════════════════════════");
   Print("🔄 ",dirLabel," CHOCH! Origin ",DoubleToString(brokenPrice,_Digits)," BROKEN");
   Print("═══════════════════════════════════════════");

   // SM event
   ENUM_TRADE_DIRECTION chDir = isBullish ? DIR_BEARISH : DIR_BULLISH;
   SM_RegisterStructuralEvent(brokenPrice, chDir, 1, LAYER_CTF);

   // ── Save pullback data BEFORE clearing ──
   bool   hadPB       = dr.pullback.confirmed;
   double pbOrgPrice  = dr.pullback.originPrice;
   datetime pbOrgTime = dr.pullback.originTime;
   double pbCLPrice   = dr.pullback.clPrice;
   datetime pbCLTime  = dr.pullback.clTime;

   // Reclassify externals to DR target lines
   ReclassifyExternalsToTargetLines(dr, isBullish);

   // Remove broken origin
   DeleteObject(dr.origins[chochIdx].lineObjName);
   DeleteObject(dr.origins[chochIdx].labelObjName);
   for(int i=chochIdx;i<dr.originCount-1;i++) dr.origins[i]=dr.origins[i+1];
   dr.originCount--;

   // Convert remaining to targets
   for(int i=0;i<dr.originCount;i++)
   {  dr.origins[i].role=ROLE_TARGET;
      UpdateOriginVisual(i,dr,isBullish); }

   // Clear old CL
   DeleteObject(dr.corrLine.vertObjName);
   DeleteObject(dr.corrLine.horizObjName);
   DeleteObject(dr.corrLine.labelObjName);
   ClearAllInternals(dr);
   ClearPullbackStructure(dr);

   dr.corrLine.isActive=false; dr.corrLine.needsUpdate=false;
   dr.isDominant=false;

   // Switch direction
   g_isBullishActive = !isBullish;
   g_currentDirection = g_isBullishActive ? DIR_BULLISH : DIR_BEARISH;
   g_ctfDirection     = g_currentDirection;

   if(isBullish)
   {
      // Was Bullish → now Bearish
      g_bullDR.isDominant=false;
      g_bearDR.isDominant=true;
      g_bearDR.Reset();
      ArrayResize(g_bearDR.pullback.counters, InpMaxPullbackCounters);

      if(hadPB && pbCLPrice>0 && pbOrgPrice>0)
      {
         // A1-c: Pullback was bearish → promotes to bearish main
         // PB CL (LOW) → new Bearish CL
         // PB Origin (HIGH) → new Bearish Origin
         int pbBar = iBarShift(_Symbol,PERIOD_CURRENT,pbCLTime,false);
         SetupCorrectionLine(g_bearDR,false,pbCLPrice,pbCLTime,pbBar,InpInitScanBars);
         CreateFirstOrigin(g_bearDR,false,pbOrgPrice,pbOrgTime);
         Print("   PB PROMOTED: CL=",DoubleToString(pbCLPrice,_Digits),
               " Origin=",DoubleToString(pbOrgPrice,_Digits));
      }
      else
      {
         int lowBar=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,50,0);
         SetupCorrectionLine(g_bearDR,false,
            iLow(_Symbol,PERIOD_CURRENT,lowBar),
            iTime(_Symbol,PERIOD_CURRENT,lowBar),lowBar,InpInitScanBars);
         CreateFirstOrigin(g_bearDR,false,oldCL,oldCLTime);
      }
   }
   else
   {
      // Was Bearish → now Bullish
      g_bearDR.isDominant=false;
      g_bullDR.isDominant=true;
      g_bullDR.Reset();
      ArrayResize(g_bullDR.pullback.counters, InpMaxPullbackCounters);

      if(hadPB && pbCLPrice>0 && pbOrgPrice>0)
      {
         // A1-c: Pullback was bullish → promotes to bullish main
         // PB CL (HIGH) → new Bullish CL
         // PB Origin (LOW) → new Bullish Origin
         int pbBar = iBarShift(_Symbol,PERIOD_CURRENT,pbCLTime,false);
         SetupCorrectionLine(g_bullDR,true,pbCLPrice,pbCLTime,pbBar,InpInitScanBars);
         CreateFirstOrigin(g_bullDR,true,pbOrgPrice,pbOrgTime);
         Print("   PB PROMOTED: CL=",DoubleToString(pbCLPrice,_Digits),
               " Origin=",DoubleToString(pbOrgPrice,_Digits));
      }
      else
      {
         int highBar=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,50,0);
         SetupCorrectionLine(g_bullDR,true,
            iHigh(_Symbol,PERIOD_CURRENT,highBar),
            iTime(_Symbol,PERIOD_CURRENT,highBar),highBar,InpInitScanBars);
         CreateFirstOrigin(g_bullDR,true,oldCL,oldCLTime);
      }
   }

   UpdateEntryZone();
   SendAlert("🔄 "+dirLabel+" ChoCh at "+DoubleToString(brokenPrice,_Digits),false,false,true);
   g_forceDashboardUpdate=true;

}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 9: MAIN UPDATE FUNCTIONS  (MODIFIED)                    ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Update Single DR  (MODIFIED – pullback steps added)               |
//+------------------------------------------------------------------+
void UpdateSingleDR(SDealingRange &dr, bool isBullish)
{
   if(!dr.corrLine.isActive && !dr.corrLine.needsUpdate) return;
   double atr=GetATR(); if(atr<=0) return;

   // Step 1: CL update check
   if(dr.corrLine.needsUpdate)
   {  CheckCorrectionLineUpdate(dr,isBullish);
      if(dr.corrLine.needsUpdate){ TrackPendingExtreme(dr,isBullish); return; } }

   // Step 2: Internal levels
   DetectNewInternalLevels(dr, isBullish);

   // Step 2.5: Pullback counter-levels (NEW)
   DetectPullbackCounterLevels(dr, isBullish);

   // Step 3: Internal break status
   UpdateInternalsBrokenStatus(dr, isBullish);

   // Step 3.5: Pullback counter sweeps (NEW)
   CheckPullbackCounterSweeps(dr, isBullish);

   // Step 3.6: Track pullback sweep extreme (NEW)
   TrackPullbackSweepExtreme(dr, isBullish);

   // Step 4: External sweeps
   CheckExternalSweeps(dr, isBullish);

   // Step 5: Track external extreme
   if(dr.externalSwept) TrackExtremeReached(dr, isBullish);

   // Step 5.5: Detect pullback structure Mode A (NEW)
   DetectPullbackStructure(dr, isBullish);

   // Step 5.6: Track pullback CL (NEW)
   UpdatePullbackCL(dr, isBullish);

   // Step 5.7: Check pullback origin break A2-a (NEW)
   CheckPullbackOriginBreak(dr, isBullish);

   // Step 6: BOS
   CheckDR_BOS(dr, isBullish);

   // Step 7: ChoCh
   CheckDR_ChoCh(dr, isBullish);

   // Step 8: Dimming
   ApplyDistanceDimming(dr, isBullish);

   // Step 9: Extend lines
   ExtendDR_Lines(dr);
}

// UpdateDealingRangeSystem — UNCHANGED except pullback line extension
void UpdateDealingRangeSystem()
{
   if(!g_drInitialized) return;

   if(g_isBullishActive)
   {  if(g_bullDR.isActive) UpdateSingleDR(g_bullDR,true); }
   else
   {  if(g_bearDR.isActive) UpdateSingleDR(g_bearDR,false); }

   ExtendTargetLines(g_bullDR);
   ExtendTargetLines(g_bearDR);
   CheckTargetsReached();
   CheckDRTargetLinesReached();
   ExtendDRTargetLines();
   UpdateEntryZone();
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 10: ENTRY ZONE  (UNCHANGED)                             ║
// ╚══════════════════════════════════════════════════════════════════╝

void UpdateEntryZone()
{
   SDealingRange* dr = g_isBullishActive ? GetPointer(g_bullDR) : GetPointer(g_bearDR);
   g_entryZone.Reset();
   if(!dr.corrLine.isActive) return;
   g_entryZone.direction=g_currentDirection;
   g_entryZone.definedBy=LAYER_CTF;
   g_entryZone.startTime=dr.corrLine.verticalTime;

   if(g_isBullishActive)
   {  g_entryZone.upperBound=dr.corrLine.extremePrice;
      double lb=0;
      for(int i=dr.externalCount-1;i>=0;i--)
         if(dr.externals[i].status==DR_ACTIVE){ lb=dr.externals[i].price; break; }
      int ci=GetChochOriginIndex(dr);
      if(ci>=0 && (lb==0||dr.origins[ci].price>lb)) lb=dr.origins[ci].price;
      if(lb>0){ g_entryZone.lowerBound=lb; g_entryZone.isValid=true; } }
   else
   {  g_entryZone.lowerBound=dr.corrLine.extremePrice;
      double ub=0;
      for(int i=dr.externalCount-1;i>=0;i--)
         if(dr.externals[i].status==DR_ACTIVE){ ub=dr.externals[i].price; break; }
      int ci=GetChochOriginIndex(dr);
      if(ci>=0 && (ub==0||dr.origins[ci].price<ub)) ub=dr.origins[ci].price;
      if(ub>0){ g_entryZone.upperBound=ub; g_entryZone.isValid=true; } }

   if(g_entryZone.isValid && InpShowEntryZone)
   {  string zn=GenerateDRObjectName("EntryZone");
      datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
      DrawEntryZone(zn,g_entryZone.startTime,g_entryZone.upperBound,
         g_entryZone.lowerBound,ct,g_entryZone.direction); }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 11: LINE EXTENSION  (MODIFIED – pullback lines)         ║
// ╚══════════════════════════════════════════════════════════════════╝

void ExtendDR_Lines(SDealingRange &dr)
{
   if(dr.corrLine.isActive)
      ExtendLineToCurrent(dr.corrLine.horizObjName);

   for(int i=0;i<dr.externalCount;i++)
      if(!dr.externals[i].isReached) ExtendLineToCurrent(dr.externals[i].lineObjName);

   for(int i=0;i<dr.internalCount;i++)
      if(!dr.internals[i].isBroken) ExtendLineToCurrent(dr.internals[i].lineObjName);

   for(int i=0;i<dr.originCount;i++)
      if(!dr.origins[i].isReached) ExtendLineToCurrent(dr.origins[i].lineObjName);

   // ── NEW: Pullback lines ──
   if(dr.pullback.confirmed)
   {  ExtendLineToCurrent(dr.pullback.originLineObj);
      ExtendLineToCurrent(dr.pullback.clHorizObj); }

   for(int i=0;i<dr.pullback.counterCount;i++)
      if(!dr.pullback.counters[i].isConsumed)
         ExtendLineToCurrent(dr.pullback.counters[i].lineObjName);
}

void ExtendTargetLines(SDealingRange &dr)
{
   for(int i=0;i<dr.originCount;i++)
   {  if(dr.origins[i].isReached) continue;
      if(dr.origins[i].role==ROLE_TARGET)
         ExtendLineToCurrent(dr.origins[i].lineObjName); }
}

void CheckTargetsReached()
{
   double pH=g_prevBarHigh, pL=g_prevBarLow;
   datetime pT=g_prevBarTime;
   for(int i=0;i<g_bullDR.originCount;i++)
   {  if(g_bullDR.origins[i].role!=ROLE_TARGET||g_bullDR.origins[i].isReached) continue;
      if(pL<=g_bullDR.origins[i].price)
      {  g_bullDR.origins[i].isReached=true; g_bullDR.origins[i].reachedTime=pT;
         if(ObjectFind(0,g_bullDR.origins[i].lineObjName)>=0)
         {  ObjectSetInteger(0,g_bullDR.origins[i].lineObjName,OBJPROP_TIME,1,pT);
            ObjectSetInteger(0,g_bullDR.origins[i].lineObjName,OBJPROP_COLOR,clrDarkSlateGray); }
         Print("Target HIT: ",DoubleToString(g_bullDR.origins[i].price,_Digits)); } }
   for(int i=0;i<g_bearDR.originCount;i++)
   {  if(g_bearDR.origins[i].role!=ROLE_TARGET||g_bearDR.origins[i].isReached) continue;
      if(pH>=g_bearDR.origins[i].price)
      {  g_bearDR.origins[i].isReached=true; g_bearDR.origins[i].reachedTime=pT;
         if(ObjectFind(0,g_bearDR.origins[i].lineObjName)>=0)
         {  ObjectSetInteger(0,g_bearDR.origins[i].lineObjName,OBJPROP_TIME,1,pT);
            ObjectSetInteger(0,g_bearDR.origins[i].lineObjName,OBJPROP_COLOR,clrDarkSlateGray); }
         Print("Target HIT: ",DoubleToString(g_bearDR.origins[i].price,_Digits)); } }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 12: DR TARGET LINE MANAGEMENT  (UNCHANGED)              ║
// ╚══════════════════════════════════════════════════════════════════╝

void ReclassifyExternalsToTargetLines(SDealingRange &oldDR, bool wasBullish)
{
   ClearDRTargetLines();
   ENUM_TRADE_DIRECTION newDir = wasBullish ? DIR_BEARISH : DIR_BULLISH;
   double cp=iClose(_Symbol,PERIOD_CURRENT,0);

   for(int i=0;i<oldDR.externalCount;i++)
   {  if(oldDR.externals[i].status!=DR_ACTIVE) continue;
      bool ok=false;
      if(newDir==DIR_BEARISH && oldDR.externals[i].price<cp) ok=true;
      if(newDir==DIR_BULLISH && oldDR.externals[i].price>cp) ok=true;
      if(ok) AddDRTargetLine(oldDR.externals[i].price,oldDR.externals[i].time,
                             TARGET_FROM_EXT_IDMT,newDir); }
   for(int i=0;i<oldDR.originCount;i++)
   {  if(oldDR.origins[i].role==ROLE_TARGET && !oldDR.origins[i].isReached)
      {  bool ok=false;
         if(newDir==DIR_BEARISH && oldDR.origins[i].price<cp) ok=true;
         if(newDir==DIR_BULLISH && oldDR.origins[i].price>cp) ok=true;
         if(ok) AddDRTargetLine(oldDR.origins[i].price,oldDR.origins[i].time,
                                TARGET_FROM_ORIGIN,newDir); } }

   SortDRTargetsByProximity(cp,newDir);
   Print("═══ DR TARGETS RECLASSIFIED: ",g_drTargetLineCount," ═══");
}

void AddDRTargetLine(double price, datetime time, ENUM_TARGET_SOURCE source,
                     ENUM_TRADE_DIRECTION forDir)
{
   for(int i=0;i<g_drTargetLineCount;i++)
      if(MathAbs(g_drTargetLines[i].price-price)<_Point*5) return;
   if(g_drTargetLineCount>=g_maxDRTargetLines) return;
   int idx=g_drTargetLineCount;
   g_drTargetLines[idx].Reset();
   g_drTargetLines[idx].price=price; g_drTargetLines[idx].time=time;
   g_drTargetLines[idx].source=source; g_drTargetLines[idx].forDirection=forDir;
   g_drTargetLines[idx].lineObjName=GenerateDRObjectName("DRT");
   g_drTargetLines[idx].labelObjName=g_drTargetLines[idx].lineObjName+"_lbl";
   g_drTargetLineCount++;
   if(InpShowDR_TargetLines) DrawDR_TargetLine(idx);
}

void SortDRTargetsByProximity(double refPrice, ENUM_TRADE_DIRECTION tradeDir)
{
   for(int i=0;i<g_drTargetLineCount;i++)
      g_drTargetLines[i].distanceFromEntry=MathAbs(g_drTargetLines[i].price-refPrice);
   for(int i=0;i<g_drTargetLineCount-1;i++)
      for(int j=0;j<g_drTargetLineCount-i-1;j++)
         if(g_drTargetLines[j].distanceFromEntry>g_drTargetLines[j+1].distanceFromEntry)
         {  SDR_TargetLine tmp=g_drTargetLines[j];
            g_drTargetLines[j]=g_drTargetLines[j+1];
            g_drTargetLines[j+1]=tmp; }
}

bool GetDRTargetPrices(double entryPrice, bool isBullish,
                       double &tp1, double &tp2, double &tp3)
{
   tp1=0; tp2=0; tp3=0;
   ENUM_TRADE_DIRECTION td = isBullish ? DIR_BULLISH : DIR_BEARISH;
   SortDRTargetsByProximity(entryPrice,td);
   int assigned=0;
   for(int i=0;i<g_drTargetLineCount && assigned<3;i++)
   {  if(g_drTargetLines[i].isReached) continue;
      if(g_drTargetLines[i].forDirection!=td) continue;
      if(isBullish && g_drTargetLines[i].price<=entryPrice) continue;
      if(!isBullish && g_drTargetLines[i].price>=entryPrice) continue;
      assigned++;
      if(assigned==1) tp1=g_drTargetLines[i].price;
      else if(assigned==2) tp2=g_drTargetLines[i].price;
      else tp3=g_drTargetLines[i].price; }
   return (assigned>=1);
}

void CheckDRTargetLinesReached()
{
   if(g_drTargetLineCount==0) return;
   double pH=g_prevBarHigh, pL=g_prevBarLow, bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   for(int i=0;i<g_drTargetLineCount;i++)
   {  if(g_drTargetLines[i].isReached) continue;
      bool hit=false;
      if(g_drTargetLines[i].forDirection==DIR_BEARISH)
         hit=(bid<=g_drTargetLines[i].price||pL<=g_drTargetLines[i].price);
      else if(g_drTargetLines[i].forDirection==DIR_BULLISH)
         hit=(bid>=g_drTargetLines[i].price||pH>=g_drTargetLines[i].price);
      if(hit)
      {  g_drTargetLines[i].isReached=true;
         g_drTargetLines[i].reachedTime=TimeCurrent();
         if(ObjectFind(0,g_drTargetLines[i].lineObjName)>=0)
         {  ObjectSetInteger(0,g_drTargetLines[i].lineObjName,OBJPROP_TIME,1,
               g_drTargetLines[i].reachedTime);
            ObjectSetInteger(0,g_drTargetLines[i].lineObjName,OBJPROP_COLOR,clrDarkSlateGray);
            ObjectSetInteger(0,g_drTargetLines[i].lineObjName,OBJPROP_STYLE,STYLE_DOT); }
         Print("🎯 DR Target REACHED: ",DoubleToString(g_drTargetLines[i].price,_Digits)); } }
}

void DrawDR_TargetLine(int index)
{
   if(index>=g_drTargetLineCount) return;
   double atr=GetATRSafe(); if(atr<=0) return;
   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   bool isBull=(g_drTargetLines[index].forDirection==DIR_BULLISH);
   string st=(g_drTargetLines[index].source==TARGET_FROM_EXT_IDMT)
             ?"IDMT\x2192Target":"Org\x2192Target";
   string lt=BuildDRLabel(LAYER_CTF,isBull,st,
      DoubleToString(g_drTargetLines[index].price,_Digits));
   DrawTrendLine(g_drTargetLines[index].lineObjName,
      g_drTargetLines[index].time, g_drTargetLines[index].price,
      ct, g_drTargetLines[index].price,
      InpDR_TargetLineColor, 2, STYLE_DASH, false);
   double off=isBull?atr*0.1:-atr*0.1;
   DrawText(g_drTargetLines[index].labelObjName,
      g_drTargetLines[index].time, g_drTargetLines[index].price+off,
      lt, InpDR_TargetLineColor, 8, ANCHOR_LEFT, "Arial Bold");
}

void ClearDRTargetLines()
{
   for(int i=0;i<g_drTargetLineCount;i++)
   {  DeleteObject(g_drTargetLines[i].lineObjName);
      DeleteObject(g_drTargetLines[i].labelObjName); }
   g_drTargetLineCount=0;
}

void ExtendDRTargetLines()
{
   for(int i=0;i<g_drTargetLineCount;i++)
      if(!g_drTargetLines[i].isReached)
         ExtendLineToCurrent(g_drTargetLines[i].lineObjName);
}

int CountUnreachedDRTargets(ENUM_TRADE_DIRECTION dir)
{
   int c=0;
   for(int i=0;i<g_drTargetLineCount;i++)
      if(!g_drTargetLines[i].isReached && g_drTargetLines[i].forDirection==dir) c++;
   return c;
}

#endif // ICT_DEALINGRANGE_MQH