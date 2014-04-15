//+------------------------------------------------------------------+
//|                                              CorrelatedPairs.mqh |
//|                                                   DWH Enterpises |
//|                                http://nohypeforexrobotreview.com |
//+------------------------------------------------------------------+
#property copyright "DWH Enterpises"
#property link      "http://nohypeforexrobotreview.com"
#property strict
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
string correlatedPairs[][2] = { {"EURUSD", "GBPUSD"},
                                { "GBPUSD", "EURUSD"} };
string FindCorrelatedPair()
{

   string symbolSuffix = StringSubstr(_Symbol,6);
   string thisSymbol = StringSubstr(_Symbol, 0, 6);
   for(int ix=0;ix<ArrayRange(correlatedPairs, 0);ix++)
     {
         if (correlatedPairs[ix][0] == thisSymbol)
            return (correlatedPairs[ix][1] + symbolSuffix);
     }
   return "";

}