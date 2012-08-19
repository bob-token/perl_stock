use warnings;
use strict;
use LWP;
use Encode;
use DBI;
require "perl_common.pl";
require "perl_stockcommon.pl";
require "perl_database.pl";
require "perl_database_tools.pl";
require "perl_stocknetwork.pl";

our $StockExDb="StockExchangeDb";
our $StockInfoDb="StockInfoDb";
our $StockProfitDb="StockProfitDb";
our $StockCodeFile="stock_code.txt";
our $fromcode;

$|=1;
sub _clean_exchange_db{
	my $dbh=_open_stock_db();
	my @tablesname=MSH_GetAllTablesNameArrary($dbh,$StockExDb);
	foreach my $code (@tablesname) {
		chomp $code;
		my $sql=sprintf("delete from %s where KAIPANJIA=0",$code);
		$dbh->do($sql);
		print "$code cleared","\n";
	}
	$dbh->disconnect;
	return 1;	
}
sub _update_stock_code{
	my $browser = LWP::UserAgent->new;
	my $i=1;
	my $type="a";
#	$browser->timeout(30);
	open(OUT,'>',shift);
	while(1){
		my $url=sprintf("http://vip.stock.finance.sina.com.cn/quotes_service/api/json_v2.php/Market_Center.getHQNodeData?page=%d&num=80&sort=symbol&asc=1&node=hs_%s&_s_r_a=page",$i,$type);	
		my $response = $browser->get($url);
		if($response->is_success and 'null' ne $response->content){
			my @result=$response->content =~ m/(s[hz]\d{6})/g;
			foreach my $code(@result){
				print $code,"\n";
				syswrite(OUT,$code);
				syswrite(OUT,"\n");
			}
			++$i;			
		}else{
			if($type eq "a"){
				$type="b";
				$i=1;
			}else{
				last;
			}
		}
	}
	close(OUT);
}

sub _open_stock_db{
	return MSH_OpenDB("mysql");
}

sub _create_stock_db{
	#connect db server
	my $dbh = _open_stock_db();
	#create db
	MSH_CreateDB($dbh,shift);
	#close db
	$dbh->disconnect;
}
sub _clear_stock_db{
	#connect db server
	my $dbh = _open_stock_db();
	#create db
	MSH_DropDB($dbh,shift);
	#close db
	$dbh->disconnect;
}

sub _get_stock_exchange{
	my $code=shift;
	my $year=shift;
	my $jidu=shift;
	if($code=~ /s[hz]/){
		$code=substr($code,2);
	}
	my $url=sprintf("http://money.finance.sina.com.cn/corp/go.php/vMS_MarketHistory/stockid/%s.phtml?year=%s&jidu=%s", $code,$year,$jidu);
	my $browser = LWP::UserAgent->new;
	my $times=0;
	my @stock;
	while(1){
		my $response = $browser->get($url);
		if($response->is_success and 'null' ne $response->content){
			my @date=($response->content =~ /(?<=date=)(\d{4}.*)(?='>)/g);
			my @exchangeinfo=($response->content =~ /(?<=center">)(\d{1,7}.*)(?=<\/div>)/g);
			for( my $idd=0;$idd<(@date);$idd++){
				my $start=$idd*6;
				my $info=join(',',join('"','',$date[$idd],''),$exchangeinfo[$start+0],$exchangeinfo[$start+1],$exchangeinfo[$start+2],$exchangeinfo[$start+3],$exchangeinfo[$start+4],$exchangeinfo[$start+5]);
				$info=sprintf("%s$info%s",'(',')');
				push (@stock,$info);
			}
			return  @stock;
		}
		if ($times < 10){
			++$times;
			sleep 1;			
			if(!$times%3){
				$browser = LWP::UserAgent->new;
			}
		}else {
			last;
		}
	}
}
sub _get_stock_base_info{
	my $code=shift;
	my $url=sprintf("http://finance.ifeng.com/app/hq/stock/%s/", $code);
	my $browser = LWP::UserAgent->new;
	my $times=0;
	my @stock;
	while(1){
		my $response = $browser->get($url);
		if($response->is_success and 'null' ne $response->content){
			my @ltg=($response->content =~ /ltg\s*:\s*(\d{3,})/);
			my @zgb=($response->content =~ /zgb\s*:\s*(\d{3,})/);
			push @ltg,@zgb;
			unshift @ltg,('\''.$code.'\'');
			return  @ltg;
		}
		if ($times < 10){
			++$times;
			sleep 1;			
		}else {
			last;
		}
	}
}
sub _update_stock_season_exchange_info{
	my ($code,$dhp)=@_;
	my $index = SCOM_get_part($code,'index');
	my $url = "http://money.finance.sina.com.cn/corp/go.php/vFD_FinanceSummary/stockid/$index/displaytype/4.phtml";
	open(IN,$StockCodeFile);
	my $content = COM_get_page_content($url,5);
	#截至日期
	my @date =($$content =~ /<a name=\"([\d-].*)\"><\/a><strong>/);
	#每股净资产
	my @mgjzc =($$content =~ /type=mgjzc\">([-\.\d]*).*<\/a>/);
	#每股收益
	my @mgsy =($$content =~ /type=mgsy\">([-\.\d]*).*<\/a>/);
	if(@date && @mgjzc && @mgsy){
		my $date ='"'.$date[0].'"';
		my $info = join(',',$date,$mgjzc[0],$mgsy[0]);
		print "$code :$info\n";
		my $sql=sprintf("INSERT IGNORE INTO  %s VALUES (%s) ;",$code,$info);
		$dhp->do($sql) or print $!;
		
	}
	close IN;
}
sub _update_stocks_season_exchange_info{
	my $dhp = MSH_OpenDB($StockProfitDb);
	my $tablesname=MSH_GetAllTablesName($dhp,$StockProfitDb);
	my $codeiterator;
	#foreach my $code (<IN>) {
	SCOM_start_code_iterate(\$codeiterator,COM_get_fromcode());
	while(my $code =SCOM_iterator_get_code(\$codeiterator)) {
		chomp $code;
		if(index (uc($tablesname),uc($code)) < 0){
			#create tables;
			my $table_p="DATE DATE,MEIGUJINGZICHAN FLOAT,MEIGUSHOUYI FLOAT";
			MSH_CreateTableIfNotExist($dhp,$code,$table_p);
			MSH_SetUniqueKey($dhp,$code,"DATE");
		}
		_update_stock_season_exchange_info($code,$dhp);
	}
	$dhp->disconnect;
}
sub _update_stock_base_info{
	my $dbh=shift;
	my $code=shift;
	my $tbl_name=$code;
	my $sql;
	my @info=_get_stock_base_info($code);
	if(@info){
		my $str_info=join(',',@info,'');
		chop $str_info;
		
		$sql=sprintf("INSERT IGNORE INTO  %s VALUES (%s) ;",$tbl_name,$str_info);
		print "$str_info\n";
		print "$sql\n";
		$dbh->do($sql) or print $!;			
	}
}
sub _update_stocks_base_info{
	my $dbh=_open_stock_db();
	my $tablesname=MSH_GetAllTablesName($dbh,$StockInfoDb);
	open(IN,shift);
	foreach my $code (<IN>) {
		chop $code;
		if(index (uc($tablesname),uc($code)) < 0){
			#create tables;
			my $table_p="STOCKNAME VARCHAR(20) CHARACTER SET utf8,LIUTONGGU BIGINT,ZONGGUBEN BIGINT";
			MSH_CreateTableIfNotExist($dbh,$code,$table_p);
			MSH_SetUniqueKey($dbh,$code,"STOCKNAME");
			_update_stock_base_info($dbh,$code);
		}
	}
	close(IN);
	$dbh->disconnect;
	return 1;	
}
sub _update_stock_exchange{
	my $dbh=shift;
	my $code=shift;
	my $nStartYear=shift;
	my $nStartJidu=shift;
	my $nTotalJidu=shift;
	my $tbl_name=$code;
	my $sql;
	foreach my $i(0..$nTotalJidu-1){
		my $year=$nStartYear+int(($nStartJidu-1+$i)/4);
		my $jidu=1+($nStartJidu-1+$i)%4;
		print $code," ",$year," year ",$jidu," season\n";
		my @info=_get_stock_exchange($code,$year,$jidu);
		if(@info){
			my $str_info=join(',',@info,'');
			chop $str_info;
			$sql=sprintf("INSERT IGNORE INTO  %s VALUES %s ;",$tbl_name,$str_info);
			$dbh->do($sql) or print $!;			
		}
	}
}
sub _smart_update_stocks_exchange{
	my $dbh=_open_stock_db();
	my $tablesname=MSH_GetAllTablesName($dbh,$StockExDb);
	open(IN,shift);
	my $year=shift;
	my $cday;
	my $cmon;
	my $cyear;
	my $cyday;
	$cyear=COM_get_cur_time('year');;
	$cmon=COM_get_cur_time('month')+1;
	$cday=COM_get_cur_time('day');
	my $today=$cyear."-$cmon"."-$cday";
	if(COM_get_cur_time('year') >= $year){
		my $total=4;
		my $start=1;
		if($cyear == $year){
			$total=int(($cmon-1)/3)+1;
		}
		if(COM_get_fromcode()){
			$start=0;	
		}
		foreach my $code (<IN>) {
			chop $code;
			if(!$start){
				next if(index(COM_get_fromcode(),$code)==-1);
				$start=1;
			}
			if(index (uc($tablesname),uc($code)) < 0){
				#create tables;
				my $table_p="DATE DATE,KAIPANJIA FLOAT,ZUIGAOJIA FLOAT,SHOUPANJIA FLOAT,ZUIDIJIA FLOAT,JIAOYIGUSHU BIGINT,JIAOYIJINE BIGINT";
				MSH_CreateTableIfNotExist($dbh,$code,$table_p);
				MSH_SetUniqueKey($dbh,$code,"DATE");
				_update_stock_exchange($dbh,$code,$year,'1',$total);
			}else{
				for(my $season=0;$season<$total;$season++){
					#如果下个季度交易日为空从本季度开始更新数据
					my @days=DBT_get_season_exchage_days($dbh,$code,$year,$season+1);
					if(!@days){
						_update_stock_exchange($dbh,$code,$year,$season+1,1);
					}elsif($year==$cyear && $season+1==$total){
						_update_stock_exchange($dbh,$code,$year,$season+1,1);
					}
				}
			}
		}
	}
	close(IN);
	$dbh->disconnect;
	return 1;	
}
sub _delete_date_exchange_info
{
	my ($date)=@_;
	open(IN,"<",$StockCodeFile);	
	my $dbh=MSH_OpenDB($StockExDb);
	foreach my $code (<IN>) {
		chomp $code;
		print "$code:$date exchange info"."\n";
		_delete_stock_exchange_info($code,$date,$dbh);
	}
	close(IN);
	$dbh->disconnect;
}
sub _delete_stock_exchange_info
{
	my ($code,$date,$dbh)=@_;
   	my $condition="DATE=\"$date\"";
 	MSH_Delete($dbh,$code,$condition);
}
sub _update_stocks_exchange{
	my $dbh=_open_stock_db();
	my $tablesname=MSH_GetAllTablesName($dbh,$StockExDb);
	open(IN,shift);
	my $year=shift;
	my $csec;
	my $cmin;
	my $chour;
	my $cday;
	my $cmon;
	my $cyear;
	my $cwday;
	my $cyday;
	my $cisdst;
	($csec, $cmin, $chour, $cday, $cmon, $cyear, $cwday, $cyday, $cisdst) = localtime();
	$cyear=$cyear+1900;
	$cmon+=1;
	if($cyear >= $year){
		my $total=4;
		my $start=1;
		if($cyear == $year){
			$total=int(($cmon-1)/3)+1;
		}
		if(defined $fromcode){
			$start=0;	
		}
		foreach my $code (<IN>) {
			chop $code;
			if(!$start){
				next if(index($fromcode,$code)==-1);
				$start=1;
			}
			if(index (uc($tablesname),uc($code)) < 0){
				#create tables;
				my $table_p="DATE DATE,KAIPANJIA FLOAT,ZUIGAOJIA FLOAT,SHOUPANJIA FLOAT,ZUIDIJIA FLOAT,JIAOYIGUSHU BIGINT,JIAOYIJINE BIGINT";
				MSH_CreateTableIfNotExist($dbh,$code,$table_p);
				MSH_SetUniqueKey($dbh,$code,"DATE");
			}
			_update_stock_exchange($dbh,$code,$year,'1',$total);
		}
	}
	close(IN);
	$dbh->disconnect;
	return 1;	
}
sub _USDE{
	my ($ref_years,$ref_seasons)=@_;
	my $dbh=_open_stock_db();
	my $tablesname=MSH_GetAllTablesName($dbh,$StockExDb);
	open(IN,$StockCodeFile);
	my $year;
	my $csec;
	my $cmin;
	my $chour;
	my $cday;
	my $cmon;
	my $cyear;
	my $cwday;
	my $cyday;
	my $cisdst;
	my $start = 1;
	($csec, $cmin, $chour, $cday, $cmon, $cyear, $cwday, $cyday, $cisdst) = localtime();
	$cyear=$cyear+1900;
	$cmon+=1;
	$fromcode = COM_get_fromcode();
	if(defined $fromcode){
		$start=0;	
	}
	foreach my $code (<IN>) {
		chop $code;
		if(!$start){
			next if(index($fromcode,$code)==-1);
			$start=1;
		}
		foreach $year(@$ref_years){
			if($cyear >= $year){
				my $total=4;
				my $start=1;
				if($cyear == $year){
					$total=int(($cmon-1)/3)+1;
				}
				if(index (uc($tablesname),uc($code)) < 0){
					#create tables;
					my $table_p="DATE DATE,KAIPANJIA FLOAT,ZUIGAOJIA FLOAT,SHOUPANJIA FLOAT,ZUIDIJIA FLOAT,JIAOYIGUSHU BIGINT,JIAOYIJINE BIGINT";
					MSH_CreateTableIfNotExist($dbh,$code,$table_p);
					MSH_SetUniqueKey($dbh,$code,"DATE");
				}
				foreach my $jd(@$ref_seasons){
					_update_stock_exchange($dbh,$code,$year,$jd,1);
				}
			}
		}
	}
	close(IN);
	$dbh->disconnect;
	return 1;	
}
sub _UCYE{
	my ($code,@years)=@_;
	my $dbh=MSH_OpenDB($StockExDb);
	my $tablesname=MSH_GetAllTablesName($dbh,$StockExDb);
	my $year;
	my $csec;
	my $cmin;
	my $chour;
	my $cday;
	my $cmon;
	my $cyear;
	my $cwday;
	my $cyday;
	my $cisdst;
	($csec, $cmin, $chour, $cday, $cmon, $cyear, $cwday, $cyday, $cisdst) = localtime();
	$cyear=$cyear+1900;
	foreach $year(@years){
		if($cyear >= $year){
			my $total=4;
			my $start=1;
			if($cyear == $year){
				$total=int(($cmon-1)/3)+1;
			}
			if($code){
				chomp $code;
				if(index (uc($tablesname),uc($code)) < 0){
					#create tables;
					my $table_p="DATE DATE,KAIPANJIA FLOAT,ZUIGAOJIA FLOAT,SHOUPANJIA FLOAT,ZUIDIJIA FLOAT,JIAOYIGUSHU BIGINT,JIAOYIJINE BIGINT";
					MSH_CreateTableIfNotExist($dbh,$code,$table_p);
					MSH_SetUniqueKey($dbh,$code,"DATE");
				}
				_update_stock_exchange($dbh,$code,$year,'1',$total);
			}
		}
	}
	$dbh->disconnect;
	return 1;	
}
sub _update_last_exchange{
	my $dbh=MSH_OpenDB($StockExDb);
	my $tablesname=MSH_GetAllTablesName($dbh,$StockExDb);
	my $year;
	my $csec;
	my $cmin;
	my $chour;
	my $cday;
	my $cmon;
	my $cyear;
	my $cwday;
	my $cyday;
	my $cisdst;
	($csec, $cmin, $chour, $cday, $cmon, $cyear, $cwday, $cyday, $cisdst) = localtime();
	$cyear=$cyear+1900;
	my $name=0;
	my $kaipan=1;
	my $zuoshou=2;
	my $shoupan=3;
	my $zuigao=4;
	my $zuidi=5;
	my $jiaoyigushu=8;
	my $jiaoyijine=9;
	my $jiaoyidate=-3;
	my $jiaoyitime=-2;
	my $start=1;
	if(COM_get_fromcode()){
		$start=0;	
	}
	open IN,"<",$StockCodeFile;
	foreach my $code(<IN>){
		if($code){
			chomp $code;
			if(!$start){
				next if(index(COM_get_fromcode(),$code)==-1);
				$start=1;
			}
			if(index (uc($tablesname),uc($code)) < 0){
				#create tables;
				my $table_p="DATE DATE,KAIPANJIA FLOAT,ZUIGAOJIA FLOAT,SHOUPANJIA FLOAT,ZUIDIJIA FLOAT,JIAOYIGUSHU BIGINT,JIAOYIJINE BIGINT";
				MSH_CreateTableIfNotExist($dbh,$code,$table_p);
				MSH_SetUniqueKey($dbh,$code,"DATE");
			}
			#获取最新产生的交易数据
			my @einfo;
			if (@einfo=SN_get_stock_cur_exchange_info($code) ){
				my $str_info='"'.$einfo[$jiaoyidate].'"'.','.$einfo[$kaipan].','.$einfo[$zuigao].','.$einfo[$shoupan].','.$einfo[$zuidi].','.$einfo[$jiaoyigushu].','.$einfo[$jiaoyijine];
				my $sql=sprintf("INSERT IGNORE INTO  %s VALUES (%s) ;",$code,$str_info);
				if($einfo[$kaipan]<=0){
					printf 	"Skip ";
				}
				printf $code.":".$str_info."\n";
				$dbh->do($sql);
			}
		}
	}
	$dbh->disconnect;
	close IN;
	return 1;	
}
sub main{
	my @years;
	my $flag_ude=0;
	my $flag_sude=0;
	COM_filter_param(\@ARGV);
	while(my $opt=shift @ARGV){
		#help infomation
		if ($opt =~ /-h/){			 
		print <<"END";
		-uc:  update sotck code 
		-cdi: create  database for stock base info
		-cri: drop stock base info database
		-udi: update stock base info
		-cdsi: create  database for stock season exchange info
		-crsi: drop stock season exchange database
		-udsi: update stock season exchange  info
		-cde: create  database for stock daily exchange
		-cre: drop stock daily excange database
		-dde: delete exchange info in date
		-ude[year1 [year2...]]: update stock year(s) exchange
		-ulde: update stock last daily excange
		-sude[year1 [year2...]]: smart update stock daily exchange,before get data from internet ,query database;
		-ucye code [year1 [year2...]]: update stock year(s) exchange
		-usde[season1 [season2...]]: update stock season exchange
		-ufc:<code> from code
		-clearexdb:clear exchange database
END
	}
		#clear exchange database
		$opt =~ /-clearexdb\b/ && _clean_exchange_db()&&print "clear exchange database success\n";
		#update sotck code
		$opt =~ /-uc\b/ && _update_stock_code($StockCodeFile)&&print "update socks code success\n";
		#create  database for stock base info
		$opt =~ /-cdi\b/ && _create_stock_db($StockInfoDb)&&print "create stock exchange database:$StockExDb success\n";
		#drop stock base info database
		$opt =~ /-cri\b/ && _clear_stock_db($StockInfoDb)&& print "$StockInfoDb cleared!\n";
		#update stock base info
		$opt =~ /-udi\b/ && _update_stocks_base_info($StockCodeFile) && print "update stock info success\n";
		#create  database for stock daily exchange
		$opt =~ /-cde\b/ && _create_stock_db($StockExDb)&&print "create stock exchange database:$StockExDb success\n";
		#drop stock daily excange database
		$opt =~ /-cre\b/ && _clear_stock_db($StockExDb)&& print "$StockExDb cleared!\n";
		#delete exchange info in date
		$opt =~ /-dde\b/ && _delete_date_exchange_info(shift @ARGV);
		#-cdsi: create  database for stock season profit info
		$opt =~ /-cdsi\b/ && _create_stock_db($StockProfitDb)&&print "create stock season profit database:$StockProfitDb success\n";
		#-crsi: drop stock season exchange database
		$opt =~ /-crsi\b/ &&_clear_stock_db($StockProfitDb)&& print "$StockProfitDb cleared!\n";
		#-udsi: update stock season exchange  info
		$opt =~ /-udsi\b/ &&  _update_stocks_season_exchange_info()&& print "update stock profit info success\n";
		#update from the code
		if($opt =~ /-ufc\b/){
			$fromcode=shift @ARGV;
		}
		#update stock last daily excange
		if($opt =~ /-ulde\b/){
			_update_last_exchange();
		}
		#-ucye code [year1 [year2...]]: update stock daily excange
		if($opt =~ /-ucye\b/){
			my $year;
			my $code=shift @ARGV;
			while($year=shift @ARGV and $year =~ /\b\d{4}\b/){
				push @years,$year;
			}
			if(defined $year){
				unshift(@ARGV,$year);
			}
			_UCYE($code,@years);
			print $code." ",join(":",@years)," exchange data update success !","\n";
		}
		#-usde[season1 [season2...]]: update stock season exchange
		if($opt =~ /-usde\b/){
			my $year;
			my @season;
			while($year=shift @ARGV and $year =~ /\b\d{4}\b/){
				push @years,$year;
			}
			if(defined $year){
				unshift(@ARGV,$year);
			}
			while($year=shift @ARGV and $year =~ /\b\d\b/){
				push @season,$year;
			}
			if(defined $year){
				unshift(@ARGV,$year);
			}
			 _USDE(\@years,\@season);
			print join(":",@years,@season)," exchange data update success !","\n";
		}
		#start update stock daily excange
		if($opt =~ /-sude\b/){
			my $year;
			$flag_sude=1;
			while($year=shift @ARGV and $year =~ /\b\d{4}\b/){
				push @years,$year;
			}
			if(defined $year){
				unshift(@ARGV,$year);
			}
		};
		#update stock daily excange
		if($opt =~ /-ude\b/){
			my $year;
			$flag_ude=1;
			while($year=shift @ARGV and $year =~ /\b\d{4}\b/){
				push @years,$year;
			}
			if(defined $year){
				unshift(@ARGV,$year);
			}
		};

	}
	if($flag_sude){
		foreach my $year(@years){
			_smart_update_stocks_exchange($StockCodeFile,$year)&&print "smart update $year socks info success\n";
		}
	}
	if($flag_ude){
		foreach my $year(@years){
			_update_stocks_exchange($StockCodeFile,$year)&&print "update $year socks info success\n";
		}
	}
	print "\nbye bye!\n";
}

main;
