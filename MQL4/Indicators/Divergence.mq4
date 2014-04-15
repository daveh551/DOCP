//+------------------------------------------------------------------+
//|                                                   Divergence.mq4 |
//|                                                  DWH Enterprises |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "DWH Enterprises"
#property link      "http://nohypeforexrobotreview.com"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
//--- plot Divergence
#property indicator_label1  "Divergence"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRoyalBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- indicator buffers
double         DivergenceBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,DivergenceBuffer);
   
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
                const int &spread[])
  {
//---
   double adjustedPrice = iCustom(_Symbol, PERIOD_M1, "DOCP", 0, 0);
   DivergenceBuffer[0] = NormalizeDouble(adjustedPrice - Bid, _Digits);   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
