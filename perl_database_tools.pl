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
require "perl_database.pl";

$|=1;
sub DBT_get_earlier_exchange_days{
	my ($dhe,$code,$last_day,$day_cnt)=@_;
	if($code && $last_day && defined $day_cnt){
    	my $condition="DATE<=\"$last_day\" ORDER BY DATE DESC LIMIT $day_cnt";
		my @days=MSH_GetValue($dhe,$code,"DATE",$condition); 
		return @days; 
	}
	return undef;
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
sub DBT_get_next_date_closing_price{
	my @value;
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE>\"$date\" ORDER BY DATE ASC LIMIT 1";
	return MSH_GetValue($dhe,$code,"DATE,SHOUPANJIA",$condition); 
}
sub DBT_get_season_exchage_days{
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
sub DBT_get_min_price{
	my @value;
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"ZUIDIJIA",$condition); 
}
sub DBT_get_max_price{
	my @value;
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"ZUIGAOJIA",$condition); 
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
sub DBT_get_rise{
	my ($code,$dhe,$datefrom,$dateto)=@_;
	my @earlier_datefroms=DBT_get_earlier_exchange_days($dhe,$code,$datefrom,2);
	my $from_open_price = DBT_get_opening_price($code,$datefrom,$dhe);
	#use fore-closing price
	if (@earlier_datefroms){
		$from_open_price  = DBT_get_closing_price($code,$earlier_datefroms[1],$dhe);
	}
	my $to_close_price = DBT_get_closing_price($code,$dateto,$dhe);
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
