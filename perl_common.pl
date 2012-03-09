#!/usr/bin/perl 
#===============================================================================
#
#         FILE: perl_common.pl
#
#        USAGE: ./perl_common.pl  
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
#      CREATED: 03/09/2012 02:27:34 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;


$|=1;
sub COM_is_earlier_than{
	my $dest=shift;
	my $src=shift;
	if(defined $dest && defined $src){
		my @ddate=split('-',$dest);
		my @sdate=split('-',$src);
		if($ddate[0]<$sdate[0] || $ddate[1]<$sdate[1]||$ddate[2]<$sdate[2]){		
			return 1;	
		}
	}	
	return 0;
}
sub COM_is_same_day{
	my $dest=shift;
	my $src=shift;
	if(defined $dest && defined $src){
		my @ddate=split('-',$dest);
		my @sdate=split('-',$src);
		if($ddate[0]==$sdate[0] && $ddate[1]==$sdate[1]&&$ddate[2]==$sdate[2]){		
			return 1;	
		}
	}	
	return 0;
}
