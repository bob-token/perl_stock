#!/usr/bin/perl -w
use utf8;
use strict;
use Cwd;
use File::Path;
use File::Copy;

# 打印数组内容
sub print_array
{
	foreach my $member (@_)
	{
		print $member, "\n";
	}
}


# 获取目录并进行数据拷贝处理
sub process_dir_data_src_to_dst
{
    my ($file_func, $src_sub_dir, $dst_sub_dir, $postfix) = @_;
    my $interl_postfix;
    
    if ((!defined($file_func)) || (!defined($src_sub_dir)) || (!defined($dst_sub_dir)))
    {
    	print 'not exist $file_func、 $src_sub_dir or $dst_sub_dir.', " line ", __LINE__, ".\n";
    	return 0;
    }
    
	$src_sub_dir =~ s/\\/\//g;
	$dst_sub_dir =~ s/\\/\//g;
	
    if (!defined($postfix))
    {
    	$interl_postfix = "";
    }
    else
    {
    	$interl_postfix = $postfix;
    }
    
    #print $src_sub_dir."\n";
    opendir (DIR,"$src_sub_dir") or die "Can't open dir: $!";
    my @file = readdir(DIR);
    closedir(DIR);
    
    # 如果不存在目标文件夹，则创建目标文件夹
    if (not -e $dst_sub_dir)
    {
    	if (!mkdir($dst_sub_dir, 0755))
    	{
    		print "not create dir $dst_sub_dir\n";
    		return;
    	}
    }
    
    foreach (@file)
    {
        next if $_ eq '.' or $_ eq '..';
        my $src_file = "$src_sub_dir/$_";
        my $dst_file = "$dst_sub_dir/$_";
        if (-d $src_file)
        {
            ## !! recursive !!
            if (-e $src_file)
            {
            	# 如果不存在目的目录，则创建目的目录
            	if (not -e $dst_file)
            	{
            		last if (!mkdir($dst_file, 0755));
            	}
            
            	# 循环拷贝数据
           		process_dir_data_src_to_dst($file_func, $src_file, $dst_file, $interl_postfix);
        	}
        } 
        else 
        {
        	$dst_file.=$interl_postfix;
            &{$file_func}($src_file, $dst_file) if -e $src_file;
        }
    }
	
	return 1;
}

# 获取目录并进行数据拷贝处理
sub process_dir_data_src_to_dst_not_with_mkdir
{
    my ($file_func, $src_sub_dir, $dst_sub_dir, $postfix) = @_;
    my $interl_postfix;
    
    if ((!defined($file_func)) || (!defined($src_sub_dir)) || (!defined($dst_sub_dir)))
    {
    	print 'not exist $file_func、 $src_sub_dir or $dst_sub_dir.', " line ", __LINE__, ".\n";
    	return 0;
    }
    
	$src_sub_dir =~ s/\\/\//g;
	$dst_sub_dir =~ s/\\/\//g;
	
    if (!defined($postfix))
    {
    	$interl_postfix = "";
    }
    else
    {
    	$interl_postfix = $postfix;
    }
    
    #print $src_sub_dir."\n";
    opendir (DIR,"$src_sub_dir") or die "Can't open dir: $!";
    my @file = readdir(DIR);
    closedir(DIR);
    
    foreach (@file)
    {
        next if $_ eq '.' or $_ eq '..';
        my $src_file = "$src_sub_dir/$_";
        my $dst_file = "$dst_sub_dir/$_";
        if (-d $src_file)
        {
            ## !! recursive !!
            if (-e $src_file)
            {
            	# 循环拷贝数据
           		process_dir_data_src_to_dst_not_with_mkdir($file_func, $src_file, $dst_file, $interl_postfix);
        	}
        } 
        else 
        {
        	$dst_file.=$interl_postfix;
            &{$file_func}($src_file, $dst_file) if -e $src_file;
        }
    }
	
	return 1;
}

# 对指定目录进行数据处理
sub process_dir_data
{
    my ($file_func, $src_sub_dir, $dir_flag) = @_;
    
    if ((!defined($file_func)) || (!defined($src_sub_dir)))
    {
    	print 'not defined $file_func or $src_sub_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
	if (not defined $dir_flag)
	{
		$dir_flag = 0;
	}
	
    opendir (DIR,"$src_sub_dir") or die "Can't open dir: $!";
    my @file = readdir(DIR);
    closedir(DIR);
    
    foreach (@file)
    {
        next if $_ eq '.' or $_ eq '..';
        my $src_file = "$src_sub_dir/$_";
        if (-d $src_file)
        {
           	# 循环处理数据
			if ($dir_flag == 1)
			{
				&{$file_func}($src_file);
			}
			
           	process_dir_data($file_func, $src_file);
        } 
        else 
        {
            &{$file_func}($src_file) if -e $src_file;
        }
    }
	
	return 1;
}

# 创建目录拷贝文件
sub copy_full_path_file
{
	my ($src_full_file_name, $dst_full_file_name, $copy_func_ref) = @_;
	
	if ((!defined($src_full_file_name)) || (!defined($dst_full_file_name)))
    {
    	print 'not exist $src_full_file_name or $dst_full_file_name',"\n";
    	return 0;
    }
	
	if (not defined $copy_func_ref)
	{
		$copy_func_ref = \&copy;
	}
	
	if ((not -e $src_full_file_name) || (-d $src_full_file_name))
	{
		print "$src_full_file_name not exist or is dir.\n";
		return 0;
	}
	
	my $rtn;
	my $full_pure_path;
	if ($dst_full_file_name =~ m/^(.*)[\\\/][^\\\/]+$/)
	{
		$full_pure_path = $1;
		if (!(-d $full_pure_path))
		{
			$rtn = mkpath($full_pure_path);
			if (!$rtn)
			{
				return 0;
			}
		}
	}
	else
	{
		print "the file path of $dst_full_file_name is invalid!", " line ", __LINE__, ".\n";
		return 0;
	}
	
	&{$copy_func_ref}($src_full_file_name, $dst_full_file_name);
	print "copy $src_full_file_name to dst_full_file_name.\n";
	
	return 1;
}

# 比较两个数组是否相等
sub compare_string_array
{
    my ($fir_array_ref, $sec_array_ref) = @_;
    
    if ((!(defined $fir_array_ref)) || (!(defined $sec_array_ref)))
    {
        print 'not defined $fir_array_ref or $sec_array_ref.', " line ", __LINE__, ".\n";
        return 0;
    }

    my $eq_flag = 0;
    my $fir_cnt = 0;
    my $sec_cnt = 0;
    
    # 统计第一个项目有效个数
    foreach my $fir_item (@{$fir_array_ref}) 
    {
        if (!($fir_item =~ m/^\s*$/))
        {
            $fir_cnt++;
        }
    }
    
    my $temp_item;
    my $item_eq_flag = 0;
    # 更新编译包含宏列表
    foreach my $sec_item (@{$sec_array_ref})
    {
        $temp_item = $sec_item;
        
        $temp_item =~ s/^\s+//;
        $temp_item =~ s/\s+$//;
        
        if ($temp_item =~ m/^$/)
        {
            next;
        }
        
        # 如果为有效路径，则计数递增
        $sec_cnt++;
        
        my $temp_item_1;
        $item_eq_flag = 0;
        foreach my $fir_item (@{$fir_array_ref}) 
        {
            $temp_item_1 = $fir_item;
            $temp_item_1 =~ s/^\s+//;
            $temp_item_1 =~ s/\s+$//;
            
            if ($temp_item eq $temp_item_1)
            { 
                $item_eq_flag = 1;          
                #print "match $temp_item.\n";
                last;
            } 
        }
        
        # 如果不存在，则置文件修改标志
        if ($item_eq_flag == 0)
        {
            return 0;
        }
    }
    
    if ($fir_cnt != $sec_cnt)
    {
        return 0;
    }
    
    return 1;
}

# 进指定目录执行某种操作
sub entry_special_dir_and_process
{
    my ($src_dir, $func_ref, $para_ref) = @_;
    
    if ((!defined($src_dir)) || (!defined($func_ref)))
    {
    	print 'not defined $src_dir or $func_ref!'," line ", __LINE__, ".\n";
    	return 0;
    }
    
    if (not -e $src_dir)
    {
        print "not exist $src_dir!", " line ", __LINE__, ".\n";
    	return 0;
    }
    
    my $cur_dir = getcwd;
    
    # 进指定目录
    if (not (chdir $src_dir))
    {
        print "enter the directory of $src_dir failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    &{$func_ref}($para_ref);
    
    # 恢复成原始路径
    if (not (chdir $cur_dir))
    {
        print "recover to the directory of $cur_dir failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    return 1;
}

# 执行某条命令
sub run_commond_func
{
    my ($para_ref) = @_;
    
    if (not defined $para_ref)
    {
        print 'not defined $para_ref!'," line ", __LINE__, ".\n";
        return 0;
    }
    
	my ($commond, $rtn_str_ref) = @{$para_ref};
	if (not defined $commond)
    {
        print 'not defined $commond!'," line ", __LINE__, ".\n";
        return 0;
    }
	
	if (not defined $rtn_str_ref)
	{
		system("$commond");
	}
    else
	{
		${$rtn_str_ref} = qx{$commond};
	}
    
    return 1;
}

# 进指定目录运行系统命令
sub entry_special_dir_and_run_commond
{
    my ($src_dir, $commond, $rtn_str_ref) = @_;
	
    my @para = ($commond, $rtn_str_ref);
    entry_special_dir_and_process($src_dir, \&run_commond_func, \@para);
    
    return 1;
}

sub adp_str_val_to_use_in_regex
{
	my ($src_str, $dst_str_ref) = @_;
	
	if ((not defined $src_str) || (not defined $dst_str_ref))
    {
        print 'not defined $src_str or $dst_str_ref!'," line ", __LINE__, ".\n";
        return 0;
    }
    
	${$dst_str_ref} = $src_str;
	${$dst_str_ref} =~ s/\\/\\\\/g;
	${$dst_str_ref} =~ s/\$/\\\$/g;
	${$dst_str_ref} =~ s/\^/\\\^/g;
	${$dst_str_ref} =~ s/\(/\\\(/g;
    ${$dst_str_ref} =~ s/\)/\\\)/g;
	${$dst_str_ref} =~ s/\+/\\\+/g;
	
	return 1;
}

# 通用修改保存文件函数
# 输入参数:
# $file_name 全路径文件名;
# $gbk_flag 1 表示为gbk编码，0 表示非gbk编码;
# $process_func_ref 处理函数指针，其前两个参数分别为字符串和是否修改标识;
# $para_ref 处理函数对应参数;
sub modify_file_data
{
    my ($file_name, $gbk_flag, $process_func_ref, $para_ref) = @_;
    
    if ((!defined($file_name)) || (!defined($gbk_flag)) || (!defined($process_func_ref)))
    {
    	print 'not defined $file_name, $gbk_flag or $process_func_ref!'," line ", __LINE__, ".\n";
		return 0;
    }
    
	if (not -e $file_name)
	{
		print "not exist $file_name!"," line ", __LINE__, ".\n";
		return 0;
	}
	
    open (FH,"$file_name") or die "Can't open the file:$!\n";
    binmode(FH);
    my $file_data=join '', <FH>;
    close FH;
    
    my $file_middle;
	if ($gbk_flag == 1)
	{
		$file_middle = decode("gbk", $file_data);
	}
	else
	{
		$file_middle = $file_data;
	}

	# 对文件进行处理
	my $file_flag = 0;
	&{$process_func_ref}(\$file_middle, \$file_flag, $para_ref);
    
    if ($file_flag == 1)
    {
		if ($gbk_flag == 1)
		{
			$file_data = encode("gbk", $file_middle);
		}
		else
		{
			$file_data = $file_middle;
		}
		
    	open (FH,">$file_name") or die "Can't open the file:$!\n";
    	binmode(FH);
    	print FH $file_data;
    	close FH;
    }
	
	return 1;
}

1;
