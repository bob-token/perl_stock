#!/usr/bin/perl 
#===============================================================================
#
#         FILE: perl_customer.pl
#
#        USAGE: ./perl_customer.pl  
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
#      CREATED: 2012-6-13 14:28:37
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
require "perl_common.pl";
$|++;
sub CUS_GetFileName{
	my ($customer,$flag)=@_;
	if($flag=~/\blog\b/){
		return "$customer"."_log";		
	}elsif($flag=~/\bcfg\b/){
		return "$customer";
	}elsif($flag=~/\bmsg\b/){
		return "$customer"."_msg";
	}
	return undef;
}
sub CUS_GetFlag{
	my ($user,$flag)=@_;
	if($flag =~ "property"){
		return "property";
	}elsif($flag =~ "code"){
		return "code";
	}
	return undef;
}
sub CUS_AddUser{
	my ($user,$ref_property)=@_;
	my $type=join(COM_get_string("user_property_assignment"),"type",CUS_GetFlag($user,"property"));
	my $str=join(COM_get_string("user_property_separator"),$type,@$ref_property);
	open OUT,">",CUS_GetFileName($user,"cfg");
	print OUT $str ;
	close OUT;
}
sub CUS_DelUser{
	unlink(CUS_GetFileName(shift,"cfg"));
}
sub CUS_AddProperty{
}
sub CUS_DelProperty{
}
sub CUS_GetProperty{
}
main{
	my @test=qw{aa bb};
	CUS_DelUser("13590216192");
	
}
