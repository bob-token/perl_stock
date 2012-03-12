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
our $g_fromcode;

$|=1;
sub COM_get_fromcode{
	return $g_fromcode;
}
sub COM_filter_param{
	my ($param)=@_;
	my @others;
	while(my $opt=shift @$param){
		if($opt =~ /-ufc\b/){
			$g_fromcode=shift @$param;
			next;
		}
		unshift @others,$opt;
	}
		unshift @$param,reverse(@others);
}
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
sub COM_is_valid_code{
    my $code =shift;
    return $code =~/s[hz]\d{6}/;
}
sub COM_get_page_content{
	my ($url,$max_try_times)=@_;
    my $browser = LWP::UserAgent->new;
    while(1){
            my $response = $browser->get($url);
            if($response->is_success and 'null' ne $response->content){
                    return \$response->content;
            }
            if ($max_try_times--){
                    sleep 1;			
            }else {
                    last;
            }
    }
	return undef;
}
