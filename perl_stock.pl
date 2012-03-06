use warnings;
use strict;
use LWP;
use Encode;
use DBI;
require "perl_database.pl";

our $StockExDb="StockExchangeDb";
our $StockInfoDb="StockInfoDb";
our $StockCodeFile="stock_code.txt";
our $fromcode;

$|=1;
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
	return DBI->connect("DBI:mysql:database=mysql;host=localhost", "root", "1983410", {'RaiseError' => 1});
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
#			while(($response->content =~ /.a/g)){
#				my $matchs = $&;
#				print $matchs;
#			}
			for( my $idd=0;$idd<(@date);$idd++){
				my $start=$idd*6;
				my $info=join(',',join('"','',$date[$idd],''),$exchangeinfo[$start+0],$exchangeinfo[$start+1],$exchangeinfo[$start+2],$exchangeinfo[$start+3],$exchangeinfo[$start+4],$exchangeinfo[$start+5]);
				$info=sprintf("%s$info%s",'(',')');
				push (@stock,$info);
			}
#			return  sort @stock;
			return  @stock;
		}
		if ($times < 10){
			++$times;
			sleep 1;			
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
	if($cyear >= $year){
		my $total=4;
		my $start=1;
		if($cyear == $year){
			$total=$cmon;
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

sub main{
	my @years;
	my $flag_ude=0;
	while(my $opt=shift @ARGV){
		#help infomation
		if ($opt =~ /-h/){			 
		print <<"END";
		-uc:  update sotck code 
		-cdi: create  database for stock base info
		-cri: drop stock base info database
		-udi: update stock base info
		-cde: create  database for stock daily exchange
		-cre: drop stock daily excange database
		-ude[year1 [year2...]]: update stock daily excange
		-fc:{code} from code
END
	}
		#update sotck code
		$opt =~ /-uc/ && _update_stock_code($StockCodeFile)&&print "update socks code success\n";
		#create  database for stock base info
		$opt =~ /-cdi/ && _create_stock_db($StockInfoDb)&&print "create stock exchange database:$StockExDb success\n";
		#drop stock base info database
		$opt =~ /-cri/ && _clear_stock_db($StockInfoDb)&& print "$StockInfoDb cleared!\n";
		#update stock base info
		$opt =~ /-udi/ && _update_stocks_base_info($StockCodeFile) && print "update stock info success\n";
		#create  database for stock daily exchange
		$opt =~ /-cde/ && _create_stock_db($StockExDb)&&print "create stock exchange database:$StockExDb success\n";
		#drop stock daily excange database
		$opt =~ /-cre/ && _clear_stock_db($StockExDb)&& print "$StockExDb cleared!\n";
		#update from the code
		if($opt =~ /-ufc/){
			$fromcode=shift @ARGV;
		}
		#update stock daily excange
		if($opt =~ /-ude/){
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
	if($flag_ude){
		foreach my $year(@years){
			_update_stocks_exchange($StockCodeFile,$year)&&print "update $year socks info success\n";

		}
	}
	print "\nbye bye!\n";
}

main;
