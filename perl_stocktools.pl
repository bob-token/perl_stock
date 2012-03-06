#!/usr/bin/perl -w
use strict;
use warnings;
use LWP;
use DBI;
use DateTime;
use DateTime::Event::Recurrence;
require "perl_database.pl";
our $StockExDb="StockExchangeDb";
our $StockInfoDb="StockInfoDb";
our $StockCodeFile="stock_code.txt";
our $monitor_code="monitor_stock_code.txt";
$|=1;
sub _get_cur_stock_exchange_info{
    my $code = shift;
    my $url=sprintf("http://hq.sinajs.cn/?_=1314426110204&list=%s",$code);
    my $browser = LWP::UserAgent->new;
    my $times=0;
    my @stock;
    while(1){
            my $response = $browser->get($url);
            if($response->is_success and 'null' ne $response->content){
                    my $info =$response->content;
                    chomp $info;
                    $info = substr($info,length('var hq_str_')+length($code)+1+1,-2);
                    my @info=split('\,',$info);
                    return  @info;
            }
            if ($times < 10){
                    ++$times;
                    sleep 1;			
            }else {
                    last;
            }
    }
}
sub _is_valid_code{
    my $code =shift;
    return $code =~/s[hz]\d{6}/;
}
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
sub _get_next_date{
	my $date=shift;
	my $mydate=DateTime->new($date);
	my $daily_set = DateTime::Event::Recurrence->daily;
	my $dt_next = $daily_set->next( $dt );
	return $dt_next; 
}
sub _get_next_date_closing_price{
	my @value;
	my $code=shift;
	my $date=shift;
	my $dhe=shift;
    my $condition="DATE>\"$date\" LIMIT 1";
	return MSH_GetValueFirst($dhe,$code,"DATE,SHOUPANJIA",$condition); 
	
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
	my $v_ma=_MA($code,@days);
	my $P=_get_closing_price($code,$date,$dhe);
#计算开始$date天的平均值
	my $first_ema;
	for(my $i=0;$i<$day_cnt;$i++){
		my @day_price=_get_next_date_closing_price($code,$day_exchange_start,$dhe);
		if(!defined @day_price){
			return $first_ema/$i;	
		}
		$first_ema+=@day_price[1];
		$code=@day_price[0];
	}		
	return $P*$v_K+_EMA($code,$day-1,$days)*(1-$v_K);
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
	    foreach my $code(@code){
		my @date=MSH_GetValue($deh,$code,"DATE",$condition);
		my $total=0;
    		foreach my $date(@date){
		    my $turnover=_get_turnover($date,$code,$deh,$dih);
 #   		    print $code," $date,"," $turnover\n";
		    if($turnover >= $min && $turnover <= $max){
			if(++$total >= $daymin){
			    print $code."\n";
			}
		    }		
		}	
	    }
	    $deh->disconnect;
	    $dih->disconnect;
}
sub main{
    my $pause=0;
	while(my $opt=shift @ARGV){
		#help infomation
		if ($opt =~ /-h/){			 
		print <<"END";
		-p:  pause before exit;
                -scp[ code[ code[ ...]]]: show current stock exchange price
                -dmi[ code[ code[ ...]]]: delete monitor stock from file
                -ami[ code[ code[ ...]]]: add monitor stock ,save to file
                -mcp[ code[ code[ ...]]]: monitor stock;if omit code ,read in file
END
	}
		#help info
		if ($opt =~ /-p\b/){
                    $pause=1;
                }
                #turnover rate
                if($opt =~ /-tor/){
                    my $datefrom=shift @ARGV;
                    my $dateto=shift @ARGV;
                    my $min=shift @ARGV;
                    my $max=shift @ARGV;
                    my $daytotal=shift @ARGV;
                    my $num=shift @ARGV;
                    _turnover_get_codes($datefrom,$dateto,$min,$max,$daytotal,$num);
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
			while($code=shift @ARGV and _is_valid_code($code) ){
				my @info =_get_cur_stock_exchange_info($code);
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
                        while(@oldcodea and $code=shift @ARGV and _is_valid_code($code)){
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
			while($code=shift @ARGV and _is_valid_code($code)){
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
			while($code=shift @ARGV and _is_valid_code($code) ){
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
                                my @info =_get_cur_stock_exchange_info($code);
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
