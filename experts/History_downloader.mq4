//+------------------------------------------------------------------+
//|                                           History_downloader.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input int bar_count = 1;

struct bar_info
{
   double bar_open;
   double bar_close;
   double bar_high;
   double bar_low; 
   
   bar_info():
      bar_open(0),
      bar_close(0),
      bar_high(0),
      bar_low(0)
      {}
};

bar_info get_bar(int bar);
string get_string_bar(bar_info &bi);
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  
  //Comment(get_string_bar(get_bar(1)));
  log_open();
  
  for(int i = 1; i < bar_count; i++)
      log(get_string_bar(get_bar(i)));
  
  log_close();
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

bar_info get_bar(int bar)
{
   bar_info bi;
   bi.bar_open = Open[bar];
   bi.bar_close = Close[bar];
   bi.bar_high = High[bar];
   bi.bar_low = Low[bar];
   return bi;
}

string get_string_bar(bar_info &bi)
{
   string tmp = (string)Symbol() + "   " + (string)Period() + "   " + (string)bi.bar_open + "   " + (string)bi.bar_close + "  " + (string)bi.bar_high + "   " + (string)bi.bar_low;
   return tmp;
}

int log_handle = -1;
 
//+---------------------------------------------------------------+
// void log_open( string ExpertName = "Expert" )
//
// Функция, открывающая личный логфайл эксперта.
// Директория, в которой будет создан файл:
// "...\MetaTrader 4\experts\files\logs\ExpertName\"
// Имя файла - дата записи файла в формате "гггг.мм.дд"
//+---------------------------------------------------------------+
void log_open()
 {
     string log_name = "File" + " (" + Symbol() + ", " + 
                    strPeriod( Period() ) + ")"  + ".txt";
  log_handle = FileOpen ( log_name, FILE_READ | FILE_WRITE, " " );
  if( log_handle < 0 )
     {
         int _GetLastError = GetLastError();
    Print( "FileOpen( ", log_name, 
          ", FILE_READ | FILE_WRITE, \" \" ) - Error #", 
          _GetLastError );
   }
 }
string strPeriod( int intPeriod )
 {
     switch ( intPeriod )
     {
         case PERIOD_MN1: return("Monthly");
    case PERIOD_W1:  return("Weekly");
    case PERIOD_D1:  return("Daily");
    case PERIOD_H4:  return("H4");
    case PERIOD_H1:  return("H1");
    case PERIOD_M30: return("M30");
    case PERIOD_M15: return("M15");
    case PERIOD_M5:  return("M5");
    case PERIOD_M1:  return("M1");
    default:        return("UnknownPeriod");
   }
 }
 
//+---------------------------------------------------------------+
// log_close()
//
// Функция, закрывающая личный логфайл эксперта.
//+---------------------------------------------------------------+
void log_close()
 {
      if( log_handle > 0 ) FileClose( log_handle );
 }  
 
 void log( string text )
 {
     int _GetLastError = 0;
   if( log_handle < 0 )
      {
             Print( "Log write error! Text: ", text );
    }
    
     //---- Перемещаем файловый указатель в конец файла
     if( !FileSeek ( log_handle, 0, SEEK_END ) )
     {
          _GetLastError = GetLastError();
    Print( "FileSeek ( " + (string)log_handle + ", 0, SEEK_END ) - Error #", 
           _GetLastError );
   }
 
    //---- Если строка, которую хочет записать эксперт, это не символ 
 //переноса строки, 
    //---- добавляем в начало строки время записи
    if( text != "\n" && text != "\r\n" )
         text = StringConcatenate( TimeToStr( LocalTime(), TIME_SECONDS ), 
                             " - - - ", text );
    //---- Сбрасываем записанный тест на диск
    FileFlush( log_handle );
 }