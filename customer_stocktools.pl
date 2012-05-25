#!/usr/bin/perl -w
use strict;
use warnings;
use LWP;
require "perl_common.pl";
require "perl_stockcommon.pl";
require "perl_stocknetwork.pl";
our $BuyStockCode="customer_stock_code.txt";
our $code_property_separator='@';
our $code_property_assignment=':';
$|=1;

sub _get_all_cus_stocks{
	my @codes;
#读取信息文件
	open IN,"<",$BuyStockCode;
	while(<IN>){
		my @codeinfo=split($code_property_separator,$_);
		my $code;
		if(@codeinfo and COM_get_property(\@codeinfo,'code',\$code) and SCOM_is_valid_code($code)){
			push @codes,$code;
		}
	}
	close IN;	
	return @codes;
}
sub _delete_cus_stock_info{
	my ($code)=@_;
	my @buycodes;
#读取信息文件
	if(open IN,"<",$BuyStockCode){
		while(<IN>){
			chomp $_;
			my @info=split($code_property_separator,$_);
			my $value;
			if(@info && COM_get_property(\@info,'code',\$value) && index($code,$value)!=0){
				push @buycodes,$_;
			}
		}
		close IN;	
	}
#保存到文件
	open OUT,">",$BuyStockCode;
	syswrite(OUT,join("\n",@buycodes));
	close OUT;	
}
sub _add_cus_stock_info{
	my (@codeinfo)=@_;
	my $order=join($code_property_separator,@codeinfo);
#保存到文件
	open OUT,">>",$BuyStockCode;
	syswrite(OUT,"\n");
	syswrite(OUT,$order);
	close OUT;	
	return 1;
}
sub _get_cus_code_info{
	my ($code,$flag)=@_;
	my @info;
#读取信息文件
	open IN,"<",$BuyStockCode;
	while(<IN>){
		@info=split($code_property_separator,$_);
		my $value;
		if(@info && COM_get_property(\@info,'code',\$value) && index($code,$value)==0){
			last;	
		}
	}
	close IN;	

	if(@info and !$flag){
		return @info;
	}
	my $value;
	if(COM_get_property(\@info,$flag,\$value)){
		return $value;	
	}
	return undef;
}
sub _add_property{
	my ($ref_info,$key,$value)=@_;
	push @{$ref_info},join($code_property_assignment,$key,$value);	
}
sub _remove_property{
	my ($ref_info,$key,$value)=@_;
	if($ref_info and $key){
		 COM_get_command_line_property(\@{$ref_info},$key);
	}
}
sub _add{
	my ($code,$callnumber)=@_;
	_delete_cus_stock_info($code);
	my @codeinfo;
	_add_property(\@codeinfo,'code',$code);
	_add_property(\@codeinfo,'call_number',$callnumber);
	return _add_cus_stock_info(@codeinfo);
}
sub _get_code_monitor_info_file{
	my ($code,$flag)=@_;
	return SCOM_code_get_file_name($code,'cus_'.$flag);
}
sub _log{
	my ($logfile,$msg)=@_;
	open OUT,">>",$logfile;
	syswrite(OUT,"\n");
	syswrite(OUT,$msg);
	close OUT; 
}
sub _get_flag{
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
sub _sms{
	my ($flag0,$flag1,$flag2,$flag3)=@_;
	if($flag3){
		system("python2 pywapfetion/bobfetion.py $flag0 $flag1 $flag2 \"$flag3\"");
	}else{
		system("python2 pywapfetion/bobfetion.py $flag0 $flag1 \"$flag2\"");
	}
}
sub _report_code{
	my ($code,$msg)=@_;
	printf $msg."\n";	
	my $flag0=_get_flag(0,"flag");
	my $flag1=_get_flag(1,"flag");
	my $flag2=_get_flag(2,"flag");
	my $cus_number=_get_cus_code_info($code,'call_number');
#	chomp $cus_number;
	if($cus_number){
		_sms($flag0,$flag1,$cus_number,qq{$msg});
	}
	_log( _get_code_monitor_info_file($code,'log'),$msg);
}
sub _construct_code_day_header{
	my ($code,$type)=@_;
	if(SCOM_is_valid_code($code)){
		my $day=COM_today(0);
		return "$day:$code:$type";
	}
	return undef;
}
sub _construct_code_header{
	my ($code,$type)=@_;
	if(SCOM_is_valid_code($code)){
		return "$code:$type";
	}
	return undef;
}
sub _is_exchange_info_loged{
	my ($code,$logflag)=@_;
	if(open (IN,'<', _get_code_monitor_info_file($code,'log'))){
		foreach my $line(<IN>){
			if(index($line,$logflag)!=-1){
				close IN;
				return 1;
			}
		}
	}
	close IN;
	return 0;
}
sub _is_today_loged{
	my ($logflag)=@_;
	if(open (IN,'<',COM_today(1))){
		foreach my $line(<IN>){
			if(index($line,$logflag)!=-1){
				close IN;
				return 1;
			}
		}
	}
	close IN;
	return 0;
}
sub _monitor_cus_stock{
	my ($code,$refarrar_monitor_info)=@_;
	if($code){
		if (!SCOM_today_is_exchange_day()){
			return;
		}
		my $tip_percent_average_diff=0.005;
		my $tip_percent_reported_diff=0.005;
		my $tip_percent_fore_diff=0.007;
		my $hour=COM_get_cur_time('hour');
		my $minute=COM_get_cur_time('minute');
		my $average=\@{$refarrar_monitor_info}[0];
		my $max=\@{$refarrar_monitor_info}[1];
		my $fore_price=\@{$refarrar_monitor_info}[2];
		my $reported_price=\@{$refarrar_monitor_info}[3];
		my $cur_price=SN_get_stock_cur_price($code);
		#交易期间检测
		#my $reported_price_diff=0;
		#my $reportstr=_construct_code_header($code,'rep_dif').":($cur_price):rep_dif:($reported_price_diff)";
		#_report_code($code,$reportstr);
		#$$reported_price=$cur_price;
		if (SCOM_is_exchange_duration($hour,$minute)){
			#为了减少SCOM_is_suspension函数的联网先判断$cur_price是否为0
			if($cur_price==0 ){
				if( SCOM_is_suspension($code)){
					my $last_close_price=SN_get_stock_last_close_price($code);
					if( !_is_exchange_info_loged($code,_construct_code_day_header($code,'suspension'))){
						my $reportstr=_construct_code_day_header($code,'suspension').":($last_close_price)";
						 _report_code($code,$reportstr);
						$$reported_price=$cur_price;
					}
				}
				return;
			}
			if($$max <$cur_price){
			   $$max=$cur_price;	
			}
			if(${$average}==0){
				${$average}=$cur_price;
			}
			if($$fore_price==0){
				$$fore_price=$cur_price;
			}
			if($$reported_price==0){
				$$reported_price=$cur_price;
			}
			#提示	
			my $average_diff=($cur_price-${$average})/$$average;
			if(abs($average_diff)>=$tip_percent_average_diff){
				$average_diff=sprintf("%.4f",$average_diff);
				my $reportstr=_construct_code_header($code,'ave_dif').":($cur_price):ave_dif:($average_diff)";
				 _report_code($code,$reportstr);
				$$reported_price=$cur_price;
			}
			my $reported_price_diff=(($cur_price-$$reported_price)/$$reported_price);
			if(abs($reported_price_diff)>$tip_percent_reported_diff){
				$reported_price_diff=sprintf("%.4f",$reported_price_diff);
				my $reportstr=_construct_code_header($code,'rep_dif').":($cur_price):rep_dif:($reported_price_diff)";
				 _report_code($code,$reportstr);
				$$reported_price=$cur_price;
			}
			if(($cur_price+${$average})/2 != ${$average}){
				${$average}=(${$average}+$cur_price)/2;
			}
			$$fore_price=$cur_price;
			printf("\naverage:$$average");
			printf("\nfore_price:$$fore_price");
			printf("\nreported_price:$$reported_price");
		}else{
			#中午休市提示
			if( $hour >=11&& $hour <13&&!_is_exchange_info_loged($code,_construct_code_day_header($code,'AM'))){
				my $reportstr=_construct_code_day_header($code,'AM').":($cur_price)";
				 _report_code($code,$reportstr);
			}
			#下午休市提示
			if( $hour >=15&& !_is_exchange_info_loged($code,_construct_code_day_header($code,'PM'))){
				my $reportstr=_construct_code_day_header($code,'PM').":($cur_price)";
				 _report_code($code,$reportstr);
			}
		}
	}
}
sub _monitor_cus_stocks{
	my (@codes)=@_;
	my @opt=();
#init
	foreach my $code(@codes){
		my @info=[0,0,0,0];
		push @opt,@info;
	}
	while(1){
		my $i=0;
		foreach my $code(@codes){
			_monitor_cus_stock($code,$opt[$i++]);
		}
		sleep 10;
	}
}
sub main
{
    my $pause=0;
	#传引用
	COM_filter_param(\@ARGV);
	while(my $opt=shift @ARGV){
		#help infomation
		if ($opt =~ /-h/){			 
		print <<"END";
		-add <code> <call number>:add a customer stock 
		-lc[code [code ..]]:list customer stock(s)
		-remove <code> remove a customer stock 
		-mcs [code [code ..]]:monitor bought stock(s)
END
	}
		#monitor bought stock(s)
		if ($opt =~ /-mcs\b/){
			my $code;
			my @codes;
			my @tmpcodes;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
				push @tmpcodes , $code;
			}
			if(@tmpcodes){
				foreach $code(@tmpcodes){
					my @info=_get_cus_code_info($code,'code');
					if(@info){
						push @codes,$code;		
					}
				}
			}else{
				@codes=_get_all_cus_stocks();	
			}
			if(@codes){
				_monitor_cus_stocks(@codes);
			}
		}
		#remove customer stock
		if ($opt =~ /-remove\b/){
			my $code;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
					_delete_cus_stock_info($code);
					#删除log信息
					my $log=_get_code_monitor_info_file($code,'log');
					if($log){
						unlink($log);
					}
			}
		}
		#list customer stock
		if ($opt =~ /-lc\b/){
			my $code;
			my @codes;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
				push @codes,$code;	
			}
			if(!@codes){
				@codes=_get_all_cus_stocks();
			}
			foreach $code(@codes){
				my @info=_get_cus_code_info($code);
				if(@info){
					printf join(':',@info),"\n";
				}
			}
		}
		#customer stock
		if ($opt =~ /-add\b/){
			my $code;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
				_add($code,shift @ARGV);
			}
		}
	print "\nbye bye!\n";
	}
}

main;
