#!/usr/bin/perl -w
use utf8;
use Encode;
use strict;
use HTTP::Date;

my $work_dir = $ARGV[0];
my $dst_prj_name = $ARGV[1];
my $dst_bin_crc = $ARGV[2];

sub print_array
{
	foreach my $member (@_)
	{
		my $str_tmp = decode("gb2312", $member);
		print $str_tmp, " ";
	}
	print "\n";
}

sub get_bin_run_size
{
	my ($src_file) = @_;
    my $bin_ro_size = 0;
    my $bin_rw_size = 0;
    my $bin_zi_size = 0;
    my $flag_cnt = 0;
    my $total_size = 0;
    
    if (!defined($src_file))
    {
    	print 'not exist $src_file!\n';
    	return 0;
    }
    
    # 将文件内容解析出来并使用变量存储
	my $parse_info = qx{fromelf -y $src_file};
	#print $parse_info."\n";
		
	while ($parse_info =~ /\*{2}\s+section\s+#\d\s+'(\w+)'[^\n]+\s+Size\s+:\s+(\d+)\s+[^\n]+\s+address\s*:[^\n]+$/igm)
	{
		my $info = $1;
		my $size_temp = $2;
		
		print "name: $info, size: $size_temp\n";
		if ($info =~ /ro/i)
		{
			$bin_ro_size = $size_temp;
			$flag_cnt++;
		}
		elsif ($info =~ /rw/i)
		{
			$bin_rw_size = $size_temp;
			$flag_cnt++;
		}
		elsif ($info =~ /zi/i)
		{
			$bin_zi_size = $size_temp;
			$flag_cnt++;
		}
	}
	
	# 如果所有的段都找到，则计算得出bin文件运行时需要占用空间总大小
	if (3 == $flag_cnt)
	{
		$total_size = $bin_ro_size + $bin_rw_size + $bin_zi_size;
	}
	
	return $total_size;
}

sub create_ori_config_file
{
	my ($src_file) = @_;
	
	if (not defined $src_file)
	{
		return 0;
	}
	
	my @data_array = split /[\\\/]/, $src_file;
	my $item_name = $data_array[@data_array-2];
	if (not defined $item_name)
	{
		$item_name = 'xx';
	}
	
	$item_name = uc($item_name);
	
	# 获取当前本地时间
	my $string = HTTP::Date::time2iso();
	my ($year, $month, $day, $hour, $min, $sec, $tz) = HTTP::Date::parse_date($string);
	my $ver_info = $item_name."1.0";
	my $little_item_name = lc $item_name;
	my $ori_config_info = <<"__CONFIG_INFO";
<?xml version="1.0" encoding="UTF-8" ?> 
<AppHeader>
  <Magic>APP</Magic> 
  <Endian>1</Endian> 
  <Time>$year-$month-$day</Time> 
  <AppId>$item_name</AppId>
  <AppType>0</AppType>
  <AppName>$item_name</AppName>
  <AppVer>$ver_info</AppVer>
  <InAppVer>$little_item_name$year$month$day</InAppVer>
  <MinLoaderVer>LM1.0</MinLoaderVer>
  <BuildEnvi>1</BuildEnvi> 
  <MinLoadMem>137836</MinLoadMem>
  <MinRunMem>250</MinRunMem> 
  <RegCode>516b58czde98er0a</RegCode> 
  <CipherKey>0985167</CipherKey> 
  <Crc>50000</Crc> 
  <LargeLogo>\\\\bin\\\\LLogo.jpg</LargeLogo>
  <SmallLogo>\\\\bin\\\\LLogo.jpg</SmallLogo>
  <Describe>\\\\bin\\\\info.txt</Describe>
</AppHeader>

__CONFIG_INFO

	open (FH,">$src_file") or die "Can't open the file: $src_file $!\n";
    print FH $ori_config_info;
    close FH;
	
	if (not -e $src_file)
	{
		return 0;
	}
	
	return 1;
}

# 从配置字符串中获取指定项的值
sub get_config_info_from_str
{
	my ($src_str, $item, $out_ref) = @_;
	
	if ((!defined($src_str)) || (!defined($item)) || (!defined($out_ref)))
    {
    	print 'not exist $src_str, $item or $out_ref!', " line ", __LINE__, ".\n";
    	return 0;
    }
	
	my $rtn_flag = 0;
	
	if ($src_str =~ m/^\s*<$item>\s*([^<\s]*)\s*<\/$item>\s*$/im)
	{
		if (defined $1)
		{
			${$out_ref} = $1;
		}
		else
		{
			${$out_ref} = '';
		}
		
		$rtn_flag = 1;
	}
	else
	{
		${$out_ref} = '';
		$rtn_flag = 0;
	}
	
	return $rtn_flag;
}

sub get_config_info_and_write_file
{
	my ($config_file, $dst_file) = @_;
	
	if ((!defined($config_file)) || (!defined($dst_file)))
    {
    	print 'not exist $config_data or $dst_file!', " line ", __LINE__, ".\n";
    	return 0;
    }
	
	if (not -e $config_file)
	{
		printf("not exist $config_file. line %d.\n", __LINE__);
		return 0;
	}
	
	open (FH,"$config_file") or die "Can't open the file: $config_file $!\n";
    my $file_data=join '', <FH>;
    close FH;
    
   	#先转换成utf-8编码再处理
   	my $file_middle = '';
   	$file_data = Encode::decode_utf8($file_data);
    my $utf8_flag = Encode::is_utf8($file_data);
    if (!$utf8_flag)
    {
    	$file_middle = decode("gb2312", $file_data);
    }
    else
    {
    	$file_middle = $file_data;
    }
	
	my $inner_ver = '';
	get_config_info_from_str($file_middle, "InAppVer", \$inner_ver);
	
	my $app_ver = '';
	get_config_info_from_str($file_middle, "AppVer", \$app_ver);
	
	my $min_ld_ver = '';
	get_config_info_from_str($file_middle, "MinLoaderVer", \$min_ld_ver);
	
	my $min_ld_mem = '';
	get_config_info_from_str($file_middle, "MinLoadMem", \$min_ld_mem);
	
	my $min_run_mem = '';
	get_config_info_from_str($file_middle, "MinRunMem", \$min_run_mem);
	
	my $bin_info = <<"__BIN_INFO";
应用安装路径：\\hm\\app\\ipk
内部版本号：$inner_ver
显示版本号：$app_ver
平台：6252_11B_1032
加载器版本：$min_ld_ver
加载内存(B)：$min_ld_mem
运行内存(B)：$min_run_mem
是否触屏：是
分辨率：240X320

__BIN_INFO

	open (FH,">$dst_file") or die "Can't open the file: $dst_file $!\n";
    my $to_write_data = encode("gb2312", $bin_info);
	print FH $to_write_data;
    close FH;
	
	return 1;
}

# 更新应用配置文件中的MinLoadMem值
sub update_bin_run_info
{
	my ($src_file, $bin_run_size, $bin_crc) = @_;
    my $bin_ro_size = 0;
    my $bin_rw_size = 0;
    my $bin_zi_size = 0;
    my $flag_cnt = 0;
    
    if ((!defined($src_file)) || (!defined($bin_run_size)) || (!defined($bin_crc)))
    {
    	print 'not exist $src_file or $bin_run_size or $bin_crc!\n';
    	return;
    }
    
	if (not -e $src_file)
	{
		my $rtn = create_ori_config_file($src_file);
		if ($rtn == 0)
		{
			print "create $src_file failed!", " line ", __LINE__, ".\n";
			return 0;
		}
	}
	
    open (FH,"$src_file") or die "Can't open the file: $src_file $!\n";
    my $file_data=join '', <FH>;
    close FH;
    
   	#先转换成utf-8编码再处理
   	my $file_middle = '';
   	$file_data = Encode::decode_utf8($file_data);
    my $utf8_flag = Encode::is_utf8($file_data);
    if (!$utf8_flag)
    {
    	$file_middle = decode("gb2312", $file_data);
    }
    else
    {
    	$file_middle = $file_data;
    }
	
	my $file_flag = 0;
	
	if ($file_middle =~ s/(<MinLoadMem>\s*)(\d*)(\s*<\/MinLoadMem>)/$1$bin_run_size$3/ig)
	{
		$file_flag = 1;
		print "replace MinLoadMem's value with $bin_run_size.\n";
	}
	
	if ($file_middle =~ s/(<Crc>\s*)([-]*\d*)(\s*<\/Crc>)/$1$bin_crc$3/ig)
	{
		$file_flag = 1;
		print "replace crc's value with $bin_crc.\n";
	}
	
	if ($file_flag == 1)
    {
    	if (!$utf8_flag)
		{
			$file_data = encode("gb2312", $file_middle);
		}
		else
		{
			$file_data = $file_middle;
		}
	
    	open (FH,">$src_file") or die "Can't open the file:$!\n";
    	print FH $file_data;
    	close FH;
    }
	
	return 1;
}

# 更新配置文件
sub update_config_values
{
	my ($src_file_dir, $prj_name, $bin_crc) = @_;
	
	if ((!defined($src_file_dir)) || (!defined($prj_name)) || (!defined($bin_crc)))
    {
    	print 'not exist $src_file_dir or $prj_name or $bin_crc!\n';
    	return 0;
    }
    
    my $src_elf_file = $src_file_dir."/build/release/".$prj_name."/".$prj_name.".axf";
    my $bin_run_size = get_bin_run_size($src_elf_file);
    
	my $config_file = '';
    if (0 != $bin_run_size)
    {
	    $config_file = $src_file_dir."/build/release/".$prj_name."/"."config.xml";
	    update_bin_run_info($config_file, $bin_run_size, $bin_crc);
	}
	else
	{
		print "not update the config file!\n";
	}
	
	my $dst_file = $src_file_dir."/build/release/".$prj_name."/".$prj_name."_config.txt";
	get_config_info_and_write_file($config_file, $dst_file);
	
	return 1;
}

update_config_values($work_dir, $dst_prj_name, $dst_bin_crc);