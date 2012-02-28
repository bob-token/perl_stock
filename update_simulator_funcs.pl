#!/usr/bin/perl -w
use utf8;
use strict;
use Encode;
use Cwd;

# 更新模拟器工程配置文件

=cut
sub print_array
{
	foreach my $member (@_)
	{
		print $member, "\n";
	}
	print "\n";
}
=cut

# 更新源文件列表
sub update_file_to_list
{
    my ($ori_file_list, $file_data_ref, $src_file_path_pre, $out_file_ref, $file_flag_ref, $line_pre) = @_;
       
    if ((!defined($ori_file_list)) || (!defined($file_data_ref)) || (!defined($src_file_path_pre)) || (!defined($out_file_ref)) || (!defined($file_flag_ref)))
    {
        return 0;
    }
    
    if (!defined($line_pre))
    {
        $line_pre = "\t\t\t";
    }
    
    my $file_flag = 0;
    my $item_pre = '<File';
    my $item_flag = 'RelativePath=';
    my $item_end = '</File>';
    my $dst_src_cnt = 0;
    my $new_src_cnt = 0;
    
    my $add_pre;
    my $add_end;
    
    # 获取需要新添加内容项的前后内容字段
    if ($ori_file_list =~ m/(\s*$item_pre\s+$item_flag")[.\\\/\w]+("\s*>\s*$item_end[ \t]*\n)/i)
    {
        $add_pre = $1;
        $add_end = $2;
    }
    else
    {
        $add_pre = "$line_pre$item_pre\n$line_pre\t$item_flag\"";
        $add_end = "\"\n$line_pre\t>\n$line_pre$item_end\n";
    }
    
    # 统计原始文件中源文件项个数
    while ($ori_file_list =~ m/$item_pre\s+$item_flag"[.\/\\\w]+"\s*>\s*$item_end/ig)
    {
        $dst_src_cnt++;
    }
    
    #print "$dst_src_cnt\n";
    
    #print $ori_file_list;
    
    # 如果源文件不存在编译列表中，则加到最后面
    my $src_file_full_path;
    
    # 更新编译源文件表
    foreach my $src_item (@{$file_data_ref})
    {
        chomp $src_item;
        
        # 清除掉空格或制表符
        $src_item =~ s/\s//g; 
        
        if ($src_item =~ m/^\s*$/i)
        {
            #print "blank line.\n";
            next;
        }
        
        # 有效源文件数自增
        $new_src_cnt++;
        
        $src_file_full_path = $src_file_path_pre.$src_item;
        
        # 使用'\'统一路径表示方式
        $src_file_full_path =~ s/\//\\/g; 
        
        #print "$src_item\n";
        
        # 判断是否已经存在该编译项，如果不存在，则置文件标志
        my $item_flag = 0;
        while ($ori_file_list =~ m/<File\s+RelativePath="([.\/\\\w]+)"\s*>\s*<\/File>/ig)
        {
            if ($src_file_full_path eq $1)
            {
                $item_flag = 1;
                #print "match $src_file_full_path.\n";
                last;
            }
        }
        
        if ($item_flag == 0)
        {
            $file_flag = 1;
        }
        
        ${$out_file_ref} .= $add_pre.$src_file_full_path.$add_end;
    }
    
    if ($file_flag == 0)
    {
        if ($dst_src_cnt != $new_src_cnt)
        {
            $file_flag = 1;
        }
    }
    
    ${$file_flag_ref} = $file_flag;
    
    return 1;
}

# 通过控制台命令 dir 获取头文件列表
sub get_head_files
{
    my ($src_file_path, $recursion_flag, $filter, $out_data_ref) = @_;
    
    if ((!(defined $src_file_path)) || (!(defined $recursion_flag)) || (!(defined $filter)) || (!(defined $out_data_ref)))
    {
        return 0;
    }
    
    my $cur_dir = getcwd;
    
    #print "$cur_dir\n";
    
    # 进指定目录
    if (not (chdir $src_file_path))
    {
        print "enter the directory of $src_file_path failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    my $regular_file_path = $src_file_path;
    $regular_file_path =~ s/\\/\\\\/g;
    
    my $head_files;
    if ($recursion_flag == 1)
    {
        $head_files = qx{dir /S /B $filter};
    }
    else
    {
        $head_files = qx{dir /B $filter};
    }
    
    #print "$head_files\n";
    my @head_files = split('\n', $head_files);
    foreach my $head_item (@head_files)
    {
        $head_item =~ s/^s+//;
        $head_item =~ s/s+$//;
		if ($recursion_flag == 1)
		{
			if ($head_item =~ m/(^.*?)$regular_file_path(.*$)/)
			{
				push @{$out_data_ref}, $src_file_path.$2;
			}
		}
        else
		{
			push @{$out_data_ref}, $src_file_path."\\".$head_item;
		}
    }
    
    # 恢复成原始路径
    if (not (chdir $cur_dir))
    {
        print "recover to the directory of $cur_dir failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    return 1;
}

# 更新模拟器工程源文件列表
sub update_pure_simulator_files_list
{
    my ($dst_file_name, $src_list_ref, $head_file_list, $src_file_path_pre) = @_;
        
    if ((!defined($dst_file_name)) || (!defined($src_list_ref)) || (!defined($head_file_list)) || (!defined($src_file_path_pre)))
	{
		return 0;
	}
    
    if (not (-e $dst_file_name))
    {
        print "not exist $dst_file_name!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    open(DST_FILE, "$dst_file_name") or die "Can't open the file:$!\n";
    my $dst_file_data = join '', <DST_FILE>;
    close DST_FILE;
   
    my $file_flag = 0;
    my $def_pre = '<Filter';
    my @def_flag = ('Name="Source Files"', 'Name="Header Files"');
    my $def_end = '</Filter>';
    my $item_pre = '<File';
    my $item_flag = 'RelativePath=';
    my $item_end = '</File>';
    my %src_file_list_hash = ('Name="Source Files"'=>$src_list_ref,
                              'Name="Header Files"'=>$head_file_list);
    my $new_src_list = '';
    
    # 找出源文件列表，如果存在变化则更新  
    foreach my $def_flag (@def_flag)
    {
        if ($dst_file_data =~ m/$def_pre\s+$def_flag[^>]*>[ \t]*\n(([ \t]*$item_pre\s+$item_flag"[.\\\/\w]+"\s*>\s*$item_end[ \t]*\n)*)\s*$def_end/im)
        {
            print "match $def_flag list!\n";
            
            my $modify_flag = 0;
            my $ori_file_list = $1;
            
            if (!defined($ori_file_list))
            {
                $ori_file_list = '';
            }
            
            $new_src_list = '';
            update_file_to_list($ori_file_list, $src_file_list_hash{$def_flag}, $src_file_path_pre, \$new_src_list, \$modify_flag);
            
            if ($modify_flag == 1)
            {
                if (not ($dst_file_data =~ s/($def_pre\s+$def_flag[^>]*>[ \t]*\n)(([ \t]*$item_pre\s+$item_flag"[.\\\/\w]+"\s*>\s*$item_end[ \t]*\n)*)(\s*$def_end)/$1$new_src_list$4/i))
                {
                    print "update $dst_file_data src file list failed!", " line ", __LINE__, ".\n";
                    return 0;
                }
                
                $file_flag = 1;
            }
        }
    }
     
    if ($file_flag == 1)
    {
    	open (DST_FILE,">$dst_file_name") or die "Can't open the file:$!\n";
    	print DST_FILE $dst_file_data;
    	close DST_FILE;
    	print "updates files list.\n";
    }
    else
    {
        print "no files updates.\n";
    }
    
    return 1;
}

# 从列表中获取指定前缀表项
sub get_special_pre_list
{
    my ($file_data_ref, $file_item_pre, $out_list_ref) = @_;
    
    if ((!(defined $file_data_ref)) || (!(defined $file_item_pre)) || (!(defined $out_list_ref)))
    {
        return 0;
    }
    
    #print "$file_item_pre\n";
    
    my $regular_file_item_pre = $file_item_pre;
    $regular_file_item_pre =~ s/\\/\\\\/g;
    #print "$regular_file_item_pre\n";
    #print_array(@{$file_data_ref});
    my $temp_item;
    foreach my $item (@{$file_data_ref})
    {
        $temp_item = $item;
        # 替换掉所有空格
		$temp_item =~ s/^\s+//;
        $temp_item =~ s/\s+$//;
        
        # 如果为空则处理下一个
        if ($temp_item =~ m/^$/i)
        {
            next;
        }
        
        #print "$item\n";
        
        # 如果匹配，则添加到目标数组中
        if ($temp_item =~ m/^.*?$regular_file_item_pre/i)
        {
            #print "$item match!\n";
            push @{$out_list_ref}, $temp_item;
        }   
    }
    
    return 1;
}

# 更新模拟器工程头文件路径列表
sub update_pure_simulator_ini_file
{
    my ($dst_file_name, $inc_list_ref, $def_list_ref, $src_file_path_pre) = @_;
        
    if ((!defined($dst_file_name)) || (!defined($inc_list_ref)) || (!defined($def_list_ref)) || (!defined($src_file_path_pre)))
	{
		return 0;
	}
    
    open(DST_FILE, "$dst_file_name") or die "Can't open the file:$!\n";
    my @dst_file_data = <DST_FILE>;
    close DST_FILE;
    
    my @new_ini_list = ();
    my $file_flag = 0;
    my $add_end = "\"\n";
    my $new_def_cnt = 0;
    my $dst_def_cnt = 0;
    
    # 设置新添加宏定义项的前置内容
    my $item_def_pre_fir = "\/D";
    my $add_def_pre = $item_def_pre_fir.' "';
    
    # 统计模拟器应用端有效宏定义个数
    foreach my $dst_item (@dst_file_data) 
    {   
        if ($dst_item =~ m/$item_def_pre_fir\s+"\w+"?/)
        {
            # 如果为有效路径，则计数递增
            $dst_def_cnt++;
        }
    }
    
    my $src_item_temp;
    
    # 更新编译包含宏列表
    foreach my $src_item (@{$def_list_ref})
    {
        chomp $src_item;
        
        if ($src_item =~ m/^\s*$/ig)
        {
            #print "blank line.\n";
            next;
        }
        
        # 如果为有效路径，则计数递增
        $new_def_cnt++;
        
        $src_item_temp = $src_item;
        
        # 替换掉多余的空格
        $src_item_temp =~ s/\s//g; 
        
        #print "$src_item_temp\n";
        
        # 判断是否已经存在该路径项，如果不存在，则添加到编译列表
        my $item_flag = 0;

        foreach my $dst_item (@dst_file_data) 
        {   
            if ($dst_item =~ m/$item_def_pre_fir\s+"\s*(\w+)\s*"?/)
            {   
                if ($src_item_temp eq $1)
                { 
                    $item_flag = 1;              
                    #print "match $src_file_full_path.\n";
                    last;
                } 
            }
        }
        
        # 如果不存在，则置文件修改标志
        if ($item_flag == 0)
        {
            $file_flag = 1;
        }
        
        # 生成一份新的列表备用
        push @new_ini_list, $add_def_pre.$src_item_temp.$add_end;
    }

    # 设置新添加包含路径项的前置内容
    my $item_inc_pre_fir = "\/I";
    my $add_inc_pre = $item_inc_pre_fir.' "';
    
    my $src_file_full_path;
    my $new_inc_cnt = 0;
    my $dst_inc_cnt = 0;
    
    # 统计模拟器应用端有效路径个数
    foreach my $dst_item (@dst_file_data) 
    {   
        if ($dst_item =~ m/$item_inc_pre_fir\s+"[.\/\\]+([.\/\\\w]+)"?/)
        {
            # 如果为有效路径，则计数递增
            $dst_inc_cnt++;
        }
    }
    
    # 更新编译包含头文件路径表
    foreach my $src_item (@{$inc_list_ref})
    {
        chomp $src_item;
        
        if ($src_item =~ m/^\s*$/ig)
        {
            #print "blank line.\n";
            next;
        }
        
        # 如果为有效路径，则计数递增
        $new_inc_cnt++;
        
        # 替换掉多余的空格
        $src_item =~ s/\s//g;
        $src_file_full_path = $src_file_path_pre.$src_item;
        
        # 使用'\'统一路径表示方式
        $src_file_full_path =~ s/\//\\/g; 
        
        #print "$src_file_full_path\n";
        
        # 判断是否已经存在该路径项，如果不存在，则添加到编译列表
        my $item_flag = 0;

        foreach my $dst_item (@dst_file_data) 
        {   
            if ($dst_item =~ m/$item_inc_pre_fir\s+"[.\/\\]+([.\/\\\w]+)"?/)
            {   
                if ($src_item eq $1)
                { 
                    $item_flag = 1;              
                    #print "match $src_file_full_path.\n";
                    last;
                } 
            }
        }
        
        # 如果不存在，则置文件修改标志
        if ($item_flag == 0)
        {
            $file_flag = 1;
        }
        
        # 生成一份新的列表备用
        push @new_ini_list, $add_inc_pre.$src_file_full_path.$add_end;
    }
    
    #print_array(@new_ini_list);
    
    # 如果数目不一致也要更新表项
    if (($new_inc_cnt != $dst_inc_cnt) || ($new_def_cnt != $dst_def_cnt))
    {
        $file_flag = 1;
    }
    
    my $dst_file_data = ''; 
    if ($file_flag == 1)
    {
        $dst_file_data = join '', @new_ini_list;
    	open (DST_FILE,">$dst_file_name") or die "Can't open the file:$!\n";
    	print DST_FILE $dst_file_data;
    	close DST_FILE;
    	print "update ini list.\n";
    }
    else
    {
        print "no updates in ini list.\n";
    }   

    return 1;
}

# 更新模拟器工程头文件路径列表
sub update_loader_simulator_ini_file
{
    my ($dst_file_name, $inc_list_ref, $def_list_ref, $src_file_path_pre, $file_item_pre) = @_;
	    
    if ((!defined($dst_file_name)) || (!defined($inc_list_ref)) || (!defined($def_list_ref)) || (!defined($src_file_path_pre)) || (!defined($file_item_pre)))
	{
		return 0;
	}
    
    open(DST_FILE, "$dst_file_name") or die "Can't open the file:$!\n";
    my @dst_file_data = <DST_FILE>;
    close DST_FILE;
    
    #print_array(@dst_file_data);
    
    # 获取目的端文件列表
    my @dst_filter_inc_file_data = ();
    my $rtn = get_special_pre_list(\@dst_file_data, $file_item_pre, \@dst_filter_inc_file_data);
    if ($rtn == 0)
    {
        print "get dst filter inc file data failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    my @new_ini_list = ();
    my $file_flag = 0;
    my $add_end = "\"\n";
    
    # 设置新添加包含路径项的前置内容
    my $item_inc_pre_fir = "\/I";
    my $add_inc_pre = $item_inc_pre_fir.' "';
    
    my $src_file_full_path;
    my $new_inc_cnt = 0;
    my $dst_inc_cnt = 0;
    
    # 统计模拟器应用端有效路径个数
    foreach my $dst_item (@dst_filter_inc_file_data) 
    {   
        if ($dst_item =~ m/$item_inc_pre_fir\s+"[.\/\\]+([.\/\\\w]+)"?/)
        {
            # 如果为有效路径，则计数递增
            $dst_inc_cnt++;
        }
    }
    
    # 更新编译包含头文件路径表
    foreach my $src_item (@{$inc_list_ref})
    {
        chomp $src_item;
        
        if ($src_item =~ m/^\s*$/ig)
        {
            #print "blank line.\n";
            next;
        }
        
        # 如果为有效路径，则计数递增
        $new_inc_cnt++;
        
        # 替换掉多余的空格
        $src_item =~ s/^\s+//;
		$src_item =~ s/\s+$//;
        $src_file_full_path = $src_file_path_pre.$src_item;
        
        # 使用'\'统一路径表示方式
        $src_file_full_path =~ s/\//\\/g; 
        
        # 判断是否已经存在该路径项，如果不存在，则添加到编译列表
        my $item_flag = 0;

        foreach my $dst_item (@dst_filter_inc_file_data) 
        {   
            if ($dst_item =~ m/$item_inc_pre_fir\s+"[.\/\\]+([.\/\\\w]+)"?/)
            {   
                if ($src_item eq $1)
                { 
                    $item_flag = 1;              
                    #print "match $src_file_full_path.\n";
                    last;
                } 
            }
        }
        
        # 如果不存在，则置文件修改标志
        if ($item_flag == 0)
        {
            $file_flag = 1;
        }
        
        # 生成一份新的列表备用
        push @new_ini_list, $add_inc_pre.$src_file_full_path.$add_end;
    }
    
    #print_array(@new_ini_list);
    
    # 从原始列表中提取出非指定模式内容
    my @dst_ori_exclude_data = ();
    my $regular_file_item_pre = $file_item_pre;
    $regular_file_item_pre =~ s/\\/\\\\/g;
    foreach my $dst_item (@dst_file_data) 
    {   
        # 如果不匹配，则添加到目标数组中
        if (not ($dst_item =~ m/^.*?$regular_file_item_pre/i))
        {
            #print "$dst_item match!\n";
            push @dst_ori_exclude_data, "$dst_item";
        } 
    }
	
	# 添加一个回车符，避免出现一行存在多个表项情况
    $dst_ori_exclude_data[@dst_ori_exclude_data-1] .= "\n";
    push @dst_ori_exclude_data, @new_ini_list;
    
    # 如果数目不一致也要更新表项
    if ($new_inc_cnt != $dst_inc_cnt)
    {
        $file_flag = 1;
    }
    
    my $dst_file_data = ''; 
    if ($file_flag == 1)
    {
        $dst_file_data = join '', @dst_ori_exclude_data;
    	open (DST_FILE,">$dst_file_name") or die "Can't open the file:$!\n";
    	print DST_FILE $dst_file_data;
    	close DST_FILE;
    	print "update ini list.\n";
    }
    else
    {
        print "no updates in ini list.\n";
    }   

    return 1;
}

# 将字符串数组中的空行或字符串前后的空格过滤掉
sub filter_string_array
{
    my ($src_ref, $dst_ref) = @_;
    
    if ((!defined($src_ref)) || (!defined($dst_ref)))
	{
        print 'not defined  $src_ref or $dst_ref.', " line ", __LINE__, ".\n";
		return 0;
	}
    
    my $temp_item;
    foreach my $item (@{$src_ref})
    {
        $temp_item = $item;
        $temp_item =~ s/^\s+//;
        $temp_item =~ s/\s+$//;
        if (not ($temp_item =~ m/^$/))
        {
            push @{$dst_ref}, $temp_item;
        }
    }
    
    return 1;
}

sub filter_string_array_with_fixed_pre
{
    my ($src_ref, $dst_ref, $file_item_pre) = @_;
	
    return get_special_pre_list($src_ref, $file_item_pre, $dst_ref);
}

# 从def,lis,pth,inc编译文件中整个获取更新模拟器工程用的数据
sub get_whole_src_mak_lists_from_mak_files
{
    my ($src_file_dir, $src_name, $out_put_ref, $add_head_file_flag, $filter_func_ref, $func_para_ref) = @_;
        
    if ((!defined($src_file_dir)) || (!defined($src_name)) || (!defined($out_put_ref)))
	{
		return 0;
	}
    
	if (!defined($add_head_file_flag))
	{
		$add_head_file_flag = 1;
	}
	
    if (!defined($filter_func_ref))
	{
		$filter_func_ref = \&filter_string_array;
	}
	
    my ($src_list_ref, $inc_list_ref, $hd_files_list_ref, $def_list_ref) = @{$out_put_ref};
    if ((!defined($src_list_ref)) || (!defined($inc_list_ref)) || (!defined($hd_files_list_ref)) || (!defined($def_list_ref)))
	{
		return 0;
	}
    
    my $src_file_name = $src_file_dir.'\\'.$src_name.'.lis';
    my $src_ini_file_name = $src_file_dir.'\\'.$src_name.'.inc';
    my $src_def_file_name = $src_file_dir.'\\'.$src_name.'.def';
 
    my @temp_array = ();
    if (not (-e $src_file_name))
    {
        print "not exist $src_file_name.", " line ", __LINE__, ".\n";
        return 0;
    }
    open(SRC_FILE, "$src_file_name") or die "Can't open the file:$!\n";
    @temp_array = <SRC_FILE>;
    close SRC_FILE;
    &{$filter_func_ref}(\@temp_array, $src_list_ref, $func_para_ref);
    
    if (not (-e $src_ini_file_name))
    {
        print "not exist $src_ini_file_name.", " line ", __LINE__, ".\n";
        return 0;
    }
    open(INI_FILE, "$src_ini_file_name") or die "Can't open the file:$!\n";
    @temp_array = <INI_FILE>;
    close INI_FILE;
    &{$filter_func_ref}(\@temp_array, $inc_list_ref, $func_para_ref);
    
    # 获取头文件列表
	if ($add_head_file_flag == 1)
	{
		@temp_array = ();
		my $rtn = 0;
		my @internal = ();
		foreach my $item (@{$inc_list_ref})
		{
			@internal = ();
			$rtn = get_head_files($item, 0, "*.h *.inc", \@internal);
			if ($rtn == 0)
			{
				print "get head file list from $item failed!", " line ", __LINE__, ".\n";
				return 0;
			}
			push @temp_array, @internal;
		}
		filter_string_array(\@temp_array, $hd_files_list_ref);
	}
    
    
    if (-e $src_def_file_name)
    {
        open(DEF_FILE, "$src_def_file_name") or die "Can't open the file:$!\n";
        @temp_array = <DEF_FILE>;
        close DEF_FILE;
        filter_string_array(\@temp_array, $def_list_ref);
    }
    
    return 1;
}

sub get_list_from_make_file_string
{
	my ($src_file_data, $key_info, $output_array_ref) = @_;
	
	if ((not defined $src_file_data) || (not defined $key_info) || (not defined $output_array_ref))
	{
		return 0;
	}
	
	# 内部使用正则表达式
	my $regex = qr{\s*\+=\s*\#*\s*([.\\\/\w]+\s+(\\\s+\#*\s*[.\\\/\w]+\s+)*)};
	while ($src_file_data =~ m/^[ \t]*$key_info$regex/img)
	{
		my $src_list = $1;
		my @middle_array = split /\s\\\s/, $src_list;
		foreach my $item (@middle_array)
		{
			if (not($item =~ m/^\s*\#/))
			{
				push @{$output_array_ref}, $item;
			}
		}
	}
	
	return 1;
}

# 从makefile编译文件中整个获取更新模拟器工程用的数据
sub get_whole_src_mak_lists_from_single_makefile
{
    my ($src_file_dir, $src_name, $out_put_ref, $add_head_file_flag, $filter_func_ref, $func_para_ref) = @_;
        
    if ((!defined($src_file_dir)) || (!defined($src_name)) || (!defined($out_put_ref)))
	{
		return 0;
	}
    
	if (!defined($add_head_file_flag))
	{
		$add_head_file_flag = 1;
	}
	
    if (!defined($filter_func_ref))
	{
		$filter_func_ref = \&filter_string_array;
	}
	
    my ($src_list_ref, $inc_list_ref, $hd_files_list_ref, $def_list_ref) = @{$out_put_ref};
    if ((!defined($src_list_ref)) || (!defined($inc_list_ref)) || (!defined($hd_files_list_ref)) || (!defined($def_list_ref)))
	{
		return 0;
	}
    
    my $src_file_name = $src_file_dir.'\\'.$src_name.'.mak';
	if (not (-e $src_file_name))
    {
        print "not exist $src_file_name.", " line ", __LINE__, ".\n";
        return 0;
    }
 
	open(SRC_FILE, "$src_file_name") or die "Can't open the file:$!\n";
    my $src_mak_data = join('', <SRC_FILE>);
    close SRC_FILE;
 
	# 过滤出编译列表文件
	my @temp_array = ();
	my $list_kind = "SRC_LIST";
	get_list_from_make_file_string($src_mak_data, $list_kind, \@temp_array);
	&{$filter_func_ref}(\@temp_array, $src_list_ref, $func_para_ref);

	# 过滤出头文件包含路径列表
	@temp_array = ();
	$list_kind = "INC_DIR";
	get_list_from_make_file_string($src_mak_data, $list_kind, \@temp_array);
    &{$filter_func_ref}(\@temp_array, $inc_list_ref, $func_para_ref);
    
    # 获取头文件列表
	if ($add_head_file_flag == 1)
	{
		@temp_array = ();
		my $rtn = 0;
		my @internal = ();
		foreach my $item (@{$inc_list_ref})
		{
			@internal = ();
			$rtn = get_head_files($item, 0, "*.h *.inc", \@internal);
			if ($rtn == 0)
			{
				print "get head file list from $item failed!", " line ", __LINE__, ".\n";
				return 0;
			}
			push @temp_array, @internal;
		}
		filter_string_array(\@temp_array, $hd_files_list_ref);
	}
    
    return 1;
}

# 更新模拟器工程相关文件
sub update_pure_simulator_project_files
{
    my ($dst_file_dir, $dst_name, $make_array_ref, $src_file_path_pre, $add_head_file_flag) = @_;
        
    if ((!defined($dst_file_dir)) || (!defined($dst_name)) || (!defined($make_array_ref)) || (!defined($src_file_path_pre)))
	{
		return 0;
	}
	
	if (!defined($add_head_file_flag))
	{
		$add_head_file_flag = 1;
	}
    
    my ($src_file_list_ref, $inc_list_ref, $head_file_list_ref, $def_list_ref) = @{$make_array_ref};
    
    my $rtn = 0;
    my $dst_file_name = $dst_file_dir.'\\'.$dst_name.'.vcproj';
    my $dst_ini_file_name = $dst_file_dir.'\\'.$dst_name.'.ini';
    
	my @head_file_list = ();
	my $head_files_para_ref;
	if ($add_head_file_flag == 1)
	{
		$head_files_para_ref = $head_file_list_ref;
	}
	else
	{
		$head_files_para_ref = \@head_file_list;
	}
	
    $rtn = update_pure_simulator_files_list($dst_file_name, $src_file_list_ref, $head_files_para_ref, $src_file_path_pre);
    if ($rtn != 0)
    {
        return update_pure_simulator_ini_file($dst_ini_file_name, $inc_list_ref, $def_list_ref, $src_file_path_pre);
    }
    else
    {
        return 0;
    }
}

# 更新模拟器工程相关文件
sub update_pure_simulator_project
{
    my ($src_file_dir, $src_name, $dst_file_dir, $dst_name, $src_file_path_pre, $add_head_files_flag) = @_;
        
    if ((!defined($src_file_dir)) || (!defined($src_name)) || (!defined($dst_file_dir)) || (!defined($dst_name)) || (!defined($src_file_path_pre)))
	{
		return 0;
	}
    
	if (!defined($add_head_files_flag))
	{
		$add_head_files_flag = 1;
	}
	
    my $rtn = 0;
    my $dst_file_name = $dst_file_dir.'\\'.$dst_name.'.vcproj';
    my $dst_ini_file_name = $dst_file_dir.'\\'.$dst_name.'.ini';
    my @src_file_list = ();
    my @inc_list = ();
    my @head_file_list = ();
    my @def_list = ();
    my @get_info_array = (\@src_file_list, \@inc_list, \@head_file_list, \@def_list);
    # 从lis,inc,def文件中获取编译所需列表
    $rtn = get_whole_src_mak_lists_from_mak_files($src_file_dir, $src_name, \@get_info_array, $add_head_files_flag);
    if ($rtn == 0)
    {
        print "get make list from $src_file_dir $src_name failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    $rtn = update_pure_simulator_project_files($dst_file_dir, $dst_name, \@get_info_array, $src_file_path_pre, $add_head_files_flag);
    if ($rtn == 0)
    {
		print "update simulator project files failed!", " line ", __LINE__, ".\n";
        return 0;
    }
	
	return 1;
}

sub devenv_build
{
    my ($dst_file_dir, $dst_name) = @_;
	
	if ((!defined($dst_file_dir)) || (!defined($dst_name)))
    {
        return 0;
    }
	
    my $def_dir = "Program Files\\Microsoft Visual Studio 9.0\\Common7\\IDE";
    my $config_path = '.\config.txt';
    my $relative_path = '';
    
    if (-e $config_path)
    {
        open(DST_FILE, "$config_path") or die "Can't open the file:$!\n";
        $relative_path = <DST_FILE>;
        close DST_FILE;
        
        if(!defined($relative_path))
        {
           $relative_path = '';
        }
        else
        {
           $relative_path =~ s/(^\s+)|(\s+$)//g; 
        }
    }
    else
    {
        print "$config_path not find, use default dir=$def_dir";
        $relative_path = $def_dir;
    }
    
    if($relative_path eq '')
    {
        $relative_path = $def_dir;
    }
	
    my $drv_str="CDEFGHIJKLMN";
    my @drv_array=split('', $drv_str);
	my $absolute_path = '';
	my $absolute_path_default = '';
    my $absolute_path_config = '';
    foreach my $drv_ch (@drv_array)
    {
		$absolute_path_default = $drv_ch.':\\'.$def_dir;
		if (-e $absolute_path_default)
        {
			$absolute_path = $absolute_path_default;
            last;
        }
		
        $absolute_path_config = $drv_ch.':\\'.$relative_path;
        if (-e $absolute_path_config)
        {
			$absolute_path = $absolute_path_config;
            last;
        }
    }
    
    if ($absolute_path eq '')
    {
        print "not exist Devenv.exe.\n";
        exit(1);
    }
    
    my $absolute_full_path = $absolute_path."\\devenv";
    my $prj_full_path = $dst_file_dir.'\\'.$dst_name.'.vcproj';
    print "make file: $absolute_full_path.\n"; 
    print "project file: $prj_full_path.\n"; 
    # 将stderr 重定向到 stdout: system("$command 2>&1");
    system("\"$absolute_full_path\" $prj_full_path /build 2>&1");
    #my $parse_info = qx{\"$absolute_full_path\" $prj_full_path /build};
    #print $parse_info;
    return 1;
}

sub update_loader_simulator_files_list
{
    my ($dst_file_name, $src_file_list_ref, $head_file_list_ref, $src_file_path_pre, $file_item_pre) = @_;
	
    if ((!defined($dst_file_name)) || (!defined($src_file_list_ref)) || (!defined($head_file_list_ref)) || (!defined($src_file_path_pre)) || (!defined($file_item_pre)))
	{
		return 0;
	}
    
    if (!(-e $dst_file_name))
    {
        print "not exist $dst_file_name!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    # 将其中以.c 结尾的源文件提取出来
    my @src_file_data = ();
    foreach my $item (@{$src_file_list_ref})
    {
        if ($item =~ m/\.c$/i)
        {
            push @src_file_data, $item;
        }
    }
	
    #print_array(@src_file_data);
    
    open(DST_FILE, "$dst_file_name") or die "Can't open the file:$!\n";
    my $dst_file_data = join('', <DST_FILE>);
    close DST_FILE;
    
    # 找出源文件列表，如果存在变化则更新 (后续再完善比对，确定是否需要更新)    
    my @item_pre_lsit = split('[\\\/]', $file_item_pre);
    my $dir_name = $item_pre_lsit[@item_pre_lsit-1];
    
    my $file_flag = 0;
    my $src_file_flag = 0;
    my $inc_file_flag = 0;
    my $new_src_list = '';
    my $src_filter_name = "src";
    my $inc_filter_name = "inc";
    my $line_file_pre;
    my $files_list;
    
    if ($dst_file_data =~ m/(<Filter\s+Name="$dir_name"\s+>[ \t]*\n([ \t]+))\s*((<Filter\s+Name="\w+"\s+>\s+(<File\s+RelativePath="[.\\\/\w]+"\s+>\s+<\/File>\s+)*<\/Filter>\s+)+)(<\/Filter>)/i)
    { 
        $line_file_pre = "$2\t";
        $files_list = $3;
        print "match $dir_name!", " line ", __LINE__, ".\n";
    }
    else
    {
        print "not find $dir_name!", " line ", __LINE__, ".\n";
        
        # 如果不存在该项，则添加相应filter
        if ($dst_file_data =~ m/\n([ \t]*)<Files>/i)
        {
            my $line_pre = $1;
            $line_file_pre = "$line_pre\t\t\t";
            my $file_struct_begin = "$line_pre\t<Filter\n$line_pre\t\tName=\"$dir_name\"\n$line_pre\t\t>\n";
            my $file_struct_src   = "$line_pre\t\t<Filter\n$line_pre\t\t\tName=\"$src_filter_name\"\n$line_pre\t\t\t>\n$line_pre\t\t</Filter>\n";
            my $file_struct_inc   = "$line_pre\t\t<Filter\n$line_pre\t\t\tName=\"$inc_filter_name\"\n$line_pre\t\t\t>\n$line_pre\t\t</Filter>\n";
            my $file_struct_end   = "$line_pre\t</Filter>\n";
            my $whole_add = $file_struct_begin.$file_struct_inc.$file_struct_src.$file_struct_end;
            if (!($dst_file_data =~ s/(<Files>[ \t]*\n)/$1$whole_add/i))
            {
                print "insert $dir_name filter failed!", " line ", __LINE__, ".\n";
                return 0;
            }
            else
            {
                if ($dst_file_data =~ m/(<Filter\s+Name="$dir_name"\s+>\s+)((<Filter\s+Name="\w+"\s+>\s+(<File\s+RelativePath="[.\\\/\w]+"\s+>\s+<\/File>\s+)*<\/Filter>\s+)+)(<\/Filter>)/i)
                { 
                    $files_list = $2;
                }
                else
                {
                    print "insert $dir_name filter failed!", " line ", __LINE__, ".\n";
                    return 0;
                }
            }
        }
        else
        {
            print "insert $dir_name filter failed!", " line ", __LINE__, ".\n";
            return 0;
        }
    }
        
    my $ori_file_list;
    
    # 将真机源文件列表更新到模拟器工程中
    if ($files_list =~ m/<Filter\s+Name="$src_filter_name"\s+>[^\n]*\n((\s*<File\s+RelativePath="[.\\\/\w]+"\s+>\s+<\/File>[ \t]*\n)*)\s*<\/Filter>/i)
    {
        $ori_file_list = $1;
        $new_src_list = '';
        $src_file_flag = 0;
        update_file_to_list($ori_file_list, \@src_file_data, $src_file_path_pre, \$new_src_list, \$src_file_flag, $line_file_pre);
        if ($src_file_flag == 1)
        {
            if (not ($files_list =~ s/(<Filter\s+Name="$src_filter_name"\s+>[^\n]*\n)((\s*<File\s+RelativePath="[.\\\/\w]+"\s+>\s+<\/File>[ \t]*\n)*)(\s*<\/Filter>)/$1$new_src_list$4/))
            {
                print "replace src file list failed!", " line ", __LINE__, ".\n";
                return 0;
            }
            else
            {
                print "update src file list succese!\n";
            }
        }
        else
        {
            print "no src file list update!\n";
        }
    }
 
    # 将获取的头文件列表更新到模拟器工程中
    if ($files_list =~ m/<Filter\s+Name="$inc_filter_name"\s+>[^\n]*\n((\s*<File\s+RelativePath="[.\\\/\w]+"\s+>\s+<\/File>[ \t]*\n)*)\s*<\/Filter>/i)
    {
        $ori_file_list = $1;
        $new_src_list = '';
        $inc_file_flag = 0;
        update_file_to_list($ori_file_list, $head_file_list_ref, $src_file_path_pre, \$new_src_list, \$inc_file_flag, $line_file_pre);
        if ($inc_file_flag == 1)
        {
            if (not ($files_list =~ s/(<Filter\s+Name="$inc_filter_name"\s+>[^\n]*\n)((\s*<File\s+RelativePath="[.\\\/\w]+"\s+>\s+<\/File>[ \t]*\n)*)(\s*<\/Filter>)/$1$new_src_list$4/))
            {
                print "replace inc file list failed!", " line ", __LINE__, ".\n";
                return 0;
            }
            else
            {
                print "update inc file list succese!\n";
            }
        }
        else
        {
            print "no inc file list update!\n";
        }
    }
    
    if (($src_file_flag == 1) || ($inc_file_flag == 1))
    {
        $file_flag = 1;
    }
    
    if ($file_flag == 1)
    {
        if (not($dst_file_data =~ s/(<Filter\s+Name="$dir_name"\s+>\s+)((<Filter\s+Name="\w+"\s+>\s+(<File\s+RelativePath="[.\\\/\w]+"\s+>\s+<\/File>\s+)*<\/Filter>\s+)+)(<\/Filter>)/$1$files_list$5/i))
        {
            print "replace src and inc file list failed!", " line ", __LINE__, ".\n";
            return 0;
        }
        
        open(DST_FILE, ">$dst_file_name") or die "Can't open the file:$!\n";
        print DST_FILE $dst_file_data;
        close DST_FILE;
    }
    
    return 1;
}

# 更新模拟器工程相关文件
sub update_loader_simulator_project_files
{
    my ($dst_file_dir, $dst_name, $make_array_ref, $src_file_path_pre, $file_item_pre) = @_;
        
    if ((!defined($dst_file_dir)) || (!defined($dst_name)) || (!defined($make_array_ref)) || (!defined($src_file_path_pre)) || (!defined($file_item_pre)))
	{
		return 0;
	}
    
    my ($src_file_list_ref, $inc_list_ref, $head_file_list_ref, $def_list_ref) = @{$make_array_ref};
    
    my $rtn = 0;
    my $dst_file_name = $dst_file_dir.'\\'.$dst_name.'.vcproj';
    my $dst_ini_file_name = $dst_file_dir.'\\'.$dst_name.'.ini';
    
    $rtn = update_loader_simulator_files_list($dst_file_name, $src_file_list_ref, $head_file_list_ref, $src_file_path_pre, $file_item_pre);
    if ($rtn != 0)
    {
        return update_loader_simulator_ini_file($dst_ini_file_name, $inc_list_ref, $def_list_ref, $src_file_path_pre, $file_item_pre);
    }
    else
    {
        return 0;
    }
}

# 更新加载器端模拟器工程相关文件
sub update_loader_simulator_project
{
    my ($src_file_dir, $src_name, $dst_file_dir, $dst_name, $src_file_path_pre, $file_item_pre, $get_list_func_ref) = @_;
        
    if ((!defined($src_file_dir)) || (!defined($src_name)) || (!defined($dst_file_dir)) || (!defined($dst_name)) || (!defined($src_file_path_pre)) || (!defined($file_item_pre)))
	{
		return 0;
	}
	
    if (!defined($get_list_func_ref))
	{
		$get_list_func_ref = \&get_whole_src_mak_lists_from_mak_files;
	}
	
    my $rtn = 0;
    my $dst_file_name = $dst_file_dir.'\\'.$dst_name.'.vcproj';
    my $dst_ini_file_name = $dst_file_dir.'\\'.$dst_name.'.ini';
    my @src_file_list = ();
    my @inc_list = ();
    my @head_file_list = ();
    my @def_list = ();
    my @get_info_array = (\@src_file_list, \@inc_list, \@head_file_list, \@def_list);
	my $add_head_file_flag = 1;
    # 从lis,inc,def文件中获取编译所需列表
    $rtn = &{$get_list_func_ref}($src_file_dir, $src_name, \@get_info_array, $add_head_file_flag, \&filter_string_array_with_fixed_pre, $file_item_pre);
    if ($rtn == 0)
    {
        print "get make list from $src_file_dir $src_name failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    $rtn = update_loader_simulator_project_files($dst_file_dir, $dst_name, \@get_info_array, $src_file_path_pre, $file_item_pre);
    if ($rtn == 0)
    {
		print "update simulator project files failed!", " line ", __LINE__, ".\n";
        return 0;
    }
	
	return 1;
}

1;
