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
sub DBT_get_closing_price{
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"SHOUPANJIA",$condition); 
}
