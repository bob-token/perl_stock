#!/usr/bin/perl -w
use strict;
use warnings;
use LWP;
use DBI;
require "perl_common.pl";
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
sub _get_closing_price{
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE=\"$date\"";
	return MSH_GetValueFirst($dhe,$code,"SHOUPANJIA",$condition); 
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
sub _MACD_DEALITTLETHANZERO{
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
	if($dea < 0){
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
	if($first_ema=_get_closing_price($code,$day_exchange_start,$dhe)){
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
		my $date="2012-04-05";
		my @last_exchange_data_day=DBT_get_earlier_exchange_days($dhe,$code,$date,3);
		$date=$last_exchange_data_day[0];
		if($gflag_selectcode_macd){
			#my $macd=_MACD(12,26,9,$code,$dhe,"2011-01-01",$date);
			my $macd= _MACD_DEALITTLETHANZERO(12,26,9,$code,$dhe,"2011-01-01",$date);
			next if(!$macd);
			my $macd1=_MACD(12,26,9,$code,$dhe,"2011-01-01",$last_exchange_data_day[1]);
			next if($macd < 0.03 || $macd <$macd1 );
			my $macd2=_MACD(12,26,9,$code,$dhe,"2011-01-01",$last_exchange_data_day[2]);
			next if($macd1<$macd2);
			print $code,":$date:MACD:$macd","\n";
			push @codes,join(":",$code,$date,$macd);
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
		if(@codeinfo&&COM_is_valid_code($codeinfo[0])){
			push @codes,$codeinfo[0];
		}
	}
	close IN;	
	return @codes;
}
sub _get_buy_code_info{
	my $code=shift;
#读取信息文件
	open IN,"<",$BuyStockCode;
	while(<IN>){
		if(index($_,$code)==0){
			return split(':',$_);
		}
	}
	close IN;	
	return undef;
}
sub _delete_buy_code{
	my $code=shift;
	my @buycodes;
#读取信息文件
	open IN,"<",$BuyStockCode;
	while(<IN>){
		if(index($_,$code)!=0){
			push @buycodes,$_;
		}
	}
	close IN;	
#保存到文件
	open OUT,">",$BuyStockCode;
	syswrite(OUT,join("\n",@buycodes));
	close OUT;	
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
	my ($code,$price,$total,$stoploss)=@_;
	if(!defined $stoploss){
		$stoploss=$price*0.98;#将止损点设在98%
	}
	_delete_buy_code($code);
	return _add_buy_code($code,$price,$total,$stoploss);
}
sub _report{
	my $msg=shift;
	printf $msg."\n";	
	system("/usr/local/bin/cliofetion -f 13590216192 -p15989589076xhb -d\"$msg\"");
}
sub _monitor_bought_stock{
	my ($code,$buyprice,$stoploss)=@_;
	my $cur_price=SN_get_stock_cur_price($code);
	my @reported_codes;
	chomp $stoploss;
	if($stoploss>$cur_price){
		my $reportstr=$code."($buyprice:$cur_price):lower than stop loss order($stoploss)";
		_report($reportstr);
	}
}
sub _monitor_bought_stocks{
	my @codes=@_;
	while(1){
		foreach my $code(@codes){
			my @info=_get_buy_code_info($code);
			_monitor_bought_stock($info[0],$info[1],$info[3]);
		}
		sleep 60;
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
		-select [macd] [turnover]:select stock by some flag
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
			while($code=shift @ARGV and COM_is_valid_code($code) ){
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
			while($code=shift @ARGV and COM_is_valid_code($code) ){
					_delete_buy_code($code);
			}
		}
		#list buy stock
		if ($opt =~ /-lb\b/){
			my $code;
			my @codes;
			while($code=shift @ARGV and COM_is_valid_code($code) ){
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
			while($code=shift @ARGV and COM_is_valid_code($code) ){
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
			while($code=shift @ARGV and COM_is_valid_code($code) ){
				my @info =PS_get_stock_cur_exchange_info($code);
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
                        my @codea;
                        my @oldcodea;
                        my @newcodea;
                        open(IN,$monitor_code);
                        foreach my $tmp(<IN>){
                            push @oldcodea,$tmp;         
                        }
                        close IN;
                        my $codes=join(' ',@oldcodea);
                        while(@oldcodea and $code=shift @ARGV and COM_is_valid_code($code)){
                            push @codea,$code;
						}
                        my $codea =join(' ',@codea);
                        foreach my $tmp(@oldcodea){
                            chomp $tmp;
                            if(index($codea,$tmp)==-1){
                                push @newcodea,$tmp;
                            }
                        }
                            open(OUT,'>',$monitor_code);
                            print OUT @newcodea;
                            close OUT;

 			if(defined $code){
				unshift(@ARGV,$code);
			}
                }
                if($opt =~ /-ami/){
                    	my $code;
                        my @codea;
			while($code=shift @ARGV and COM_is_valid_code($code)){
                            push @codea,$code;
			}
                        if(@codea>0){
                            open(IN,'>>',$monitor_code);
                                foreach my $tmp(@codea){
                                    syswrite(IN,$tmp);
                                    syswrite(IN,"\n");
                                }
                            close IN;
                        }
			if(defined $code){
				unshift(@ARGV,$code);
			}
                }
		if($opt =~ /-mcp/){
			my $code;
                        my @codes;
			while($code=shift @ARGV and COM_is_valid_code($code) ){
                                push @codes,$code;
			}
                        if(@codes==0){
                            open(IN,$monitor_code);
                             foreach my $tmp(<IN>){
                                 push @codes,$tmp;         
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
		};

	}
        if($pause){
            system("pause");
        }   
	print "\nbye bye!\n";
}

main;
