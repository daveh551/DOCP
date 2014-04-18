//+------------------------------------------------------------------+
//|                                                         DOCP.mq4 |
//|                                                   DWH Enterpises |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "DWH Enterpises"
#property link      "http://nohypeforexrobotreview.com"
#property version   "1.11"
#property strict
#include <stdlib.mqh>
#include <stderror.mqh> 
#include <OrderReliable_2011.01.07.mqh>
#include "OrderInfo.mqh";
#include "CorrelatedTrade.mqh";

#include <CorrelatedPairs.mqh>;

// input parameters
input int DivergenceInterval = 20;
input int MaxIntervals = 5;
input double TradeSize = .2;
input int MaxSlippagePoints = 2;
// global variables
int numberOfOpenTrades = 0;
CorrelatedTrade *openTrades[];
datetime lastBarStart = 0;
double divergenceIntervalPoints;
double divergenceCloseLevel;
double normalizedLotSize;
int maxSlippageOnEntry;
string otherPair;
int thisPairTickets[];
int otherPairTickets[];
OrderInfo allOrders[];
double lastDivergenceLevel = 0.0;
datetime lastOrderOpened = 0;

string Title="Divergence Of Correlated Pairs (DOCP)"; 
string Prefix="DOCP_EA_";
string Version="v1.11";
int DFVersion = 1;
string saveFileName;
//datetime ExpireDate=D'2041.11.30 00:01';

//double RiskPcnt=1.0;
// int MagicNumber=1111234;

string TextFont="Verdana";
int FiveDig;
int MaxInt=2147483646;
int LotDigits;
bool MarginAlert=false;
double AdjPoint;
static datetime LastTradeTime=0;
color TextColor=Goldenrod;
int debug = 0;
bool HeartBeat = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Print("---------------------------------------------------------");
   Print("-----",Title," ",Version," Initializing ",_Symbol,"-----"); 
   if(Digits==5||Digits==3)
      FiveDig = 10;
   else
      FiveDig = 1;
   AdjPoint = Point * FiveDig;
   DrawVersion(); 

   if(MarketInfo(_Symbol,MODE_LOTSTEP) < 0.1)
      LotDigits = 2;
   else if(MarketInfo(_Symbol,MODE_LOTSTEP) < 1.0)
      LotDigits = 1;
   else
      LotDigits = 0;

   CheckGlobalVariables();
  //---------------------------------------------------- 

   divergenceIntervalPoints = DivergenceInterval * FiveDig;
   if(TradeSize < MarketInfo(_Symbol, MODE_LOTSIZE))
     {
      normalizedLotSize = MarketInfo(_Symbol, MODE_LOTSIZE);
      Alert("TradeSize has been increased to Minimum LotSize of ", DoubleToStr(normalizedLotSize, LotDigits));
     }
   else
   {
      normalizedLotSize = NormalizeDouble(TradeSize, LotDigits);
   }
   maxSlippageOnEntry = MaxSlippagePoints;
   otherPair = FindCorrelatedPair();
   saveFileName = Prefix + StringSubstr(_Symbol, 0, 6) + "_" + StringSubstr(otherPair, 0, 6) + "_DivergentTrades.txt";
   
   FindOpenTrades();

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteAllObjects();
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   double divergence = Divergence();
   // Check if we should be opening a new trade
   if ((MathAbs(divergence) > MathAbs(lastDivergenceLevel) + DivergenceInterval)&&
      numberOfOpenTrades < MaxIntervals)
     {
      OpenTrade(divergence);
     }  
   // Check if we should be closing trades
   if(numberOfOpenTrades > 0)
   {
      if ((lastDivergenceLevel > 0 && divergence <= divergenceCloseLevel) ||
          (lastDivergenceLevel < 0 && divergence >= divergenceCloseLevel))
      {
         CloseTrades();
      }
   }
   if(!IsNewBar())
     {
      return;
     }
   CheckGlobalVariables();
//---
   
  }
//+------------------------------------------------------------------+
void CheckGlobalVariables()
{
   if(GlobalVariableCheck(StringConcatenate(Prefix,"debug")))
      {
      debug = (int) GlobalVariableGet(StringConcatenate(Prefix,"debug"));
      }

   if(GlobalVariableCheck(StringConcatenate(Prefix,"HeartBeat")))
      {
      if(GlobalVariableGet(StringConcatenate(Prefix,"HeartBeat")) == 1)
         HeartBeat = true;
      else
         HeartBeat = false;
      }
}
double Divergence()
{
   return (iCustom(_Symbol, PERIOD_M1, "Divergence", 0, 0));
}

bool IsNewBar()
{
   datetime thisBarTime = iTime(NULL, 0, 0);
   if(thisBarTime != lastBarStart)
     {
      lastBarStart = thisBarTime;
      UpdateDivergenceCloseLevel();
      return true;
     }
   return false;
}

void OpenTrade(double divergence)
{
   int startingOpenTrades = numberOfOpenTrades;
   if(divergence < 0)
     {
         OpenTradePair(_Symbol, otherPair);
     }
     else
       {
        OpenTradePair(otherPair,_Symbol);
       }
    if (numberOfOpenTrades > startingOpenTrades)
    {
      openTrades[startingOpenTrades].divergenceLevel = divergence;
      lastDivergenceLevel = divergence;
      divergenceCloseLevel = 0.0;
      lastOrderOpened = TimeCurrent();
      RecordOpenTrade(startingOpenTrades);
    }
}

void FindOpenTrades()
{
   int totalOrders = OrdersTotal();
   int countThisSymbol =0;
   int countOtherSymbol = 0;
   ArrayResize(allOrders, totalOrders);
   for(int ix=0;ix<totalOrders;ix++)   
     {
      if (OrderSelect(ix,SELECT_BY_POS))
      {
         allOrders[ix].TicketId = OrderTicket();
         allOrders[ix].OrderType = OrderType();
         allOrders[ix].EntryPrice = OrderOpenPrice();
         allOrders[ix].EntryTime = OrderOpenTime();
         allOrders[ix].Symbol = OrderSymbol();
         if(allOrders[ix].Symbol == _Symbol)
           {
            countThisSymbol++;
           }
         if(allOrders[ix].Symbol == otherPair)
           {
            countOtherSymbol++;
           }
      }
      else
        {
         Alert("OrderSelect failed: Error=", GetLastError());
        }
     }
   ArrayResize(thisPairTickets, countThisSymbol);
   ArrayResize(otherPairTickets, countOtherSymbol);
   countThisSymbol = 0;
   countOtherSymbol = 0;
   for(int ix=0;ix<totalOrders;ix++)
     {
      if(allOrders[ix].Symbol == _Symbol)
        {
         thisPairTickets[countThisSymbol++] = allOrders[ix].TicketId;
         
        }
      if(allOrders[ix].Symbol == otherPair)
        {
         otherPairTickets[countOtherSymbol++] = allOrders[ix].TicketId;
        }
     }
   if (countThisSymbol <= countOtherSymbol)
      numberOfOpenTrades = countThisSymbol;
   else
      numberOfOpenTrades = countOtherSymbol;
   
}

void DeleteAllObjects()
   {
   int objs = ObjectsTotal();
   string name;
   for(int cnt=ObjectsTotal()-1;cnt>=0;cnt--)
      {
      name=ObjectName(cnt);
      if (StringFind(name,Prefix,0)>-1) 
         ObjectDelete(name);
      WindowRedraw();
      }
   } //void DeleteAllObjects()
 
void DrawVersion()
   {
   string name;
   name = StringConcatenate(Prefix,"Version");
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name,Version,8,TextFont,TextColor);
   ObjectSet(name,OBJPROP_CORNER,2);
   ObjectSet(name,OBJPROP_XDISTANCE,5);
   ObjectSet(name,OBJPROP_YDISTANCE,2);
   } //void DrawVersion()

void SetGV(string VarName,double VarVal)
   {
   string strVarName = StringConcatenate(Prefix,Symbol(),"_",VarName);

   GlobalVariableSet(strVarName,VarVal);
   if(debug)
      Print("###Set GV ",strVarName," Value=",VarVal);
   } //void SetGV

double GetGV(string VarName)
   {
   string strVarName = StringConcatenate(Prefix,Symbol(),"_",VarName);
   double VarVal = -99999999;

   if(GlobalVariableCheck(strVarName))
      {
      VarVal = GlobalVariableGet(strVarName);
      if(debug)
         Print("###Get GV ",strVarName," Value=",VarVal);
      }

   return(VarVal); 
   } //double GetGV(string VarName)

void HeartBeat(int TimeFrame=PERIOD_H1)
   {
   static datetime LastHeartBeat;
   datetime CurrentTime;

   if(GlobalVariableCheck(StringConcatenate(Prefix,"HeartBeat")))
      {
      if(GlobalVariableGet(StringConcatenate(Prefix,"HeartBeat")) == 1)
         HeartBeat = true;
      else
         HeartBeat = false;
   }  //void HeartBeat(int TimeFrame=PERIOD_H1)

   if(HeartBeat)
      { 
      CurrentTime = iTime(NULL,TimeFrame,0);
      if(CurrentTime > LastHeartBeat)
         {
         Print(Version," HeartBeat ",TimeToStr(TimeCurrent(),TIME_DATE|TIME_MINUTES));
         LastHeartBeat = CurrentTime;
         } //if(CurrentTime > ...
      } //if(HeartBeat)

   } //HeartBeat()
  //------------------------------------------------------
 
 void OpenTradePair(string buySymbol, string sellSymbol)
 {
      OrderInfo *buyResult;
      OrderInfo *sellResult;
      buyResult = OrderBuy(buySymbol);
      if (buyResult.TicketId > 0)
      {
         sellResult = OrderSell(sellSymbol);
         if(sellResult.TicketId >0)
           {
              ArrayResize(openTrades, ++numberOfOpenTrades);
              CorrelatedTrade *thisTrade = new CorrelatedTrade();
              thisTrade.TradeLots = normalizedLotSize;
              thisTrade.BuyTrade = buyResult;
              thisTrade.SellTrade = sellResult;
              openTrades[numberOfOpenTrades-1] = thisTrade;
              return;
           }
           else // If matching order fails, immediately close the buy order
             {
               double closePrice = MarketInfo(buySymbol, MODE_BID);
               int slippage = 5;  // use a large slippage to make sure it succeeds.
              OrderCloseReliable(buyResult.TicketId,buyResult.Lots, closePrice, slippage);
             }
      }
 }
 
 OrderInfo *OrderBuy(string symbol)
 {
   int cmd = OP_BUY;
   double orderPrice = MarketInfo(symbol, MODE_ASK);
   
   return (OrderEnter(symbol, cmd, normalizedLotSize, orderPrice));
 }
 
 OrderInfo *OrderSell(string symbol)
 {
   int cmd = OP_SELL;
   double orderPrice = MarketInfo(symbol, MODE_BID);
   
   return (OrderEnter(symbol, cmd, normalizedLotSize, orderPrice));
 }
 
 OrderInfo *OrderEnter(string symbol, int cmd, double lots, double price)
 {
   OrderInfo *result = new OrderInfo();
   int slippage = maxSlippageOnEntry;
   int ticket = OrderSendReliable(symbol, cmd, lots, price, slippage, 0.0, 0.0, "", 0, 0, clrBlue);
   if (ticket > 0)
   {
      result.TicketId = ticket;
      if (OrderSelect(ticket, SELECT_BY_TICKET))
      {
         result.EntryPrice = OrderOpenPrice();
         result.EntryTime = OrderOpenTime();
         result.ExitTime = 0;
         result.Lots = OrderLots();
         result.OrderType = OrderType();
         result.StopLoss = OrderStopLoss();
         result.Symbol = OrderSymbol();
         result.TakeProfit = OrderTakeProfit();
         result.Status = 0;
         return (result);
      }
      else
      {
         int err = GetLastError();
         PrintFormat("Failed to select order after entry for %s. Error = %s (%i)",
            symbol, ErrorDescription(err), err);
         //TODO: Need to indicate the failure somehow.
         result.Symbol = symbol;
         result.Status = err;
         return result;
      }
   } 
   result.TicketId = -1;
   result.Status = OrderReliableLastErr();
   return result;
 }
 
 void CloseTrades()
 {
   for(int ix=0;ix<numberOfOpenTrades;ix++)
     {
         CloseOpenPairTrade(openTrades[ix]);
         openTrades[ix] = NULL;
     }
   numberOfOpenTrades = 0;
   lastDivergenceLevel = 0.0;
   lastOrderOpened = 0;
 }
 
 void CloseOpenPairTrade(CorrelatedTrade *tradePair)
 {
   CloseTrade(tradePair.BuyTrade);
   tradePair.BuyTrade = NULL;
   CloseTrade(tradePair.SellTrade);
   tradePair.SellTrade = NULL;

 }
 
 void CloseTrade(OrderInfo *tradeInfo)
 {
   if(OrderSelect(tradeInfo.TicketId, SELECT_BY_TICKET))
   {
      double price =
         MarketInfo(tradeInfo.Symbol, (tradeInfo.OrderType == OP_BUY) ? MODE_BID : MODE_ASK);
      OrderCloseReliable(tradeInfo.TicketId, tradeInfo.Lots, price, 5, clrRed);
   }
   else
     {
      int err = GetLastError();
      PrintFormat("Unable to close order %i. Failed to Select order: %s (%i)", tradeInfo.TicketId, ErrorDescription(err),err);
      Alert("Unable to close order ID ", tradeInfo.TicketId, ". Failed to Select Order: ", ErrorDescription(err), " {", err, ")");

     }
 }
 
 void UpdateDivergenceCloseLevel()
 {
 }
 
 void RecordOpenTrade(int tradeIndex)
 {
   int fileHandle = FileOpen(saveFileName, FILE_TXT | FILE_ANSI | FILE_WRITE | FILE_READ);
   CorrelatedTrade *tradeToRecord = openTrades[tradeIndex];
   if (fileHandle != -1)
   {
      FileSeek(fileHandle, 0, SEEK_END);
      ulong pos = FileTell(fileHandle);
      if (pos == 0) //Then this is the first write to this file. Record the DFVersion
      {
         FileWriteString(fileHandle, StringFormat("DataVersion: %i\r\n", DFVersion));
      }
      FileWriteString(fileHandle,  StringFormat("OpenTrade number %i\r\n", tradeIndex));
      FileWriteString(fileHandle, StringFormat("Trade Lots: %f\r\n", tradeToRecord.TradeLots));
      FileWriteString(fileHandle, StringFormat("Sell %s", tradeToRecord.SellTrade.Symbol));
      RecordTrade(fileHandle, tradeToRecord.SellTrade, "Sell");
      RecordTrade(fileHandle, tradeToRecord.BuyTrade, "Buy");
      FileWriteString(fileHandle, StringFormat( "Divergence Level: %f\r\n", tradeToRecord.divergenceLevel));
      FileClose(fileHandle);
   }
   else
   {
      Alert("Unable to open File ", saveFileName, ". Error=", GetLastError());
   }     
}

void RecordTrade(const int fileHandle, const OrderInfo *trade, const string direction)
{
   FileWriteString(fileHandle, StringFormat("%s %s\r\n", direction, trade.Symbol));
   FileWriteString(fileHandle, StringFormat("Entry Price: %f\r\n", trade.EntryPrice));
   FileWriteString(fileHandle, StringFormat("Entry Time: %s", TimeToString(trade.EntryTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS)));
   FileWriteString(fileHandle, StringFormat("Stop Loss: %f\r\n", trade.StopLoss));
   FileWriteString(fileHandle, StringFormat("Take Profit: %f\r\n", trade.TakeProfit));
   FileWriteString(fileHandle, StringFormat("TicketId: %i\r\n", trade.TicketId));
} 