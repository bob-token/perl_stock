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
	if(($hour > 9 && $minute>20 && $hour <11) ||($hour>13 && $minute>20 && $hour <15) ){
		return 1;
	}
	return 0;
}
