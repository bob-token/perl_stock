#!/usr/bin/perl 
#===============================================================================
#
#         FILE: perl_stockcommon.pl
#
#        USAGE: ./perl_stockcommon.pl  
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
#      CREATED: 03/20/2012 01:05:59 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
require "perl_common.pl";
$|=1;
sub SCOM_is_valid_code{
    my $code =shift;
    return $code =~/s[hz]\d{6}/;
}

sub SCOM_today_is_exchange_day{
	my $today=COM_today(0);
	if(COM_get_cur_time('week_of_day')==0 || COM_get_cur_time('week_of_day')==6){
		return 0;	
	}
	my $non_exchangeday=SCOM_get_file_name('non-exchangeday');
	open (IN,'<',$non_exchangeday);
	while(<IN>){
		if(COM_is_same_day($_,$today)){
			return 0;
		}
	}
	close IN;
	return 1;
}
sub SCOM_is_exchange_duration{
	my ($hour,$minute)=@_;
	#上午9:20-11:20
	if(9*60+30<= $hour*60+$minute &&11*60+30 >= $hour*60+$minute ){
		return 1;
	}
	#下午13:00-15:00
	if(13*60 <= $hour*60+$minute &&15*60 >= $hour*60+$minute ){
		return 1;
	}
	return 0;
}
sub SCOM_calc_income{
	my ($code,$buyprice,$sellprice,$total)=@_;
	my $yinhuatax=0.001;
	my $servicechange=0.002;
	if(SCOM_is_valid_code($code)){
		my $income=($sellprice-$buyprice)*$total-($yinhuatax+$servicechange)*$sellprice;
		#沪市股票要加一元的过户费
		if(index($code,'sh')!=-1){
			$income=$income-1;
		}
		return $income;
	}
	return 0;
}
sub SCOM_get_file_name{
	my ($flag)=@_;
	if($flag=~/\bnon-exchangeday\b/){
		return "non_exchangeday_txt";		
	}
	return undef;
}
sub SCOM_code_get_file_name{
	my ($code,$flag)=@_;
	if($flag=~/\blog\b/){
		return "$code"."_log";		
	}elsif($flag=~/\bstatus\b/){
		return "$code"."_status";
	}elsif($flag=~/\bcus_log\b/){
		return "$code"."cus_log";
	}
	return undef;
}
