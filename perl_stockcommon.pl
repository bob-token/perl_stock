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

sub SCOM_is_exchange_duration{
	my ($hour,$minute)=@_;
	#ионГ9:20-11:20
	if(9*60+20 <= $hour*60+$minute &&11*60+20 >= $hour*60+$minute ){
		return 1;
	}
	#обнГ13:00-15:00
	if(13*60 <= $hour*60+$minute &&15*60 >= $hour*60+$minute ){
		return 1;
	}
	return 0;
}
