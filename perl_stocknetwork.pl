
$|=1;
sub SN_get_stock_last_close_price{
  if(my @info=SN_get_stock_cur_exchange_info(shift)){
    return $info[2];
  }
  return undef;
} 
sub SN_get_stock_cur_price{
  if(my @info=SN_get_stock_cur_exchange_info(shift)){
    return $info[3];
  }
  return undef;
} 
sub SN_get_stock_today_trading_volume{
  if(my @info=SN_get_stock_cur_exchange_info(shift)){
  	if(COM_is_same_day($info[30],COM_today(0))){
    	return $info[8];
	}
  }
  return 0;
}
#0：”大秦铁路”，股票名字；
#1：”27.55″，今日开盘价；
#2：”27.25″，昨日收盘价；
#3：”26.91″，当前价格；
#4：”27.55″，今日最高价；
#5：”26.20″，今日最低价；
#6：”26.91″，竞买价，即“买一”报价；
#7：”26.92″，竞卖价，即“卖一”报价；
#8：”22114263″，成交的股票数，由于股票交易以一百股为基本单位，所以在使用时，通常把该值除以一百；
#9：”589824680″，成交金额，单位为“元”，为了一目了然，通常以“万元”为成交金额的单位，所以通常把该值除以一万；
#10：”4695″，“买一”申请4695股，即47手；
#11：”26.91″，“买一”报价；
#12：”57590″，“买二”
#13：”26.90″，“买二”
#14：”14700″，“买三”
#15：”26.89″，“买三”
#16：”14300″，“买四”
#17：”26.88″，“买四”
#18：”15100″，“买五”
#19：”26.87″，“买五”
#20：”3100″，“卖一”申报3100股，即31手；
#21：”26.92″，“卖一”报价
#(22, 23), (24, 25), (26,27), (28, 29)分别为“卖二”至“卖四的情况”
#30：”2008-01-11″，日期；
#31：”15:05:32″，时间；
sub SN_get_stock_cur_exchange_info{
    my $code = shift;
    my $url=sprintf("http://hq.sinajs.cn/?_=1314426110204&list=%s",$code);
    if(my $content_ref=COM_get_page_content($url,10)){
	    chomp $$content_ref;
	    my $info = substr($$content_ref,length('var hq_str_')+length($code)+1+1,-2);
	    my @info=split('\,',$info);
	    return  @info;
    }
	return undef;
} 

