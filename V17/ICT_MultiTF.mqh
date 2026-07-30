//+------------------------------------------------------------------+
//|                        ICT_MultiTF.mqh                            |
//|         Multi-Timeframe DR + Pullback Sub-Structure               |
//|         "ICT Unified Professional EA v18"                         |
//+------------------------------------------------------------------+
#ifndef ICT_MULTITF_MQH
#define ICT_MULTITF_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../Core/ICT_Utilities.mqh"
#include "../UI/ICT_Drawing.mqh"
#include "ICT_DealingRange.mqh"

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 1: INITIALIZATION                                       ║
// ╚══════════════════════════════════════════════════════════════════╝

bool InitializeMultiTF()
{
   g_htfLayer.Reset();
   g_htfLayer.timeframe=InpHTF_Timeframe; g_htfLayer.layer=LAYER_HTF;
   g_htfLayer.isEnabled=InpEnableHTF;
   if(InpEnableHTF)
   {  g_htfLayer.atrHandle=iATR(_Symbol,InpHTF_Timeframe,50);
      ArraySetAsSeries(g_htfLayer.atrBuffer,true);
      SetupMTFVisual(g_htfLayer,LAYER_HTF);
      ArrayResize(g_htfLayer.bullDR.origins,InpMaxOriginsTrack);
      ArrayResize(g_htfLayer.bullDR.externals,InpMaxExtInducements);
      ArrayResize(g_htfLayer.bullDR.internals,20);
      ArrayResize(g_htfLayer.bearDR.origins,InpMaxOriginsTrack);
      ArrayResize(g_htfLayer.bearDR.externals,InpMaxExtInducements);
      ArrayResize(g_htfLayer.bearDR.internals,20);
      // NEW: pullback arrays
      ArrayResize(g_htfLayer.bullDR.pullback.counters,InpMaxPullbackCounters);
      ArrayResize(g_htfLayer.bearDR.pullback.counters,InpMaxPullbackCounters);
   }

   g_ctfLayer.Reset();
   g_ctfLayer.timeframe=PERIOD_CURRENT; g_ctfLayer.layer=LAYER_CTF;
   g_ctfLayer.isEnabled=true; g_ctfLayer.isInitialized=true;
   SetupMTFVisual(g_ctfLayer,LAYER_CTF);

   g_ltfLayer.Reset();
   g_ltfLayer.timeframe=InpLTF_Timeframe; g_ltfLayer.layer=LAYER_LTF;
   g_ltfLayer.isEnabled=InpEnableLTF;
   if(InpEnableLTF)
   {  g_ltfLayer.atrHandle=iATR(_Symbol,InpLTF_Timeframe,50);
      ArraySetAsSeries(g_ltfLayer.atrBuffer,true);
      SetupMTFVisual(g_ltfLayer,LAYER_LTF);
      ArrayResize(g_ltfLayer.bullDR.origins,InpMaxOriginsTrack);
      ArrayResize(g_ltfLayer.bullDR.externals,InpMaxExtInducements);
      ArrayResize(g_ltfLayer.bullDR.internals,20);
      ArrayResize(g_ltfLayer.bearDR.origins,InpMaxOriginsTrack);
      ArrayResize(g_ltfLayer.bearDR.externals,InpMaxExtInducements);
      ArrayResize(g_ltfLayer.bearDR.internals,20);
      // NEW: pullback arrays
      ArrayResize(g_ltfLayer.bullDR.pullback.counters,InpMaxPullbackCounters);
      ArrayResize(g_ltfLayer.bearDR.pullback.counters,InpMaxPullbackCounters);
   }

   g_mtfInitialized=true;
   Print("Multi-TF initialized: HTF=",TFToString(InpHTF_Timeframe),
         " CTF=",TFToString((ENUM_TIMEFRAMES)Period()),
         " LTF=",TFToString(InpLTF_Timeframe));
   return true;
}

// SetupMTFVisual — UNCHANGED
void SetupMTFVisual(SMTFLayer &layer, ENUM_TF_LAYER layerType)
{
   string tfName=TFToString(layer.timeframe);
   switch(layerType)
   {
      case LAYER_HTF:
         layer.visual.lineWidth=4; layer.visual.lineStyle=STYLE_SOLID;
         layer.visual.labelSize=11;
         layer.visual.bullCL=InpBullCL_Color; layer.visual.bearCL=InpBearCL_Color;
         layer.visual.originColor=InpOriginChochColor;
         layer.visual.extColor=InpExtInducementColor;
         layer.visual.intColor=InpInternalLevelColor;
         layer.visual.targetColor=InpOriginTargetColor;
         layer.visual.prefix=g_prefix+"HTF_"; layer.visual.tfLabel="HTF."+tfName;
         break;
      case LAYER_CTF:
         layer.visual.lineWidth=2; layer.visual.lineStyle=STYLE_SOLID;
         layer.visual.labelSize=9;
         layer.visual.bullCL=InpBullCL_Color; layer.visual.bearCL=InpBearCL_Color;
         layer.visual.originColor=InpOriginChochColor;
         layer.visual.extColor=InpExtInducementColor;
         layer.visual.intColor=InpInternalLevelColor;
         layer.visual.targetColor=InpOriginTargetColor;
         layer.visual.prefix=g_drPrefix; layer.visual.tfLabel="CTF."+tfName;
         break;
      case LAYER_LTF:
         layer.visual.lineWidth=1; layer.visual.lineStyle=STYLE_DOT;
         layer.visual.labelSize=7;
         layer.visual.bullCL=ColorDarken(InpBullCL_Color,30);
         layer.visual.bearCL=ColorDarken(InpBearCL_Color,30);
         layer.visual.originColor=ColorDarken(InpOriginChochColor,30);
         layer.visual.extColor=ColorDarken(InpExtInducementColor,30);
         layer.visual.intColor=ColorDarken(InpInternalLevelColor,30);
         layer.visual.targetColor=ColorDarken(InpOriginTargetColor,30);
         layer.visual.prefix=g_prefix+"LTF_"; layer.visual.tfLabel="LTF."+tfName;
         break;
   }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 2: ATR & INITIAL SCAN                                   ║
// ╚══════════════════════════════════════════════════════════════════╝

bool UpdateLayerATR(SMTFLayer &layer)
{  if(layer.atrHandle==INVALID_HANDLE) return false;
   return (CopyBuffer(layer.atrHandle,0,0,10,layer.atrBuffer)>0); }

double GetLayerATR(SMTFLayer &layer, int index=0)
{  if(ArraySize(layer.atrBuffer)>index) return layer.atrBuffer[index];
   return 0; }

void ScanLayerInitialStructure(SMTFLayer &layer)
{
   ENUM_TIMEFRAMES tf=layer.timeframe;
   int ba=iBars(_Symbol,tf);
   int scanBars=MathMin(InpInitScanBars,ba-50);
   if(scanBars<30){ Print("MTF: Not enough bars for ",layer.visual.tfLabel); return; }

   int hBar=TF_Highest(tf,scanBars,1);
   int lBar=TF_Lowest(tf,scanBars,1);
   double hP=TF_High(tf,hBar), lP=TF_Low(tf,lBar);
   bool initBull=(TF_Close(tf,0)>(hP+lP)/2.0);
   layer.isBullishActive=initBull;

   if(initBull)
   {  SetupLayerCorrectionLine(layer,layer.bullDR,true,hP,TF_Time(tf,hBar),hBar,scanBars);
      CreateLayerFirstOrigin(layer,layer.bullDR,true,lP,TF_Time(tf,lBar));
      layer.bullDR.isDominant=true; layer.bearDR.isDominant=false; layer.bearDR.isActive=false; }
   else
   {  SetupLayerCorrectionLine(layer,layer.bearDR,false,lP,TF_Time(tf,lBar),lBar,scanBars);
      CreateLayerFirstOrigin(layer,layer.bearDR,false,hP,TF_Time(tf,hBar));
      layer.bearDR.isDominant=true; layer.bullDR.isDominant=false; layer.bullDR.isActive=false; }

   layer.isInitialized=true;
   Print(layer.visual.tfLabel," initialized: ",(initBull?"BULLISH":"BEARISH"));
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 3: LAYER CL SETUP & UPDATE                              ║
// ╚══════════════════════════════════════════════════════════════════╝

void SetupLayerCorrectionLine(SMTFLayer &layer, SDealingRange &dr,
   bool isBullish, double extremePrice, datetime extremeTime,
   int extremeBar, int scanRange)
{
   dr.corrLine.extremePrice=extremePrice; dr.corrLine.extremeTime=extremeTime;
   dr.corrLine.verticalTime=extremeTime;  dr.corrLine.isActive=true;
   dr.corrLine.needsUpdate=false; dr.corrLine.pendingExtreme=0;
   dr.corrLine.pendingExtremeTime=0;
   dr.timeframe=layer.timeframe; dr.tfLayer=layer.layer; dr.isActive=true;

   if(InpShowCorrectionLines) DrawLayerCL(layer,dr,isBullish);
   ScanLayerExternals(layer,dr,isBullish,extremeTime,extremeBar,scanRange);

   // Initialize pullback
   ClearLayerInternals(layer,dr);
   ClearLayerPullbackStructure(layer,dr);
}

//+------------------------------------------------------------------+
//| Update layer CL after BOS (NEW)                                   |
//+------------------------------------------------------------------+
void CheckLayerCLUpdate(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(!dr.corrLine.needsUpdate) return;
   ENUM_TIMEFRAMES tf=layer.timeframe;

   // Track pending extreme
   if(isBullish)
   {  double h=TF_High(tf,1);
      if(h>dr.corrLine.pendingExtreme)
      {  dr.corrLine.pendingExtreme=h;
         dr.corrLine.pendingExtremeTime=TF_Time(tf,1); } }
   else
   {  double l=TF_Low(tf,1);
      if(dr.corrLine.pendingExtreme==0||l<dr.corrLine.pendingExtreme)
      {  dr.corrLine.pendingExtreme=l;
         dr.corrLine.pendingExtremeTime=TF_Time(tf,1); } }

   // Immediate update for MTF (simplified)
   if(dr.corrLine.pendingExtreme>0 && dr.corrLine.pendingExtremeTime>0)
      UpdateLayerCorrectionLine(layer,dr,isBullish,
         dr.corrLine.pendingExtreme,dr.corrLine.pendingExtremeTime);
}

//+------------------------------------------------------------------+
//| Apply layer CL update (NEW)                                       |
//+------------------------------------------------------------------+
void UpdateLayerCorrectionLine(SMTFLayer &layer, SDealingRange &dr,
   bool isBullish, double newExtreme, datetime newTime)
{
   DeleteObject(dr.corrLine.vertObjName);
   DeleteObject(dr.corrLine.horizObjName);
   DeleteObject(dr.corrLine.labelObjName);

   dr.corrLine.extremePrice=newExtreme; dr.corrLine.extremeTime=newTime;
   dr.corrLine.verticalTime=newTime;    dr.corrLine.needsUpdate=false;
   dr.corrLine.pendingExtreme=0; dr.corrLine.pendingExtremeTime=0;

   if(InpShowCorrectionLines) DrawLayerCL(layer,dr,isBullish);
   ClearLayerInternals(layer,dr);
   ClearLayerPullbackStructure(layer,dr);

   dr.externalSwept=false; dr.extremeReached=0; dr.sweepTime=0;
}

//+------------------------------------------------------------------+
//| Update layer CL vertical span (NEW)                               |
//+------------------------------------------------------------------+
void UpdateLayerCLVertical(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(dr.corrLine.vertObjName=="" || ObjectFind(0,dr.corrLine.vertObjName)<0) return;
   double atr=GetLayerATR(layer); if(atr<=0) atr=GetATRSafe();
   double top,bottom;
   int ci=-1;
   for(int i=0;i<dr.originCount;i++)
      if(dr.origins[i].role==ROLE_CHOCH){ ci=i; break; }

   if(isBullish){ top=dr.corrLine.extremePrice;
      bottom=(ci>=0)?dr.origins[ci].price:top-atr*3; }
   else         { bottom=dr.corrLine.extremePrice;
      top=(ci>=0)?dr.origins[ci].price:bottom+atr*3; }

   int off=MathMax(1,PeriodSeconds(layer.timeframe)/4);
   ObjectSetInteger(0,dr.corrLine.vertObjName,OBJPROP_TIME,0,dr.corrLine.verticalTime);
   ObjectSetInteger(0,dr.corrLine.vertObjName,OBJPROP_TIME,1,dr.corrLine.verticalTime+off);
   ObjectSetDouble(0,dr.corrLine.vertObjName,OBJPROP_PRICE,0,bottom);
   ObjectSetDouble(0,dr.corrLine.vertObjName,OBJPROP_PRICE,1,top);
   ObjectSetInteger(0,dr.corrLine.vertObjName,OBJPROP_WIDTH,GetMainCLWidth(layer.layer));
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 4: LAYER ORIGIN MANAGEMENT (MODIFIED)                   ║
// ╚══════════════════════════════════════════════════════════════════╝

void CreateLayerFirstOrigin(SMTFLayer &layer, SDealingRange &dr,
   bool isBullish, double price, datetime time)
{
   int idx=dr.originCount;
   if(idx>=ArraySize(dr.origins)) ArrayResize(dr.origins,idx+3);
   dr.origins[idx].Reset();
   dr.origins[idx].price=price; dr.origins[idx].time=time;
   dr.origins[idx].role=ROLE_CHOCH; dr.origins[idx].isFromSweep=true;
   dr.origins[idx].lineObjName=layer.visual.prefix+"Origin_"+IntegerToString(g_objCount++);
   dr.origins[idx].labelObjName=dr.origins[idx].lineObjName+"_lbl";
   dr.originCount++;
   if(InpShowDR_Origins) DrawLayerOrigin(layer,idx,dr,isBullish);
   UpdateLayerCLVertical(layer,dr,isBullish);                // ← NEW
}

//+------------------------------------------------------------------+
//| Create Layer Origin with demotion (NEW)                           |
//+------------------------------------------------------------------+
void CreateLayerOrigin(SMTFLayer &layer, SDealingRange &dr,
   double price, datetime time, bool isBullish)
{
   // Demote existing CHOCH → TARGET
   for(int i=0;i<dr.originCount;i++)
   {  if(dr.origins[i].role==ROLE_CHOCH)
      {  dr.origins[i].role=ROLE_TARGET;
         DrawLayerOrigin(layer,i,dr,isBullish); } }

   // Capacity check
   if(dr.originCount>=InpMaxOriginsTrack)
   {  int oI=-1; datetime oT=D'2099.01.01';
      for(int i=0;i<dr.originCount;i++)
         if(dr.origins[i].role==ROLE_TARGET&&dr.origins[i].time<oT){ oT=dr.origins[i].time; oI=i; }
      if(oI>=0)
      {  DeleteObject(dr.origins[oI].lineObjName);
         DeleteObject(dr.origins[oI].labelObjName);
         for(int i=oI;i<dr.originCount-1;i++) dr.origins[i]=dr.origins[i+1];
         dr.originCount--; } }

   CreateLayerFirstOrigin(layer,dr,isBullish,price,time);
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 5: LAYER EXTERNAL MANAGEMENT (UNCHANGED except pivots)  ║
// ╚══════════════════════════════════════════════════════════════════╝

void ScanLayerExternals(SMTFLayer &layer, SDealingRange &dr,
   bool isBullish, datetime clTime, int clBar, int maxBars)
{
   ENUM_TIMEFRAMES tf=layer.timeframe;
   int lB=InpDR_ExtPivotLeftBars, rB=InpDR_ExtPivotRightBars;
   int ba=TF_Bars(tf);
   double atr=GetLayerATR(layer); if(atr<=0) return;

   for(int i=rB+1;i<maxBars&&dr.externalCount<InpMaxExtInducements;i++)
   {  if(i+lB>=ba) break;
      datetime bT=TF_Time(tf,i); if(bT>=clTime) continue;
      bool isP=false; double pr=0;
      if(isBullish){ isP=IsPivotLow(tf,i,lB,rB); if(isP) pr=TF_Low(tf,i); }
      else         { isP=IsPivotHigh(tf,i,lB,rB); if(isP) pr=TF_High(tf,i); }
      if(!isP) continue;
      if(isBullish&&pr>=dr.corrLine.extremePrice) continue;
      if(!isBullish&&pr<=dr.corrLine.extremePrice) continue;
      if(IsLevelBroken(tf,pr,isBullish,i)) continue;
      double depth=CalculateSwingDepth(tf,i,isBullish,lB,rB);
      if(depth<atr*InpExtMinDepthATR) continue;
      double minD=atr*InpExtMinDistanceATR; bool tc=false;
      for(int k=0;k<dr.externalCount;k++)
         if(MathAbs(dr.externals[k].price-pr)<minD){ tc=true; break; }
      if(tc) continue;
      AddLayerExternal(layer,dr,pr,bT,i,isBullish); }
}

void AddLayerExternal(SMTFLayer &layer, SDealingRange &dr,
   double price, datetime time, int barIndex, bool isBullish)
{
   for(int i=0;i<dr.externalCount;i++)
      if(MathAbs(dr.externals[i].price-price)<_Point*10) return;
   if(dr.externalCount>=InpMaxExtInducements) return;
   int idx=dr.externalCount;
   if(idx>=ArraySize(dr.externals)) ArrayResize(dr.externals,idx+5);
   dr.externals[idx].Reset();
   dr.externals[idx].price=price; dr.externals[idx].time=time;
   dr.externals[idx].barIndex=barIndex; dr.externals[idx].status=DR_ACTIVE;
   dr.externals[idx].lineObjName=layer.visual.prefix+"Ext_"+IntegerToString(g_objCount++);
   dr.externals[idx].labelObjName=dr.externals[idx].lineObjName+"_lbl";
   dr.externalCount++;
   if(InpShowDR_Externals) DrawLayerExternal(layer,idx,dr,isBullish);
}

void CheckLayerExternalSweeps(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   ENUM_TIMEFRAMES tf=layer.timeframe;
   double pH=TF_High(tf,1), pL=TF_Low(tf,1), pC=TF_Close(tf,1);
   for(int i=dr.externalCount-1;i>=0;i--)
   {  if(dr.externals[i].status!=DR_ACTIVE) continue;
      bool consumed=false; double eP=dr.externals[i].price;
      if(isBullish) consumed=((pL<=eP&&pC>eP)||(pC<=eP));
      else          consumed=((pH>=eP&&pC<eP)||(pC>=eP));
      if(consumed)
      {  dr.externalSwept=true; dr.sweepTime=TF_Time(tf,1);
         if(isBullish){ int db=TF_Lowest(tf,10,1); double dl=TF_Low(tf,db);
            if(dr.extremeReached==0||dl<dr.extremeReached) dr.extremeReached=dl; }
         else         { int hb=TF_Highest(tf,10,1); double hh=TF_High(tf,hb);
            if(dr.extremeReached==0||hh>dr.extremeReached) dr.extremeReached=hh; }
         DeleteObject(dr.externals[i].lineObjName);
         DeleteObject(dr.externals[i].labelObjName);
         for(int j=i;j<dr.externalCount-1;j++) dr.externals[j]=dr.externals[j+1];
         dr.externalCount--; } }
}

void TrackLayerExtreme(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   ENUM_TIMEFRAMES tf=layer.timeframe;
   if(isBullish){ double l=TF_Low(tf,1);
      if(dr.extremeReached==0||l<dr.extremeReached) dr.extremeReached=l; }
   else         { double h=TF_High(tf,1);
      if(dr.extremeReached==0||h>dr.extremeReached) dr.extremeReached=h; }
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 6: LAYER INTERNAL MANAGEMENT (ALL NEW)                  ║
// ╚══════════════════════════════════════════════════════════════════╝

void AddLayerInternal(SMTFLayer &layer, SDealingRange &dr,
   double price, datetime time, bool isBullish)
{
   for(int i=0;i<dr.internalCount;i++)
      if(MathAbs(dr.internals[i].price-price)<_Point*10) return;
   int idx=dr.internalCount;
   if(idx>=ArraySize(dr.internals)) ArrayResize(dr.internals,idx+5);
   dr.internals[idx].Reset();
   dr.internals[idx].price=price; dr.internals[idx].time=time;
   dr.internals[idx].lineObjName=layer.visual.prefix+"Int_"+IntegerToString(g_objCount++);
   dr.internals[idx].labelObjName=dr.internals[idx].lineObjName+"_lbl";
   dr.internalCount++;
   // MTF internals: no chart drawing (keep clean)
}

void DetectLayerInternalLevels(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   ENUM_TIMEFRAMES tf=layer.timeframe;
   int cb=InpDR_IntPivotRightBars; if(cb<1) cb=1;
   datetime clT=dr.corrLine.verticalTime;

   if(isBullish)
   {  if(IsPivotLow(tf,cb,InpDR_IntPivotLeftBars,InpDR_IntPivotRightBars))
      {  datetime pt=TF_Time(tf,cb);
         if(pt>clT){ double p=TF_Low(tf,cb);
            if(p<dr.corrLine.extremePrice)
               AddLayerInternal(layer,dr,p,pt,isBullish); } } }
   else
   {  if(IsPivotHigh(tf,cb,InpDR_IntPivotLeftBars,InpDR_IntPivotRightBars))
      {  datetime pt=TF_Time(tf,cb);
         if(pt>clT){ double p=TF_High(tf,cb);
            if(p>dr.corrLine.extremePrice)
               AddLayerInternal(layer,dr,p,pt,isBullish); } } }
}

void UpdateLayerInternalsBroken(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   ENUM_TIMEFRAMES tf=layer.timeframe;
   double pL=TF_Low(tf,1), pH=TF_High(tf,1);
   datetime pT=TF_Time(tf,1);
   for(int i=0;i<dr.internalCount;i++)
   {  if(dr.internals[i].isBroken) continue;
      bool broken=false;
      if(isBullish){ if(pL<dr.internals[i].price) broken=true; }
      else         { if(pH>dr.internals[i].price) broken=true; }
      if(broken){ dr.internals[i].isBroken=true; dr.internals[i].brokenTime=pT; } }
}

void ClearLayerInternals(SMTFLayer &layer, SDealingRange &dr)
{
   for(int i=0;i<dr.internalCount;i++)
   {  DeleteObject(dr.internals[i].lineObjName);
      DeleteObject(dr.internals[i].labelObjName); }
   dr.internalCount=0;
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 7: LAYER PULLBACK DETECTION (ALL NEW)                   ║
// ╚══════════════════════════════════════════════════════════════════╝

void AddLayerPullbackCounter(SMTFLayer &layer, SDealingRange &dr,
   double price, datetime time, int barIndex, bool mainIsBullish)
{
   for(int i=0;i<dr.pullback.counterCount;i++)
      if(MathAbs(dr.pullback.counters[i].price-price)<_Point*10) return;
   if(dr.pullback.counterCount>=InpMaxPullbackCounters) return;
   int idx=dr.pullback.counterCount;
   if(idx>=ArraySize(dr.pullback.counters))
      ArrayResize(dr.pullback.counters,idx+5);
   dr.pullback.counters[idx].Reset();
   dr.pullback.counters[idx].price=price; dr.pullback.counters[idx].time=time;
   dr.pullback.counters[idx].barIndex=barIndex;
   dr.pullback.counters[idx].lineObjName=layer.visual.prefix+"PB_Cnt_"+IntegerToString(g_objCount++);
   dr.pullback.counters[idx].labelObjName=dr.pullback.counters[idx].lineObjName+"_lbl";
   dr.pullback.counterCount++;
   if(InpShowPullbackCounters && layer.layer==LAYER_HTF)
      DrawLayerPullbackCounter(layer,idx,dr,mainIsBullish);
}

void DetectLayerPullbackCounters(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure || !dr.corrLine.isActive) return;
   ENUM_TIMEFRAMES tf=layer.timeframe;
   int cb=InpDR_IntPivotRightBars; if(cb<1) cb=1;
   datetime clT=dr.corrLine.verticalTime;

   if(isBullish)
   {  // Bull main → bear pullback → counter = pivot HIGH
      if(IsPivotHigh(tf,cb,InpDR_IntPivotLeftBars,InpDR_IntPivotRightBars))
      {  datetime pt=TF_Time(tf,cb);
         if(pt>clT){ double p=TF_High(tf,cb);
            if(p<dr.corrLine.extremePrice)
               AddLayerPullbackCounter(layer,dr,p,pt,cb,isBullish); } } }
   else
   {  // Bear main → bull pullback → counter = pivot LOW
      if(IsPivotLow(tf,cb,InpDR_IntPivotLeftBars,InpDR_IntPivotRightBars))
      {  datetime pt=TF_Time(tf,cb);
         if(pt>clT){ double p=TF_Low(tf,cb);
            if(p>dr.corrLine.extremePrice)
               AddLayerPullbackCounter(layer,dr,p,pt,cb,isBullish); } } }
}

void CheckLayerPullbackSweeps(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure) return;
   ENUM_TIMEFRAMES tf=layer.timeframe;
   double pH=TF_High(tf,1), pL=TF_Low(tf,1), pC=TF_Close(tf,1);

   for(int i=dr.pullback.counterCount-1;i>=0;i--)
   {  if(dr.pullback.counters[i].isConsumed) continue;
      bool consumed=false; double cP=dr.pullback.counters[i].price;
      if(isBullish) consumed=((pH>=cP&&pC<cP)||(pC>=cP));   // counter=HIGH swept above
      else          consumed=((pL<=cP&&pC>cP)||(pC<=cP));   // counter=LOW swept below
      if(consumed)
      {  dr.pullback.counters[i].isConsumed=true;
         dr.pullback.counters[i].consumedTime=TF_Time(tf,1);
         dr.pullback.sweepPending=true;
         dr.pullback.sweepTime=TF_Time(tf,1);
         if(isBullish){ if(pH>dr.pullback.sweepExtreme) dr.pullback.sweepExtreme=pH; }
         else         { if(dr.pullback.sweepExtreme==0||pL<dr.pullback.sweepExtreme)
                           dr.pullback.sweepExtreme=pL; }
         if(ObjectFind(0,dr.pullback.counters[i].lineObjName)>=0)
         {  ObjectSetInteger(0,dr.pullback.counters[i].lineObjName,OBJPROP_COLOR,clrDarkSlateGray);
            ObjectSetInteger(0,dr.pullback.counters[i].lineObjName,OBJPROP_STYLE,STYLE_DOT); }
         Print(layer.visual.tfLabel," PB Counter SWEPT at ",DoubleToString(cP,_Digits)); } }
}

void TrackLayerPullbackSweepExtreme(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(!dr.pullback.sweepPending) return;
   ENUM_TIMEFRAMES tf=layer.timeframe;
   if(isBullish){ double h=TF_High(tf,1);
      if(h>dr.pullback.sweepExtreme) dr.pullback.sweepExtreme=h; }
   else         { double l=TF_Low(tf,1);
      if(dr.pullback.sweepExtreme==0||l<dr.pullback.sweepExtreme)
         dr.pullback.sweepExtreme=l; }
}

void DetectLayerPullbackStructure(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure || !dr.pullback.sweepPending) return;

   for(int i=0;i<dr.internalCount;i++)
   {  if(!dr.internals[i].isBroken) continue;
      if(dr.internals[i].brokenTime<dr.pullback.sweepTime) continue;

      if(dr.pullback.confirmed)
      {  // Replace origin
         dr.pullback.originPrice=dr.pullback.sweepExtreme;
         dr.pullback.originTime=dr.pullback.sweepTime;
         dr.pullback.sweepPending=false;
         if(InpShowPullbackOrigin) DrawLayerPullbackOrigin(layer,dr,isBullish);
         Print(layer.visual.tfLabel," PB Origin UPDATED → ",
               DoubleToString(dr.pullback.originPrice,_Digits)); }
      else
      {  // First confirmation
         dr.pullback.confirmed=true; dr.pullback.active=true;
         dr.pullback.originPrice=dr.pullback.sweepExtreme;
         dr.pullback.originTime=dr.pullback.sweepTime;
         dr.pullback.sweepPending=false;
         if(InpShowPullbackOrigin) DrawLayerPullbackOrigin(layer,dr,isBullish);
         if(InpShowPullbackCL) DrawLayerPullbackCL(layer,dr,isBullish);
         Print("═══ ",layer.visual.tfLabel," PULLBACK MODE A ═══");
         g_forceDashboardUpdate=true; }
      break; }
}

void UpdateLayerPullbackCL(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(!InpDetectPullbackStructure || !dr.corrLine.isActive) return;
   ENUM_TIMEFRAMES tf=layer.timeframe;
   double pH=TF_High(tf,1), pL=TF_Low(tf,1);
   bool updated=false;

   if(isBullish)
   {  if(dr.pullback.clPrice==0||pL<dr.pullback.clPrice)
      {  dr.pullback.clPrice=pL; dr.pullback.clTime=TF_Time(tf,1); updated=true; } }
   else
   {  if(pH>dr.pullback.clPrice)
      {  dr.pullback.clPrice=pH; dr.pullback.clTime=TF_Time(tf,1); updated=true; } }

   if(updated && dr.pullback.confirmed && InpShowPullbackCL)
      DrawLayerPullbackCL(layer,dr,isBullish);
}

void CheckLayerPullbackOriginBreak(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(!dr.pullback.confirmed || !dr.pullback.active) return;
   ENUM_TIMEFRAMES tf=layer.timeframe;
   bool broken=false;

   if(isBullish) broken=CheckBreak(tf,dr.pullback.originPrice,true);  // counter=HIGH break above
   else          broken=CheckBreak(tf,dr.pullback.originPrice,false); // counter=LOW break below

   if(!broken) return;
   double pbPeak=dr.pullback.clPrice;
   datetime pbPeakTime=dr.pullback.clTime;

   Print("═══ ",layer.visual.tfLabel," PB ORIGIN BROKEN (A2-a) ═══");
   Print("  PB Peak → Origin: ",DoubleToString(pbPeak,_Digits));

   CreateLayerOrigin(layer,dr,pbPeak,pbPeakTime,isBullish);
   ClearLayerPullbackStructure(layer,dr);
   g_forceDashboardUpdate=true;
}

void ClearLayerPullbackStructure(SMTFLayer &layer, SDealingRange &dr)
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
   ArrayResize(dr.pullback.counters,InpMaxPullbackCounters);
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 8: LAYER DRAWING (MODIFIED)                             ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Draw Layer CL (MODIFIED – vertical segment + configurable width)  |
//+------------------------------------------------------------------+
void DrawLayerCL(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   double atr=GetLayerATR(layer); if(atr<=0) atr=GetATRSafe();
   color clColor=isBullish?layer.visual.bullCL:layer.visual.bearCL;
   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);

   dr.corrLine.vertObjName =layer.visual.prefix+"CL_V_"+IntegerToString(g_objCount++);
   dr.corrLine.horizObjName=layer.visual.prefix+"CL_H_"+IntegerToString(g_objCount++);
   dr.corrLine.labelObjName=layer.visual.prefix+"CL_L_"+IntegerToString(g_objCount++);

   // Vertical: Origin ↔ CL Extreme
   double vTop,vBot;
   int ci=-1;
   for(int i=0;i<dr.originCount;i++)
      if(dr.origins[i].role==ROLE_CHOCH){ ci=i; break; }

   if(isBullish){ vTop=dr.corrLine.extremePrice;
      vBot=(ci>=0)?dr.origins[ci].price:vTop-atr*3; }
   else         { vBot=dr.corrLine.extremePrice;
      vTop=(ci>=0)?dr.origins[ci].price:vBot+atr*3; }

   DrawVerticalSegment(dr.corrLine.vertObjName,
      dr.corrLine.verticalTime, vTop, vBot,
      clColor, GetMainCLWidth(layer.layer), STYLE_DOT);

   DrawTrendLine(dr.corrLine.horizObjName,
      dr.corrLine.extremeTime, dr.corrLine.extremePrice,
      ct, dr.corrLine.extremePrice, clColor,
      layer.visual.lineWidth, layer.visual.lineStyle, false);

   double off=isBullish?atr*0.15:-atr*0.15;
   string lt=BuildDRLabel(layer.layer,isBullish,"CL");
   DrawText(dr.corrLine.labelObjName, dr.corrLine.extremeTime,
      dr.corrLine.extremePrice+off, lt, clColor,
      layer.visual.labelSize, ANCHOR_LEFT, "Arial Bold");
}

void DrawLayerOrigin(SMTFLayer &layer, int index, SDealingRange &dr, bool isBullish)
{
   if(index>=dr.originCount) return;
   double atr=GetLayerATR(layer); if(atr<=0) atr=GetATRSafe();
   color oC; int lw; ENUM_LINE_STYLE ls; string lt;

   switch(dr.origins[index].role)
   {
      case ROLE_CHOCH:
         oC=layer.visual.originColor; lw=layer.visual.lineWidth+1; ls=STYLE_SOLID;
         lt=BuildDRLabel(layer.layer,isBullish,"Origin",
            "\x2605 "+DoubleToString(dr.origins[index].price,_Digits));
         break;
      case ROLE_TARGET:
         oC=layer.visual.targetColor; lw=MathMax(1,layer.visual.lineWidth-1); ls=STYLE_DASH;
         lt=BuildDRLabel(layer.layer,!isBullish,"Target",
            DoubleToString(dr.origins[index].price,_Digits));
         break;
      default: return;
   }

   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   DeleteObject(dr.origins[index].lineObjName);
   DrawTrendLine(dr.origins[index].lineObjName,
      dr.origins[index].time, dr.origins[index].price,
      ct, dr.origins[index].price, oC, lw, ls, false);

   double off=isBullish?-atr*0.12:atr*0.12;
   DeleteObject(dr.origins[index].labelObjName);
   DrawText(dr.origins[index].labelObjName, dr.origins[index].time,
      dr.origins[index].price+off,
      lt+" "+DoubleToString(dr.origins[index].price,_Digits),
      oC, layer.visual.labelSize, ANCHOR_LEFT, "Arial Bold");
}

void DrawLayerExternal(SMTFLayer &layer, int index, SDealingRange &dr, bool isBullish)
{
   if(index>=dr.externalCount) return;
   double atr=GetLayerATR(layer); if(atr<=0) atr=GetATRSafe();
   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   DrawTrendLine(dr.externals[index].lineObjName,
      dr.externals[index].time, dr.externals[index].price,
      ct, dr.externals[index].price, layer.visual.extColor,
      MathMax(1,layer.visual.lineWidth-1), STYLE_DASHDOT, false);
   double off=isBullish?-atr*0.1:atr*0.1;
   string lt=BuildDRLabel(layer.layer,isBullish,"Ext.IDMT",
      DoubleToString(dr.externals[index].price,_Digits));
   DrawText(dr.externals[index].labelObjName, dr.externals[index].time,
      dr.externals[index].price+off, lt, layer.visual.extColor,
      layer.visual.labelSize, ANCHOR_LEFT, "Arial");
}

//+------------------------------------------------------------------+
//| Draw Layer Pullback Origin (NEW)                                  |
//+------------------------------------------------------------------+
void DrawLayerPullbackOrigin(SMTFLayer &layer, SDealingRange &dr, bool mainIsBullish)
{
   double atr=GetLayerATR(layer); if(atr<=0) atr=GetATRSafe();
   DeleteObject(dr.pullback.originLineObj);
   DeleteObject(dr.pullback.originLabelObj);
   dr.pullback.originLineObj =layer.visual.prefix+"PB_Org_"+IntegerToString(g_objCount++);
   dr.pullback.originLabelObj=dr.pullback.originLineObj+"_lbl";

   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   bool pbBull=!mainIsBullish;
   string lt=BuildDRLabel(layer.layer,pbBull,"PB.Origin",
      "\x2605 "+DoubleToString(dr.pullback.originPrice,_Digits));

   DrawTrendLine(dr.pullback.originLineObj,
      dr.pullback.originTime, dr.pullback.originPrice,
      ct, dr.pullback.originPrice,
      InpPullbackOriginColor, MathMax(1,layer.visual.lineWidth), STYLE_SOLID, false);

   double off=pbBull?-atr*0.12:atr*0.12;
   DrawText(dr.pullback.originLabelObj, dr.pullback.originTime,
      dr.pullback.originPrice+off, lt,
      InpPullbackOriginColor, layer.visual.labelSize, ANCHOR_LEFT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Draw Layer Pullback CL (NEW)                                      |
//+------------------------------------------------------------------+
void DrawLayerPullbackCL(SMTFLayer &layer, SDealingRange &dr, bool mainIsBullish)
{
   double atr=GetLayerATR(layer); if(atr<=0) atr=GetATRSafe();
   DeleteObject(dr.pullback.clVertObj);
   DeleteObject(dr.pullback.clHorizObj);
   DeleteObject(dr.pullback.clLabelObj);
   dr.pullback.clVertObj =layer.visual.prefix+"PB_CLV_"+IntegerToString(g_objCount++);
   dr.pullback.clHorizObj=layer.visual.prefix+"PB_CLH_"+IntegerToString(g_objCount++);
   dr.pullback.clLabelObj=layer.visual.prefix+"PB_CLL_"+IntegerToString(g_objCount++);

   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   bool pbBull=!mainIsBullish;
   color clC=InpPullbackCLColor;

   double vTop,vBot;
   double fallback=dr.corrLine.extremePrice;
   if(pbBull){ vTop=dr.pullback.clPrice;
      vBot=(dr.pullback.originPrice>0)?dr.pullback.originPrice:fallback; }
   else     { vBot=dr.pullback.clPrice;
      vTop=(dr.pullback.originPrice>0)?dr.pullback.originPrice:fallback; }

   DrawVerticalSegment(dr.pullback.clVertObj,
      dr.pullback.clTime, vTop, vBot,
      clC, GetPBCLWidth(layer.layer), STYLE_DOT);

   DrawTrendLine(dr.pullback.clHorizObj,
      dr.pullback.clTime, dr.pullback.clPrice,
      ct, dr.pullback.clPrice, clC, 1, STYLE_DASH, false);

   double off=pbBull?atr*0.12:-atr*0.12;
   string lt=BuildDRLabel(layer.layer,pbBull,"PB.CL");
   DrawText(dr.pullback.clLabelObj, dr.pullback.clTime,
      dr.pullback.clPrice+off, lt, clC,
      layer.visual.labelSize, ANCHOR_LEFT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Draw Layer Pullback Counter (NEW)                                 |
//+------------------------------------------------------------------+
void DrawLayerPullbackCounter(SMTFLayer &layer, int index,
   SDealingRange &dr, bool mainIsBullish)
{
   if(index>=dr.pullback.counterCount) return;
   double atr=GetLayerATR(layer); if(atr<=0) atr=GetATRSafe();
   datetime ct=iTime(_Symbol,PERIOD_CURRENT,0);
   bool pbBull=!mainIsBullish;

   DrawTrendLine(dr.pullback.counters[index].lineObjName,
      dr.pullback.counters[index].time, dr.pullback.counters[index].price,
      ct, dr.pullback.counters[index].price,
      InpPullbackCounterColor, 1, STYLE_DOT, false);

   double off=pbBull?-atr*0.08:atr*0.08;
   string lt=BuildDRLabel(layer.layer,pbBull,"PB.Cnt",
      DoubleToString(dr.pullback.counters[index].price,_Digits));
   DrawText(dr.pullback.counters[index].labelObjName,
      dr.pullback.counters[index].time,
      dr.pullback.counters[index].price+off,
      lt, InpPullbackCounterColor, layer.visual.labelSize-1, ANCHOR_LEFT);
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 9: LAYER BOS & CHOCH (MODIFIED – pullback logic)       ║
// ╚══════════════════════════════════════════════════════════════════╝

void CheckLayerBOS(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   if(dr.corrLine.extremePrice<=0||dr.corrLine.needsUpdate) return;
   ENUM_TIMEFRAMES tf=layer.timeframe;
   double atr=GetLayerATR(layer);
   datetime pT=TF_Time(tf,1);
   if(pT<=dr.corrLine.extremeTime) return;

   if(!HasPulledBackFromExtreme(tf,dr.corrLine.extremePrice,
      dr.corrLine.extremeTime,isBullish,atr)) return;

   if(!CheckBreak(tf,dr.corrLine.extremePrice,isBullish)) return;

   Print(layer.visual.tfLabel," BOS at ",DoubleToString(dr.corrLine.extremePrice,_Digits));
   SM_RegisterStructuralEvent(dr.corrLine.extremePrice,
      isBullish?DIR_BULLISH:DIR_BEARISH, 0, layer.layer);

   // PRIORITY 1: External sweep
   if(dr.externalSwept && dr.extremeReached>0)
   {  CreateLayerOrigin(layer,dr,dr.extremeReached,dr.sweepTime,isBullish); }
   // PRIORITY 2: Pullback peak fallback (NEW)
   else if(dr.pullback.confirmed && dr.pullback.clPrice>0)
   {  CreateLayerOrigin(layer,dr,dr.pullback.clPrice,dr.pullback.clTime,isBullish);
      Print("   ",layer.visual.tfLabel," Origin from PB PEAK"); }

   dr.corrLine.needsUpdate=true;
   if(isBullish){ dr.corrLine.pendingExtreme=TF_High(tf,1);
      dr.corrLine.pendingExtremeTime=TF_Time(tf,1); }
   else         { dr.corrLine.pendingExtreme=TF_Low(tf,1);
      dr.corrLine.pendingExtremeTime=TF_Time(tf,1); }

   dr.externalSwept=false; dr.extremeReached=0; dr.sweepTime=0;
}

void CheckLayerChoCh(SMTFLayer &layer, SDealingRange &dr, bool isBullish)
{
   int ci=-1;
   for(int i=0;i<dr.originCount;i++)
      if(dr.origins[i].role==ROLE_CHOCH){ ci=i; break; }
   if(ci<0) return;

   ENUM_TIMEFRAMES tf=layer.timeframe;
   datetime pT=TF_Time(tf,1);
   if(pT<=dr.origins[ci].time) return;

   bool broken=isBullish?
      CheckBreak(tf,dr.origins[ci].price,false):
      CheckBreak(tf,dr.origins[ci].price,true);
   if(!broken) return;

   double brkPrice=dr.origins[ci].price;
   double oldCL=dr.corrLine.extremePrice;
   datetime oldCLTime=dr.corrLine.extremeTime;

   Print("═══ ",layer.visual.tfLabel," CHOCH at ",DoubleToString(brkPrice,_Digits)," ═══");
   SM_RegisterStructuralEvent(brkPrice,
      isBullish?DIR_BEARISH:DIR_BULLISH, 0, layer.layer);

   // Save pullback data BEFORE clearing
   bool hadPB=dr.pullback.confirmed;
   double pbOrg=dr.pullback.originPrice;
   datetime pbOrgT=dr.pullback.originTime;
   double pbCL=dr.pullback.clPrice;
   datetime pbCLT=dr.pullback.clTime;

   // Remove broken origin
   DeleteObject(dr.origins[ci].lineObjName);
   DeleteObject(dr.origins[ci].labelObjName);
   for(int i=ci;i<dr.originCount-1;i++) dr.origins[i]=dr.origins[i+1];
   dr.originCount--;
   for(int i=0;i<dr.originCount;i++)
   {  dr.origins[i].role=ROLE_TARGET;
      DrawLayerOrigin(layer,i,dr,isBullish); }

   DeleteObject(dr.corrLine.vertObjName);
   DeleteObject(dr.corrLine.horizObjName);
   DeleteObject(dr.corrLine.labelObjName);
   ClearLayerInternals(layer,dr);
   ClearLayerPullbackStructure(layer,dr);

   dr.corrLine.isActive=false; dr.corrLine.needsUpdate=false;
   dr.isDominant=false;
   layer.isBullishActive=!isBullish;

   if(isBullish)
   {  // Was Bull → now Bear
      layer.bearDR.Reset();
      ArrayResize(layer.bearDR.origins,InpMaxOriginsTrack);
      ArrayResize(layer.bearDR.externals,InpMaxExtInducements);
      ArrayResize(layer.bearDR.internals,20);
      ArrayResize(layer.bearDR.pullback.counters,InpMaxPullbackCounters);

      if(hadPB && pbCL>0 && pbOrg>0)
      {  int pbBar=TF_BarShift(tf,pbCLT);
         SetupLayerCorrectionLine(layer,layer.bearDR,false,pbCL,pbCLT,pbBar,InpInitScanBars);
         CreateLayerFirstOrigin(layer,layer.bearDR,false,pbOrg,pbOrgT);
         Print("   ",layer.visual.tfLabel," PB PROMOTED: CL=",DoubleToString(pbCL,_Digits)); }
      else
      {  int lBar=TF_Lowest(tf,50,0);
         SetupLayerCorrectionLine(layer,layer.bearDR,false,
            TF_Low(tf,lBar),TF_Time(tf,lBar),lBar,InpInitScanBars);
         CreateLayerFirstOrigin(layer,layer.bearDR,false,oldCL,oldCLTime); }

      layer.bearDR.isDominant=true; layer.bullDR.isDominant=false;
   }
   else
   {  // Was Bear → now Bull
      layer.bullDR.Reset();
      ArrayResize(layer.bullDR.origins,InpMaxOriginsTrack);
      ArrayResize(layer.bullDR.externals,InpMaxExtInducements);
      ArrayResize(layer.bullDR.internals,20);
      ArrayResize(layer.bullDR.pullback.counters,InpMaxPullbackCounters);

      if(hadPB && pbCL>0 && pbOrg>0)
      {  int pbBar=TF_BarShift(tf,pbCLT);
         SetupLayerCorrectionLine(layer,layer.bullDR,true,pbCL,pbCLT,pbBar,InpInitScanBars);
         CreateLayerFirstOrigin(layer,layer.bullDR,true,pbOrg,pbOrgT);
         Print("   ",layer.visual.tfLabel," PB PROMOTED: CL=",DoubleToString(pbCL,_Digits)); }
      else
      {  int hBar=TF_Highest(tf,50,0);
         SetupLayerCorrectionLine(layer,layer.bullDR,true,
            TF_High(tf,hBar),TF_Time(tf,hBar),hBar,InpInitScanBars);
         CreateLayerFirstOrigin(layer,layer.bullDR,true,oldCL,oldCLTime); }

      layer.bullDR.isDominant=true; layer.bearDR.isDominant=false;
   }

   if(layer.layer==LAYER_HTF)
      g_htfDirection=layer.isBullishActive?DIR_BULLISH:DIR_BEARISH;
   else if(layer.layer==LAYER_LTF)
      g_ltfDirection=layer.isBullishActive?DIR_BULLISH:DIR_BEARISH;

   g_forceDashboardUpdate=true; 
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 10: LAYER UPDATE (MODIFIED – full pullback pipeline)    ║
// ╚══════════════════════════════════════════════════════════════════╝

void UpdateLayer(SMTFLayer &layer)
{
   if(!layer.isEnabled) return;
   if(!UpdateLayerATR(layer)) return;
   if(!layer.isInitialized){ ScanLayerInitialStructure(layer); return; }

   bool isBullish=layer.isBullishActive;
   SDealingRange* dr=isBullish?GetPointer(layer.bullDR):GetPointer(layer.bearDR);
   if(!dr.isActive) return;

   // Step 1: CL update (NEW)
   CheckLayerCLUpdate(layer,dr,isBullish);
   if(dr.corrLine.needsUpdate) return;

   // Step 2: Internal levels (NEW)
   DetectLayerInternalLevels(layer,dr,isBullish);

   // Step 2.5: Pullback counters (NEW)
   DetectLayerPullbackCounters(layer,dr,isBullish);

   // Step 3: Internal breaks (NEW)
   UpdateLayerInternalsBroken(layer,dr,isBullish);

   // Step 3.5: Pullback counter sweeps (NEW)
   CheckLayerPullbackSweeps(layer,dr,isBullish);

   // Step 3.6: Track PB sweep extreme (NEW)
   TrackLayerPullbackSweepExtreme(layer,dr,isBullish);

   // Step 4: External sweeps
   CheckLayerExternalSweeps(layer,dr,isBullish);

   // Step 5: Track external extreme
   if(dr.externalSwept) TrackLayerExtreme(layer,dr,isBullish);

   // Step 5.5: Pullback Mode A (NEW)
   DetectLayerPullbackStructure(layer,dr,isBullish);

   // Step 5.6: Pullback CL tracking (NEW)
   UpdateLayerPullbackCL(layer,dr,isBullish);

   // Step 5.7: Pullback origin break A2-a (NEW)
   CheckLayerPullbackOriginBreak(layer,dr,isBullish);

   // Step 6: BOS (MODIFIED)
   CheckLayerBOS(layer,dr,isBullish);

   // Step 7: ChoCh (MODIFIED)
   CheckLayerChoCh(layer,dr,isBullish);

   // Step 8: Extend lines (MODIFIED)
   ExtendLayerLines(layer,dr);
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 11: LINE EXTENSION (MODIFIED – pullback lines)          ║
// ╚══════════════════════════════════════════════════════════════════╝

void ExtendLayerLines(SMTFLayer &layer, SDealingRange &dr)
{
   if(dr.corrLine.isActive) ExtendLineToCurrent(dr.corrLine.horizObjName);

   for(int i=0;i<dr.externalCount;i++)
      if(!dr.externals[i].isReached) ExtendLineToCurrent(dr.externals[i].lineObjName);

   for(int i=0;i<dr.originCount;i++)
      if(!dr.origins[i].isReached) ExtendLineToCurrent(dr.origins[i].lineObjName);

   // NEW: Pullback lines
   if(dr.pullback.confirmed)
   {  ExtendLineToCurrent(dr.pullback.originLineObj);
      ExtendLineToCurrent(dr.pullback.clHorizObj); }

   for(int i=0;i<dr.pullback.counterCount;i++)
      if(!dr.pullback.counters[i].isConsumed)
         ExtendLineToCurrent(dr.pullback.counters[i].lineObjName);
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 12: MAIN UPDATE + ALIGNMENT                             ║
// ╚══════════════════════════════════════════════════════════════════╝

void UpdateMultiTF()
{
   if(!g_mtfInitialized) return;
   if(g_htfLayer.isEnabled) UpdateLayer(g_htfLayer);
   if(g_ltfLayer.isEnabled) UpdateLayer(g_ltfLayer);
   g_ctfLayer.isBullishActive=g_isBullishActive;
   CheckTFAlignment();
}

void CheckTFAlignment()
{
   g_htfDirection=g_htfLayer.isInitialized?
      (g_htfLayer.isBullishActive?DIR_BULLISH:DIR_BEARISH):DIR_NONE;
   g_ctfDirection=g_isBullishActive?DIR_BULLISH:DIR_BEARISH;
   g_ltfDirection=g_ltfLayer.isInitialized?
      (g_ltfLayer.isBullishActive?DIR_BULLISH:DIR_BEARISH):DIR_NONE;
   g_allTFsAligned=(g_htfDirection==g_ctfDirection&&g_ctfDirection==g_ltfDirection)
                   &&(g_htfDirection!=DIR_NONE);
   g_htfCtfAligned=(g_htfDirection==g_ctfDirection)&&(g_htfDirection!=DIR_NONE);
}

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 13: QUERY HELPERS                                       ║
// ╚══════════════════════════════════════════════════════════════════╝

bool HasHTFOrigin()
{  if(!g_htfLayer.isInitialized) return false;
   SDealingRange* dr=g_htfLayer.isBullishActive?GetPointer(g_htfLayer.bullDR):GetPointer(g_htfLayer.bearDR);
   for(int i=0;i<dr.originCount;i++) if(dr.origins[i].role==ROLE_CHOCH) return true;
   return false; }

bool HasCTFOrigin()
{  SDealingRange* dr=g_isBullishActive?GetPointer(g_bullDR):GetPointer(g_bearDR);
   for(int i=0;i<dr.originCount;i++) if(dr.origins[i].role==ROLE_CHOCH) return true;
   return false; }

bool HasLTFOrigin()
{  if(!g_ltfLayer.isInitialized) return false;
   SDealingRange* dr=g_ltfLayer.isBullishActive?GetPointer(g_ltfLayer.bullDR):GetPointer(g_ltfLayer.bearDR);
   for(int i=0;i<dr.originCount;i++) if(dr.origins[i].role==ROLE_CHOCH) return true;
   return false; }

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 14: MTF PULLBACK DASHBOARD HELPERS (ALL NEW)            ║
// ╚══════════════════════════════════════════════════════════════════╝

//+------------------------------------------------------------------+
//| Generic layer pullback status builder                             |
//+------------------------------------------------------------------+
string BuildLayerPullbackStatus(SMTFLayer &layer, string tfTag)
{
   if(!layer.isEnabled || !layer.isInitialized)
      return tfTag+" PB: N/A";
   if(!InpDetectPullbackStructure)
      return tfTag+" PB: Off";

   SDealingRange* dr=layer.isBullishActive?
      GetPointer(layer.bullDR):GetPointer(layer.bearDR);
   bool pbBull=!layer.isBullishActive;
   string d=pbBull?"Bull":"Bear";

   if(dr.pullback.confirmed)
      return tfTag+" PB."+d+" Active|Org:"+
             DoubleToString(dr.pullback.originPrice,_Digits)+
             " CL:"+DoubleToString(dr.pullback.clPrice,_Digits);
   if(dr.pullback.sweepPending)
      return tfTag+" PB."+d+" Sweep|Ext:"+
             DoubleToString(dr.pullback.sweepExtreme,_Digits);
   if(dr.pullback.counterCount>0)
   {  int act=0;
      for(int i=0;i<dr.pullback.counterCount;i++)
         if(!dr.pullback.counters[i].isConsumed) act++;
      if(act>0) return tfTag+" PB."+d+" Track|Cnt:"+IntegerToString(act); }
   return tfTag+" PB: Idle";
}

bool HasLayerActivePullback(SMTFLayer &layer)
{  if(!layer.isEnabled||!layer.isInitialized) return false;
   SDealingRange* dr=layer.isBullishActive?
      GetPointer(layer.bullDR):GetPointer(layer.bearDR);
   return dr.pullback.confirmed; }

string GetHTFPullbackStatusString() { return BuildLayerPullbackStatus(g_htfLayer,"HTF"); }
string GetLTFPullbackStatusString() { return BuildLayerPullbackStatus(g_ltfLayer,"LTF"); }

// ╔══════════════════════════════════════════════════════════════════╗
// ║  SECTION 15: CLEANUP                                             ║
// ╚══════════════════════════════════════════════════════════════════╝

void CleanupMTF()
{
   if(g_htfLayer.atrHandle!=INVALID_HANDLE)
   {  IndicatorRelease(g_htfLayer.atrHandle); g_htfLayer.atrHandle=INVALID_HANDLE; }
   if(g_ltfLayer.atrHandle!=INVALID_HANDLE)
   {  IndicatorRelease(g_ltfLayer.atrHandle); g_ltfLayer.atrHandle=INVALID_HANDLE; }
   CleanupObjectsWithPrefix(g_prefix+"HTF_");
   CleanupObjectsWithPrefix(g_prefix+"LTF_");
}

#endif // ICT_MULTITF_MQH