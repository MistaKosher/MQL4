//+------------------------------------------------------------------+
//|                                                   ax_adv_022.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "http://www.mql4.com"
#property version   "1.00"
#property strict

#import "fx_sample_001.dll"
        void   axInit(string symbol);
        void   axDeinit(string symbol);
        void   axAddOrder(string symbol, int ticket, double sl, int fibo_level, int ext_data, double by_rsi);
        void   axRemoveOrder(string symbol, int ticket);
        double axGetOrderSL(string symbol, int ticket);
        int    axGetOrderFiboLevel(string symbol, int ticket);
        int    axGetOrderExtData(string symbol, int ticket);
        double axGetOrderByRSI(string symbol, int ticket);
        bool   axSetOrderSL(string symbol, int ticket, double sl);
        bool   axSetOrderFiboLevel(string symbol, int ticket, int fibo_level);
        bool   axSetOrderExtData(string symbol, int ticket, int ext_data);
        bool   axSetOrderByRSI(string symbol, int ticket, double by_rsi);
        //array
        void   axClearArray(string symbol);
        void   axAddArrayValue(string symbol, double v);
        double axGetArrayMinValue(string symbol);
        double axGetArrayMaxValue(string symbol);
        //atr_array
        void   axClearATRArray(string symbol);
        void   axAddATRArrayValue(string symbol, int trend_type, double price, double atr_value);
        double axGetATRArrayMinPrice(string symbol);
        double axGetATRArrayMinPriceATR(string symbol);
        double axGetATRArrayMaxPrice(string symbol);
        double axGetATRArrayMaxPriceATR(string symbol);        
#import

#include <stdlib.mqh>

MqlRates g_ready_bar;

//####################################################################
input int g_delta_points=10;//запас хода, в пипсах
input double g_lot=0.01;//лот
input double g_lot2=0.02;//"усиленный" лот
input int g_slippage=3;//проскальзывание
input int g_try_count=3;//количество попыток
/*input */double g_gator_wake_up_val=1.001;//гатор просыпается
bool g_set_tp=false;//устанавливать явно TakeProfit
int g_reversal_bar_cnt_wait=3;//количество баров для включения отложенного
//int g_direct_order_exp_bar_count=3;//время ожидания включения (прямой ордер),в барах
//int g_reverse_order_exp_bar_count=21;//время ожидания включения (обратный ордер),в барах
input int g_order_exp_bar_count=1;//время ожидания включения,в барах
//input bool g_tp_explicit=false;//явный TakeProfit
input int g_magic_distance=1;//"волшебное" расстояние
//если по прошествии g_order_passive_bar_count график не пересек какую-нибудь линий из гатора, то ордер закрываем
//input int g_order_passive_bar_count=3;//1("разворотный")+1("неконтролируемый")+1
int g_order_count;//внутренний счетчик ордеров 
double g_gator_bar_diff=1;//расстояние между гатором и баром (разворотным) (в барах:))
double g_profit_coef=1.0;//уровень TakeProfit в отношении TakeProfit/StopLoss
int g_handle;
double g_profit=1.0;
double g_loss=-0.5;
double g_fibo_coef=0.382;//0.236 0.382 0.500 0.618
//input int g_rsi_period=14;//RSI период
//input int g_demark_period=5;//DeMarker период
//input bool g_use_rsi_signal=true;//использовать DeMarker для подтверждения
input bool g_logging=false;//вести логирование в файл

double g_buy_max;
double g_sell_min;
double g_buy_loc_min;
double g_sell_loc_max;
double g_upper_frac;
double g_lower_frac;

double g_fibo_coefs[6];

#include "ax_bar_utils.mqh"
//#include "ax_tick_worker.mqh"
#include "ax_mfi_worker.mqh"
//#include "ax_mfi_worker2.mqh"

input bool g_use_ichimoku=false;//использовать ichimoku kumo для фильтрации флета
input adv_trade_mode g_trade_mode=ADVTRADEMODE_BOTH;//режим работы
//input t_tickworkglobalmode g_tickworkmode=TICKWORKGLOBALMODE_BWCUSTOM;//определение разворотного бара
input t_mfiworkmode g_mfiworkmode    =MFIWORKMODE_AXMFI;//сигнал на открытие ордера
input t_mfiworkmode g_mfiworkmode_sl =MFIWORKMODE_AXMFI;//сигнал на подтягивание ордера
input bool g_open_lot2_order =false;//открывать второй "усиленный" ордер
const double g_min_level =0.99;
const double g_max_level =1.01;

//ax_tick_worker g_tick_worker;
ax_mfi_worker  g_mfi_worker;
//ax_mfi_worker2 g_mfi_worker;
ax_mfi_worker  g_mfi_worker_sl;

ax_settings g_settings;

ax_array_worker g_array;

//####################################################################

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
 Comment("");
 
 ax_bar_utils::do_settings(g_settings);
 
 g_order_count=0;

 g_fibo_coefs[FIBO_100]=1.000;
 g_fibo_coefs[FIBO_764]=0.764;
 g_fibo_coefs[FIBO_618]=0.618;
 g_fibo_coefs[FIBO_500]=0.500;
 g_fibo_coefs[FIBO_382]=0.382;
 g_fibo_coefs[FIBO_236]=0.236;
 
 //g_tick_worker.init(g_tickworkmode,Period(),g_min_level,g_max_level);
 
 g_mfi_worker.init(g_mfiworkmode);
 g_mfi_worker_sl.init(g_mfiworkmode_sl);
 //g_mfi_worker_sl.init(MFIWORKMODE_MFIORAXMFI);
 
 //сразу получаем значение последнего сформированного бара
 MqlRates rates[];
 ArrayCopyRates(rates,NULL,0);

 g_ready_bar=rates[1]; 
 
 if(g_logging)
 {
  string filename=Symbol()+"_"+IntegerToString(Period())+".log"; 
 
  g_handle=FileOpen(filename,FILE_WRITE|FILE_TXT); 
 }
 
 return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
 if(g_logging)
  FileClose(g_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//typidor kekekeke
 string err_msg;
 
 MqlRates rates[];
 ArrayCopyRates(rates,NULL,0);

 ax_order_settings order_stgs(g_lot,g_lot2,g_slippage,"",g_order_exp_bar_count,0,FIBO_764,g_try_count);
 
 if(!ax_bar_utils::is_equal(g_ready_bar,rates[1]))//подошел следующий бар
 {
  g_ready_bar=rates[1];//это будет новый сформированный бар - работаем с ним
  
  gator_bar_cross_t gbc=ax_bar_utils::get_gator_bar_cross(g_settings,g_ready_bar);
  
  double gator_jaw=ax_bar_utils::get_gator_val(g_settings,MODE_GATORJAW,1);

  MqlRates dummy_bar;
  
  order_data order;
 
  //Print("g_array.count=",g_array.count());
  //Print(g_array.print(Symbol(),Period()));
  
  //пытаемся модифицировать существующие ордера
  for(int i=0;i<g_array.count();i++)
  {
   //Print("ticket=",g_array.get_ticket(i));
   
   if(!(OrderSelect(g_array.get_ticket(i),SELECT_BY_TICKET) && OrderCloseTime()==0))
    continue;
   
   int order_type   =OrderType();
   int order_ticket =OrderTicket();
   
   //Print("ticket=",g_array.get_ticket(i)," 2");
   
   if(!g_array.order_exists(Symbol(),Period(),order_ticket))
    continue;
    
   //Print("ticket=",g_array.get_ticket(i)," 3");
   
   g_array.inc_bars_count(Symbol(),Period(),order_ticket);
   
   /*
   if(g_array.get_bars_count(Symbol(),Period(),order_ticket)>=g_order_passive_bar_count-1 && g_array.get_comment(Symbol(),Period(),order_ticket)=="")
   {
    ax_bar_utils::CloseOrder(order_stgs,order_ticket);
    //g_array будет sweep'иться при добавление нового ордера
    continue;
   }
   */
   if(order_type==OP_BUY)
   {
    /*
    if(gbc==GATORBARCROSS_JAWBULL || gbc==GATORBARCROSS_JAWBEAR)
    {
     if(gbc==GATORBARCROSS_JAWBULL && g_array.get_comment(Symbol(),Period(),order_ticket)!=EnumToString(GATORBARCROSS_JAWBULL))
      g_array.set_comment(Symbol(),Period(),order_ticket,EnumToString(gbc));//первое пересечение
     else
     {
      //dummy_bar.high =g_ready_bar.high+NormalizeDouble(iATR(NULL,0,14,1),Digits);
      //dummy_bar.high =g_ready_bar.high+NormalizeDouble(iATR(NULL,0,g_array.get_bars_count(Symbol(),Period(),order_ticket),1),Digits);
      dummy_bar.low=g_ready_bar.low;
      ax_bar_utils::SetOrderSL(order_ticket,dummy_bar,err_msg);
     }
    }
    else
    if(gbc!=GATORBARCROSS_NONE)
     g_array.set_comment(Symbol(),Period(),order_ticket,EnumToString(gbc));
    */
    if(gbc==GATORBARCROSS_JAWBULL)
    {
     g_array.set_comment(Symbol(),Period(),order_ticket,EnumToString(gbc));//первое пересечение
     //Print("order(",order_ticket,") "+EnumToString(gbc));
    }
    else
    if((g_mfi_worker_sl.value(rates,1,MFIVALUE_BROWN)||g_mfi_worker_sl.value(rates,1,MFIVALUE_PINK)) && g_array.get_comment(Symbol(),Period(),order_ticket)==EnumToString(GATORBARCROSS_JAWBULL))
    {
     //Print("order(",order_ticket,") "+EnumToString(gbc)," sl=",gator_jaw);
     dummy_bar.low=gator_jaw;
     
     ax_bar_utils::SetOrderSL(order_ticket,dummy_bar,err_msg);
     
     if(g_open_lot2_order && !g_array.get_lot2_set(Symbol(),Period(),order_ticket) && ax_bar_utils::OpenOrder3_CloseOpenImmediate(dummy_bar,TRADEMODE_BUY,order_stgs,order_ticket,err_msg,order)>0)
     {
      order.comment=EnumToString(GATORBARCROSS_JAWBULL);
      g_array.add(order);
      g_array.set_lot2_set(Symbol(),Period(),order_ticket,true);
     }
    }
   }
   else
   if(order_type==OP_SELL)
   {
    /*
    if(gbc==GATORBARCROSS_JAWBULL || gbc==GATORBARCROSS_JAWBEAR)
    {
     if(gbc==GATORBARCROSS_JAWBEAR && g_array.get_comment(Symbol(),Period(),order_ticket)!=EnumToString(GATORBARCROSS_JAWBEAR))
      g_array.set_comment(Symbol(),Period(),order_ticket,EnumToString(gbc));//первое пересечение
     else
     {
      dummy_bar.high =g_ready_bar.high;
      //dummy_bar.low  =g_ready_bar.low-NormalizeDouble(iATR(NULL,0,g_array.get_bars_count(Symbol(),Period(),order_ticket),1),Digits);
      //dummy_bar.low  =g_ready_bar.low-NormalizeDouble(iATR(NULL,0,14,1),Digits);
      ax_bar_utils::SetOrderSL(order_ticket,dummy_bar,err_msg);
     }
    }
    else
    if(gbc!=GATORBARCROSS_NONE)
     g_array.set_comment(Symbol(),Period(),order_ticket,EnumToString(gbc));
    */
    if(gbc==GATORBARCROSS_JAWBEAR)
     g_array.set_comment(Symbol(),Period(),order_ticket,EnumToString(gbc));//первое пересечение
    else
    if((g_mfi_worker_sl.value(rates,1,MFIVALUE_BROWN)||g_mfi_worker_sl.value(rates,1,MFIVALUE_PINK)) && g_array.get_comment(Symbol(),Period(),order_ticket)==EnumToString(GATORBARCROSS_JAWBEAR))
    {
     dummy_bar.high=gator_jaw;
     
     ax_bar_utils::SetOrderSL(order_ticket,dummy_bar,err_msg);
     
     if(g_open_lot2_order && !g_array.get_lot2_set(Symbol(),Period(),order_ticket) && ax_bar_utils::OpenOrder3_CloseOpenImmediate(dummy_bar,TRADEMODE_SELL,order_stgs,order_ticket,err_msg,order)>0)
     {
      order.comment=EnumToString(GATORBARCROSS_JAWBEAR);
      g_array.add(order);
      g_array.set_lot2_set(Symbol(),Period(),order_ticket,true);
     }
    }
   }//if order_type
  }//for
 
  if(StringLen(err_msg)!=0)
   Print(Symbol()," ",err_msg);
  
  err_msg="";   
 
  //t_tickbarpair tbp=g_tick_worker.get_tickbarpair(TICKWORKMODE_SINGLE);
 
  //double loc_ext;
 
  //проверяем признак разворотного бара (по классике)
  //если tickworker что-то выдает, то значит бар переключился - используем rates[1] и rates[2] 
  if((g_trade_mode==ADVTRADEMODE_BUY || g_trade_mode==ADVTRADEMODE_BOTH)/* &&
      tbp==TICKBARPAIR_NONEUP*/ && rates[1].low<rates[2].low)//бар разворотный вверх
  {
   //if(ax_bar_utils::get_bar_ma_position(g_settings,rates,BARPOSITION_UNDERGATOR,1))
   if(ax_bar_utils::get_bar_gator_position(rates,BARPOSITION_UNDERGATOR,BARPOSITIONMODE_FULL,1))//PART2
   {
    //if(ax_bar_utils::ma_cross_distance(g_settings,rates,BARPOSITION_UNDERGATOR,DISTANCE_LOCALEXTREMUM))
    //if(ax_bar_utils::gator_cross_distance(g_settings,rates,BARPOSITION_UNDERGATOR,DISTANCE_LOCALEXTREMUM,loc_ext))
    {
     if(g_mfi_worker.value(rates,1,MFIVALUE_PINK) || g_mfi_worker.value(rates,1,MFIVALUE_BROWN))
     {
      //if(g_tp_explicit)
      // order_stgs.profit=loc_ext;
     
      if(ax_bar_utils::trade6_simple(rates,TRADEMODE_BUY,order_stgs,err_msg,order,g_use_ichimoku,ORDERSLTYPE_MINMAXBACKWARD))
      {
       //если сам разворотный бар пересек jaw, то сразу отметим этот факт
       order.comment=!ax_bar_utils::get_bar_gator_position(rates,BARPOSITION_UNDERGATOR,BARPOSITIONMODE_FULL,1)&&
                      ax_bar_utils::get_gator_mode(1)==GATORMODE_NORMAL?EnumToString(GATORBARCROSS_JAWBULL):"";
       g_array.add(order);
       //Print(g_array.print(Symbol(),Period()));
      }
     }//color
    }//distance
   }
  }
  else
  if((g_trade_mode==ADVTRADEMODE_SELL || g_trade_mode==ADVTRADEMODE_BOTH)/* &&
      tbp==TICKBARPAIR_NONEDOWN*/ && rates[1].high>rates[2].high)//бар разворотный вниз
  {
   //if(ax_bar_utils::get_bar_ma_position(g_settings,rates,BARPOSITION_ABOVEGATOR,1))
   if(ax_bar_utils::get_bar_gator_position(rates,BARPOSITION_ABOVEGATOR,BARPOSITIONMODE_FULL,1))//PART2
   {
    //if(ax_bar_utils::ma_cross_distance(g_settings,rates,BARPOSITION_ABOVEGATOR,DISTANCE_LOCALEXTREMUM))
    //if(ax_bar_utils::gator_cross_distance(g_settings,rates,BARPOSITION_ABOVEGATOR,DISTANCE_LOCALEXTREMUM,loc_ext))
    {
     if(g_mfi_worker.value(rates,1,MFIVALUE_PINK) || g_mfi_worker.value(rates,1,MFIVALUE_BROWN))
     {
      //if(g_tp_explicit)
      // order_stgs.profit=loc_ext;
    
      if(ax_bar_utils::trade6_simple(rates,TRADEMODE_SELL,order_stgs,err_msg,order,g_use_ichimoku,ORDERSLTYPE_MINMAXBACKWARD))
      {
       order.comment=!ax_bar_utils::get_bar_gator_position(rates,BARPOSITION_ABOVEGATOR,BARPOSITIONMODE_FULL,1)&&
                      ax_bar_utils::get_gator_mode(1)==GATORMODE_REVERSAL?EnumToString(GATORBARCROSS_JAWBEAR):"";
       g_array.add(order);
       //Print(g_array.print(Symbol(),Period()));
      }
     }//color
    }//distance
   }
  }
 
  if(StringLen(err_msg)!=0)
   Print(Symbol()," ",err_msg);
 }//if g_ready_bar
}

//+------------------------------------------------------------------+
