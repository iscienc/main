//+------------------------------------------------------------------+
//|                       ICT_MLEngine.mqh                            |
//|         Online Machine Learning Engine                            |
//|         Pure Narrative SM compatible                              |
//|            "ICT Unified Professional EA v17"                      |
//+------------------------------------------------------------------+
#ifndef ICT_MLENGINE_MQH
#define ICT_MLENGINE_MQH

#include "../Core/ICT_Types.mqh"
#include "../Core/ICT_Config.mqh"
#include "../Core/ICT_Globals.mqh"
#include "../StateMachine/ICT_SMEngine.mqh"

//+------------------------------------------------------------------+
//|              SECTION 1: INITIALIZATION                             |
//+------------------------------------------------------------------+
bool InitializeMLEngine()
{
   if(InpML_Mode == ML_OFF)
   {
      g_mlStatus = ML_STATUS_OFF;
      g_mlInitialized = false;
      Print("ML Engine: OFF");
      return true;
   }

   g_mlWeights.Reset();
   g_mlWeights.InitDefaults();
   g_mlPrediction.Reset();
   g_mlPrediction.recommend = true;
   g_mlStats.Reset();
   g_mlAdaptive.Reset();
   g_mlDiag.Reset();
   g_mlClosedTradeCount = 0;

   ArrayResize(g_mlSamples, ML_MAX_SAMPLES);
   for(int i = 0; i < ML_MAX_SAMPLES; i++)
      g_mlSamples[i].Reset();
   g_mlSampleCount = 0;
   g_mlSampleWriteIdx = 0;

   ArrayResize(g_mlPredHistory, ML_MAX_HISTORY);
   for(int i = 0; i < ML_MAX_HISTORY; i++)
      g_mlPredHistory[i].Reset();
   g_mlPredHistCount = 0;
   g_mlPredHistWriteIdx = 0;

   for(int j = 0; j < ML_FEATURE_COUNT; j++)
   {
      g_mlFeatureMean[j] = 0.5;
      g_mlFeatureStd[j] = 0.3;
   }
   g_mlStatsComputed = false;

   if(!InpML_ResetOnStart && LoadMLWeights())
   {
      Print("ML Engine: Loaded saved state (",
            g_mlWeights.updateCount, " updates, ",
            g_mlClosedTradeCount, " closed trades)");
   }
   else
   {
      InitializeDefaultWeights();
   }

   UpdateMLStatus();
   g_mlInitialized = true;

   Print("=== ML ENGINE v2.0 INITIALIZED ===");
   Print("  Mode: ", EnumToString(InpML_Mode));
   Print("  Status: ", MLStatusToString(g_mlStatus));
   Print("  Closed Trades: ", g_mlClosedTradeCount);
   Print("  Min Samples Filter: ", InpML_MinSamplesFilter);
   Print("  Min Accuracy Filter: ", DoubleToString(InpML_MinAccuracyFilter, 1), "%");
   Print("==================================");

   return true;
}

//+------------------------------------------------------------------+
//| Initialize Default Weights                                        |
//+------------------------------------------------------------------+
void InitializeDefaultWeights()
{
   g_mlWeights.weights[MLF_HTF_ALIGNED]    = 0.05;
   g_mlWeights.weights[MLF_ALL_TF_ALIGNED] = 0.08;
   g_mlWeights.weights[MLF_KZ_ACTIVE]      = 0.05;
   g_mlWeights.weights[MLF_HAS_OB]         = 0.05;
   g_mlWeights.weights[MLF_HAS_FVG]        = 0.03;
   g_mlWeights.weights[MLF_HAS_CONFLUENCE]      = 0.00; // stack removed in pure mode
   g_mlWeights.weights[MLF_OTE_IN_ZONE]    = 0.03;
   g_mlWeights.weights[MLF_ZONE_ALIGNED]   = 0.05;
   g_mlWeights.weights[MLF_SMT_CONFIRMED]  = 0.03;
   g_mlWeights.weights[MLF_EXT_SWEPT]      = 0.05;
   g_mlWeights.weights[MLF_RR_RATIO]       = 0.08;
   g_mlWeights.weights[MLF_DISPLACEMENT]   = 0.05;
   g_mlWeights.weights[MLF_BODY_CLOSE]     = 0.03;
   g_mlWeights.weights[MLF_ORIGIN_EXISTS]  = 0.05;

   g_mlWeights.weights[MLF_SPREAD_NORM]    = -0.02;

   g_mlWeights.bias = 0.1;
   g_mlWeights.updateCount = 0;
}

//+------------------------------------------------------------------+
//|              SECTION 2: STATUS MANAGEMENT                          |
//+------------------------------------------------------------------+
void UpdateMLStatus()
{
   if(InpML_Mode == ML_OFF)
   {
      g_mlStatus = ML_STATUS_OFF;
      return;
   }

   if(InpML_FreezeLearning)
   {
      g_mlStatus = ML_STATUS_FROZEN;
      return;
   }

   if(g_mlClosedTradeCount < InpML_WarmupTrades)
   {
      g_mlStatus = ML_STATUS_WARMUP;
      g_mlStats.warmupRemaining = InpML_WarmupTrades - g_mlClosedTradeCount;
      return;
   }

   g_mlDiag.hasEnoughSamples = (g_mlClosedTradeCount >= InpML_MinSamplesFilter);
   g_mlDiag.hasGoodAccuracy = (g_mlStats.predictionAccuracy >= InpML_MinAccuracyFilter);

   if(g_mlDiag.hasEnoughSamples && g_mlDiag.hasGoodAccuracy)
   {
      g_mlStatus = ML_STATUS_FILTERING;
      return;
   }

   g_mlStatus = ML_STATUS_OBSERVING;
   g_mlStats.warmupRemaining = 0;
}

//+------------------------------------------------------------------+
//|              SECTION 3: SIGMOID & MATH                             |
//+------------------------------------------------------------------+
double Sigmoid(double x)
{
   if(x > 500.0) return 1.0;
   if(x < -500.0) return 0.0;
   return 1.0 / (1.0 + MathExp(-x));
}

double Clamp(double val, double lo, double hi)
{
   return MathMax(lo, MathMin(hi, val));
}

//+------------------------------------------------------------------+
//|              SECTION 4: FEATURE EXTRACTION                         |
//+------------------------------------------------------------------+
SMLFeatureVector ExtractFeatures()
{
   SMLFeatureVector fv;
   fv.Reset();

   bool isBull = g_isBullishActive;
   int idx = -1;

   fv.Set(MLF_HTF_ALIGNED,    g_htfCtfAligned ? 1.0 : 0.0);
   fv.Set(MLF_ALL_TF_ALIGNED, g_allTFsAligned ? 1.0 : 0.0);
   fv.Set(MLF_KZ_ACTIVE,      g_killzone.isActive ? 1.0 : 0.0);
   fv.Set(MLF_KZ_MULTIPLIER,  Clamp(g_killzone.multiplier / 2.0, 0.0, 1.0));

   double amdVal = 0.0;
   switch(g_amdPhase.currentPhase)
   {
      case AMD_ACCUMULATION: amdVal = 0.33; break;
      case AMD_MANIPULATION: amdVal = 0.66; break;
      case AMD_DISTRIBUTION: amdVal = 1.00; break;
      default: amdVal = 0.0; break;
   }
   fv.Set(MLF_AMD_PHASE, amdVal);

   fv.Set(MLF_HAS_OB, (GetBestOrderBlock(isBull) >= 0) ? 1.0 : 0.0);

   bool inFVG = IsPriceInFVG(isBull, idx);
   fv.Set(MLF_HAS_FVG, inFVG ? 1.0 : 0.0);

   // Pure Narrative SM: stack feature disabled
   fv.Set(MLF_HAS_CONFLUENCE, 0.0);
   fv.Set( MLF_CONFLUENCE_COUNT, 0.0);

   fv.Set(MLF_OTE_IN_ZONE, IsPriceInOTEZone() ? 1.0 : 0.0);
   fv.Set(MLF_ZONE_ALIGNED, IsZoneAligned(isBull) ? 1.0 : 0.0);
   fv.Set(MLF_SMT_CONFIRMED, HasSMTConfirmation(isBull) ? 1.0 : 0.0);
   fv.Set(MLF_JUDAS_ACTIVE, HasActiveJudasSwing() ? 1.0 : 0.0);

   SDealingRange* dr = isBull ? GetPointer(g_bullDR) : GetPointer(g_bearDR);
   fv.Set(MLF_EXT_SWEPT, (dr != NULL && dr.externalSwept) ? 1.0 : 0.0);

   double rr = g_currentSignal.riskReward;
   if(rr <= 0.0) rr = InpRiskReward;
   fv.Set(MLF_RR_RATIO, Clamp(rr / 5.0, 0.0, 1.0));

   double atr = GetATRSafe();
   fv.Set(MLF_DISPLACEMENT, (atr > 0.0 && IsDisplacementCandle(PERIOD_CURRENT, 1, atr)) ? 1.0 : 0.0);

   double prevC = iClose(_Symbol, PERIOD_CURRENT, 1);
   double prevO = iOpen(_Symbol, PERIOD_CURRENT, 1);
   bool bodyOK = isBull ? (prevC > prevO) : (prevC < prevO);
   fv.Set(MLF_BODY_CLOSE, bodyOK ? 1.0 : 0.0);

   bool ltfBOS = false;
   if(g_ltfLayer.isInitialized)
   {
      SDealingRange* ltfDR = g_ltfLayer.isBullishActive ? GetPointer(g_ltfLayer.bullDR) : GetPointer(g_ltfLayer.bearDR);
      ltfBOS = (ltfDR != NULL && ltfDR.corrLine.isActive && ltfDR.externalSwept);
   }
   fv.Set(MLF_LTF_BOS, ltfBOS ? 1.0 : 0.0);
   fv.Set(MLF_ORIGIN_EXISTS, HasCTFOrigin() ? 1.0 : 0.0);

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   fv.Set(MLF_SPREAD_NORM, Clamp(spread / 50.0, 0.0, 1.0));

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   fv.Set(MLF_HOUR_NORM, tm.hour / 24.0);

   SM_FillMLFeatures(fv);
   return fv;
}

//+------------------------------------------------------------------+
//|              SECTION 5: PREDICTION                                 |
//+------------------------------------------------------------------+
SMLPrediction PredictOutcome(SMLFeatureVector &fv)
{
   SMLPrediction pred;
   pred.Reset();
   pred.recommend = true;

   if(!g_mlInitialized || InpML_Mode == ML_OFF)
   {
      pred.probability = 0.5;
      pred.reason = "ML Off";
      return pred;
   }

   if(g_mlStatus == ML_STATUS_WARMUP)
   {
      pred.probability = 0.5;
      pred.recommend = true;
      pred.confidence = 0.0;
      pred.adjustedBias = 0.0;
      pred.reason = "Warmup (" + IntegerToString(g_mlStats.warmupRemaining) + " trades left)";
      return pred;
   }

   double z = g_mlWeights.bias;
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      z += g_mlWeights.weights[i] * fv.features[i];

   g_mlDiag.lastLinearZ = z;
   pred.probability = Sigmoid(z);

   double confRaw = Clamp((double)g_mlClosedTradeCount / (double)InpML_MinSamplesFilter, 0.0, 1.0);
   pred.confidence = confRaw * 100.0;

   pred.adjustedBias = 0.0;
   if(InpML_Mode == ML_ADAPTIVE || InpML_Mode == ML_COMBINED)
      pred.adjustedBias = CalculateAdaptiveAdjustment(fv);

   switch(g_mlStatus)
   {
      case ML_STATUS_OBSERVING:
         pred.recommend = true;
         if(pred.probability < InpML_MinProbability)
            pred.reason = "Observing: P=" + DoubleToString(pred.probability, 3) + " (not blocking yet)";
         else
            pred.reason = "Observing: P=" + DoubleToString(pred.probability, 3) + " OK";
         break;

      case ML_STATUS_FILTERING:
      case ML_STATUS_FROZEN:
         if(InpML_Mode == ML_LOGISTIC || InpML_Mode == ML_COMBINED)
         {
            pred.recommend = (pred.probability >= InpML_MinProbability);
            pred.reason = pred.recommend
                          ? "Filter: P=" + DoubleToString(pred.probability, 3) + " OK"
                          : "Filter: P=" + DoubleToString(pred.probability, 3) + " below threshold";
         }
         else
         {
            pred.recommend = true;
            pred.reason = "Adaptive: Adj=" + DoubleToString(pred.adjustedBias, 1);
         }
         break;

      default:
         pred.recommend = true;
         pred.reason = "Unknown status";
         break;
   }

   return pred;
}

//+------------------------------------------------------------------+
//| Calculate Adaptive Score Adjustment                               |
//+------------------------------------------------------------------+
double CalculateAdaptiveAdjustment(SMLFeatureVector &fv)
{
   if(g_mlAdaptive.winCount < 3 || g_mlAdaptive.lossCount < 3)
      return 0.0;

   double adjustment = 0.0;
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      adjustment += g_mlAdaptive.featureEffect[i] * fv.features[i];

   double maxEffect = 0.0;
   for(int j = 0; j < ML_FEATURE_COUNT; j++)
      maxEffect += MathAbs(g_mlAdaptive.featureEffect[j]);

   if(maxEffect > 0.0)
      adjustment = (adjustment / maxEffect) * InpML_ScoreAdjustMax;

   return Clamp(adjustment, -InpML_ScoreAdjustMax, InpML_ScoreAdjustMax);
}

//+------------------------------------------------------------------+
//|              SECTION 6: TRAINING                                   |
//+------------------------------------------------------------------+
void AddTrainingSample(SMLFeatureVector &fv, double pnl, ENUM_SIGNAL_TYPE type, int score)
{
   if(!g_mlInitialized || InpML_Mode == ML_OFF)
      return;

   bool isWin = (pnl > 0.0);
   int writeIdx = g_mlSampleWriteIdx % ML_MAX_SAMPLES;

   g_mlSamples[writeIdx].Reset();
   g_mlSamples[writeIdx].featureVec = fv;
   g_mlSamples[writeIdx].label = isWin ? 1.0 : 0.0;
   g_mlSamples[writeIdx].pnl = pnl;
   g_mlSamples[writeIdx].time = TimeCurrent();
   g_mlSamples[writeIdx].signalQuality = score;
   g_mlSamples[writeIdx].signalType = type;

   g_mlSampleWriteIdx++;
   if(g_mlSampleCount < ML_MAX_SAMPLES) g_mlSampleCount++;

   g_mlDiag.samplesFromTrades++;
   UpdateAdaptiveStats(fv, isWin);
   UpdateFeatureNormalization(fv);

   if(!InpML_FreezeLearning && (InpML_Mode == ML_LOGISTIC || InpML_Mode == ML_COMBINED))
      PerformLearningStep(g_mlSamples[writeIdx]);

   g_mlStats.totalSamples = g_mlSampleCount;
   UpdateMLStatus();

   if(InpML_AutoSave && (g_mlClosedTradeCount % InpML_SaveInterval == 0))
      SaveMLWeights();

   UpdateFeatureImportance();

   Print("ML: Sample added (", (isWin ? "WIN" : "LOSS"),
         " $", DoubleToString(pnl, 2),
         ") Total: ", g_mlClosedTradeCount,
         " Status: ", MLStatusToString(g_mlStatus));
}

void UpdateAdaptiveStats(SMLFeatureVector &fv, bool isWin)
{
   if(isWin)
   {
      for(int i = 0; i < ML_FEATURE_COUNT; i++)
         g_mlAdaptive.winFeatureSum[i] += fv.features[i];
      g_mlAdaptive.winCount++;
   }
   else
   {
      for(int j = 0; j < ML_FEATURE_COUNT; j++)
         g_mlAdaptive.lossFeatureSum[j] += fv.features[j];
      g_mlAdaptive.lossCount++;
   }

   g_mlAdaptive.UpdateEffects();
}

void PerformLearningStep(SMLTrainingSample &sample)
{
   double decayedLR = InpML_LearningRate / (1.0 + InpML_DecayRate * g_mlWeights.updateCount);
   double lr = MathMax(decayedLR, InpML_LearningRate * 0.01);

   double z = g_mlWeights.bias;
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      z += g_mlWeights.weights[i] * sample.featureVec.features[i];

   double predicted = Sigmoid(z);
   double error = sample.label - predicted;

   for(int k = 0; k < ML_FEATURE_COUNT; k++)
   {
      double gradient = error * sample.featureVec.features[k];
      double l2_penalty = InpML_RegStrength * g_mlWeights.weights[k];
      g_mlWeights.weights[k] += lr * (gradient - l2_penalty);
      g_mlWeights.weights[k] = Clamp(g_mlWeights.weights[k], -InpML_WeightBound, InpML_WeightBound);
   }

   g_mlWeights.bias += lr * error;
   g_mlWeights.bias = Clamp(g_mlWeights.bias, -InpML_WeightBound, InpML_WeightBound);
   g_mlWeights.updateCount++;
}

void UpdateFeatureNormalization(SMLFeatureVector &fv)
{
   double alpha = 0.05;

   for(int i = 0; i < ML_FEATURE_COUNT; i++)
   {
      g_mlFeatureMean[i] = g_mlFeatureMean[i] * (1.0 - alpha) + fv.features[i] * alpha;
      double diff = fv.features[i] - g_mlFeatureMean[i];
      double variance = g_mlFeatureStd[i] * g_mlFeatureStd[i];
      variance = variance * (1.0 - alpha) + diff * diff * alpha;
      g_mlFeatureStd[i] = MathSqrt(MathMax(0.01, variance));
   }

   g_mlStatsComputed = true;
}

//+------------------------------------------------------------------+
//|              SECTION 7: PREDICTION HISTORY                         |
//+------------------------------------------------------------------+
void RecordPrediction(double prob, bool tradeTaken, int origScore)
{
   if(!g_mlInitialized) return;

   int writeIdx = g_mlPredHistWriteIdx % ML_MAX_HISTORY;

   g_mlPredHistory[writeIdx].Reset();
   g_mlPredHistory[writeIdx].time = TimeCurrent();
   g_mlPredHistory[writeIdx].predictedProb = prob;
   g_mlPredHistory[writeIdx].tradeTaken = tradeTaken;
   g_mlPredHistory[writeIdx].originalQuality = origScore;

   g_mlPredHistWriteIdx++;
   if(g_mlPredHistCount < ML_MAX_HISTORY) g_mlPredHistCount++;

   if(tradeTaken) g_mlDiag.tradesAllowed++;
   else g_mlDiag.tradesBlocked++;
}

void UpdatePredictionOutcome(bool win, double pnl)
{
   if(g_mlPredHistCount == 0) return;

   for(int lookback = 0; lookback < g_mlPredHistCount; lookback++)
   {
      int idx = (g_mlPredHistWriteIdx - 1 - lookback + ML_MAX_HISTORY) % ML_MAX_HISTORY;
      if(idx < 0 || idx >= ML_MAX_HISTORY) continue;

      if(g_mlPredHistory[idx].tradeTaken && g_mlPredHistory[idx].pnl == 0)
      {
         g_mlPredHistory[idx].actualWin = win;
         g_mlPredHistory[idx].pnl = pnl;

         bool correctPred = (g_mlPredHistory[idx].predictedProb >= 0.5) == win;
         g_mlStats.totalPredictions++;
         if(correctPred) g_mlStats.correctPredictions++;
         g_mlStats.Calculate();

         if(win)
         {
            if(g_mlStats.avgWinProb == 0) g_mlStats.avgWinProb = g_mlPredHistory[idx].predictedProb;
            else g_mlStats.avgWinProb = g_mlStats.avgWinProb * 0.9 + g_mlPredHistory[idx].predictedProb * 0.1;
         }
         else
         {
            if(g_mlStats.avgLossProb == 0) g_mlStats.avgLossProb = g_mlPredHistory[idx].predictedProb;
            else g_mlStats.avgLossProb = g_mlStats.avgLossProb * 0.9 + g_mlPredHistory[idx].predictedProb * 0.1;
         }

         break;
      }
   }

   int recentCorrect = 0;
   int recentTotal = 0;
   for(int n = 0; n < g_mlPredHistCount && recentTotal < 20; n++)
   {
      int rIdx = (g_mlPredHistWriteIdx - 1 - n + ML_MAX_HISTORY) % ML_MAX_HISTORY;
      if(rIdx < 0 || rIdx >= ML_MAX_HISTORY) continue;

      if(g_mlPredHistory[rIdx].pnl != 0)
      {
         recentTotal++;
         bool correct = (g_mlPredHistory[rIdx].predictedProb >= 0.5) == g_mlPredHistory[rIdx].actualWin;
         if(correct) recentCorrect++;
      }
   }

   if(recentTotal > 0)
      g_mlStats.recentAccuracy = (double)recentCorrect / recentTotal * 100.0;

   UpdateMLStatus();
}

//+------------------------------------------------------------------+
//|              SECTION 8: SCORING INTERFACE                          |
//+------------------------------------------------------------------+
int GetMLScoreAdjustment()
{
   return 0;
}

bool ShouldMLBlockTrade()
{
   if(!g_mlInitialized || InpML_Mode == ML_OFF)
      return false;

   if(g_mlStatus == ML_STATUS_WARMUP || g_mlStatus == ML_STATUS_OBSERVING)
      return false;

   if(InpML_Mode == ML_ADAPTIVE)
      return false;

   return (!g_mlPrediction.recommend);
}

//+------------------------------------------------------------------+
//|              SECTION 9: FEATURE IMPORTANCE                         |
//+------------------------------------------------------------------+
void UpdateFeatureImportance()
{
   double maxWeight = 0.001;
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
   {
      double absW = MathAbs(g_mlWeights.weights[i]);
      if(absW > maxWeight) maxWeight = absW;
   }

   for(int j = 0; j < ML_FEATURE_COUNT; j++)
   {
      double logisticImp = MathAbs(g_mlWeights.weights[j]) / maxWeight;
      double adaptiveImp = 0.0;

      if(g_mlAdaptive.winCount > 0 || g_mlAdaptive.lossCount > 0)
      {
         double maxEffect = 0.001;
         for(int k = 0; k < ML_FEATURE_COUNT; k++)
            maxEffect = MathMax(maxEffect, MathAbs(g_mlAdaptive.featureEffect[k]));
         adaptiveImp = MathAbs(g_mlAdaptive.featureEffect[j]) / maxEffect;
      }

      g_mlStats.featureImportance[j] = (logisticImp * 0.6 + adaptiveImp * 0.4);
   }
}

//+------------------------------------------------------------------+
//|              SECTION 10: SAVE/LOAD                                 |
//+------------------------------------------------------------------+
bool SaveMLWeights()
{
   string filename = InpML_SavePath + "_" + _Symbol + ".csv";
   int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("ML: Cannot save to ", filename);
      return false;
   }

   FileWrite(handle, "Type", "Index", "Value");
   FileWrite(handle, "BIAS", 0, DoubleToString(g_mlWeights.bias, 10));

   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      FileWrite(handle, "WEIGHT", i, DoubleToString(g_mlWeights.weights[i], 10));

   for(int j = 0; j < ML_FEATURE_COUNT; j++)
      FileWrite(handle, "WIN_SUM", j, DoubleToString(g_mlAdaptive.winFeatureSum[j], 10));

   for(int k = 0; k < ML_FEATURE_COUNT; k++)
      FileWrite(handle, "LOSS_SUM", k, DoubleToString(g_mlAdaptive.lossFeatureSum[k], 10));

   for(int m = 0; m < ML_FEATURE_COUNT; m++)
      FileWrite(handle, "FEAT_MEAN", m, DoubleToString(g_mlFeatureMean[m], 10));

   for(int n = 0; n < ML_FEATURE_COUNT; n++)
      FileWrite(handle, "FEAT_STD", n, DoubleToString(g_mlFeatureStd[n], 10));

   FileWrite(handle, "UPDATE_COUNT", 0, IntegerToString(g_mlWeights.updateCount));
   FileWrite(handle, "CLOSED_TRADES", 0, IntegerToString(g_mlClosedTradeCount));
   FileWrite(handle, "PREDICTIONS", 0, IntegerToString(g_mlStats.totalPredictions));
   FileWrite(handle, "CORRECT", 0, IntegerToString(g_mlStats.correctPredictions));
   FileWrite(handle, "WIN_COUNT", 0, IntegerToString(g_mlAdaptive.winCount));
   FileWrite(handle, "LOSS_COUNT", 0, IntegerToString(g_mlAdaptive.lossCount));
   FileWrite(handle, "VERSION", 0, "2");

   FileClose(handle);

   Print("ML: State saved (", g_mlClosedTradeCount, " trades, ",
         g_mlWeights.updateCount, " updates)");
   return true;
}

bool LoadMLWeights()
{
   string filename = InpML_SavePath + "_" + _Symbol + ".csv";
   if(!FileIsExist(filename, FILE_COMMON))
      return false;

   int handle = FileOpen(filename, FILE_READ | FILE_CSV | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   if(!FileIsEnding(handle))
   {
      FileReadString(handle);
      FileReadString(handle);
      FileReadString(handle);
   }

   while(!FileIsEnding(handle))
   {
      string type = FileReadString(handle);
      if(StringLen(type) == 0) break;

      int index = (int)FileReadNumber(handle);
      string value = FileReadString(handle);

      if(type == "BIAS")
         g_mlWeights.bias = StringToDouble(value);
      else if(type == "WEIGHT" && index >= 0 && index < ML_FEATURE_COUNT)
         g_mlWeights.weights[index] = StringToDouble(value);
      else if(type == "WIN_SUM" && index >= 0 && index < ML_FEATURE_COUNT)
         g_mlAdaptive.winFeatureSum[index] = StringToDouble(value);
      else if(type == "LOSS_SUM" && index >= 0 && index < ML_FEATURE_COUNT)
         g_mlAdaptive.lossFeatureSum[index] = StringToDouble(value);
      else if(type == "FEAT_MEAN" && index >= 0 && index < ML_FEATURE_COUNT)
         g_mlFeatureMean[index] = StringToDouble(value);
      else if(type == "FEAT_STD" && index >= 0 && index < ML_FEATURE_COUNT)
         g_mlFeatureStd[index] = StringToDouble(value);
      else if(type == "UPDATE_COUNT")
         g_mlWeights.updateCount = (int)StringToInteger(value);
      else if(type == "CLOSED_TRADES")
         g_mlClosedTradeCount = (int)StringToInteger(value);
      else if(type == "PREDICTIONS")
         g_mlStats.totalPredictions = (int)StringToInteger(value);
      else if(type == "CORRECT")
         g_mlStats.correctPredictions = (int)StringToInteger(value);
      else if(type == "WIN_COUNT")
         g_mlAdaptive.winCount = (int)StringToInteger(value);
      else if(type == "LOSS_COUNT")
         g_mlAdaptive.lossCount = (int)StringToInteger(value);
   }

   FileClose(handle);

   g_mlStats.totalSamples = g_mlClosedTradeCount;
   g_mlStats.Calculate();
   g_mlAdaptive.UpdateEffects();
   g_mlStatsComputed = true;
   UpdateFeatureImportance();

   return true;
}

//+------------------------------------------------------------------+
//|              SECTION 11: UTILITIES                                 |
//+------------------------------------------------------------------+
string MLStatusToString(ENUM_ML_STATUS status)
{
   switch(status)
   {
      case ML_STATUS_OFF:       return "OFF";
      case ML_STATUS_WARMUP:    return "WARMUP";
      case ML_STATUS_OBSERVING: return "OBSERVING";
      case ML_STATUS_FILTERING: return "FILTERING";
      case ML_STATUS_FROZEN:    return "FROZEN";
      case ML_STATUS_ERROR:     return "ERROR";
      default:                  return "UNKNOWN";
   }
}

string MLModeDescription()
{
   switch(InpML_Mode)
   {
      case ML_ADAPTIVE: return "Score adjustment only, never blocks";
      case ML_LOGISTIC: return "Probability filter, can block trades";
      case ML_COMBINED: return "Score adjust + probability filter";
      default:          return "Off";
   }
}

string MLStatusDescription()
{
   switch(g_mlStatus)
   {
      case ML_STATUS_WARMUP:
         return "Observing " + IntegerToString(g_mlStats.warmupRemaining) + " more trades before learning";
      case ML_STATUS_OBSERVING:
         return "Learning, adjusting scores. Need " +
                IntegerToString(MathMax(0, InpML_MinSamplesFilter - g_mlClosedTradeCount)) +
                " more trades + " + DoubleToString(InpML_MinAccuracyFilter, 0) +
                "% accuracy for filtering";
      case ML_STATUS_FILTERING:
         return "Full mode: can block low-probability trades";
      case ML_STATUS_FROZEN:
         return "Weights locked, using saved model";
      default:
         return "";
   }
}

void DeinitMLEngine()
{
   if(g_mlInitialized && InpML_AutoSave)
      SaveMLWeights();
}

#endif // ICT_MLENGINE_MQH