//+------------------------------------------------------------------+
//|                                                   ax_ind_001.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "http://www.mql4.com"
#property version   "1.00"
#property strict

//---- indicator settings
#property  indicator_separate_window
//#property indicator_minimum 0
#property indicator_buffers 5
#property indicator_color1  Black
#property indicator_color2  Lime
#property indicator_color3  SaddleBrown
#property indicator_color4  Blue
#property indicator_color5  Pink
#property indicator_width2  2
#property indicator_width3  2
#property indicator_width4  2
#property indicator_width5  2
//---- indicator buffers
double ExtMFIBuffer[];
///*
double ExtMFIUpVUpBuffer[];
double ExtMFIDownVDownBuffer[];
double ExtMFIUpVDownBuffer[];
double ExtMFIDownVUpBuffer[];
//*/

//double ExtMFIUpBuffer[];
//double ExtMFIDownBuffer[];

int hGator;
double jaw_buf[];
int jaw_shift=0;

//будем хранить количество значений в индикаторе Alligator 
int bars_calculated=0;


//+------------------------------------------------------------------+ 
//| Custom indicator initialization function                         | 
//+------------------------------------------------------------------+ 
int OnInit() 
{ 
//---- indicator buffers mapping
   SetIndexBuffer(0,ExtMFIBuffer);       
   //SetIndexBuffer(1,ExtMFIUpBuffer);
   //SetIndexBuffer(2,ExtMFIDownBuffer);
   SetIndexBuffer(1,ExtMFIUpVUpBuffer);
   SetIndexBuffer(2,ExtMFIDownVDownBuffer);
   SetIndexBuffer(3,ExtMFIUpVDownBuffer);
   SetIndexBuffer(4,ExtMFIDownVUpBuffer);
//---- drawing settings
   SetIndexStyle(0,DRAW_NONE);
   SetIndexStyle(1,DRAW_HISTOGRAM);
   SetIndexStyle(2,DRAW_HISTOGRAM);
   SetIndexStyle(3,DRAW_HISTOGRAM);
   SetIndexStyle(4,DRAW_HISTOGRAM);   
//---- name for DataWindow and indicator subwindow label
   IndicatorShortName("AX BW MFI Alligator");
   SetIndexLabel(0,"AX BW MFI Alligator");      
   SetIndexLabel(1,NULL);
   SetIndexLabel(2,NULL);
   SetIndexLabel(3,NULL);
   SetIndexLabel(4,NULL);
//---- sets drawing line empty value
   SetIndexEmptyValue(0, 0.0);
   SetIndexEmptyValue(1, 0.0);
   SetIndexEmptyValue(2, 0.0);       
   SetIndexEmptyValue(3, 0.0);
   SetIndexEmptyValue(4, 0.0);      
//---- initialization done
   return(INIT_SUCCEEDED);
} 

//+------------------------------------------------------------------+ 
//| Custom indicator iteration function                              | 
//+------------------------------------------------------------------+ 
int OnCalculate(const int rates_total, 
                const int prev_calculated, 
                const datetime& time[], 
                const double& open[], 
                const double& high[], 
                const double& low[], 
                const double& close[], 
                const long& tick_volume[], 
                const long& volume[], 
                const int& spread[]) 
{ 
   int  i,nLimit,nCountedBars;
   bool bMfiUp=true,bVolUp=true;
//---- bars count that does not changed after last indicator launch.
   nCountedBars=IndicatorCounted();
//---- last counted bar will be recounted
   if(nCountedBars>0) nCountedBars--;
   nLimit=Bars-nCountedBars;
//---- Market Facilitation Index calculation
   for(i=0; i<nLimit; i++)
     {
      if(CompareDouble(tick_volume[i],0.0))
        {
         Print(tick_volume[i]);
         if(i==Bars-1) ExtMFIBuffer[i]=0.0;
         else ExtMFIBuffer[i]=ExtMFIBuffer[i+1];
        }
      //else ExtMFIBuffer[i]=(high[i]-low[i])/(tick_volume[i]*Point);
      else 
      {
       ExtMFIBuffer[i]=MathAbs((high[i]+low[i])/2-get_iAlligator(i,MODE_GATORJAW))/Point/tick_volume[i];
       //Comment("GATOR[",i,"]=",val,"\nCLOSE[",i,"]=",close[i],"\ntick_volume[",i,"]=",tick_volume[i]/*,"\nvolume[",i,"]=",volume[i]*/);
      }
     }
 
 /*    
 //normalize last mfi value
 if(rates_total>1)
 {
  datetime ctm=//TimeTradeServer()
  TimeCurrent(),lasttm=time[rates_total-1],nexttm=lasttm+datetime(PeriodSeconds());
 
  if(ctm<nexttm && ctm>=lasttm && nexttm!=lasttm)
  {
   double correction_koef=double(1+ctm-lasttm)/double(nexttm-lasttm);
   ExtMFIBuffer[rates_total-1]*=correction_koef;
  }
 }*/
     
     
     
     
     
//---- upanddown flags setting
   if(nCountedBars>1)
     {
      //---- analyze previous bar before recounted bar
      i=nLimit+1;
      if(ExtMFIUpVUpBuffer[i]!=0.0)
//      if(ExtMFIUpBuffer[i]!=0.0)
        {
         bMfiUp=true;
         bVolUp=true;
        }
      //if(ExtMFIDownBuffer[i]!=0.0)
      if(ExtMFIDownVDownBuffer[i]!=0.0)
        {
         bMfiUp=false;
         bVolUp=false;
        }
        ///*
      if(ExtMFIUpVDownBuffer[i]!=0.0)
        {
         bMfiUp=true;
         bVolUp=false;
        }
      if(ExtMFIDownVUpBuffer[i]!=0.0)
        {
         bMfiUp=false;
         bVolUp=true;
        }
        //*/
     }
//---- dispatch values between 4 buffers
   for(i=nLimit-1; i>=0; i--)
     {
      if(i<Bars-1)
        {
         if(ExtMFIBuffer[i]>ExtMFIBuffer[i+1]) bMfiUp=true;
         if(ExtMFIBuffer[i]<ExtMFIBuffer[i+1]) bMfiUp=false;
         if(tick_volume[i]>tick_volume[i+1])             bVolUp=true;
         if(tick_volume[i]<tick_volume[i+1])             bVolUp=false;
        }
        
        /*
        if(bMfiUp)
        {
         ExtMFIUpBuffer[i]=ExtMFIBuffer[i];
         ExtMFIDownBuffer[i]=0.0;
        }
        else
        {
         ExtMFIUpBuffer[i]=0.0;
         ExtMFIDownBuffer[i]=ExtMFIBuffer[i];
        }
        */
        
        ///*
     if(bMfiUp && bVolUp)
       {
        ExtMFIUpVUpBuffer[i]=ExtMFIBuffer[i];
        ExtMFIDownVDownBuffer[i]=0.0;
        ExtMFIUpVDownBuffer[i]=0.0;
        ExtMFIDownVUpBuffer[i]=0.0;
        continue;
       }
     if(!bMfiUp && !bVolUp)
       {
        ExtMFIUpVUpBuffer[i]=0.0;
        ExtMFIDownVDownBuffer[i]=ExtMFIBuffer[i];
        ExtMFIUpVDownBuffer[i]=0.0;
        ExtMFIDownVUpBuffer[i]=0.0;
        continue;         
       }
     if(bMfiUp && !bVolUp)
       {
        ExtMFIUpVUpBuffer[i]=0.0;
        ExtMFIDownVDownBuffer[i]=0.0;
        ExtMFIUpVDownBuffer[i]=ExtMFIBuffer[i];
        ExtMFIDownVUpBuffer[i]=0.0;
        continue;         
       }
     if(!bMfiUp && bVolUp)
       {
        ExtMFIUpVUpBuffer[i]=0.0;
        ExtMFIDownVDownBuffer[i]=0.0;
        ExtMFIUpVDownBuffer[i]=0.0;
        ExtMFIDownVUpBuffer[i]=ExtMFIBuffer[i];
        continue;         
       }  
       //*/      
    }
 return rates_total;  
} 

//+------------------------------------------------------------------+
bool CompareDouble(double dNumber1, double dNumber2)
  {
   bool bCompare=NormalizeDouble(dNumber1-dNumber2,8) == 0;
   return(bCompare);
  }
  
//+------------------------------------------------------------------+
double get_iAlligator(int shift,int mode)
{
 return iAlligator(NULL,0,13,8,8,5,5,3,MODE_SMMA,PRICE_MEDIAN,mode,shift);
}

/*


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   
//--- return value of prev_calculated for next call
   return(5);
  }
//+------------------------------------------------------------------+
*/