
$|=1;
sub SN_get_stock_cur_price{
  if(my @info=SN_get_stock_cur_exchange_info(shift)){
    return $info[1];
  }
  return undef;
}
sub SN_get_stock_cur_exchange_info{
    my $code = shift;
    my $url=sprintf("http://hq.sinajs.cn/?_=1314426110204&list=%s",$code);
    if(my $content_ref=COM_get_page_content($url,10)){
	    chomp $$content_ref;
	    my $info = substr($$content_ref,length('var hq_str_')+length($code)+1+1,-2);
	    my @info=split('\,',$info);
	    return  @info;
    }
} 

