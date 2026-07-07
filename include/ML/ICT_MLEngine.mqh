//+------------------------------------------------------------------+
//|                       ICT_MLEngine.mqh                            |
//|         Online Machine Learning Engine v2.0                        |
//|         Fixed Deadlocks + Proper 3-Mode Implementation            |
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
   
   // Reset all ML state
   g_mlWeights.Reset();
   g_mlWeights.InitDefaults();
   g_mlPrediction.Reset();
   g_mlPrediction.recommend = true;  // FIX: Default to ALLOW trades
   g_mlStats.Reset();
   g_mlAdaptive.Reset();
   g_mlDiag.Reset();
   g_mlClosedTradeCount = 0;
   
   // Initialize sample buffers
   ArrayResize(g_mlSamples, ML_MAX_SAMPLES);
   for(int i = 0; i < ML_MAX_SAMPLES; i++) g_mlSamples[i].Reset();
   g_mlSampleCount = 0;
   g_mlSampleWriteIdx = 0;
   
   // Initialize prediction history
   ArrayResize(g_mlPredHistory, ML_MAX_HISTORY);
   for(int i = 0; i < ML_MAX_HISTORY; i++) g_mlPredHistory[i].Reset();
   g_mlPredHistCount = 0;
   g_mlPredHistWriteIdx = 0;
   
   // Initialize normalization
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
   {
      g_mlFeatureMean[i] = 0.5;
      g_mlFeatureStd[i] = 0.3;
   }
   g_mlStatsComputed = false;
   
   // Load saved weights (unless reset requested)
   if(!InpML_ResetOnStart && LoadMLWeights())
   {
      Print("ML Engine: Loaded saved state (",
            g_mlWeights.updateCount, " updates, ",
            g_mlClosedTradeCount, " closed trades)");
   }
   else
   {
      // Initialize with small sensible defaults
      InitializeDefaultWeights();
   }
   
   // Determine initial status
   UpdateMLStatus();
   
   g_mlInitialized = true;
   
   Print("═══ ML ENGINE v2.0 INITIALIZED ═══");
   Print("  Mode: ", EnumToString(InpML_Mode));
   Print("  Status: ", MLStatusToString(g_mlStatus));
   Print("  Closed Trades: ", g_mlClosedTradeCount);
   Print("  Min Samples Filter: ", InpML_MinSamplesFilter);
   Print("  Min Accuracy Filter: ", DoubleToString(InpML_MinAccuracyFilter, 1), "%");
   Print("═══════════════════════════════════");
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Default Weights (Sensible Starting Point)              |
//+------------------------------------------------------------------+
void InitializeDefaultWeights()
{
   // Small positive weights for features known to be generally positive
   g_mlWeights.weights[MLF_HTF_ALIGNED]    = 0.05;
   g_mlWeights.weights[MLF_ALL_TF_ALIGNED] = 0.08;
   g_mlWeights.weights[MLF_KZ_ACTIVE]      = 0.05;
   g_mlWeights.weights[MLF_HAS_OB]         = 0.05;
   g_mlWeights.weights[MLF_HAS_FVG]        = 0.03;
   g_mlWeights.weights[MLF_HAS_STACK]      = 0.05;
   g_mlWeights.weights[MLF_OTE_IN_ZONE]    = 0.03;
   g_mlWeights.weights[MLF_ZONE_ALIGNED]   = 0.05;
   g_mlWeights.weights[MLF_SMT_CONFIRMED]  = 0.03;
   g_mlWeights.weights[MLF_EXT_SWEPT]      = 0.05;
   g_mlWeights.weights[MLF_RR_RATIO]       = 0.08;
   g_mlWeights.weights[MLF_DISPLACEMENT]   = 0.05;
   g_mlWeights.weights[MLF_BODY_CLOSE]     = 0.03;
   g_mlWeights.weights[MLF_ORIGIN_EXISTS]  = 0.05;
   
   // Neutral/slightly negative for ambiguous features
   g_mlWeights.weights[MLF_SPREAD_NORM]    = -0.02;
   
   // Bias: slight positive (default is "allow")
   g_mlWeights.bias = 0.1;
   
   g_mlWeights.updateCount = 0;
}

//+------------------------------------------------------------------+
//|              SECTION 2: STATUS MANAGEMENT                          |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Update ML Status Based on Data Available                          |
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
   
   // WARMUP: Not enough closed trades
   if(g_mlClosedTradeCount < InpML_WarmupTrades)
   {
      g_mlStatus = ML_STATUS_WARMUP;
      g_mlStats.warmupRemaining = InpML_WarmupTrades - g_mlClosedTradeCount;
      return;
   }
   
   // Check if we have enough data for filtering
   g_mlDiag.hasEnoughSamples = (g_mlClosedTradeCount >= InpML_MinSamplesFilter);
   g_mlDiag.hasGoodAccuracy = (g_mlStats.predictionAccuracy >= InpML_MinAccuracyFilter);
   
   // FILTERING: Enough samples AND demonstrated accuracy
   if(g_mlDiag.hasEnoughSamples && g_mlDiag.hasGoodAccuracy)
   {
      g_mlStatus = ML_STATUS_FILTERING;
      return;
   }
   
   // OBSERVING: Past warmup but not enough for filtering
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
   int idx = 0;
   

   
   // Binary features
   fv.Set(MLF_HTF_ALIGNED,    g_htfCtfAligned ? 1.0 : 0.0);
   fv.Set(MLF_ALL_TF_ALIGNED, g_allTFsAligned ? 1.0 : 0.0);
   fv.Set(MLF_KZ_ACTIVE,      g_killzone.isActive ? 1.0 : 0.0);
   fv.Set(MLF_KZ_MULTIPLIER,  Clamp(g_killzone.multiplier / 2.0, 0, 1));
   
   // AMD Phase
   double amdVal = 0;
   switch(g_amdPhase.currentPhase)
   {
      case AMD_ACCUMULATION: amdVal = 0.33; break;
      case AMD_MANIPULATION: amdVal = 0.66; break;
      case AMD_DISTRIBUTION: amdVal = 1.0; break;
   }
   fv.Set(MLF_AMD_PHASE, amdVal);
   
   // PD Array presence
   fv.Set(MLF_HAS_OB,  (GetBestOrderBlock(isBull) >= 0) ? 1.0 : 0.0);
   
   bool inFVG = IsPriceInFVG(isBull, idx);
   fv.Set(MLF_HAS_FVG, inFVG ? 1.0 : 0.0);
   
   int bestStack = GetBestStack(isBull);
   fv.Set(MLF_HAS_STACK,   (bestStack >= 0) ? 1.0 : 0.0);
   fv.Set(MLF_STACK_COUNT,  (bestStack >= 0 && bestStack < g_stackCount) ? 
                            Clamp(g_pdStacks[bestStack].stackCount / 5.0, 0, 1) : 0.0);
   
   fv.Set(MLF_OTE_IN_ZONE,   IsPriceInOTEZone() ? 1.0 : 0.0);
   fv.Set(MLF_ZONE_ALIGNED,  IsZoneAligned(isBull) ? 1.0 : 0.0);
   fv.Set(MLF_SMT_CONFIRMED, HasSMTConfirmation(isBull) ? 1.0 : 0.0);
   fv.Set(MLF_JUDAS_ACTIVE,  HasActiveJudasSwing() ? 1.0 : 0.0);
   
   // DR state
   SDealingRange* dr = isBull ? GetPointer(g_bullDR) : GetPointer(g_bearDR);
   fv.Set(MLF_EXT_SWEPT, (dr != NULL && dr.externalSwept) ? 1.0 : 0.0);
   
   // Risk/Reward
   double rr = g_currentSignal.riskReward;
if(rr <= 0) rr = InpRiskReward;
fv.Set(MLF_RR_RATIO, Clamp(rr / 5.0, 0, 1));
   
   // Displacement
   double atr = GetATRSafe();
   fv.Set(MLF_DISPLACEMENT, (atr > 0 && IsDisplacementCandle(PERIOD_CURRENT, 1, atr)) ? 1.0 : 0.0);
   
   // Body close
   double prevC = iClose(_Symbol, PERIOD_CURRENT, 1);
   double prevO = iOpen(_Symbol, PERIOD_CURRENT, 1);
   bool bodyOK = isBull ? (prevC > prevO) : (prevC < prevO);
   fv.Set(MLF_BODY_CLOSE, bodyOK ? 1.0 : 0.0);
   
   // LTF BOS
   bool ltfBOS = false;
   if(g_ltfLayer.isInitialized)
   {
      SDealingRange* ltfDR = g_ltfLayer.isBullishActive ? 
                             GetPointer(g_ltfLayer.bullDR) : GetPointer(g_ltfLayer.bearDR);
      ltfBOS = (ltfDR != NULL && ltfDR.corrLine.isActive && ltfDR.externalSwept);
   }
   fv.Set(MLF_LTF_BOS, ltfBOS ? 1.0 : 0.0);
   fv.Set(MLF_ORIGIN_EXISTS, HasCTFOrigin() ? 1.0 : 0.0);
   
   // Spread (normalized)
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   fv.Set(MLF_SPREAD_NORM, Clamp(spread / 50.0, 0, 1));
   
   // Hour (normalized)
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   fv.Set(MLF_HOUR_NORM, tm.hour / 24.0);
   
      // === STATE MACHINE NARRATIVE FEATURES ===
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
   pred.recommend = true;  // DEFAULT: allow trades
   
   if(!g_mlInitialized || InpML_Mode == ML_OFF)
   {
      pred.probability = 0.5;
      pred.reason = "ML Off";
      return pred;
   }
   
   // ═══ WARMUP: No effect, always allow ═══
   if(g_mlStatus == ML_STATUS_WARMUP)
   {
      pred.probability = 0.5;
      pred.recommend = true;
      pred.confidence = 0;
      pred.adjustedBias = 0;
      pred.reason = "Warmup (" + IntegerToString(g_mlStats.warmupRemaining) + " trades left)";
      return pred;
   }
   
   // ═══ Compute logistic probability ═══
   double z = g_mlWeights.bias;
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      z += g_mlWeights.weights[i] * fv.features[i];
   
   g_mlDiag.lastLinearZ = z;
   pred.probability = Sigmoid(z);
   
   // Confidence based on data quality
   double confRaw = Clamp((double)g_mlClosedTradeCount / (double)InpML_MinSamplesFilter, 0, 1);
   pred.confidence = confRaw * 100.0;
   
   // ═══ Score adjustment (ADAPTIVE & COMBINED modes) ═══
   pred.adjustedBias = 0;
   if(InpML_Mode == ML_ADAPTIVE || InpML_Mode == ML_COMBINED)
   {
      pred.adjustedBias = CalculateAdaptiveAdjustment(fv);
   }
   
   // ═══ Trade recommendation ═══
   switch(g_mlStatus)
   {
      case ML_STATUS_OBSERVING:
         // Adjust scores but NEVER block
         pred.recommend = true;
         if(pred.probability < InpML_MinProbability)
            pred.reason = "Observing: P=" + DoubleToString(pred.probability, 3) + 
                         " (would block, but not enough data yet)";
         else
            pred.reason = "Observing: P=" + DoubleToString(pred.probability, 3) + " ✓";
         break;
         
      case ML_STATUS_FILTERING:
      case ML_STATUS_FROZEN:
         // Only LOGISTIC and COMBINED modes can block
         if(InpML_Mode == ML_LOGISTIC || InpML_Mode == ML_COMBINED)
         {
            pred.recommend = (pred.probability >= InpML_MinProbability);
            if(pred.recommend)
               pred.reason = "Filter: P=" + DoubleToString(pred.probability, 3) + " ✓";
            else
               pred.reason = "Filter: P=" + DoubleToString(pred.probability, 3) + 
                            " < " + DoubleToString(InpML_MinProbability, 2) + " ✗";
         }
         else // ML_ADAPTIVE: never blocks, only adjusts scores
         {
            pred.recommend = true;
            pred.reason = "Adaptive: Adj=" + DoubleToString(pred.adjustedBias, 1);
         }
         break;
         
      default:
         pred.recommend = true;
         pred.reason = "Unknown status";
   }
   
   return pred;
}

//+------------------------------------------------------------------+
//| Calculate Adaptive Score Adjustment                               |
//| Uses feature effectiveness (winAvg - lossAvg per feature)        |
//+------------------------------------------------------------------+
double CalculateAdaptiveAdjustment(SMLFeatureVector &fv)
{
   if(g_mlAdaptive.winCount < 3 || g_mlAdaptive.lossCount < 3)
      return 0;
   
   double adjustment = 0;
   
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
   {
      // Effect = how much more this feature appears in wins vs losses
      // Positive effect + high feature value = boost score
      // Negative effect + high feature value = reduce score
      adjustment += g_mlAdaptive.featureEffect[i] * fv.features[i];
   }
   
   // Scale to ±ScoreAdjustMax
   double maxEffect = 0;
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      maxEffect += MathAbs(g_mlAdaptive.featureEffect[i]);
   
   if(maxEffect > 0)
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
   
   bool isWin = (pnl > 0);
   
   // ═══ Store sample in ring buffer ═══
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
   
   // ═══ Update adaptive statistics (ALL modes) ═══
   UpdateAdaptiveStats(fv, isWin);
   
   // ═══ Update feature normalization ═══
   UpdateFeatureNormalization(fv);
   
   // ═══ Logistic regression learning step ═══
   if(!InpML_FreezeLearning && 
      (InpML_Mode == ML_LOGISTIC || InpML_Mode == ML_COMBINED))
   {
      PerformLearningStep(g_mlSamples[writeIdx]);
   }
   
   // ═══ Update status ═══
   g_mlStats.totalSamples = g_mlSampleCount;
   UpdateMLStatus();
   
   // ═══ Auto-save ═══
   if(InpML_AutoSave && (g_mlClosedTradeCount % InpML_SaveInterval == 0))
      SaveMLWeights();
   
   // ═══ Update feature importance ═══
   UpdateFeatureImportance();
   
   Print("ML: Sample added (", (isWin ? "WIN" : "LOSS"),
         " $", DoubleToString(pnl, 2),
         ") Total: ", g_mlClosedTradeCount,
         " Status: ", MLStatusToString(g_mlStatus));
}

//+------------------------------------------------------------------+
//| Update Adaptive Statistics                                        |
//+------------------------------------------------------------------+
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
      for(int i = 0; i < ML_FEATURE_COUNT; i++)
         g_mlAdaptive.lossFeatureSum[i] += fv.features[i];
      g_mlAdaptive.lossCount++;
   }
   
   g_mlAdaptive.UpdateEffects();
}

//+------------------------------------------------------------------+
//| Perform SGD Learning Step (Logistic Regression)                   |
//+------------------------------------------------------------------+
void PerformLearningStep(SMLTrainingSample &sample)
{
   // Learning rate with decay (FIX: cap minimum LR)
   double decayedLR = InpML_LearningRate / (1.0 + InpML_DecayRate * g_mlWeights.updateCount);
   double lr = MathMax(decayedLR, InpML_LearningRate * 0.01); // Never go below 1% of base LR
   
   // Forward pass
   double z = g_mlWeights.bias;
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      z += g_mlWeights.weights[i] * sample.featureVec.features[i];
   
   double predicted = Sigmoid(z);
   double error = sample.label - predicted;
   
   // SGD update with L2 regularization
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
   {
      double gradient = error * sample.featureVec.features[i];
      double l2_penalty = InpML_RegStrength * g_mlWeights.weights[i];
      
      g_mlWeights.weights[i] += lr * (gradient - l2_penalty);
      g_mlWeights.weights[i] = Clamp(g_mlWeights.weights[i], -InpML_WeightBound, InpML_WeightBound);
   }
   
   // Bias update
   g_mlWeights.bias += lr * error;
   g_mlWeights.bias = Clamp(g_mlWeights.bias, -InpML_WeightBound, InpML_WeightBound);
   
   g_mlWeights.updateCount++;
}

//+------------------------------------------------------------------+
//| Update Feature Normalization (Running Statistics)                 |
//+------------------------------------------------------------------+
void UpdateFeatureNormalization(SMLFeatureVector &fv)
{
   double alpha = 0.05; // Exponential moving average
   
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
   
   // Track allowed/blocked
   if(tradeTaken)
      g_mlDiag.tradesAllowed++;
   else
      g_mlDiag.tradesBlocked++;
}

//+------------------------------------------------------------------+
//| Update Prediction Outcome (FIXED ring buffer indexing)            |
//+------------------------------------------------------------------+
void UpdatePredictionOutcome(bool win, double pnl)
{
   if(g_mlPredHistCount == 0) return;
   
   // Search backwards from most recent entry
   for(int lookback = 0; lookback < g_mlPredHistCount; lookback++)
   {
      int idx = (g_mlPredHistWriteIdx - 1 - lookback + ML_MAX_HISTORY) % ML_MAX_HISTORY;
      
      if(idx < 0 || idx >= ML_MAX_HISTORY) continue;
      
      if(g_mlPredHistory[idx].tradeTaken && g_mlPredHistory[idx].pnl == 0)
      {
         g_mlPredHistory[idx].actualWin = win;
         g_mlPredHistory[idx].pnl = pnl;
         
         // Update accuracy stats
         bool correctPred = (g_mlPredHistory[idx].predictedProb >= 0.5) == win;
         g_mlStats.totalPredictions++;
         if(correctPred) g_mlStats.correctPredictions++;
         g_mlStats.Calculate();
         
         // Update average probabilities
         if(win)
         {
            if(g_mlStats.avgWinProb == 0)
               g_mlStats.avgWinProb = g_mlPredHistory[idx].predictedProb;
            else
               g_mlStats.avgWinProb = g_mlStats.avgWinProb * 0.9 + 
                                      g_mlPredHistory[idx].predictedProb * 0.1;
         }
         else
         {
            if(g_mlStats.avgLossProb == 0)
               g_mlStats.avgLossProb = g_mlPredHistory[idx].predictedProb;
            else
               g_mlStats.avgLossProb = g_mlStats.avgLossProb * 0.9 + 
                                       g_mlPredHistory[idx].predictedProb * 0.1;
         }
         
         break; // Found and updated
      }
   }
   
   // Compute recent accuracy (last 20 predictions with outcomes)
   int recentCorrect = 0, recentTotal = 0;
   for(int lookback = 0; lookback < g_mlPredHistCount && recentTotal < 20; lookback++)
   {
      int idx = (g_mlPredHistWriteIdx - 1 - lookback + ML_MAX_HISTORY) % ML_MAX_HISTORY;
      if(idx < 0 || idx >= ML_MAX_HISTORY) continue;
      
      if(g_mlPredHistory[idx].pnl != 0) // Has outcome
      {
         recentTotal++;
         bool correct = (g_mlPredHistory[idx].predictedProb >= 0.5) == g_mlPredHistory[idx].actualWin;
         if(correct) recentCorrect++;
      }
   }
   if(recentTotal > 0)
      g_mlStats.recentAccuracy = (double)recentCorrect / recentTotal * 100.0;
   
   // Re-check status after accuracy update
   UpdateMLStatus();
}

//+------------------------------------------------------------------+
//|              SECTION 8: SCORING INTERFACE                          |
//+------------------------------------------------------------------+

int GetMLScoreAdjustment()
{
//all removed//
  return 0;
}
bool ShouldMLBlockTrade()
{
   if(!g_mlInitialized || InpML_Mode == ML_OFF)
      return false;

   // Never block during warmup/observing
   if(g_mlStatus == ML_STATUS_WARMUP || g_mlStatus == ML_STATUS_OBSERVING)
      return false;

   // Adaptive mode adjusts behavior, does not hard-block
   if(InpML_Mode == ML_ADAPTIVE)
      return false;

   // Filtering/Frozen + logistic/combined can block
   return (!g_mlPrediction.recommend);
   }
//+------------------------------------------------------------------+
//|              SECTION 9: FEATURE IMPORTANCE                         |
//+------------------------------------------------------------------+

void UpdateFeatureImportance()
{
   double maxWeight = 0.001; // Avoid division by zero
   
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
   {
      double absW = MathAbs(g_mlWeights.weights[i]);
      if(absW > maxWeight) maxWeight = absW;
   }
   
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
   {
      // Combine logistic weight importance with adaptive effect importance
      double logisticImp = MathAbs(g_mlWeights.weights[i]) / maxWeight;
      double adaptiveImp = 0;
      
      if(g_mlAdaptive.winCount > 0 || g_mlAdaptive.lossCount > 0)
      {
         double maxEffect = 0.001;
         for(int j = 0; j < ML_FEATURE_COUNT; j++)
            maxEffect = MathMax(maxEffect, MathAbs(g_mlAdaptive.featureEffect[j]));
         adaptiveImp = MathAbs(g_mlAdaptive.featureEffect[i]) / maxEffect;
      }
      
      // Blend importance sources
      g_mlStats.featureImportance[i] = (logisticImp * 0.6 + adaptiveImp * 0.4);
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
   
   // Logistic weights
   FileWrite(handle, "BIAS", 0, DoubleToString(g_mlWeights.bias, 10));
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      FileWrite(handle, "WEIGHT", i, DoubleToString(g_mlWeights.weights[i], 10));
   
   // Adaptive stats
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      FileWrite(handle, "WIN_SUM", i, DoubleToString(g_mlAdaptive.winFeatureSum[i], 10));
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      FileWrite(handle, "LOSS_SUM", i, DoubleToString(g_mlAdaptive.lossFeatureSum[i], 10));
   
   // Normalization
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      FileWrite(handle, "FEAT_MEAN", i, DoubleToString(g_mlFeatureMean[i], 10));
   for(int i = 0; i < ML_FEATURE_COUNT; i++)
      FileWrite(handle, "FEAT_STD", i, DoubleToString(g_mlFeatureStd[i], 10));
   
   // Metadata
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
   
   // Skip header
   if(!FileIsEnding(handle)) { FileReadString(handle); FileReadString(handle); FileReadString(handle); }
   
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
         return "Observing " + IntegerToString(g_mlStats.warmupRemaining) + 
                " more trades before learning";
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