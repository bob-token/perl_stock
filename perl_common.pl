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
use Log::Log4perl qw(:easy);

our $g_fromcode;
our $logfile = 0;
our $customlogfile;
$|=1;
sub COM_get_string{
	my ($flag)=@_;
	if($flag =~ "code_property_separator"){
		return "@";
	}elsif($flag =~ "code_property_assignment"){
		return ":";
	}elsif($flag =~ "user_property_separator"){
		return "@";
	}elsif($flag =~ "user_property_assignment"){
		return ":";
	}

	return undef;
}
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
sub COM_command_line_filter_codes
{
	my ($param)=@_;
	my @codes;
	my $code;
	my $find=0;
	while($code=shift $param and SCOM_is_valid_code($code) ){
		push @codes,$code;
	}
	if($code){
		unshift @$param,$code;
	}
	return @codes;
}
sub COM_get_command_line_property{
	my ($param,$key,$ref_value)=@_;
	my @others;
	my $assignment=':';
	my $key_ass=$key.$assignment;
	my $find=0;
	while($param and $$param[0] and index($$param[0],' -')==-1 and my $opt=shift @$param ){
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
sub COM_set_log_level{
	my ($level)=@_;
	if($level =~ /debug\b/i){
		Log::Log4perl::easy_init($DEBUG);
	}
	if($level =~ /warn\b/i){
		Log::Log4perl::easy_init($WARN);
	}
	if($level =~ /ERROR\b/i){
		Log::Log4perl::easy_init($ERROR);
	}
}
sub COM_filter_param{
	my ($param)=@_;
	my @others;
	COM_set_log_level("warn");
	while(my $opt=shift @$param){
		if($opt =~ /-fc\b/){
			$g_fromcode=shift @$param;
			next;
		}
		if($opt =~ /-log\b/){
			$logfile = 1;
			my $level;
			COM_get_command_line_property($param,"level",\$level);
			COM_set_log_level($level);
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
sub COM_download
{
	my ($url,$path,$max_try_times)=@_;
	if($url && $path){
		if (!$max_try_times){
			$max_try_times = 3;
		}
		my $page = COM_get_page_content($url,$max_try_times);
		if ($page){
			open(OUT,">$path");
			syswrite(OUT,$$page);
			close(OUT);
			return 1;
		}
	}
	return 0;
}
sub COM_get_page_content{
	my ($url,$max_try_times,$timeout)=@_;
    my $browser = LWP::UserAgent->new;
	$browser->agent('Mozilla/5.0 (X11; Linux i686; rv:22.0) Gecko/20100101 Firefox/22.0');
	if(!$max_try_times){
		$max_try_times=0;
	}
	if(!$timeout){
		$timeout = 180;
	}
	$browser->timeout($timeout);
	my $try = $max_try_times;
	COM_DEBUG("COM_get_page_content($url,$max_try_times,$timeout)");

    while(1){
            my $response = $browser->get($url);
            if($response->is_success and 'null' ne $response->content){
                    return \$response->content;
            }
            if ($try--){
					my $tims = $max_try_times-$try;
				    COM_WARN("try $tims get $url");
                    sleep 1;			
            }else {
					COM_ERROR("Error get $url");
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
sub COM_get_flag{
	my ($flag,$flagfile)=@_;
	open IN,"<",$flagfile;
	my $i=0;
	my $r;
	while(<IN>){
		if($i++<=$flag){
			$r=$_;
		}
	}
	close IN;
	chomp $r;
	return $r;
}
sub COM_remove{
	my ($ref_array,$val) = @_;
	if($val && $ref_array){
		my $index=0;
		foreach my $one(@$ref_array){
			if (index($val,$one)!=-1){
				return splice(@$ref_array,$index,1);
			}
			$index++;
		}
	}
	return 0;
}
sub COM_find{
	my ($ref_array,$val) = @_;
	if($val && $ref_array){
		foreach my $one(@$ref_array){
			if (index($val,$one)!=-1){
				return 1;
			}
		}
	}
	return 0;
}
sub COM_log_init{
	unlink COM_get_file_name("log");	
}
sub COM_DEBUG{
	my ($string)=@_;
	DEBUG $string;
	
}
sub COM_WARN{
	my ($string)=@_;
	WARN $string;
	
}
sub COM_ERROR{
	my ($string)=@_;
	ERROR $string;
	
}
sub COM_log{
	my ($string)=@_;
	my $logfilename = COM_get_file_name("log");
	if ($string){
		if ($logfile){
			open(OUT,">>$logfilename");
			foreach my $str(@_){
				print OUT $str;
			}
			close OUT;
		}
		print $string;
	}
}
sub COM_get_file_name{
	my ($flag)=@_;
	if($flag=~/\blog\b/){
		return "log_txt";		
	}
	return undef;
}
