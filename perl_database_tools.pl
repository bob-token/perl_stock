#!/usr/bin/perl 
#===============================================================================
#
#         FILE: perl_database_tools.pl
#
#        USAGE: ./perl_database_tools.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 03/09/2012 01:49:56 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
require "perl_common.pl";
require "perl_database.pl";

$|=1;
sub DBT_get_last_exchange_day{
	my ($dhe,$code)=@_;
	if($code and $dhe ){
		my $today = COM_today(0);
    	my $condition="DATE<=\"$today\" ORDER BY DATE DESC LIMIT 1";
		my $day=MSH_GetValueFirst($dhe,$code,"DATE",$condition); 
		return $day; 
	}
	return undef;
}
sub DBT_get_earlier_exchange_days{
	my ($dhe,$code,$last_day,$day_cnt)=@_;
	if($code && $last_day && defined $day_cnt){
    	my $condition="DATE<=\"$last_day\" ORDER BY DATE DESC LIMIT $day_cnt";
		my @days=MSH_GetValue($dhe,$code,"DATE",$condition); 
		return @days; 
	}
	return undef;
}
sub DBT_get_fore_exchange_day{
	my ($code,$date,$dhe) = @_;
    my $condition="DATE<\"$date\" ORDER BY DATE DESC LIMIT 1";
	if(my @days=MSH_GetValue($dhe,$code,"DATE",$condition)){
		return $days[0];
	}
	return undef
}
sub DBT_get_next_exchange_day{
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE>\"$date\" ORDER BY DATE ASC LIMIT 1";
	if(my @days=MSH_GetValue($dhe,$code,"DATE",$condition)){
		return $days[0];
	}
	return undef
}
sub DBT_get_exchange_info{
	my $code=shift;
	my $fromdate=shift;
	my $todate=shift;
	my $dhe=shift;
    my $condition="DATE>=\"$fromdate\" and DATE<=\"$todate\" ORDER BY DATE ASC ";
	return MSH_GetValue($dhe,$code,"*",$condition); 
}
sub DBT_get_fore_date_closing_price{
	my @value;
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
	my $fore_day = DBT_get_fore_exchange_day($code,$date,$dhe);
	if($fore_day){
		return DBT_get_closing_price($code,$fore_day,$dhe);
	}
	return DBT_get_closing_price($code,$date,$dhe);
}
sub DBT_get_next_date_closing_price{
	my @value;
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE>\"$date\" ORDER BY DATE ASC LIMIT 1";
	return MSH_GetValue($dhe,$code,"DATE,SHOUPANJIA",$condition); 
}
sub DBT_get_season_exchage_days{
	COM_DEBUG ("DBT_get_season_exchage_days");
	my ($dhe,$code,$year,$season)=@_;
	if($dhe && $code && $year && defined $season){
		my @exchange_days;
		my $season_start=$year.'-'.($season*3+1).'-01';
		my $season_end=$year.'-'.($season*3+3).'-31';;
		my $condition="DATE<=\"$season_end\" && DATE>=\"$season_start\" ORDER BY DATE ASC";
		@exchange_days=MSH_GetValue($dhe,$code,"DATE",$condition);
		return @exchange_days;
	}
	return undef;
}
sub DBT_get_exchange_days_ext{
	my ($code,$dhe,$from,$count)=@_;	
	if ($code && $dhe && $from && $count){
		my $condition=" DATE>=\"$from\" ORDER BY DATE ASC LIMIT $count";
		my @exchange_days=MSH_GetValue($dhe,$code,"DATE",$condition);
		return @exchange_days;
	}
	return undef;
}
sub DBT_get_exchange_days{
	my ($code,$dhe,$from,$to)=@_;	
	if ($code && $dhe && $from ){
		if(!$to){
			$to = DBT_get_last_exchange_day($dhe,$code);	
			if(COM_is_earlier_than($to,$from)){
				$to = $from;
			}
		}
		my $condition="DATE<=\"$to\" && DATE>=\"$from\" ORDER BY DATE ASC";
		my @exchange_days=MSH_GetValue($dhe,$code,"DATE",$condition);
		return @exchange_days;
	}
	return undef;
}
sub DBT_get_max_closing_price{
	my ($code,$dhe,$from,$to)=@_;	
	if($code && $dhe && $from){
		my @days = DBT_get_exchange_days($code,$dhe,$from,$to);	
		my $max = 0;
		foreach my $day(@days){
			my $price = DBT_get_closing_price($code,$day,$dhe);	
			if ($price > $max){
				$max = $price;
			}
		}
		return $max;
	}
	return undef;
}
sub DBT_get_min_price{
	my ($code,$date,$dhe)=@_;
	my @value;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"ZUIDIJIA",$condition); 
}
sub DBT_get_max_price{
	my ($code,$date,$dhe)=@_;
	my @value;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"ZUIGAOJIA",$condition); 
}
#获取交易量
sub DBT_get_volume{
	my ($code,$dhe,$date)=@_;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"JIAOYIGUSHU",$condition);
}
sub DBT_get_opening_price{
	my @value;
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"KAIPANJIA",$condition); 
}
sub DBT_get_closing_price{
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"SHOUPANJIA",$condition); 
}
sub DBT_get_days_rise{
	my ($code,$dhe,$datefrom,$dateto)=@_;
	my $from_open_price = DBT_get_opening_price($code,$datefrom,$dhe);
	my $fore_close_price = DBT_get_fore_date_closing_price($code,$datefrom,$dhe);
	#use fore-closing price
	if ($fore_close_price){
		$from_open_price  = $fore_close_price;
	}
	my $to_close_price = DBT_get_closing_price($code,$dateto,$dhe);
	if ($from_open_price and $to_close_price){
		my $rise = ($to_close_price - $from_open_price )/$from_open_price;
		return $rise;
	}
	return 0;
}
#当天振幅
sub DBT_get_amplitude{
	my ($code,$dhe,$date)=@_;
	my $max_price = DBT_get_max_price($code,$date,$dhe);
	my $min_price = DBT_get_min_price($code,$date,$dhe);
	my $fore_close_price = DBT_get_fore_date_closing_price($code,$date,$dhe);
	my $opening_price = DBT_get_opening_price($code,$date,$dhe);
	if ($fore_close_price){
		return ($max_price-$min_price)/$fore_close_price;
	}
	return ($max_price-$min_price)/$opening_price;
}
sub DBT_get_rise{
	my ($code,$dhe,$date)=@_;
	my $from_open_price = DBT_get_opening_price($code,$date,$dhe);
	my $fore_close_price = DBT_get_fore_date_closing_price($code,$date,$dhe);
	#use fore-closing price
	if ($fore_close_price){
		$from_open_price  = $fore_close_price;
	}
	my $to_close_price = DBT_get_closing_price($code,$date,$dhe);
	if ($from_open_price and $to_close_price){
		my $rise = ($to_close_price - $from_open_price )/$from_open_price;
		return $rise;
	}
	return 0;
}
sub DBT_get_exchange_stockts{
	my $code=shift;
	my $dhe=shift;
	return MSH_GetValueFirst($dhe,$code,"LIUTONGGU"); 
}
sub DBT_get_profit{
	my ($code,$dhp,$before_end_date)=@_;
	#before_end_date是指在这个日期上的截至日或者在这个日期之前的上一个截至日时
	#例如：2012-03-31或者 2012-04-22 都会获取2012-03-31这个截至日发布的每股收益
	if($before_end_date){
    	my $condition="DATE<=\"$before_end_date\"";
		return MSH_GetValueFirst($dhp,$code,"MEIGUSHOUYI",$condition);
	}
	return MSH_GetValueFirst($dhp,$code,"MEIGUSHOUYI");
}
