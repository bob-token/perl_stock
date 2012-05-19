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
sub COM_get_property{
	my ($param,$key,$ref_value)=@_;
	my @others;
	my $assignment=':';
	my $key_ass=$key.$assignment;
	my $find=0;
	while($param and $$param[0] and index($$param[0],'-')==-1 and my $opt=shift @$param ){
		unshift @others,$opt;
		if(index($opt,$key_ass)!=-1 ){
			my @property=split($assignment,$opt);
			if ($ref_value){
				$$ref_value=$property[1];
				chomp $$ref_value;
			}
			$find=1;
			last;
		}
		if(index($opt,$key)!=-1 ){
			if ($ref_value){
				$$ref_value=();
			}
			$find=1;
			last;
		}
	}
		unshift @$param,reverse(@others);
		return $find;
}
sub COM_get_command_line_property{
	my ($param,$key,$ref_value)=@_;
	my @others;
	my $assignment=':';
	my $key_ass=$key.$assignment;
	my $find=0;
	while($param and $$param[0] and index($$param[0],'-')==-1 and my $opt=shift @$param ){
		if(index($opt,$key_ass)!=-1 ){
			my @property=split($assignment,$opt);
			if ($ref_value){
				$$ref_value=$property[1];
			}
			$find=1;
			last;
		}
		if(index($opt,$key)!=-1 ){
			if ($ref_value){
				$$ref_value=();
			}
			$find=1;
			last;
		}
		unshift @others,$opt;
	}
		unshift @$param,reverse(@others);
		return $find;
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
sub COM_is_valid_attribute{
	if (!/^-/){
		return 1;
	}
	return 0;
}

sub COM_get_page_content{
	my ($url,$max_try_times)=@_;
    my $browser = LWP::UserAgent->new;
	if(!$max_try_times){
		$max_try_times=0;
	}
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
sub COM_get_cur_time{
	my ($flag)=@_;
	my $csec;
	my $cmin;
	my $chour;
	my $cday;
	my $cmon;
	my $cyear;
	my $cwday;#$wday is the day of the week, with 0 indicating Sunday and 3 indicating Wednesday
	my $cyday;
	my $cisdst;
	($csec, $cmin, $chour, $cday, $cmon, $cyear, $cwday, $cyday, $cisdst) = localtime();
	$cyear=$cyear+1900;
	my @mytime;
	push @mytime,$cyear;
	push @mytime,$cmon;  #0-11
	push @mytime,$cday;
	push @mytime,$chour;
	push @mytime,$cmin;
	push @mytime,$csec;
	push @mytime,$cwday;
	push @mytime,$cyday;
	push @mytime,$cisdst;
	if($flag){
		if ($flag =~/\byear\b/){
			return $mytime[0];
		}elsif($flag =~/\bmonth\b/){
			return $mytime[1];
		}elsif($flag =~/\bday\b/){
			return $mytime[2];
		}elsif($flag =~/\bhour\b/){
			return $mytime[3];
		}elsif($flag =~/\bminute\b/){
			return $mytime[4];
		}elsif($flag =~/\bsecond\b/){
			return $mytime[5];
		}elsif($flag =~/\bweek_of_day\b/){
			return $cwday;
		}
		return undef;
	}
	return @mytime;
}
sub COM_today{
	my $type=shift;
	my $year=COM_get_cur_time('year');
	my $mon=COM_get_cur_time('month')+1;
	my $day=COM_get_cur_time('day');
	if($type==0){
		return join('-',$year,$mon,$day);	
	}elsif($type==1){
		return join('',$year,$mon,$day);	
	}
}
