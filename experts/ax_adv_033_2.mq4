//+------------------------------------------------------------------+
//|                                                 ax_adv_033_2.mq4 |
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
//input t_mfiworkmode g_mfiworkmode    =MFIWORKMODE_AXMFI009;//сигнал на открытие ордера
//input t_mfiworkmode g_mfiworkmode_sl =MFIWORKMODE_AXMFI;//сигнал на подтягивание ордера
//input bool g_open_lot2_order =false;//открывать второй "усиленный" ордер
const double g_min_level =0.99;
const double g_max_level =1.01;

ax_mfi_worker  g_mfi_worker;
ax_mfi_worker  g_axmfi007_worker;

ax_settings g_settings;

ax_array_worker g_array;

enum possible_trade_mode_t
{
 POSSIBLETRADEMODE_NONE,
 POSSIBLETRADEMODE_BUY,
 POSSIBLETRADEMODE_SELL
};

possible_trade_mode_t g_ptm=POSSIBLETRADEMODE_NONE;

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
 
 g_mfi_worker.init(MFIWORKMODE_MFI,false);
 g_axmfi007_worker.init(MFIWORKMODE_AXMFI007,true);
 
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
 string err_msg;
 
 MqlRates rates[];
 ArrayCopyRates(rates,NULL,0);

 //ax_order_settings order_stgs_buy(g_lot,g_lot2,g_slippage,"",g_order_exp_bar_count,1,FIBO_764,g_try_count);
 //ax_order_settings order_stgs_sell(g_lot,g_lot2,g_slippage,"",g_order_exp_bar_count,1,FIBO_764,g_try_count);
 
 ax_order_settings order_stgs(g_lot,g_lot2,g_slippage,"",g_order_exp_bar_count,2,FIBO_764,g_try_count);
 
 if(!ax_bar_utils::is_equal(g_ready_bar,rates[1]))//подошел следующий бар
 {
  g_ready_bar=rates[1];//это будет новый сформированный бар - работаем с ним
  
  
  
#ifdef 0
  MqlRates more_rates[];
  ArrayCopyRates(more_rates,NULL,ax_bar_utils::get_more_period());
  
  if(g_mfi_worker.value(more_rates,1,MFIVALUE_PINK))
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
    if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
     continue;
    
    if(OrderSymbol()!=Symbol())
     continue;
    
    //ax_bar_utils::SetOrderSLTP(int ticket,MqlRates &b,string &err_msg,datetime _exp=0)(order_stgs,OrderTicket(),err_msg);
   }//for
  }
#endif 
  
  datetime tc=TimeCurrent();
  
  //if(TimeHour(tc)==5 && TimeMinute(tc)>=45 && TimeMinute(tc)<50)
  {
  order_data order;
  
  //rsi_mode rsm=ax_bar_utils::get_rsi_mode(g_settings,1);
  
  gator_mode gm =ax_bar_utils::get_gator_mode(g_settings,1);
  
  double adx_1 =iADX(NULL,0,14,PRICE_TYPICAL,MODE_MAIN,1);
  
  if(gm==GATORMODE_NORMAL)
  {
   if(adx_1>=20 && adx_1<40)
    ax_bar_utils::trade6_simple_stoplevel(g_settings,rates,TRADEMODE_BUY,order_stgs,err_msg,order,g_use_ichimoku,ORDERSLTYPE_SINGLEBAR);
   else
   if(adx_1>=40)
    ax_bar_utils::trade6_simple_stoplevel(g_settings,rates,TRADEMODE_SELL,order_stgs,err_msg,order,g_use_ichimoku,ORDERSLTYPE_SINGLEBAR);
  }
  else
  if(gm==GATORMODE_REVERSAL)
  {
   if(adx_1>=20 && adx_1<40)
    ax_bar_utils::trade6_simple_stoplevel(g_settings,rates,TRADEMODE_SELL,order_stgs,err_msg,order,g_use_ichimoku,ORDERSLTYPE_SINGLEBAR);
   else
   if(adx_1>=40)
    ax_bar_utils::trade6_simple_stoplevel(g_settings,rates,TRADEMODE_BUY,order_stgs,err_msg,order,g_use_ichimoku,ORDERSLTYPE_SINGLEBAR);
  }
  
#ifdef 0  
  if(iADX(NULL,0,14,PRICE_TYPICAL,MODE_MAIN,1)>=20)//trend
  {
   double plus_di_1=iADX(NULL,0,14,PRICE_TYPICAL,MODE_PLUSDI,1);
   double plus_di_2=iADX(NULL,0,14,PRICE_TYPICAL,MODE_PLUSDI,2);
  
   double minus_di_1=iADX(NULL,0,14,PRICE_TYPICAL,MODE_MINUSDI,1);
   double minus_di_2=iADX(NULL,0,14,PRICE_TYPICAL,MODE_MINUSDI,2);
   
   MqlRates bar;
   
   if(gm==GATORMODE_REVERSAL && rates[1].high<jaw && ax_bar_utils::get_type5(rates,1)==BARTYPE_BULLISH && tp<plus_di_2<minus_di_2 && plus_di_1>minus_di_1 && (g_trade_mode==ADVTRADEMODE_BUY || g_trade_mode==ADVTRADEMODE_BOTH))//nuy
   //if(gm==GATORMODE_REVERSAL && sar<gator && gator<tp && (g_trade_mode==ADVTRADEMODE_BUY || g_trade_mode==ADVTRADEMODE_BOTH))
   {
    bar.low=ax_bar_utils::get_order_sl(rates,ORDERSLTYPE_LOCALEXTREMUM,TRADEMODE_BUY,1,0);
    ax_bar_utils::OpenOrder5(g_settings,bar,TRADEMODE_BUY,order_stgs,err_msg,order,2);
   }
   else
   if(gm==GATORMODE_NORMAL && rates[1].low>jaw && ax_bar_utils::get_type5(rates,1)==BARTYPE_BEARISH && plus_di_2>minus_di_2 && plus_di_1<minus_di_1 && (g_trade_mode==ADVTRADEMODE_SELL || g_trade_mode==ADVTRADEMODE_BOTH))
   //if(gm==GATORMODE_NORMAL && tp<gator && gator<sar && (g_trade_mode==ADVTRADEMODE_SELL || g_trade_mode==ADVTRADEMODE_BOTH))
   {
    bar.high=ax_bar_utils::get_order_sl(rates,ORDERSLTYPE_LOCALEXTREMUM,TRADEMODE_SELL,1,0);
    ax_bar_utils::OpenOrder5(g_settings,bar,TRADEMODE_SELL,order_stgs,err_msg,order,2);
   }
  }
  else
  {
   //закрываем все
   ax_bar_utils::CloseAllOrders();
  }
#endif   
  }
  if(StringLen(err_msg)!=0)
   Print(Symbol()," ",err_msg);
 }//if g_ready_bar
 
#ifdef 0
 for(int i=OrdersTotal()-1;i>=0;i--)
 {
  if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
   continue;
    
  if(OrderSymbol()!=Symbol())
   continue;
    
  if(OrderProfit()>=0.30)
   ax_bar_utils::CloseOrder(order_stgs,OrderTicket(),err_msg);
 }//for
#endif 
}

//+------------------------------------------------------------------+
