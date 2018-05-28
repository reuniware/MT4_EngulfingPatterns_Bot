//+------------------------------------------------------------------+
//|                                                 JCSPatterns.mq4 |
//|                            Copyright 2018, Investdata Systems|
//|                                         https://tradingbot.wixsite.com/robots-de-trading |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Investdata Systems"
#property link      "https://tradingbot.wixsite.com/robots-de-trading"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

bool enableFileLog=true;
int file_handle=INVALID_HANDLE; // File handle

double initialBalance=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//EventSetTimer(60);

   log("Point="+DoubleToString(Point));
   log("Digits="+IntegerToString(Digits));
   initialBalance=AccountBalance();
   log("Balance initiale = "+DoubleToString(initialBalance));
   if(ActiverStopSuiveur)
     {
      log("Le Stop Suiveur est activé ; Stop Suiveur = "+DoubleToString(StopSuiveur));
     }
   if(!ActiverStopSuiveur) log("Le Stop Suiveur n'est pas activé");

   if(enableFileLog)
     {
      string exportDir=TerminalInfoString(TERMINAL_COMMONDATA_PATH);
      log("exportDir = "+exportDir);
      MqlDateTime mqd;
      TimeCurrent(mqd);
      string timestamp=string(mqd.year)+IntegerToString(mqd.mon,2,'0')+IntegerToString(mqd.day,2,'0')+IntegerToString(mqd.hour,2,'0')+IntegerToString(mqd.min,2,'0')+IntegerToString(mqd.sec,2,'0');

      string strPeriod=EnumToString((ENUM_TIMEFRAMES)Period());
      StringReplace(strPeriod,"PERIOD_","");

      file_handle=FileOpen(WindowExpertName()+"_"+Symbol()+"_"+strPeriod+"_"+timestamp+"_log.txt",FILE_CSV|FILE_WRITE|FILE_ANSI|FILE_COMMON);
      if(file_handle>0)
        {
         string sep=",";
         FileWrite(file_handle,"Logging started at "+timestamp);
        }
      else
        {
         log("error : "+IntegerToString(GetLastError()));
        }
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   double finalBalance=AccountBalance();
   log("Balance finale = "+DoubleToString(finalBalance));

   if(enableFileLog)
     {
      FileClose(file_handle);
     }
//--- destroy timer
   EventKillTimer();

  }

double open_array[];
double high_array[];
double low_array[];
double close_array[];

static datetime LastBarTime=-1;

int indexPh = 0;
int indexPb = 0;
string arrowname="";
double yCoordArrowUp=0;
double yCoordArrowDown=0;

double dernierPicHaut= 0;
double dernierPicBas = 0;
double picHautLePlusBas= 0;
double picBasLePlusHaut= 0;

int count,ticket,total;
input double TakeProfit    =0;
input double InitialLots   =0.1;
input double StopSuiveur=0.0005;

input bool ActiverStopSuiveur=true;
input bool MontrerDetailsStopSuiveur=false;

double Lots=InitialLots;
double ProfitPerteTotale=0;

input bool JournaliserProfitsPertesBalanceInitiale=false;
input bool JournaliserProfitPerteTotaleCumulee=true;

double rsi=0;
double ma=0;
double previous_ma=0;
string str_ma="";
string str_prev_ma="";
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   int ordersTotal=OrdersHistoryTotal();
   for(int i=ordersTotal-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
        {
         if(OrderSymbol()==Symbol())
           {
            if(TimeCurrent()-OrderCloseTime()==1)
              {
               // Cet ordre a été clôturé par Stop Loss
               if(OrderClosePrice()==OrderStopLoss() && OrderType()==OP_BUY)
                 {
                  log("OnTick: StopLoss touché sur Ordre d'Achat ; OrderTicket #"+IntegerToString(OrderTicket())+" OrderProfit="+DoubleToString(OrderProfit()));
                 }
               else if(OrderClosePrice()==OrderStopLoss() && OrderType()==OP_SELL)
                 {
                  log("OnTick: StopLoss touché sur Ordre de Vente ; OrderTicket #"+IntegerToString(OrderTicket())+" OrderProfit="+DoubleToString(OrderProfit()));
                 }
               // Cet ordre a été clôturé par Take Profit
               if(OrderClosePrice()==OrderTakeProfit() && OrderType()==OP_BUY)
                 {
                  log("OnTick: TakeProfit touché sur Ordre d'Achat ; OrderTicket #"+IntegerToString(OrderTicket())+" OrderProfit="+DoubleToString(OrderProfit()));
                 }
               else if(OrderClosePrice()==OrderTakeProfit() && OrderType()==OP_SELL)
                 {
                  log("OnTick: TakeProfit touché sur Ordre de Vente ; OrderTicket #"+IntegerToString(OrderTicket())+" OrderProfit="+DoubleToString(OrderProfit()));
                 }
              }
           }
        }
     }

   datetime ThisBarTime=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);
   if(ThisBarTime==LastBarTime)
     {
      //printf("Same bar time ("+Symbol()+")");
     }
   else
     {
      if(LastBarTime==-1)
        {
         //printf("First bar ("+Symbol()+")");
         LastBarTime=ThisBarTime;
        }
      else
        {
         //printf("Une nouvelle bougie vient de commencer pour ["+Symbol()+"]");
         LastBarTime=ThisBarTime;

         ArraySetAsSeries(open_array,true);
         int numO=CopyOpen(Symbol(),Period(),0,4,open_array);
         ArraySetAsSeries(high_array,true);
         int numH=CopyHigh(Symbol(),Period(),0,4,high_array);
         ArraySetAsSeries(low_array,true);
         int numL=CopyLow(Symbol(),Period(),0,4,low_array);
         ArraySetAsSeries(close_array,true);
         int numC=CopyClose(Symbol(),Period(),0,4,close_array);

         checkEngulfingPattern();

        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void EntrerALAchat()
  {
   double stoploss=Ask-StopSuiveur;
//log("Ordre d'achat: stoploss="+DoubleToString(stoploss));
   ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,3,0,0,"JCS",16384,0,Green);
   if(ticket>0)
     {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
        {
         log("EntrerALAchat: Ordre d'achat #"+IntegerToString(OrderTicket())+" ouvert au prix du marché de "+DoubleToString(NormalizeDouble(OrderOpenPrice(),Digits))+" avec "+DoubleToString(Lots)+" Lots et StopLoss="+DoubleToString(stoploss));
        }
     }
   else
      log("EntrerALAchat: Erreur lors de la tentative d'ouverture de l'ordre d'achat : "+IntegerToString(GetLastError()));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void EntrerALaVente()
  {
   double stoploss=Bid+StopSuiveur;
//log("Ordre de vente: stoploss="+DoubleToString(stoploss));
   ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,3,0,0,"JCS",16384,0,Red);
   if(ticket>0)
     {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
        {
         log("EntrerALaVente: Ordre de vente #"+IntegerToString(OrderTicket())+" ouvert au prix du marché de "+DoubleToString(NormalizeDouble(OrderOpenPrice(),Digits))+" avec "+DoubleToString(Lots)+" Lots et StopLoss="+DoubleToString(stoploss));
        }
     }
   else
      log("EntrerALaVente: Erreur lors de la tentative d'ouverture de l'ordre de vente : "+IntegerToString(GetLastError()));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrailingStopPositionsAchat()
  {
//log("TrailingStopPositionsAchat");
   for(count=0; count<OrdersTotal(); count++)
     {
      if(!OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderType()<=OP_SELL && // check for opened position 
         OrderSymbol()==Symbol()) // check for symbol
        {
         //--- long position is opened
         if(OrderType()==OP_BUY)
           {
            if(StopSuiveur>0)
              {
               //log("TrailingStopPositionsAchat: Ask="+DoubleToString(Ask));
               if(Bid>OrderOpenPrice())
                 {
                  if(Bid-StopSuiveur>OrderStopLoss())
                    {
                     //--- modify order and exit
                     if(MontrerDetailsStopSuiveur) log("TrailingStopPositionsAchat: Modification stop suiveur sur ordre d'achat #"+IntegerToString(OrderTicket())+" ; Buy = "+DoubleToString(NormalizeDouble(Ask,Digits))+" ; Sell = "+DoubleToString(NormalizeDouble(Bid,Digits))+" ; Stop Loss avant modification = "+DoubleToString(NormalizeDouble(OrderStopLoss(),Digits))+" ; Nouveau Stop Loss = "+DoubleToString(NormalizeDouble(Bid-StopSuiveur,Digits)));
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),Bid-StopSuiveur,0,0,Green))
                       {
                        if(MontrerDetailsStopSuiveur) log("TrailingStopPositionsAchat: Erreur lors de la tentative de modification du stop suiveur sur ordre d'achat #"+IntegerToString(OrderTicket())+" : "+IntegerToString(GetLastError()));
                       }
                     return;
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrailingStopPositionsVente()
  {
   for(count=0; count<OrdersTotal(); count++)
     {
      if(!OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderType()<=OP_SELL && // check for opened position 
         OrderSymbol()==Symbol()) // check for symbol
        {
         //--- long position is opened
         if(OrderType()==OP_SELL)
           {
            if(StopSuiveur>0)
              {
               if((Ask<OrderOpenPrice()))
                 {
                  if((Ask+StopSuiveur<OrderStopLoss()))
                    {
                     //--- modify order and exit
                     if(MontrerDetailsStopSuiveur) log("TrailingStopPositionsVente: Modification stop suiveur sur ordre de vente #"+IntegerToString(OrderTicket())+" ; Buy = "+DoubleToString(NormalizeDouble(Ask,Digits))+" ; Sell = "+DoubleToString(NormalizeDouble(Bid,Digits))+" ; Stop Loss avant modification = "+DoubleToString(NormalizeDouble(OrderStopLoss(),Digits))+" ; Nouveau Stop Loss = "+DoubleToString(NormalizeDouble(Ask+StopSuiveur,Digits)));
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),Ask+StopSuiveur,0,0,Red))
                       {
                        if(MontrerDetailsStopSuiveur) log("TrailingStopPositionsAchat: Erreur lors de la tentative de modification du stop suiveur sur l'ordre de vente #"+IntegerToString(OrderTicket())+" : "+IntegerToString(GetLastError()));
                       }
                     return;
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double RechercherPicHaut()
  {
   ArraySetAsSeries(open_array,true);
   int numO=CopyOpen(Symbol(),Period(),0,4,open_array);
   ArraySetAsSeries(high_array,true);
   int numH=CopyHigh(Symbol(),Period(),0,4,high_array);
   ArraySetAsSeries(low_array,true);
   int numL=CopyLow(Symbol(),Period(),0,4,low_array);
   ArraySetAsSeries(close_array,true);
   int numC=CopyClose(Symbol(),Period(),0,4,close_array);

   if((high_array[3]<high_array[2]) && (high_array[2]>high_array[1]))
     {
      return high_array[2];
     }
   else
     {
      return 0;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NombreDePositionAcheteuses()
  {
   int nbPos= 0;
   for(count=0; count<OrdersTotal(); count++)
     {
      if(!OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
        {
         continue;
        }

      if(OrderType()<=OP_SELL && // check for opened position 
         OrderSymbol()==Symbol()) // check for symbol
        {
         if(OrderType()==OP_BUY)
           {
            nbPos++;
           }
        }
     }
   return nbPos;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NombreDePositionVendeuses()
  {
   int nbPos= 0;
   for(count=0; count<OrdersTotal(); count++)
     {
      if(!OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
        {
         continue;
        }

      if(OrderType()<=OP_SELL && // check for opened position 
         OrderSymbol()==Symbol()) // check for symbol
        {
         if(OrderType()==OP_SELL)
           {
            nbPos++;
           }
        }
     }
   return nbPos;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FermerLesPositionsAcheteuses()
  {
   for(count=0; count<OrdersTotal(); count++)
     {
      if(!OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
        {
         continue;
        }

      if(OrderType()<=OP_SELL && // check for opened position 
         OrderSymbol()==Symbol()) // check for symbol
        {
         //--- long position is opened
         if(OrderType()==OP_BUY)
           {
            double orderProfit=OrderProfit()+OrderCommission()+OrderSwap(); // swap=frais positions laissée ouverte pour le jour suivant
            log("FermerLesPositionsAcheteuses: Profit/Perte pour position #"+IntegerToString(OrderTicket())+" (avant fermeture) = "+DoubleToString(orderProfit));
            if(JournaliserProfitPerteTotaleCumulee) printf("Profit/Perte Totale Cumulée Calculée = "+DoubleToString(ProfitPerteTotale));

            if(!OrderClose(OrderTicket(),OrderLots(),/*Bid*/OrderClosePrice(),3,Violet))
               log("FermerLesPositionsAcheteuses: Erreur lors de la tentative de fermeture de la position : "+IntegerToString(GetLastError()));
           }
         else
           {
            //Print("Sell order has been closed successfully");
           }
         return;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FermerLesPositionsVendeuses()
  {
   for(count=0; count<OrdersTotal(); count++)
     {
      if(!OrderSelect(count,SELECT_BY_POS,MODE_TRADES))
        {
         continue;
        }

      if(OrderType()<=OP_SELL && // check for opened position 
         OrderSymbol()==Symbol()) // check for symbol
        {
         //--- long position is opened
         if(OrderType()==OP_SELL)
           {
            double orderProfit=OrderProfit()+OrderCommission()+OrderSwap(); // swap=frais positions laissée ouverte pour le jour suivant
            log("FermerLesPositionsVendeuses: Profit/Perte pour position #"+IntegerToString(OrderTicket())+" (avant fermeture) = "+DoubleToString(orderProfit));
            
            if(!OrderClose(OrderTicket(),OrderLots(),/*Bid*/OrderClosePrice(),3,Violet))
               log("FermerLesPositionsVendeuses: Erreur lors de la tentative de fermeture de la position : "+IntegerToString(GetLastError()));
           }
         else
           {
            //Print("Sell order has been closed successfully");
           }
         return;
        }
     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---

  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MqlDateTime mqd_ts;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void log(string str)
  {
   TimeCurrent(mqd_ts);
   string timestamp=string(mqd_ts.year)+IntegerToString(mqd_ts.mon,2,'0')+IntegerToString(mqd_ts.day,2,'0')+IntegerToString(mqd_ts.hour,2,'0')+IntegerToString(mqd_ts.min,2,'0')+IntegerToString(mqd_ts.sec,2,'0');
   printf(timestamp+" : "+str);
   FileWrite(file_handle,timestamp+" : "+str);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkEngulfingPattern()
  {
// Bearish Engulfing Pattern : Bougie haussière (blanche) suivie d'une bougie baissière (noire) et bougie baissière qui englobe la bougie haussière
   if(open_array[2]<close_array[2] && open_array[1]>close_array[1])
     {
      if(close_array[1]<open_array[2] && open_array[1]>close_array[2])
        {
         log("Time = "+Time[1]+" ; Bearish Engulfing Pattern ; Ask = "+Ask+" ; Bid = "+Bid);
         FermerLesPositionsVendeuses();
         EntrerALAchat();
        }
     }
// Bullish Engulfing Pattern : Bougie baissière (noire) suivie d'une bougie haussière (blanche) et bougie haussière qui englobe la bougie baissière
   if(open_array[2]>close_array[2] && open_array[1]<close_array[1])
     {
      if(open_array[1]<close_array[2] && close_array[1]>open_array[2])
        {
         log("Time = "+Time[1]+" ; Bullish Engulfing Pattern  ; Ask = "+Ask+" ; Bid = "+Bid);
         FermerLesPositionsAcheteuses();
         EntrerALaVente();
        }
     }

  }

//+------------------------------------------------------------------+

/*int  OrderSend(
                  string   symbol,              // symbol
                  int      cmd,                 // operation
                  double   volume,              // volume
                  double   price,               // price
                  int      slippage,            // slippage
                  double   stoploss,            // stop loss
                  double   takeprofit,          // take profit
                  string   comment=NULL,        // comment
                  int      magic=0,             // magic number
                  datetime expiration=0,        // pending order expiration
                  color    arrow_color=clrNONE  // color
                  );*/
//+------------------------------------------------------------------+

// Détecter si un ordre a touché son SL
/*   int ordersTotal=OrdersHistoryTotal();
   for(int i=ordersTotal-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
        {
         if(OrderSymbol()==Symbol())
           {
            if(TimeCurrent()-OrderCloseTime()==1)
              {
               // Cet ordre a été clôturé par Stop Loss
               if(OrderClosePrice()==OrderStopLoss() && OrderType()==OP_BUY)
                 {
                  log("OnTick: StopLoss touché sur Ordre d'Achat ; OrderTicket #"+IntegerToString(OrderTicket())+" OrderProfit="+DoubleToString(OrderProfit()));
                 }
               else if(OrderClosePrice()==OrderStopLoss() && OrderType()==OP_SELL)
                 {
                  log("OnTick: StopLoss touché sur Ordre de Vente ; OrderTicket #"+IntegerToString(OrderTicket())+" OrderProfit="+DoubleToString(OrderProfit()));
                 }
              }
           }
        }
     }*/
//+------------------------------------------------------------------+

// Moving Average
/*         ma=iMA(NULL,0,13,8,MODE_SMMA,PRICE_MEDIAN,1);
         //log("ma=" + DoubleToString(ma));
         if(previous_ma!=0)
           {
            if(ma>previous_ma)
              {
               log("ma: + ; ma="+DoubleToString(ma)+" prev="+DoubleToString(previous_ma));
               str_ma = "+";
              }
            else if(ma<previous_ma)
              {
               log("ma: - ; ma="+DoubleToString(ma)+" prev="+DoubleToString(previous_ma));
               str_ma = "-";
              }
            else if(ma==previous_ma) 
              {
               log("ma: 0  ; ma="+DoubleToString(ma)+" prev="+DoubleToString(previous_ma));
               str_ma = "0";
              }
           }
          
         if (str_ma == "+" && str_prev_ma == "-"){
            if (NombreDePositionAcheteuses() == 0){
               EntrerALAchat();
            }
         }
           
         previous_ma=ma;
         str_prev_ma = str_ma;
         */
//+------------------------------------------------------------------+

// RSI
//rsi=iRSI(NULL,0,14,PRICE_CLOSE,0);

// Achat/Vente
/*if(NombreDePositionAcheteuses()==0)
           {
            log("Ordre d'achat");
            ticket=OrderSend(Symbol(),OP_BUY,2,Ask,3,Ask-0.5,Bid+0.1,"JCS",16384,0,Green);
           }

         if(NombreDePositionVendeuses()==0)
           {
            log("Ordre de vente");
            ticket=OrderSend(Symbol(),OP_SELL,2,Bid,3,Bid+0.5,Ask-0.1,"JCS",16384,0,Green);
           }*/
//+------------------------------------------------------------------+
