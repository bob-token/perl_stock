#!/usr/bin/perl -w
use strict;
use warnings;
use LWP;
use DBI;
require "perl_common.pl";
require "perl_stockcommon.pl";
require "perl_database.pl";
require "perl_database_tools.pl";
require "perl_stocknetwork.pl";
our $StockExDb="StockExchangeDb";
our $StockInfoDb="StockInfoDb";
our $BuyStockCode="buy_stock_code.txt";
our $StockCodeFile="stock_code.txt";
our $monitor_code="monitor_stock_code.txt";
#选择股票代码的技术指标开关
our $gflag_selectcode_macd=0;
our $gflag_selectcode_kdj=0;
our $gflag_selectcode_turnover=0;
our $g_fromcode;
$|=1;

# calculate moving average
sub _MA{
	my @v_days=shift;
	my $total=0;
	for my $tmp(@v_days){
		$total+=$tmp;
	}
	return $total/@v_days;
}
sub _DIFF{
	my $diff_s_day=shift;
	my $diff_l_day=shift;
	my $code=shift;
	my $dhe=shift;
	my $day_exchange_start=shift;
	my $diff_day=shift;
	my $ema_s=_EMA($code,$dhe,$day_exchange_start,$diff_day,$diff_s_day);
	my $ema_l=_EMA($code,$dhe,$day_exchange_start,$diff_day,$diff_l_day);
	my $diff=$ema_s-$ema_l;
	return $diff;
}
sub _DEA{
	my $diff_s_day=shift;
	my $diff_l_day=shift;
	my $code=shift;
	my $dhe=shift;
	my $day_exchange_start=shift;
	my $dea_day=shift;
	my $dea_day_cnt=shift;
    my $condition="DATE<=\"$dea_day\" ORDER BY DATE DESC LIMIT $dea_day_cnt";
	#获取需要计算diff的日期
	my @diff_days= DBT_get_earlier_exchange_days($dhe,$code,$dea_day,$dea_day_cnt);
#	my @diff_days=MSH_GetValue($dhe,$code,"DATE",$condition); 
	my $sum_diff;
	foreach my $diff_date(@diff_days){
		$sum_diff+=_DIFF($diff_s_day,$diff_l_day,$code,$dhe,$day_exchange_start,$diff_date);
	}
	my $dea=$sum_diff/@diff_days;
	return $dea;
}
#diff=ema(12)-ema(26)
#dea =ema(9)
#macd=diff-dea;
sub _MACD_DEALITTLETHAN{
	my $diff_s_day_cnt=shift;
	my $diff_l_day_cnt=shift;
	my $dea_day_cnt=shift;
	my $code=shift;
	my $dhe=shift;
	my $day_exchange_start=shift;
	my $ema_day=shift;
	my $max_dea=shift;
	my $diff=_DIFF($diff_s_day_cnt,$diff_l_day_cnt,$code,$dhe,$day_exchange_start,$ema_day);
	my $dea=_DEA($diff_s_day_cnt,$diff_l_day_cnt,$code,$dhe,$day_exchange_start,$ema_day,$dea_day_cnt);
	print "$code:Diff($diff_s_day_cnt,$diff_l_day_cnt):$diff,DEA($dea_day_cnt):$dea","\n";
	if($dea <= $max_dea){
		return $diff-$dea; 
	}
	return undef;
}
#diff=ema(12)-ema(26)
#dea =ema(9)
#macd=diff-dea;
sub _MACD_DIFFLITTLETHANZERO{
	my $diff_s_day_cnt=shift;
	my $diff_l_day_cnt=shift;
	my $dea_day_cnt=shift;
	my $code=shift;
	my $dhe=shift;
	my $day_exchange_start=shift;
	my $ema_day=shift;
	my $diff=_DIFF($diff_s_day_cnt,$diff_l_day_cnt,$code,$dhe,$day_exchange_start,$ema_day);
	my $dea=_DEA($diff_s_day_cnt,$diff_l_day_cnt,$code,$dhe,$day_exchange_start,$ema_day,$dea_day_cnt);
	print "$code:Diff($diff_s_day_cnt,$diff_l_day_cnt):$diff,DEA($dea_day_cnt):$dea","\n";
	if($diff < 0){
		return $diff-$dea; 
	}
	return undef;
}
#diff=ema(12)-ema(26)
#dea =ema(9)
#macd=diff-dea;
sub _MACD{
	my $diff_s_day_cnt=shift;
	my $diff_l_day_cnt=shift;
	my $dea_day_cnt=shift;
	my $code=shift;
	my $dhe=shift;
	my $day_exchange_start=shift;
	my $ema_day=shift;
	my $diff=_DIFF($diff_s_day_cnt,$diff_l_day_cnt,$code,$dhe,$day_exchange_start,$ema_day);
	my $dea=_DEA($diff_s_day_cnt,$diff_l_day_cnt,$code,$dhe,$day_exchange_start,$ema_day,$dea_day_cnt);
	print "$code:Diff($diff_s_day_cnt,$diff_l_day_cnt):$diff,DEA($dea_day_cnt):$dea","\n";
	return $diff-$dea; 
}
# calculate exponential moving average
#EMA=P今天*K+EMA昨天*(1-K)
#其中K=2/N+1
#N=EMA的天数(由交易者决定)
#EMA昨天=昨天的EMA
sub _EMA{
	my $code=shift;
	my $dhe=shift;
	my $day_exchange_start=shift;
	my $ema_day=shift;
	my $day_cnt=shift;
	my $v_K=2/($day_cnt+1);
	my @P;
#计算开始$date天的平均值
	my $first_ema;
	my $i=1;
	if($first_ema=DBT_get_closing_price($code,$day_exchange_start,$dhe)){
		$i=2;	
	}
	for(;$i<$day_cnt+1;$i++){
		my @day_price=DBT_get_next_date_closing_price($code,$day_exchange_start,$dhe);
		if(!@day_price ){
			return $first_ema/$i;	
		}
		$first_ema+=$day_price[1];
		$day_exchange_start=$day_price[0];
		if( COM_is_same_day($day_price[0],$ema_day)){
			return $first_ema/$i;
		}
	}		
	$first_ema = $first_ema/$day_cnt;
#计算后续的EMA
	while(@P=DBT_get_next_date_closing_price($code,$day_exchange_start,$dhe)){
		if(COM_is_earlier_than($P[0],$ema_day)){	
			$first_ema=$P[1]*$v_K+$first_ema*(1-$v_K);
			$day_exchange_start=$P[0];
			next;
		}
		if(COM_is_same_day($P[0],$ema_day)){
			return $P[1]*$v_K+$first_ema*(1-$v_K);
		}
		return $first_ema;
	}
	return undef;
}
#KDJ 先计算周期（n日，n周等）的RSV值（未成熟随机指标值，然后再计算K值，D值
#J值。以日KDJ数值为例，其计算公式为
#n日RSV=（C-Ln）/（Hn-Ln）×100
#第n日的收盘价，Ln为第n日内的最低收盘价，Hn为n日内最高收盘价。
#RSV值始终在1-100间波动
#其次，计算K值与D值
#当日K值=2/3×前一日K值+1/3×当日RSV
#当日D值=2/3×前一日D值+1/3当日K值
#若无前一日K值与D值则可分别用50代替
#J值=3×当日D值-2×当日K值
#以9日为周期的KD线为例，首先计算出最近9日的RSV值
#9日RSV=（C-L9）/（H9-L9）×100
#公式中C为第9日的收盘价，L9为9日内最低收盘价，H9为9日最高收盘价
#K值=2/3×第8日K值+1/3×第9日RSV
#D值=2/3×第8日D值+1/3×第9日K值
#J值=3×第9日K值-2×第9日D值
#
sub _J_OF_KDJ{
	my ($code,$date,$period,$dhe,$day_exchange_start)=@_;
	my $J=3*_K_OF_KDJ($code,$date,$period,$dhe,$day_exchange_start)-2*_D_OF_KDJ($code,$date,$period,$dhe,$day_exchange_start);
	return $J;
}
sub _D_OF_KDJ{
	my ($code,$date,$period,$dhe,$day_exchange_start)=@_;
	my $origin_exchange_start=$day_exchange_start;
	#第一天的值默认
	my $D=2/3*50+1/3*_K_OF_KDJ($code,$date,$period,$dhe,$day_exchange_start);
	if(COM_is_same_day($date,$day_exchange_start)){
			return $D;
	}
	#计算前面的值
	while(my $day=DBT_get_next_exchange_day($code,$day_exchange_start,$dhe)){
		$day_exchange_start=$day;	
		if(COM_is_earlier_than($day,$date)){	
			$D=2/3*$D+1/3*_K_OF_KDJ($code,$day,$period,$dhe,$origin_exchange_start);
			next;
		}
		if(COM_is_same_day($day,$date)){
			return 2/3*$D+1/3*_K_OF_KDJ($code,$day,$period,$dhe,$origin_exchange_start);
		}
		return $D;
	}
	return undef;
}
sub _K_OF_KDJ{
	my ($code,$date,$period,$dhe,$day_exchange_start)=@_;
	#第一天的k值默认
	my $K=2/3*50+1/3*_RSV_OF_KDJ($code,$date,$dhe,$period);
	if(COM_is_same_day($date,$day_exchange_start)){
			return $K;
	}
	
	#计算前面的k值
	while(my $day=DBT_get_next_exchange_day($code,$day_exchange_start,$dhe)){
		$day_exchange_start=$day;	
		if(COM_is_earlier_than($day,$date)){	
			$K=2/3*$K+1/3*_RSV_OF_KDJ($code,$day,$dhe,$period);
			next;
		}
		if(COM_is_same_day($day,$date)){
			return 2/3*$K+1/3*_RSV_OF_KDJ($code,$day,$dhe,$period);
		}
		return $K;
	}
	return undef;
}
sub _RSV_OF_KDJ{
	my ($code,$date,$dhe,$period)=@_;
	if(my @days=DBT_get_earlier_exchange_days($dhe,$code,$date,$period)){
		my $C=DBT_get_closing_price($code,$days[0],$dhe);
		#n日内的最低收盘价
		my $Ln=$C;
		#n日内的最高收盘价
		my $Hn=$C;
		foreach my $day(@days){
			my $t=DBT_get_closing_price($code,$day,$dhe);
			if($Ln>$t){
				$Ln=$t;
			}
			if($Hn<$t){
				$Hn=$t;
			}
		}
		if($Hn-$Ln==0){
			return 0;
		}
		return ($C-$Ln)/($Hn-$Ln)*100;
	}
	return undef;
}
sub _get_turnover{
    my $date=shift;
    my $code=shift;
    my $deh=shift;
    my $dih=shift;
    my $condition="DATE=\"$date\"";
    my @liutogu=MSH_GetValue($dih,$code,"LIUTONGGU");
    my @jiaoyigushu=MSH_GetValue($deh,$code,"JIAOYIGUSHU",$condition);
    if(defined $jiaoyigushu[0] and defined $liutogu[0]){
	return $jiaoyigushu[0]/$liutogu[0];	
    }
    return 0;
}
sub _turnover_get_codes{
	    my $datefrom=shift;
	    my $dateto=shift;
	    my $min=shift;
	    my $max=shift;
	    my $daymin=shift;
	    my $codemax=shift;
	    my $deh=MSH_OpenDB($StockExDb);
	    my $dih=MSH_OpenDB($StockInfoDb);
	    my $condition="DATE>=\"$datefrom\" && DATE<=\"$dateto\" ";
	    my @code =MSH_GetAllTablesName1($deh);
		my @codes;
	    foreach my $code(@code){
			my @date=MSH_GetValue($deh,$code,"DATE",$condition);
			my $total=0;
   			foreach my $date(@date){
		    	my $turnover=_get_turnover($date,$code,$deh,$dih);
		    	if($turnover >= $min && $turnover <= $max){
					if(++$total >= $daymin){
						push @codes,$code;
					}
		    	}		
			}	
	    }
	    $deh->disconnect;
	    $dih->disconnect;
	return @codes;
}
sub _select_codes{
	my $stockcodefile=shift;
	my $stock_cnt=shift;
	my @codes;
	my $code;
	my $start=1;
	my $dhe=MSH_OpenDB($StockExDb);
	open(IN,"<",$StockCodeFile);
	if(COM_get_fromcode()){
		$start=0;
	}
	while(<IN> ){
		$code=$_;
		chomp $code;
		if(!$start){
			next if(index(COM_get_fromcode(),$code)==-1);
			$start=1;
		}
		my $date="2052-12-31";
		my $data_start_day="2012-01-01";
		my @last_exchange_data_day=DBT_get_earlier_exchange_days($dhe,$code,$date,3);
		$date=$last_exchange_data_day[0];
		my $yesterday=$last_exchange_data_day[1];
		if($gflag_selectcode_macd){
			#my $macd=_MACD(12,26,9,$code,$dhe,"2011-01-01",$date);
			my $macd= _MACD_DEALITTLETHAN(12,26,9,$code,$dhe,$data_start_day,$date,-1.0);
			next if(!$macd);
			my $macd1=_MACD(12,26,9,$code,$dhe,$data_start_day,$last_exchange_data_day[1]);
			#next if($macd < 0.03 || $macd <$macd1 );
			next if($macd <$macd1 );
			my $macd2=_MACD(12,26,9,$code,$dhe,$data_start_day,$last_exchange_data_day[2]);
			next if($macd1<$macd2);
			print $code,":$date:MACD:$macd","\n";
			push @codes,join(":",$code,$date,"MACD",$macd);
		}
		if($gflag_selectcode_kdj){
			my $period=9;
			my @days=DBT_get_earlier_exchange_days($dhe,$code,$date,30);
			@days=reverse @days;
			#$date="2012-03-15";
			my $kdj_start_day=$days[0];
			my $K=_K_OF_KDJ($code,$date,$period,$dhe,$kdj_start_day);
			my $YK=_K_OF_KDJ($code,$yesterday,$period,$dhe,$kdj_start_day);
			my $D=_D_OF_KDJ($code,$date,$period,$dhe,$kdj_start_day);
			my $YD=_D_OF_KDJ($code,$yesterday,$period,$dhe,$kdj_start_day);
			my $J=_J_OF_KDJ($code,$date,$period,$dhe,$kdj_start_day);
			print join(":",$code,$date,"K:",$K,"D:",$D,"J:",$J),"\n";
			if($YK<= $YD and $K >= $D){
				print join(":",$code,$date,"YK:",$YK,"YD:",$YD,"J:",$J),"\n";
				push @codes,join(":",$code,$date,"K",$K,"D",$D,"J",$J);
			}
		}
		last if(@codes >= $stock_cnt);
	}
	$dhe->disconnect;
	close IN;
	return @codes;
}
sub _get_all_bought_stocks{
	my @codes;
#读取信息文件
	open IN,"<",$BuyStockCode;
	while(<IN>){
		my @codeinfo=split(':',$_);
		if(@codeinfo&&SCOM_is_valid_code($codeinfo[0])){
			push @codes,$codeinfo[0];
		}
	}
	close IN;	
	return @codes;
}
sub _get_buy_code_info{
	my ($code,$flag)=@_;
	my @info;
#读取信息文件
	open IN,"<",$BuyStockCode;
	while(<IN>){
		if(index($_,$code)==0){
			@info=split(':',$_);
		}
	}
	close IN;	
	if(@info){
		if(!$flag){
			return @info;
		}
		if($flag =~/\bcode\b/){
			return $info[0];	
		}elsif($flag =~/\bprice\b/){
			return $info[1];
		}elsif($flag =~/\btotal\b/){
			return $info[2];
		}elsif($flag =~/\bstoploss\b/){
			return $info[3];
		}elsif($flag =~/\bimportantprice\b/){
			return $info[4];
		}
	}
	return undef;
}
sub _delete_buy_code{
	my $code=shift;
	my @buycodes;
#读取信息文件
	if(open IN,"<",$BuyStockCode){
		while(<IN>){
			if(index($_,$code)!=0){
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
sub _add_buy_code_info{
	my (@codeinfo)=@_;
	my $order=join(':',@codeinfo);
#保存到文件
	open OUT,">>",$BuyStockCode;
	syswrite(OUT,$order);
	syswrite(OUT,"\n");
	close OUT;	
	return 1;
}
sub _add_buy_code{
	my ($code,$price,$total,$stoploss)=@_;
	my $order=$code.':'.$price.':'.$total.':'.$stoploss;
#保存到文件
	open OUT,">>",$BuyStockCode;
	syswrite(OUT,$order);
	syswrite(OUT,"\n");
	close OUT;	
	return 1;
}
sub _buy{
	my ($code,$price,$total,$stoploss,$importantprice)=@_;
	if(!$importantprice){
		$importantprice=$price*1.05;#将止损点设在98%
	}
	if(!defined $stoploss){
		$stoploss=$price*0.98;#将止损点设在98%
	}
	_delete_buy_code($code);
	my @codeinfo;
	push @codeinfo,$code;
	push @codeinfo,$price;
	push @codeinfo,$total;
	push @codeinfo,$stoploss;
	push @codeinfo,$importantprice;
	_AMI($code);
	return _add_buy_code_info(@codeinfo);
}
sub _log{
	my ($logfile,$msg)=@_;
	open OUT,">>",$logfile;
	syswrite(OUT,"\n");
	syswrite(OUT,$msg);
	close OUT; 
}
sub _report{
	my $msg=shift;
	printf $msg."\n";	
	system("/usr/local/bin/cliofetion -f 13590216192 -p15989589076xhb -d\"$msg\"");
	_log(COM_today(1),$msg);
}
sub _construct_header{
	my ($code,$type)=@_;
	if(SCOM_is_valid_code($code)){
		return "$code:$type";
	}
	return undef;
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
sub _monitor_bought_stock{
	my ($code)=@_;
	my $cur_price=SN_get_stock_cur_price($code);
	if($code){
		my $buyprice= _get_buy_code_info($code,'price');
		my $stoploss = _get_buy_code_info($code,'stoploss');
		my $total = _get_buy_code_info($code,'total');
		my $importantprice= _get_buy_code_info($code,'importantprice');
		my $hour=COM_get_cur_time('hour');
		my $minute=COM_get_cur_time('minute');
		my $income= SCOM_calc_income($code,$buyprice,$cur_price,$total);
		chomp $stoploss;
		#交易期间检测
		if (SCOM_is_exchange_duration($hour,$minute)){
			if($stoploss>=$cur_price && !_is_today_loged(_construct_header($code,'stoploss'))){
				my $reportstr=_construct_header($code,'stoploss').":($buyprice:$cur_price:$income):stoploss:($stoploss)";
				_report($reportstr);
			}
			if($importantprice <=$cur_price&& !_is_today_loged(_construct_header($code,'importantprice'))){
				my $reportstr=_construct_header($code,'importantprice').":($buyprice:$cur_price:$income):importantprice:($importantprice)";
				_report($reportstr);
			}
		}else{
			#中午休市提示
			if( $hour>= 11&& !_is_today_loged(_construct_header($code,'AM'))){
				my $reportstr=_construct_header($code,'AM').":($buyprice:$cur_price:$income)";
				_report($reportstr);
			}
			#下午休市提示
			if($hour>=15&& !_is_today_loged(_construct_header($code,'PM'))){
				my $reportstr=_construct_header($code,'PM').":($buyprice:$cur_price:$income)";
				_report($reportstr);
			}
		}
	}
}
sub _monitor_bought_stocks{
	my (@codes)=@_;
	while(1){
		foreach my $code(@codes){
			my @info=_get_buy_code_info($code);
			_monitor_bought_stock($info[0]);
		}
		sleep 60;
	}
}
sub _DMI{
	my @codea;
	my @oldcodea;
	my @newcodea;
	open(IN,$monitor_code);
	foreach my $tmp(<IN>){
		chomp $tmp;
		next if(!SCOM_is_valid_code($tmp));
		push @oldcodea,$tmp;         
	}
	close IN;
	while(my $code=shift @_){
		chomp $code;
		next if(!SCOM_is_valid_code($code));
		push @codea,$code;
	}
	my $codea =join(' ',@codea);
	open(OUT,'>',$monitor_code); 
	foreach my $tmp(@oldcodea){
		chomp $tmp;
		if(index($codea,$tmp)==-1){
			print OUT "\n";
			print OUT $tmp;
			print OUT @newcodea;
		}
	}
	close OUT;
}
sub _AMI{
	my @codea;
	while(my $code=shift @_ ){
		next if(!SCOM_is_valid_code($code));
		push @codea,$code;
	}
	if(@codea>0){
		open(OUT,'>>',$monitor_code);
		foreach my $tmp(@codea){
			chomp $tmp;
			syswrite(OUT,"\n");
			syswrite(OUT,$tmp);
		}
		close OUT;
	}
}
sub main{
    my $pause=0;
	#传引用
	COM_filter_param(\@ARGV);
	while(my $opt=shift @ARGV){
		#help infomation
		if ($opt =~ /-h/){			 
		print <<"END";
		-p(windows system only):pause before exit
        -scp[ code[ code[ ...]]]: show current stock exchange price -dmi[ code[ code[ ...]]]: delete monitor stock from file
        -ami[ code[ code[ ...]]]: add monitor stock ,save to file
        -mcp[ code[ code[ ...]]]: monitor stock;if omit code ,read in file
		-ema code exchange_start_day calculated_ema_day ema_delta_day eg:-ema sz002432 2012-01-01 2012-03-06 10
		-macd code exchange_start_day calculated_macd_day eg:-macd sz002432 2012-01-01 2012-03-06 
		-tor datefrom dateto turnover_min turnover_max daytotal shownum:show match condition of turnover rate stock codes
		-select [macd][kdj][turnover]:select stock by some flag
		-ufc <code> :from code
		-buy <code> <price> <total> <stop loss order>:buy a stock 
		-lb[code [code ..]]:list bought stock(s)
		-sell <code> sell a stock 
		-mbs [code [code ..]]:monitor bought stock(s)
END
	}
		#help info
		if ($opt =~ /-p\b/){
           $pause=1;
        }
		#monitor bought stock(s)
		if ($opt =~ /-mbs\b/){
			my $code;
			my @codes;
			my @tmpcodes;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
				push @tmpcodes , $code;
			}
			if(@tmpcodes){
				foreach $code(@tmpcodes){
					my @info=_get_buy_code_info($code);
					if(@info){
						push @codes,$code;		
					}
				}
			}else{
				@codes=_get_all_bought_stocks();	
			}
			if(@codes){
				_monitor_bought_stocks(@codes);
			}
		}
		#sell stock
		if ($opt =~ /-sell\b/){
			my $code;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
					_DMI($code);
					_delete_buy_code($code);
			}
		}
		#list buy stock
		if ($opt =~ /-lb\b/){
			my $code;
			my @codes;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
				push @codes,$code;	
			}
			if(!@codes){
				@codes=_get_all_bought_stocks();
			}
			foreach $code(@codes){
				my @info=_get_buy_code_info($code);
				if(@info){
					printf join(':',@info),"\n";
				}
			}
		}
		#buy stock
		if ($opt =~ /-buy\b/){
			my $code;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
				_buy($code,shift @ARGV,shift @ARGV,shift @ARGV);
			}
		}
		#select codes for exchange
		if ($opt =~ /-select/){
			my $tmp;
			while($tmp=shift @ARGV){
				if($tmp =~ /macd/){
					$gflag_selectcode_macd=1;
					next;
				}
				if($tmp =~ /kdj/){
					$gflag_selectcode_kdj=1;
					next;
				}
				if($tmp =~ /turnover/){
					$gflag_selectcode_turnover=1;
					next;
				}
				unshift @ARGV,$tmp;
				last;
			}
			my $total=20;
			my @codes=_select_codes($StockCodeFile,$total);
			print join("\n",@codes);
		}
        #turnover rate
        if($opt =~ /-tor/){
	        my $datefrom=shift @ARGV;
   		    my $dateto=shift @ARGV;
       		my $min=shift @ARGV;
        	my $max=shift @ARGV;
        	my $daytotal=shift @ARGV;
        	my $num=shift @ARGV;
       		my @codes = _turnover_get_codes($datefrom,$dateto,$min,$max,$daytotal,$num);
			print split("\n",@codes); 
         }
		 if($opt =~ /-macd/){
		 	my $code=shift @ARGV ;
		    my $dhe=MSH_OpenDB($StockExDb);
			my $day_exchange_start=shift @ARGV;
			my $macd_day=shift @ARGV;
		 	my $macd=_MACD(12,26,9,$code,$dhe,$day_exchange_start,$macd_day);	
			print $code," macd:",$macd,"\n";
		 }
		 if($opt =~ /-ema/){
		 	my $code=shift @ARGV ;
		    my $dhe=MSH_OpenDB($StockExDb);
			my $day_exchange_start=shift @ARGV;
			my $ema_day=shift @ARGV;
			my $day_cnt=shift @ARGV;
		 	my $ema=_EMA($code,$dhe,$day_exchange_start,$ema_day,$day_cnt);	
			print $code,$ema_day,$ema,"\n";
		 }
		 if($opt =~ /-cdtor/){
		    my $code=shift @ARGV;
            my $date=shift @ARGV;
		    my $deh=MSH_OpenDB($StockExDb);
		    my $dih=MSH_OpenDB($StockInfoDb);
		    print _get_turnover($date,$code,$deh,$dih);
		    $deh->disconnect;
		    $dih->disconnect;
        }
		#show current stock exchange price
		if($opt =~ /-scp/){
			my $code;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
				my @info =SN_get_stock_cur_exchange_info($code);
					my $percent =($info[3]-$info[2])*100/$info[2];
					my $str=sprintf("%s,%s,%.2f,%.2f\n",$code,$info[0],$info[3],$percent);
					print $str;
			}
			if(defined $code){
				unshift(@ARGV,$code);
			}
		};
		if($opt =~ /-dmi/){
			my $code;
			while($code=shift @ARGV){
				if(SCOM_is_valid_code($code)){
					_DMI($code);
				}
			}
			if($code){
				push @ARGV,$code;
			}
        }
	   if($opt =~ /-ami/){
			my $code;
			while($code=shift @ARGV){
				if(SCOM_is_valid_code($code)){
					_AMI($code);
				}
			}
			if($code){
				push @ARGV,$code;
			}
		}
		if($opt =~ /-mcp/){
			my $code;
            my @codes;
			while($code=shift @ARGV and SCOM_is_valid_code($code) ){
            	push @codes,$code;
			}
            if(!@codes){
            	open(IN,$monitor_code);
                foreach my $tmp(<IN>){
					chomp $tmp;
					if(SCOM_is_valid_code($tmp)){
						push @codes,$tmp;         
					}
                }
                close IN;
            }
            foreach $code(@codes){
					my @info =SN_get_stock_cur_exchange_info($code);
					my $percent =($info[3]-$info[2])*100/$info[2];
					if($info[3]==0) {
						$percent=0;
					}
					my $str=sprintf("%s,%s,%.2f,%.2f\n",$code,$info[0],$info[3],$percent);
					print $str;                            
			}

			if(defined $code){
				unshift(@ARGV,$code);
			}
		}
	}
	if($pause){
		system("pause");
	}   
	print "\nbye bye!\n";
}

main;
