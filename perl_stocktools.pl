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
our $StockProfitDb="StockProfitDb";
our $StockInfoDb="StockInfoDb";
our $BuyStockCode="buy_stock_code.txt";
our $StockCodeFile="stock_code.txt";
our $monitor_code="monitor_stock_code.txt";
our $gall_monitor_info={};
our $code_property_separator='@';
our $code_property_assignment=':';
#选择股票代码的技术指标开关
our $g_selectcode_date;
our $g_selectcode_mode;
our $gflag_selectcode_mode=0;#模式
our $gflag_selectcode_level=0;#级别(越低越严格)
our $gflag_selectcode_dig=0;#挖坑
our $gflag_selectcode_macd=0;#macd指数
our $gflag_selectcode_kdj=0;#kdj指数
our $gflag_selectcode_break_surge=0;#突破平台振荡
our $gflag_selectcode_turnover=0;#换手率
$|=1;

# calculate volume moving average
sub _MA_volume{
	my ($code,$dhe,$date,$day_count)=@_;
	my $total=0;
	my @days;
	if(@days=DBT_get_earlier_exchange_days($dhe,$code,$date,$day_count)){
		foreach my $day(@days){
			$total+=DBT_get_volume($code,$dhe,$day);
		}
	}
	return $total/@days;
}
# calculate moving average
sub _MA{
	my ($code,$dhe,$date,$day_count)=@_;
	my $total=0;
	my @days;
	if(@days=DBT_get_earlier_exchange_days($dhe,$code,$date,$day_count)){
		foreach my $day(@days){
			$total+=DBT_get_closing_price($code,$day,$dhe);
		}
	}
	return $total/@days;
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
sub _get_surge_days{
	my ($dhe,$code,$date)=@_;
	my $day_count=30;
	my $surge_min_day = 3;
	my $foreday = DBT_get_fore_exchange_day($code,$date,$dhe);
	my @durationdays= DBT_get_earlier_exchange_days($dhe,$code,$foreday,$day_count);
	my @days;
	if (@durationdays){
		foreach my $one(@durationdays){
			my $rise = DBT_get_days_rise($code,$dhe,$one,$date);
			if(abs($rise)>0.2){
				last;
			}
			push @days,$one;
		}
		if(scalar(@days)<$surge_min_day){
			return undef;
		}
		return @days;
	}
	return undef;
}
sub _is_break_surge{
	my ($dhe,$code,$date)=@_;
	my @days= DBT_get_earlier_exchange_days($dhe,$code,$date,2);
	my $rise = DBT_get_rise($code,$dhe,$days[0]);
	@days = _get_surge_days($dhe,$code,$days[1]);
	if($rise > 0.05  && $days[0]){
		my $max_closing_price = DBT_get_max_closing_price($code,$dhe,$days[$#days],$days[0]);
		my $closing_price = DBT_get_closing_price($code,$days[0],$dhe);
		if ($closing_price && ($closing_price - $max_closing_price)/$closing_price > 0.05){
			return 1;
		}
	}
	return 0;
}
sub _is_diging{
	my ($dhe,$code,$date)=@_;
	my @days= DBT_get_earlier_exchange_days($dhe,$code,$date,2);
	if(@days){
		my $rise = DBT_get_rise($code,$dhe,$days[1]); 
		if($rise < -0.04 && $rise > -0.09){
			return 1;
		}
	}
	return 0;
}
#拐点日期
sub _get_inflection_date
{
	my ($dhe,$code,$date)=@_;
}
#在一定时间里股价持续上升 
sub _is_mode1
{
	my ($dhe,$code,$date,$level)=@_;
	my @days= DBT_get_earlier_exchange_days($dhe,$code,$date,20);
	if (@days){
		my $last = $days[0];
		my $start = 0;
		my @tdays;
		my $mindays = 3;
		if ($level > 0){
			$mindays = 2;
		}
		foreach my $day(@days){
			my $rise = DBT_get_days_rise($code,$dhe,$last,$day);
			my $dayrise = DBT_get_rise($code,$dhe,$day);
			my $max = DBT_get_max_price($code,$day,$dhe);
			my $min = DBT_get_min_price($code,$day,$dhe);
			if ($max == $min && $dayrise < 0.03){
				$start =1;
				push @tdays,$day;
				next;
			}
			if($start ){
				if( scalar(@tdays)< $mindays){
					return 0;	
				}
				return 1;
			}else{
				if($rise > 0.1){
					return 0;
				}
			}
		}
	}

	return 0;
}
sub _is_mode2
{
	my ($dhe,$code,$date,$level)=@_;
	my @days= DBT_get_earlier_exchange_days($dhe,$code,$date,2);
	if (not $level){
		$level = 0;
	}
	if(@days){
		my $maxrise=0.05;
		my $durationrise = 0;
		my $day_count=12;
		my @durationdays= DBT_get_earlier_exchange_days($dhe,$code,$days[0],$day_count);
		my @daysbigvol;
		my @dayslittlevol;
		my @daysbig;
		my @dayslittle;
		my @daysother;
		my @daysup;
		my @daysdown;
		my $maxVol = 50000*100;
		my $minDurationRise = 0.06;
		my $lastupdays=4;
		my @lastupdays;
		my $lastupdaysmin=0.6;
		my $tmp = $lastupdays;
		foreach my $one(@durationdays){
			my $volume= DBT_get_volume($code,$dhe,$one); 
			my $rise = DBT_get_rise($code,$dhe,$one);
			if ($tmp> 0){
				if ($rise > 0){
					push @lastupdays,$rise;
				}
				$tmp--;
			}
			if ($rise > 0){
				push @daysup,$rise;
			}else{
				push @daysdown,$rise;
			}
			if (abs($rise) < 0.03){
				push @dayslittle,$rise;
			}elsif (abs($rise < 0.055)){
				push @daysbig,$rise;
			}else{
				push @daysother,$rise;
			}
			if ($volume >  $maxVol){
				push @daysbigvol,$volume;
			}else{
				push @dayslittlevol,$volume;
			}
		}
		if(($#daysup+1) < 3 * ($#daysdown+1)){
			return 0;
		}
		if (@durationdays && scalar(@durationdays) > 1){
			$durationrise = DBT_get_days_rise($code,$dhe,$durationdays[$#durationdays],$durationdays[0]); 
		}
		if ($level <=0){
			if (scalar(@daysbig) > $day_count/4 ){
				return 0;	
			}
			if (scalar(@daysother) < 1){
				return 0;
			}
			if (scalar(@daysbigvol) > $day_count/7){
				return 0;
			}
		}
		if ($level <= 1){
			if(abs($durationrise) < $minDurationRise){
				return 0;
			}
			if ( scalar(@daysother) >= $day_count/6 ){
				return 0;	
			}
			if (scalar(@lastupdays) < $lastupdays * $lastupdaysmin){
				return;
			}
		}
		return 1;
	}
	return 0;
}
sub _is_mode3
{
	my ($dhe,$code,$date,$level)=@_;
	my $dayscount = 5;
	my @days= DBT_get_earlier_exchange_days($dhe,$code,$date,$dayscount+1);
	if (@days){
		my $last = $days[0];
		my $foredayrise = DBT_get_rise($code,$dhe,$days[$#days]);
		if ($level < 1){
			if($foredayrise > 0){
				return 0;
			}
		}
		foreach my $day(@days){
			my $dayrise = DBT_get_rise($code,$dhe,$day);
			my $rise = DBT_get_days_rise($code,$dhe,$day,$last);
			if ($dayrise < 0){
				return 0;
			}
			if ($rise < 0){
				return 0;
			}
		}
		return 1;
	}
	return 0;
}
#底部放量
sub _is_mode4
{
	my ($dhe,$code,$date,$level)=@_;
	#底部判断
	my $dayscount = 20;
	my $dayupcount = $dayscount/10;
	my $tmp = $dayupcount;
	my @days= DBT_get_earlier_exchange_days($dhe,$code,$date,$dayscount+1);
	if (@days){
		my @tmp;
		foreach my $day(@days){
			my $volume = DBT_get_volume($code,$dhe,$day);
			push @tmp,$volume;	
		}
		my $last = $tmp[0];
		my $last1 = $tmp[1];
		my $lastday=$days[0];
		my $lastrise = DBT_get_rise($code,$dhe,$lastday);
		if ($lastrise < 0.03 || $lastrise > 0.08){
			return 0;
		}
		foreach my $tmp(@tmp){
			if ($last >	$tmp*10 && $last1 > $tmp*6){
				return 1;
			}
		}
	}
	return 0;	
}
sub _is_MA_UP{
	my ($dhe,$code,$last_day,$MA_day_count,$duration)=@_;
	if(my @days  = DBT_get_earlier_exchange_days($dhe,$code,$last_day,$duration)){
		my $max_val=10000000;
		foreach my $day(@days){
			my $tmp = _MA($code,$dhe,$day,$MA_day_count);	
			if($tmp > $max_val){
				return 0;
			}
			$max_val = $tmp;
		}
		return 1;
	}
	return 0;
}
sub _is_MA_volume_cross{
	my ($dhe,$code,$last_day,$min_MA_day_count,$max_MA_day_count,$duration)=@_;
	if(my @days  = DBT_get_earlier_exchange_days($dhe,$code,$last_day,$duration)){
		my $last_exchange_day = $days[0];
		my $first_exchange_day = $days[$#days];
		my $last_min_MA = _MA_volume($code,$dhe,$last_exchange_day,$min_MA_day_count);
		my $last_max_MA = _MA_volume($code,$dhe,$last_exchange_day,$max_MA_day_count);
		my $first_min_MA = _MA_volume($code,$dhe,$first_exchange_day,$min_MA_day_count);
		my $first_max_MA = _MA_volume($code,$dhe,$first_exchange_day,$max_MA_day_count);
		if($last_min_MA >= $last_max_MA && $first_min_MA <= $first_max_MA){
			return 1;
		}
		if($last_min_MA <= $last_max_MA && $first_min_MA >= $first_max_MA){
			return 1;
		}
	}
	return 0;
}
sub _is_MA_cross{
	my ($dhe,$code,$last_day,$min_MA_day_count,$max_MA_day_count,$duration)=@_;
	if(my @days  = DBT_get_earlier_exchange_days($dhe,$code,$last_day,$duration)){
		my $last_exchange_day = $days[0];
		my $first_exchange_day = $days[$#days];
		my $last_min_MA = _MA($code,$dhe,$last_exchange_day,$min_MA_day_count);
		my $last_max_MA = _MA($code,$dhe,$last_exchange_day,$max_MA_day_count);
		my $first_min_MA = _MA($code,$dhe,$first_exchange_day,$min_MA_day_count);
		my $first_max_MA = _MA($code,$dhe,$first_exchange_day,$max_MA_day_count);
		if($last_min_MA >= $last_max_MA && $first_min_MA <= $first_max_MA){
			return 1;
		}
		if($last_min_MA <= $last_max_MA && $first_min_MA >= $first_max_MA){
			return 1;
		}
	}
	return 0;
}
sub _day_J_OF_KDJ{
	my ($code,$dhe,$date,$KDJ_duration)=@_;
	my @tmp_day = DBT_get_earlier_exchange_days($dhe,$code,$date,$KDJ_duration);
	my $kdj_start_day = $tmp_day[$#tmp_day];
	my $period=9;
	return _J_OF_KDJ($code,$date,$period,$dhe,$kdj_start_day);

}
sub _day_D_OF_KDJ{
	my ($code,$dhe,$date,$KDJ_duration)=@_;
	my @tmp_day = DBT_get_earlier_exchange_days($dhe,$code,$date,$KDJ_duration);
	my $kdj_start_day = $tmp_day[$#tmp_day];
	my $period=9;
	return _D_OF_KDJ($code,$date,$period,$dhe,$kdj_start_day);

}
sub _day_K_OF_KDJ{
	my ($code,$dhe,$date,$KDJ_duration)=@_;
	my @tmp_day = DBT_get_earlier_exchange_days($dhe,$code,$date,$KDJ_duration);
	my $kdj_start_day = $tmp_day[$#tmp_day];
	my $period=9;
	return _K_OF_KDJ($code,$date,$period,$dhe,$kdj_start_day);

}
sub _is_valid_KDJ_cross{
	my ($code,$dhe,$date,$duration)=@_;
	my $KDJ_duration = 30;
	my @tmp_day = DBT_get_earlier_exchange_days($dhe,$code,$date,$duration);
	if(@tmp_day){
		my $start_day = $tmp_day[$#tmp_day];
		my $D_start = _day_D_OF_KDJ($code,$dhe,$start_day,$KDJ_duration);
		my $D_last = _day_D_OF_KDJ($code,$dhe,$date,$KDJ_duration);
		#确定J线是否与D线交叉
		my $J_start = _day_J_OF_KDJ($code,$dhe,$start_day,$KDJ_duration);
		my $J_last = _day_J_OF_KDJ($code,$dhe,$date,$KDJ_duration);
		if($J_last <= $D_last || $J_start > $D_start){
			return 0;
		}

		#确定K线是否与D线交叉
		my $K_start = _day_K_OF_KDJ($code,$dhe,$start_day,$KDJ_duration);
		my $K_last = _day_K_OF_KDJ($code,$dhe,$date,$KDJ_duration);
		if($K_last <= $D_last || $K_start > $D_start){
			return 0;
		}
		return 1;
	}
	return 0;
}
#金叉
sub _is_mode5
{
	my ($dhe,$code,$date,$level)=@_;
	my $min_day_count=5;
	my $max_day_count=10;
	my $duration=5;
	my @date = DBT_get_earlier_exchange_days($dhe,$code,$date,1);
	if(!@date){
		return 0;
	}
	$date = $date[0];
	#检测是平均值否一直在上升状态
	if(!_is_MA_UP($dhe,$code,$date,$min_day_count,$duration)){
		return 0;
	}
	if(!_is_MA_UP($dhe,$code,$date,$max_day_count,$duration)){
		return 0;
	}
	#检测小均值是否大于大均值
	my $tmp_min = _MA($code,$dhe,$date,$min_day_count);	
	my $tmp_max = _MA($code,$dhe,$date,$max_day_count);	
	if($tmp_max >= $tmp_min){
		return 0;
	}
	#检测平均值是否有交叉
	if(!_is_MA_cross($dhe,$code,$date,$min_day_count,$max_day_count,$duration)){
		return 0;
	}
	#检测是否KDJ有效交叉 
	if(!_is_valid_KDJ_cross($code,$dhe,$date,$duration+5)){
		return 0;
	}
	#检测交易量是否有交叉
	if(!_is_MA_volume_cross($dhe,$code,$date,$min_day_count,$max_day_count,$duration)){
		return 0;
	}
	return 1;
}
sub _select_codes
{
	my $stockcodefile=shift;
	my $stock_cnt=shift;
	my @codes;
	my $code;
	my $dhe=MSH_OpenDB($StockExDb);
	my $dhi=MSH_OpenDB($StockInfoDb);
	#流通市值限制
	my $circulation_value_limit=1;
	my $codeiterator;
	SCOM_start_code_iterate(\$codeiterator,COM_get_fromcode());
while($code = SCOM_iterator_get_code(\$codeiterator)){
my $code_info=();
chomp $code;
my $date="2052-12-31";
my $data_start_day="2012-01-01";
if (defined $g_selectcode_date){
	$date = $g_selectcode_date;
}
my @last_exchange_data_day=DBT_get_earlier_exchange_days($dhe,$code,$date,3);
$date=$last_exchange_data_day[0];
if(not $date){
	print ("skip $code ,date is not suitable!","\r\n");
	next;
}
my $yesterday=$last_exchange_data_day[1];
my $last_exchange_day = DBT_get_last_exchange_day($dhe,$code);
next if(!$last_exchange_day);
$code_info=join(':',$code,$date);
if($circulation_value_limit){
	#对流通市值做限制
	my $cur_price=DBT_get_closing_price($code,$last_exchange_day,$dhe);
	my $liutongshizhi=$cur_price*DBT_get_exchange_stockts($code,$dhi);
	my $billion=1000000000 ;
	my $million=1000000 ;
	if($liutongshizhi>18*$billion or $liutongshizhi <40*$million){
		my $mb=sprintf("%.3f",$liutongshizhi/$billion);
		print ("Skip $code:market value : $mb billion\n");
		next;
	}
}
if($gflag_selectcode_macd){
	#my $macd=_MACD(12,26,9,$code,$dhe,"2011-01-01",$date);
	my $macd= _MACD_DEALITTLETHAN(12,26,9,$code,$dhe,$data_start_day,$date,1);
	next if(!$macd);
	my $macd1=_MACD(12,26,9,$code,$dhe,$data_start_day,$last_exchange_data_day[1]);
	#next if($macd < 0.03 || $macd <$macd1 );
	next if($macd <$macd1 );
	my $macd2=_MACD(12,26,9,$code,$dhe,$data_start_day,$last_exchange_data_day[2]);
	next if($macd1<$macd2);
	COM_log($code,":$date:MACD:$macd","\n");
	#push @codes,join(":",$code,$date,"MACD",$macd);
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
	if($YK - $YD < $K - $D){
		print join(":",$code,$date,"YK:",$YK,"YD:",$YD,"J:",$J),"\n";
		$code_info=join(":",$code_info,"K",$K,"D",$D,"J",$J);
	}else{
		next;
	}
}
if($gflag_selectcode_dig){
	if(!_is_diging($dhe,$code,$date)){
		next;
	}
}
if($gflag_selectcode_break_surge){
	if(!_is_break_surge($dhe,$code,$date)){
		next;
	}
}
if($gflag_selectcode_mode){
	if($g_selectcode_mode == 1 && !_is_mode1($dhe,$code,$date,$gflag_selectcode_level)){
		next;
	}elsif ($g_selectcode_mode == 2 && !_is_mode2($dhe,$code,$date,$gflag_selectcode_level)){
		next;	
	}elsif ($g_selectcode_mode == 3 && !_is_mode3($dhe,$code,$date,$gflag_selectcode_level)){
		next;	
	}elsif ($g_selectcode_mode == 4 && !_is_mode4($dhe,$code,$date,$gflag_selectcode_level)){
		next;	
	}elsif ($g_selectcode_mode == 5 && !_is_mode5($dhe,$code,$date,$gflag_selectcode_level)){
		next;	
	}
}
push @codes,$code_info;
last if(@codes >= $stock_cnt);
	}
	$dhe->disconnect;
	$dhi->disconnect;
	return @codes;
}
sub _get_all_bought_stocks{
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
sub _delete_buy_code{
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
sub _add_buy_code_info{
	my (@codeinfo)=@_;
	my $order=join($code_property_separator,@codeinfo);
#保存到文件
	open OUT,">>",$BuyStockCode;
	syswrite(OUT,"\n");
	syswrite(OUT,$order);
	close OUT;	
	return 1;
}
sub _get_buy_code_info{
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
sub _buy{
	my ($code,$price,$total,$stoploss,$importantprice)=@_;
	if(!$importantprice){
		$importantprice=$price*1.05;
	}
	if(!defined $stoploss){
		$stoploss=$price*0.98;#将止损点设在98%
	}
	_delete_buy_code($code);
	my @codeinfo;
	#push @codeinfo,$code;
	_add_property(\@codeinfo,'code',$code);
#push @codeinfo,$price;
_add_property(\@codeinfo,'price',$price);
	#push @codeinfo,$total;
	_add_property(\@codeinfo,'total',$total);
#push @codeinfo,$stoploss;
_add_property(\@codeinfo,'stoploss',$stoploss);
	#push @codeinfo,$importantprice;
	_add_property(\@codeinfo,'importantprice',$importantprice);
_AMI($code);
return _add_buy_code_info(@codeinfo);
}
sub _get_code_monitor_info_file{
	my ($code,$flag)=@_;
	return SCOM_code_get_file_name($code,$flag);
}
sub _log{
	my ($logfile,$msg)=@_;
	open OUT,">>",$logfile;
	syswrite(OUT,"\n");
	syswrite(OUT,$msg);
	close OUT; 
}
sub _sms{
	my ($flag0,$flag1,$flag2,$flag3)=@_;
	#cliofetion
	#if($flag3){
	#	system("cliofetion -f $flag0 -p $flag1 -t $flag2 -d \"$flag3\"");
	#}else{
	#	system("cliofetion -f $flag0 -p $flag1  -d \"$flag2\"");
	#}
	#python
	if($flag3){
		system("python2 pywapfetion/bobfetion.py $flag0 $flag1 $flag2 \"$flag3\"");
	}else{
		system("python2 pywapfetion/bobfetion.py $flag0 $flag1 \"$flag2\"");
	}
}
sub _report_code{
	my ($code,$msg)=@_;
	printf $msg."\n";	
	my $flag0=COM_get_flag(0,"flag");
	my $flag1=COM_get_flag(1,"flag");
	my $flag2=COM_get_flag(2,"flag");
	_sms($flag0,$flag1,$msg);
	#_sms($flag0,$flag1,'13823510132',$msg);
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
sub _monitor_bought_stock{
	my ($code,$ref_monitor_info)=@_;
	if($code){
		if (!SCOM_today_is_exchange_day()){
			return;
		}
		my $tip_percent_average_diff=0.005;
		my $tip_percent_reported_diff=0.005;
		my $tip_percent_fore_diff=0.007;
		my $cur_price=SN_get_stock_cur_price($code);
		my $buyprice= _get_buy_code_info($code,'price');
		my $stoploss = _get_buy_code_info($code,'stoploss');
		my $total = _get_buy_code_info($code,'total');
		my $importantprice= _get_buy_code_info($code,'importantprice');
		my $percent=($importantprice-$buyprice)/$buyprice;
		my $K=int((($cur_price-$buyprice)/$buyprice)/$percent);
		my $hour=COM_get_cur_time('hour');
		my $minute=COM_get_cur_time('minute');
		my $income= SCOM_calc_income($code,$buyprice,$cur_price,$total);
		my $average=\$ref_monitor_info->{average_price};
	my $fore_price=\$ref_monitor_info->{fore_price};
my $reported_price=\$ref_monitor_info->{reported_price};
		$income=sprintf("%.2f",$income);
		chomp $stoploss;
		#交易期间检测
		if (SCOM_is_exchange_duration($hour,$minute)){
			#为了减少SCOM_is_suspension函数的联网先判断$cur_price是否为0
			if($cur_price==0){
				if( SCOM_is_suspension($code)){
					my $last_close_price=SN_get_stock_last_close_price($code);
					$income= SCOM_calc_income($code,$buyprice,$last_close_price,$total);
					$income=sprintf("%.2f",$income);
					if( !_is_exchange_info_loged($code,_construct_code_day_header($code,'suspension'))){
						my $reportstr=_construct_code_day_header($code,'suspension').":($buyprice:$last_close_price:$income)";
						_report_code($code,$reportstr);
						$$reported_price=$cur_price;
					}
				}
				return;
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
				my $reportstr=_construct_code_header($code,'ave_dif').":($buyprice:$cur_price:$income):ave_dif:($average_diff))";
				_report_code($code,$reportstr);
				$$reported_price=$cur_price;
			}
			my $fore_diff=($cur_price-${$fore_price})/$$fore_price;
			if(abs($fore_diff)>=$tip_percent_fore_diff){
				$fore_diff=sprintf("%.4f",$fore_diff);
				my $reportstr=_construct_code_header($code,'f_dif').":($buyprice:$cur_price:$income):f_dif:($fore_diff))";
				_report_code($code,$reportstr);
				$$reported_price=$cur_price;
			}

			if($stoploss>=$cur_price && ! _is_exchange_info_loged($code,_construct_code_day_header($code,'stoploss'))){
				my $reportstr=_construct_code_day_header($code,'stoploss').":($buyprice:$cur_price:$income):stoploss:($stoploss)";
				_report_code($code,$reportstr);
				$$reported_price=$cur_price;
			}
			if($K*$percent*($cur_price)<=$cur_price&& !_is_exchange_info_loged($code,_construct_code_header($code,"$K*importantprice"))){
				my $reportstr=_construct_code_header($code,"$K*importantprice").":($buyprice:$cur_price:$income))";
				_report_code($code,$reportstr);
				$$reported_price=$cur_price;
			}
			my $reported_price_diff=(($cur_price-$$reported_price)/$$reported_price);
			if(abs($reported_price_diff)>$tip_percent_reported_diff){
				$reported_price_diff=sprintf("%.4f",$reported_price_diff);
				my $reportstr=_construct_code_header($code,'rep_dif').":($buyprice:$cur_price:$income):rep_dif:$reported_price_diff";
				_report_code($code,$reportstr);
				$$reported_price=$cur_price;
			}
			if(($cur_price+${$average})/2 != ${$average}){
				${$average}=(${$average}+$cur_price)/2;
			}
			$$fore_price=$cur_price;
			printf("\n$code:average:$$average");
			printf("\n$code:fore_price:$$fore_price");
			printf("\n$code:reported_price:$$reported_price");
		}else{
			#中午休市提示
			if( $hour >=11&& $hour <13&&!_is_exchange_info_loged($code,_construct_code_day_header($code,'AM'))){
				my $reportstr=_construct_code_day_header($code,'AM').":($buyprice:$cur_price:$income)";
				_report_code($code,$reportstr);
			}
			#下午休市提示
			if( $hour >=15&& !_is_exchange_info_loged($code,_construct_code_day_header($code,'PM'))){
				my $reportstr=_construct_code_day_header($code,'PM').":($buyprice:$cur_price:$income)";
				_report_code($code,$reportstr);
			}
		}
	}
}
sub _init_code_monitor_info{
	my ($code,$ref_all_monitor_info)=@_;
	$ref_all_monitor_info->{$code}={
		average_price =>0,
		fore_price=>0,
		reported_price=>0,
	};	
}
sub _monitor_bought_stocks{
	my (@codes)=@_;
#init
	foreach my $code(@codes){
		_init_code_monitor_info($code,$gall_monitor_info);
	}
	while(1){
		my $i=0;
		foreach my $code(@codes){
			_monitor_bought_stock($code,$gall_monitor_info->{$code});
		}
		sleep 10;
	}
}
sub _monitor_exchange_stocks
{
	open(IN,"<",$StockCodeFile);
	my $dhe=MSH_OpenDB($StockExDb);
	my $dih=MSH_OpenDB($StockInfoDb);
	my @monitor_stocks;
	my $code;
	print "searching codes..."."\n";
	#寻找合适的股票
	while(<IN> ){
		$code=$_;
		chomp $code;
		my $today = COM_today(0); 
		my $foreday = DBT_get_fore_exchange_day($code,$today,$dhe);
		next if(!$foreday);
		my $rise = DBT_get_rise($code,$dhe,$foreday);
		my $volume = DBT_get_volume($code,$dhe,$foreday);
		my $turnover = _get_turnover($foreday,$code,$dhe,$dih);
		if($rise > 0.09 && $volume < 50000*100 && $turnover <0.01){
			push @monitor_stocks,$code;	
		}
	}
	close IN;
	$dhe->disconnect;
	$dhe->disconnect;
	$dih->disconnect;
	if(@monitor_stocks){
		my $i=0;
		print "find code(s):"."\n";
		foreach my $one(@monitor_stocks){
			$i++;
			if (not $i%5){
				print "\n";
			}
			print "$one  "; 
		}

	}else{
		print "no code(s) meet requirements"."\n";
		return 1;
	}
	my @prepare_stocks;
	print "\nwaiting for exchange..."."\n";
	while(1){
		my $hour=COM_get_cur_time('hour');
		my $minute=COM_get_cur_time('minute');
		if (SCOM_is_exchange_duration($hour,$minute)){ 
			last;
		}
		sleep 10;
	}
	print "start:"."\n";
	my $dhp = MSH_OpenDB($StockProfitDb);
	while(@monitor_stocks || @prepare_stocks){
		foreach $code(@monitor_stocks){
			if(SN_get_stock_cur_rise($code)>9.7){
				push @prepare_stocks,$code;	
				COM_remove(\@monitor_stocks,$code);
		}
	}
	sleep 1;
	foreach $code(@prepare_stocks){
		my $rise =  SN_get_stock_cur_rise($code);
		printf "monitor prepare $code:$rise"."\n";
		if(!_is_exchange_info_loged($code,_construct_code_day_header($code,'buytip')) && $rise<=9.7 && $rise<=8.0){
			my $profit = DBT_get_profit($code,$dhp);
			my $reportstr=_construct_code_day_header($code,'buytip').":rise($rise)"."profit:$profit:";
			_report_code($code,$reportstr);
			COM_remove(\@prepare_stocks,$code);
	}
}
	}
	$dhp->disconnect;
}
sub _DMI{
	my $code=shift;
	my @codes;
#读取信息文件
	if(open IN,"<",$monitor_code){
		while(<IN>){
			chomp $_;
			if(SCOM_is_valid_code($_) && index($_,$code)==-1){
				push @codes,$_;
			}
		}
		close IN;	
	}
#保存到文件
	open OUT,">",$monitor_code;
	syswrite(OUT,join("\n",@codes));
	close OUT;	
}
sub _AMI{
	my @codea;
	my ($code)=@_;
	if(SCOM_is_valid_code($code)){
		chomp $code;
		_DMI($code);
		open OUT,">>",$monitor_code;
		syswrite(OUT,"\n");
		syswrite(OUT,$code);
		close OUT;
	}
}
sub _get_exchange_info{
	my ($code,$from,$to)=@_;
	my $dhe=MSH_OpenDB($StockExDb);
	my @info=DBT_get_exchange_info($code,$from,$to,$dhe);
	my $i=0;
	my @onevalue=();
	my @myinfo=();
	$dhe->disconnect;
	foreach my $value(@info){
		if ($value=~/\d{4}-\d{1,2}-\d{1,2}/){
			if (@onevalue){
				push @myinfo,join(" ",@onevalue);	
				@onevalue=();
			}
		}
		push @onevalue,$value;	
	}
	if (@onevalue){
		push @myinfo,join(" ",@onevalue);
	}
	return @myinfo;
}
sub _pasre_exchange_details{
	my($info)=@_;
	if($info){
		my @info = split(" ",$info);	
		my @time;
		if (@info and $#info > 4 ){
			@time = split(":",$info[0]);
			if(@time and $#time == 2){
				return @info;	
			}
		}
	}
	return undef;
}
sub _get_details_volume{
	my($info)=@_;
	my @info ;
	if(@info = _pasre_exchange_details($info) && $#info >=3 ){
		return $info[3];
	}
	return undef;
}
sub _get_details_value{
	my($info)=@_;
	my @info = _pasre_exchange_details($info);
	if(@info && $#info >=4 ){
		return $info[4];
	}
	return undef;

}
sub _analyze_code_days{
	my ($code,$date,$count) = @_;	
	my $dhe=MSH_OpenDB($StockExDb);
	if (!$date){
		$date = DBT_get_last_exchange_day($dhe,$code);	
	}
	if (!$count){
		$count = 1;
	}
	my @days = DBT_get_earlier_exchange_days($dhe,$code,$date,$count);
	$dhe->disconnect;
	foreach my $day(@days){
		_analyze_code($code,$day);
	}
}
sub _analyze_code
{
	my ($code,$date) = @_;	
	my $dhe=MSH_OpenDB($StockExDb);
	my $big = 1000000;
	my @bigvalue;
	if (!$date){
		$date = DBT_get_last_exchange_day($dhe,$code);	
	}
	my $exchange_details_file = $code."_details_".$date;
	if (not -e $exchange_details_file){
		my $url = "http://market.finance.sina.com.cn/downxls.php?date=$date&symbol=$code";
		if(!COM_download($url,$exchange_details_file)){
			COM_log("download $exchange_details_file fail!");
			return 0;
		}
	}
	open(IN,"<$exchange_details_file");
	while(<IN>){
		my $val= _get_details_value($_);
		if($val && $val > $big){
			push @bigvalue,$val;	
		}
	}
	close IN;	
	my $bigcounts = scalar(@bigvalue);
	COM_log("$code:$date:big exchange:$bigcounts times\n");
	unlink $exchange_details_file; 
	$dhe->disconnect;
}
sub main
{
	my $pause=0;
	COM_log_init();
	#传引用
	COM_filter_param(\@ARGV);
	while(my $opt=shift @ARGV){
	if ($opt =~ /-h/){			 
		print <<"END";
		-p(windows system only):pause before exit
		-scp[ code[ code[ ...]]]: show current stock exchange price -dmi[ code[ code[ ...]]]: delete monitor stock from file
		-ami[ code[ code[ ...]]]: add monitor stock ,save to file
		-mcp[ code[ code[ ...]]]: monitor stock;if omit code ,read in file
		-ema code exchange_start_day calculated_ema_day ema_delta_day eg:-ema sz002432 2012-01-01 2012-03-06 10
		-macd code exchange_start_day calculated_macd_day eg:-macd sz002432 2012-01-01 2012-03-06 
		-tor datefrom dateto turnover_min turnover_max daytotal shownum:show match condition of turnover rate stock codes
		-select [macd][kdj][turnover][total:][date:][dig][lift][break_surge][mode:[1...]]:select stock by some flag
		-fc <code> :from code
		-buy <code> <price> <total> <stop loss order>:buy a stock 
		-lb[code [code ..]]:list bought stock(s)
		-sell <code> sell a stock 
		-mbs [code [code ..]]:monitor bought stock(s)
		-mes monitor exchange stock(s)
		-show <code> [fromdate] [todate]:show exchange info in the days
		-analyze <code> [date:2012-10-10]:analyze exchange detials info
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
				my @info=_get_buy_code_info($code,'code');
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
	if ($opt =~ /-mes\b/){
		_monitor_exchange_stocks();
	}
	#sell stock
	if ($opt =~ /-sell\b/){
		my $code;
		while($code=shift @ARGV and SCOM_is_valid_code($code) ){
			_DMI($code);
			_delete_buy_code($code);
			#删除log信息
			my $log=_get_code_monitor_info_file($code,'log');
			if($log){
				unlink($log);
			}
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
	#show exhcange info
	if ($opt =~ /-show\b/){
		my $code;
		my @info;
		my $dhe=MSH_OpenDB($StockExDb);
		while($code=shift @ARGV and SCOM_is_valid_code($code) ){
			my $from=shift @ARGV;
			my $to=shift @ARGV;
			my $date=COM_today(0);
			my @last_exchange_data_day=DBT_get_earlier_exchange_days($dhe,$code,$date,1);
			if(!$from){
				$from=$last_exchange_data_day[0];
			}
			if(!$to){
				$to=$last_exchange_data_day[0];
			}
			@info=_get_exchange_info($code,$from,$to);
			last;
		}
		$dhe->disconnect;
		print join("\n",@info);
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
		if(COM_get_command_line_property(\@ARGV,"turnover")){
		$gflag_selectcode_turnover=1;
	}
	if(COM_get_command_line_property(\@ARGV,"kdj")){
	$gflag_selectcode_kdj=1;
}
if(COM_get_command_line_property(\@ARGV,"macd")){
$gflag_selectcode_macd=1;
			}
			if(COM_get_command_line_property(\@ARGV,"dig")){
			$gflag_selectcode_dig=1;
		}
		if(COM_get_command_line_property(\@ARGV,"break_surge")){
		$gflag_selectcode_break_surge=1;
	}
	if(COM_get_command_line_property(\@ARGV,"mode",\$g_selectcode_mode)){
$gflag_selectcode_mode=1;
			}
			#$g_selectcode_date = COM_today(0);
			COM_get_command_line_property(\@ARGV,"date",\$g_selectcode_date);
	my $total=20;
	COM_get_command_line_property(\@ARGV,"total",\$total);
			my $level = 0;
			COM_get_command_line_property(\@ARGV,"level",\$gflag_selectcode_level);
	my @codes=_select_codes($StockCodeFile,$total);
	COM_log(join("\n","selected:",@codes));
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
if($opt =~ /-analyze/){
	my @codes = COM_command_line_filter_codes(\@ARGV);			
if (@codes){
	my $date ;
	my $count;
	COM_get_command_line_property(\@ARGV,"date",\$date);
				COM_get_command_line_property(\@ARGV,"count",\$count);
		foreach my $code(@codes){
			_analyze_code_days($code,$date,$count);	
		}

	}
}

	}
	if($pause){
		system("pause");
	}   
	COM_log("\nbye bye!\n");
}

main;
