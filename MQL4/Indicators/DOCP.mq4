//+------------------------------------------------------------------+
//|                                                         DOCP.mq4 |
//|                                  Copyright 2014, DWH Enterprises |
//|                            http://www.nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, DWH Enterprises"
#property link      "http://www.nohypeforexrobotreview.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
//--- plot CorrelatedPair
#property indicator_label1  "CorrelatedPair"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1


#include <stderror.mqh>
#include <stdlib.mqh>;
#include <CorrelatedPairs.mqh>
//--- input parameters
bool Testing = false;
//--- indicator buffers
double         CorrelatedPairBuffer[];
//--- global variables
double correlationBaseDelta;

bool correlationQualityPlotted = false;
string otherPair="GBPUSD.";
double otherPairBase;
const string IndicatorPrefix = "DOCP_";
string saveFileName;
const int DFVersion = 2; // Data file version
string baseLineName;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,CorrelatedPairBuffer);
   otherPair = FindCorrelatedPair();
   saveFileName = IndicatorPrefix + StringSubstr(_Symbol, 0, 6) + "_" + StringSubstr(otherPair, 0, 6) + "_BaseDelta.txt";
   correlationBaseDelta = InitializeCorrelationBase(otherPair);
   if (correlationBaseDelta == 0.0) 
      return (INIT_FAILED);
 
   RecordCorrelationValue(correlationBaseDelta);
   if (Testing)
   {
      
   }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]
                )
  {
//---
   if (rates_total != prev_calculated)
   {
      DrawIndicator(rates_total, prev_calculated, time);
   }
   // Always calculate the zero bar
   CorrelatedPairBuffer[0]=MarketInfo(otherPair, MODE_BID)-correlationBaseDelta;
 
   DisplayDelta();

//--- return value of prev_calculated for next call
   return(rates_total);
  }

void DrawIndicator(int rates_total, int prev_calculated, const datetime &time[])
{
   double otherClose[] ;
   datetime otherBarTimes[];
   int otherBarsCounted;
   int otherTimesCounted;
   ArraySetAsSeries(otherClose, true);
   ArraySetAsSeries(otherBarTimes, true);
   if (rates_total == prev_calculated)
      return ;
   otherBarsCounted =CopyClose(otherPair, PERIOD_M1, 0, rates_total-prev_calculated, otherClose);
   otherTimesCounted = CopyTime(otherPair, PERIOD_M1, 0, rates_total-prev_calculated, otherBarTimes);
   if (otherBarsCounted == -1)
   {
      Alert("Failed to copy bars for ", otherPair, ": ", ErrorDescription(GetLastError()));
   }
   else
   {
     int limit = (otherBarsCounted < rates_total-prev_calculated)? otherBarsCounted : rates_total-prev_calculated;
     int iy = 0;   
     for(int ix=0;ix<limit && iy<limit;ix++)
       {
           if (otherBarTimes[iy] == time[ix])
           {
               CorrelatedPairBuffer[ix]=otherClose[iy]-correlationBaseDelta;
           }
           else
             {
              if (otherBarTimes[iy] > time[ix])
               ix--;
             else
                iy--;
             }
            iy++;

       }
   }

   if (!correlationQualityPlotted)
      DisplayCorrelationQuality(CalculateCorrelationQuality()); 
  
   return;

}   
  void RedrawIndicator()
  {
   datetime thisPairTime[];
   ArraySetAsSeries(thisPairTime, true);
   int thisPairBars = Bars(_Symbol, PERIOD_M1);
   int thisPairTimeBars;
   thisPairTimeBars = CopyTime(_Symbol, PERIOD_M1, 0, thisPairBars, thisPairTime);
   
   DrawIndicator(thisPairTimeBars, 0, thisPairTime);
  }
  
  void OnDeinit(const int reason)
    {
      int prefixLen = StringLen(IndicatorPrefix);
      int objectsTotal = ObjectsTotal();
      string objectNames[] ;
      ArrayResize(objectNames, objectsTotal);
      int lastError = 0;
      ResetLastError();
      for(int ix=0;ix<objectsTotal;ix++)
        {
         objectNames[ix] = ObjectName(ix);
         if (objectNames[ix] ==  NULL)
         {
            lastError = GetLastError();
            Alert("ObjectName for object ", ix, " of ", objectsTotal, " is NULL. Error=", ErrorDescription(lastError), " (", lastError,")");
         }
        }
      for(int ix=0;ix<objectsTotal;ix++)
        {
         
         if (StringSubstr(objectNames[ix], 0, prefixLen) == IndicatorPrefix)
            ObjectDelete(objectNames[ix]);
        }
    }
//+------------------------------------------------------------------+



double InitializeCorrelationBase(string otherSymbol)
{
   double baseDelta = ReadCorrelationValue();
   if (baseDelta == 0.0) 
   {
      int otherPairBars = Bars(otherSymbol, PERIOD_M1);
      if (otherPairBars <=0)
      {
         Alert("There is no open chart for " + otherPair);
         return (0.0);
      }
      int thisPairBars = Bars(_Symbol, PERIOD_M1);
   
      otherPairBase = iMA(otherSymbol, PERIOD_M1, otherPairBars, 0, MODE_EMA, PRICE_CLOSE, 0);
      double thisPairBase = iMA(NULL, PERIOD_M1, thisPairBars, 0, MODE_EMA, PRICE_CLOSE, 0);
   
      baseDelta =  NormalizeDouble( otherPairBase - thisPairBase, _Digits);
   }
   baseLineName = IndicatorPrefix + "CorrelationBase";
   long currentChart = ChartID();
   ObjectDelete(currentChart,baseLineName);
   ObjectCreate(currentChart, baseLineName, OBJ_HLINE, 0, 0, otherPairBase-baseDelta);
   ObjectSetInteger(currentChart, baseLineName, OBJPROP_COLOR, clrAqua);
   return baseDelta;
}

void RecordCorrelationValue(double correlationValue)
{
   DisplayCorrelationValue(correlationValue);
   SaveCorrelationValue(correlationValue);
}
void SaveCorrelationValue(double correlationValue)
{
   int fileHandle = FileOpen(saveFileName, FILE_TXT | FILE_ANSI | FILE_WRITE);
   if (fileHandle != -1)
   {
      FileWriteString(fileHandle, StringFormat("DataVersion: %i\r\n", DFVersion));
      FileWriteString(fileHandle, StringFormat("BaseDelta: %.5f\r\n", correlationValue));
      FileWriteString(fileHandle, StringFormat("BaseValue: %.5f\r\n", otherPairBase));
      FileWriteString(fileHandle, StringFormat("Time: %s", TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS)));
      FileClose(fileHandle);
   }
   else
   {
      Alert("Unable to open File ", saveFileName, ". Error=", GetLastError());
   }     
}

double ReadCorrelationValue()
{
   double returnValue = 0.0;
   int fileHandle = FileOpen(saveFileName, FILE_TXT | FILE_ANSI | FILE_READ);
   if (fileHandle != -1)
   {
      string versionString =FileReadString(fileHandle);
      string formattedVersion = StringFormat("DataVersion: %i", DFVersion);
      if (versionString == formattedVersion)
      {
         string readString = FileReadString(fileHandle);
         StringReplace(readString, "BaseDelta: ", "");
         returnValue = StringToDouble(readString);
         readString = FileReadString(fileHandle);
         StringReplace(readString, "BaseValue: ", "");
         otherPairBase = StringToDouble(readString);
      }
      FileClose(fileHandle);
   }
   return (returnValue);
}

void DisplayCorrelationValue(double correlationValue)
{
   long chartID = ChartID();
   string correlationLabelName = IndicatorPrefix + "OffsetLabel";
   string correlationDataName = IndicatorPrefix + "OffsetValue";
   if(ObjectFind(correlationLabelName) < 0)
     {
      ObjectCreate(correlationLabelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetText(correlationLabelName, "Base Offset:", 16, NULL, clrAqua);
      ObjectSetInteger(chartID,correlationLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(chartID,correlationLabelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(chartID, correlationLabelName, OBJPROP_YDISTANCE, 10);
     }
   if(ObjectFind(correlationDataName) < 0)
     {
      ObjectCreate(correlationDataName, OBJ_LABEL, 0,0,0);
     }
   ObjectSetText(correlationDataName, DoubleToStr(correlationValue, _Digits), 16, NULL, clrAqua);
   ObjectSetInteger(chartID, correlationDataName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartID, correlationDataName, OBJPROP_XDISTANCE, 15+250);
   ObjectSetInteger(chartID, correlationDataName, OBJPROP_YDISTANCE, 10);   
   
}

void DisplayCorrelationQuality(double correlationQuality)
{
   long chartID = ChartID();
   string correlationLabelName = IndicatorPrefix + "QualityLabel";
   string correlationDataName = IndicatorPrefix + "QualityValue";
   if(ObjectFind(correlationLabelName) < 0)
     {
      ObjectCreate(correlationLabelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetText(correlationLabelName, "Correlation Quality:", 16, NULL, clrAqua);
      ObjectSetInteger(chartID,correlationLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(chartID,correlationLabelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(chartID, correlationLabelName, OBJPROP_YDISTANCE, 50);
     }
   if(ObjectFind(correlationDataName) < 0)
     {
      ObjectCreate(correlationDataName, OBJ_LABEL, 0,0,0);
     }
   ObjectSetText(correlationDataName, DoubleToStr( correlationQuality, 3), 16, NULL, clrAqua);
   ObjectSetInteger(chartID, correlationDataName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(chartID, correlationDataName, OBJPROP_XDISTANCE, 15+250);
   ObjectSetInteger(chartID, correlationDataName, OBJPROP_YDISTANCE, 50);   
   correlationQualityPlotted = true;
   
}


void OnChartEvent(const int id,const long& lparam,const double& dparam,const string& sparam)
  {
      if(id == CHARTEVENT_OBJECT_DRAG && sparam == baseLineName)
        {
            ResetLastError();
            long currentChart = ChartID();
            double lineValue;
            double originalTranslatedOtherPair = otherPairBase - correlationBaseDelta;// starting line value
            bool success = ObjectGetDouble(currentChart, baseLineName, OBJPROP_PRICE, 0, lineValue);
            if(!success)
              {   
                  int lastError = GetLastError();
                  Alert("ObjectGetDouble() [", baseLineName,"] failed: ", ErrorDescription(lastError), " (", lastError, ")");
                  return;
              }
            double movement = lineValue - originalTranslatedOtherPair;
            correlationBaseDelta -= movement;
            correlationBaseDelta = NormalizeDouble(correlationBaseDelta, _Digits);
            RecordCorrelationValue(correlationBaseDelta);
            RedrawIndicator();
            DisplayCorrelationQuality(CalculateCorrelationQuality());
        }
  }
  
  double CalculateCorrelationQuality()
  {
   // I'm not sure what the "best" algorhythm is for assigning a metric to correlation quality
   // but we'll try some out.
   
   int lengthToCompare = 1200; //20 hours worth of 1 minute bars
   int thisPairBars = Bars(_Symbol, PERIOD_M1);
   double thisPairClose[];
   ArraySetAsSeries(thisPairClose, true);
   CopyClose(_Symbol, PERIOD_M1, 0, thisPairBars, thisPairClose);
   if (thisPairBars < lengthToCompare) lengthToCompare = thisPairBars;
   int indicatorBars = ArrayRange(CorrelatedPairBuffer, 0);
   if (indicatorBars < lengthToCompare) lengthToCompare = indicatorBars;
   double quality = 0;
   for(int ix=0;ix<lengthToCompare;ix++)
   {
      double diff = NormalizeDouble(MathAbs(thisPairClose[ix] - CorrelatedPairBuffer[ix]), _Digits);
      if (diff < 1) // filter outliers
        quality += diff / (ix+1); //weight it to give more weight to differences at near the current point.
   }
   return quality * 1000.0;   
  }
   
void DisplayDelta()
{
   long chartID = ChartID();
   string deltaLabelName = IndicatorPrefix + "DeltaLabel";
   string deltaDataName = IndicatorPrefix + "DeltaValue";
   if(ObjectFind(deltaLabelName) < 0)
     {
      ObjectCreate(deltaLabelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetText(deltaLabelName, "Current Divergence:", 16, NULL, clrAqua);
      ObjectSetInteger(chartID,deltaLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(chartID,deltaLabelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(chartID, deltaLabelName, OBJPROP_YDISTANCE, 90);
     }
   if(ObjectFind(deltaDataName) < 0)
     {
      ObjectCreate(deltaDataName, OBJ_LABEL, 0,0,0);
      ObjectSetInteger(chartID, deltaDataName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(chartID, deltaDataName, OBJPROP_XDISTANCE, 15+250);
      ObjectSetInteger(chartID, deltaDataName, OBJPROP_YDISTANCE, 90);   
     }
   double offset = NormalizeDouble(CorrelatedPairBuffer[0] - Bid, _Digits);
   ObjectSetText(deltaDataName, DoubleToStr( offset, _Digits), 16, NULL, clrAqua);
   

}