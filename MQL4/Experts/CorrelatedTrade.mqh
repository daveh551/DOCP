//+------------------------------------------------------------------+
//|                                              CorrelatedTrade.mqh |
//|                                                   DWH Enterpises |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "DWH Enterpises"
#property link      "http://nohypeforexrobotreview.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CorrelatedTrade
  {
private:

public:
double TradeLots;
OrderInfo *SellTrade;
OrderInfo *BuyTrade;
double divergenceLevel;

                     CorrelatedTrade();
                    ~CorrelatedTrade();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CorrelatedTrade::CorrelatedTrade()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CorrelatedTrade::~CorrelatedTrade()
  {
  }
//+------------------------------------------------------------------+
