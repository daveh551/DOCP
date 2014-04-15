//+------------------------------------------------------------------+
//|                                                    OrderInfo.mqh |
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
class OrderInfo
  {
private:

public:
   int   TicketId;
   double   EntryPrice;
   double   StopLoss;
   double   TakeProfit;
   double   Lots;
   datetime EntryTime;
   datetime ExitTime;
   string   Symbol;
   int      OrderType;
   int      Status;
   
                     OrderInfo();
                    ~OrderInfo();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderInfo::OrderInfo()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
OrderInfo::~OrderInfo()
  {
  }
//+------------------------------------------------------------------+
