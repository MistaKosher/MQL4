//+------------------------------------------------------------------+
//|                                                         Exp2.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

MqlRates g_ready_bar;


input double g_lot=0.01;//лот
input int magic_number = 1488; //магик
input int g_slippage = 3;//проскальзывание
input int expiration_bar = 3;//экспирация
input int g_delta_points_sl=1; //дельта стоп-лосса
input int g_delta_points_p=1; //дельта отложености  
input int tp= 0; //фиксированая прибыль 
input bool use_trand = true; //трендоориентированость
input bool reverse = true; //учитывать разворотный бар
input int secret= 2; //;) 
input int ma_period= 1; //;)

double upper_fractal;   
double lower_fractal;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
