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
   ReadStoredTrades();
   
   // Have to validate the openTrades found in the ReadStoredTrades file.
   // Two possibilities for invalidation:
   //    a) Trades recorded there are no longer active
   //    b) Trades that are active aren't recorded there
   // Validate all  orders recorded
   bool tradeValidated[];
   int numOpenTrades = ArrayRange(openTrades, 0);
   ArrayResize(tradeValidated, numOpenTrades);
   for(int ix=0;ix<numOpenTrades;ix++)
     {
         tradeValidated[ix] =
            (OrderSelect(openTrades[ix].BuyTrade.TicketId, SELECT_BY_TICKET) &&
            OrderCloseTime() == 0 && 
            OrderSelect(openTrades[ix].SellTrade.TicketId, SELECT_BY_TICKET) &&
            OrderCloseTime() == 0);
         if (tradeValidated[ix])
         {
            numberOfOpenTrades = ix + 1;
            lastDivergenceLevel = openTrades[ix].divergenceLevel;
         }
     }
    for(int ix=0;ix<numOpenTrades;ix++)
      {
       if(tradeValidated[ix] == false)
       // Need to remove that trade from the array
         {
          for(int jx=ix;jx<numOpenTrades-1;jx++)
            {
             openTrades[jx] = openTrades[jx-1];
             tradeValidated[jx] = tradeValidated[jx-1];
            }
           numOpenTrades--;
           ix--;
           ArrayResize(openTrades, numOpenTrades);
         }
      }
   
   // Now make  sure all open trades are accounted for in openTrades
   int totalOrders = OrdersTotal();
   OrderInfo *unmatchedTrades[];
   int numUnMatchedTrades = 0;
   for(int ix=0;ix<totalOrders;ix++)
     {
         if (OrderSelect(ix, SELECT_BY_POS, MODE_TRADES))
         {
            string symbol = OrderSymbol();
            if (symbol == _Symbol || symbol == otherPair)
            {
               int ticketID = OrderTicket();
               if (TicketIsInOpenOrders(ticketID))
                  continue;
               else
               {
                  //store info on this trade and match up with the counter trade
                  ArrayResize(unmatchedTrades,++numUnMatchedTrades);
                  OrderInfo *thisTrade = new OrderInfo();
                  thisTrade.Symbol = symbol;
                  thisTrade.TicketId = ticketID;
                  thisTrade.EntryTime = OrderOpenTime();
                  thisTrade.EntryPrice = OrderOpenPrice();
                  thisTrade.Lots = OrderLots();
                  thisTrade.OrderType = OrderType();
                  thisTrade.StopLoss = OrderStopLoss();
                  thisTrade.TakeProfit = OrderTakeProfit();
                  unmatchedTrades[numUnMatchedTrades-1] = thisTrade;
               }
            }
         }
     }
     if (numUnMatchedTrades > 1)
     {
      FindUnsavedTrades(unmatchedTrades);
     }
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
         delete(openTrades[ix]);
         openTrades[ix] = NULL;
     }
   numberOfOpenTrades = 0;
   lastDivergenceLevel = 0.0;
   lastOrderOpened = 0;
 }
 
 void CloseOpenPairTrade(CorrelatedTrade *tradePair)
 {
   CloseTrade(tradePair.BuyTrade);
   delete(tradePair.BuyTrade);
   tradePair.BuyTrade = NULL;
   CloseTrade(tradePair.SellTrade);
   delete(tradePair.SellTrade);
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

bool ReadStoredTrades()
{
   bool retVal = true;
   int lastTradeIndex = 0;
   CorrelatedTrade *thisTrade;
   int fileHandle = FileOpen(saveFileName, FILE_TXT | FILE_ANSI | FILE_READ);
   if(fileHandle != -1)
     {
      string versionString =FileReadString(fileHandle);
      string formattedVersion = StringFormat("DataVersion: %i", DFVersion);
      if (versionString == formattedVersion)
      {
      while(!FileIsEnding(fileHandle) && retVal)
        {
            string readString = FileReadString(fileHandle);
            StringReplace(readString, "OpenTrade number ", "");
            int tradeIndex = (int) StringToInteger(readString);
            if(tradeIndex > lastTradeIndex)
            {
               if (ArrayResize(openTrades, lastTradeIndex) != -1)
               {
                  lastTradeIndex = tradeIndex;
                  thisTrade = openTrades[tradeIndex - 1];
               }
               else
               {
                  Print("Resizing openTrade array failed during ReadStoredTrades");
                  retVal = false;
               }
               
            }
            else
            {
               PrintFormat("Storage file is scrambled: tradeIndex %i <= lastTradeIndex %i", tradeIndex, lastTradeIndex);
               retVal = false;
            }
            if (!retVal || !ReadDouble(fileHandle, thisTrade.TradeLots, "Trade Lots: ")) retVal = false; 
            if (!ReadTrade(fileHandle, thisTrade.SellTrade, "Sell") || !ReadTrade(fileHandle, thisTrade.BuyTrade, "Buy"))
            {
               retVal = false;
            }         
            if (!ReadDouble(fileHandle, thisTrade.divergenceLevel, "Divergence Level: ")) retVal = false;;
         }
      }
      FileClose(fileHandle);
      return retVal;
     }
     return false;
}

bool ReadTrade(int fileHandle, OrderInfo *trade, string type)
{
   string readString;
   if (FileIsEnding(fileHandle)) return false;
   readString = FileReadString(fileHandle);
   StringReplace(readString, type + " ", "");
   trade.Symbol = readString;
   if(!ReadDouble(fileHandle, trade.EntryPrice, "Entry Price: " )) return false;
   if (FileIsEnding(fileHandle)) return false;
   readString = FileReadString(fileHandle);
   StringReplace(readString,"Entry Time: ", "");
   trade.EntryTime = StringToTime(readString);
   if(!ReadDouble(fileHandle, trade.StopLoss, "Stop Loss: " )) return false;
   if(!ReadDouble(fileHandle, trade.TakeProfit, "Take Profit: " )) return false;
   if (FileIsEnding(fileHandle)) return false;
   readString = FileReadString(fileHandle);
   StringReplace(readString,"TicketId: ", "");
   trade.TicketId = (int) StringToInteger(readString);
   return true;
}

bool ReadDouble(int fileHandle, double &target, string formatString)
{
   if (FileIsEnding(fileHandle)) return false;
   string readString = FileReadString(fileHandle);
   StringReplace(readString, formatString, "");
   target = StringToDouble(readString);
   return true;
}
bool TicketIsInOpenOrders(int ticket)
{
   int openOrderSize = ArrayRange(openTrades, 0);
   for(int ix=0;ix< openOrderSize;ix++)
     {
      if((openTrades[ix].BuyTrade.TicketId == ticket) || (openTrades[ix].SellTrade.TicketId == ticket))
        {
         return true;
        }
     }
    return false;
}

void FindUnsavedTrades(OrderInfo*  &unmatchedTrades[])
{
   //Find first (timewise) opened trade
   int numTrades = ArrayRange(unmatchedTrades, 0);
   datetime firstTradeTime= unmatchedTrades[0].EntryTime;
   int indexOfFirstTrade =0;
   OrderInfo *firstTrade;
   for(int ix=1;ix<numTrades;ix++)
     {
      if (unmatchedTrades[ix].EntryTime < firstTradeTime)
      {
         firstTradeTime = unmatchedTrades[ix].EntryTime;
         indexOfFirstTrade = ix;
      }
     }
   firstTrade = unmatchedTrades[indexOfFirstTrade];
   //Now remove that one from the array
   for(int ix=indexOfFirstTrade;ix<--numTrades;ix++)
     {
         unmatchedTrades[ix] = unmatchedTrades[ix+1];
     }
   ArrayResize(unmatchedTrades, numTrades);
   // Now find a trade within 60 seconds of that
   for(int ix=0;ix<numTrades;ix++)
     {
      if (unmatchedTrades[ix].EntryTime < firstTradeTime + 60)
        {
         if((unmatchedTrades[ix].Symbol == _Symbol && firstTrade.Symbol == otherPair) ||
            (unmatchedTrades[ix].Symbol == otherPair && firstTrade.Symbol == _Symbol))
           {
               CorrelatedTrade *newMatchedTrade = new CorrelatedTrade();
               newMatchedTrade.TradeLots = unmatchedTrades[ix].Lots; // They should both be the same
               if (unmatchedTrades[ix].OrderType == OP_BUY)
               {
                  newMatchedTrade.BuyTrade = unmatchedTrades[ix];
                  newMatchedTrade.SellTrade = firstTrade;
               }
               else
               {
                  newMatchedTrade.SellTrade = unmatchedTrades[ix];
                  newMatchedTrade.BuyTrade = firstTrade;
               }
               // But we don't know what the DivergenceLevel was.  How to figure that out?
               int newIndex = ArrayRange(openTrades,0);
               double baseDelta;
               if(newIndex > 0)  //Then there are already trades there. We can get help.
                 {   
                  CorrelatedTrade *trade = openTrades[0];
                  baseDelta = trade.BuyTrade.EntryPrice - trade.SellTrade.EntryPrice - trade.divergenceLevel;
                 }
               //Otherwise, try to get it from a GlobalVariable (passed from DOCP indicator)
                  else
                  {
                     if (GlobalVariableCheck("DOCP_BaseDelta"))
                     {
                        baseDelta = GlobalVariableGet("DOCP_BaseDelta");
                     }
                     else baseDelta = 0.0;
                  }
               if (baseDelta != 0.0)
                  newMatchedTrade.divergenceLevel = newMatchedTrade.BuyTrade.EntryPrice - newMatchedTrade.SellTrade.EntryPrice - baseDelta;
               else
               {
                  // We'll make a very poor assumption that  this trade was the first one, so it would have been offset by the 
                  // starting divergenceInterval  
                  newMatchedTrade.divergenceLevel = divergenceIntervalPoints;
               }
               ArrayResize(openTrades, newIndex+1);
               openTrades[newIndex] = newMatchedTrade;
               RecordOpenTrade(newIndex);
               numberOfOpenTrades++;
               if (MathAbs(lastDivergenceLevel) < MathAbs(newMatchedTrade.divergenceLevel))
                  lastDivergenceLevel = newMatchedTrade.divergenceLevel;
               //Now remove unmatchedTrades[ix]
               for(int jx=ix;jx<numTrades-1;jx++)
                 {
                     unmatchedTrades[jx] = unmatchedTrades[jx+1];
                 }
               numTrades--;
               ArrayResize(unmatchedTrades, numTrades);
           }
        }
     }
     if(numTrades > 1)
       {
        //Call this recursively
        FindUnsavedTrades(unmatchedTrades);
       }
}