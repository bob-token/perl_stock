my $APP_ROOT_NAME = $ARGV[0];

sub  build_make_file
{
    my ($SDK_INC_PATH, $SDK_SRC_PATH, $SDK_SRC_LIST, $dir_path) = @_;
    
    my $CUR_DIR = "";
    my $CUR_FILE = "";
    my $num = 0;
    my @DIR_STACK;
    
    #清空原有数据
    #${$SDK_INC_PATH} = "";
    #${$SDK_SRC_PATH} = "";
    #${$SDK_SRC_LIST} = "";
    
    my $INC_FLAG = 0;
    my $SRC_FLAG = 0;
    
    push (@DIR_STACK, $dir_path);
    
    while(defined($CUR_DIR = pop(@DIR_STACK)))
    {
        $INC_FLAG = 0;
        $SRC_FLAG = 0;
        
        # 扫描文件夹，加载器头文件列表
        if (!opendir(SDK_DIR, $CUR_DIR))
        {
            print STDOUT "the dir $CUR_DIR is not exits!";
            next;
        }
        
        # 遍历文件目录中的文件
        foreach (readdir(SDK_DIR))
        {
            next if (($_ eq ".") || ($_ eq ".."));
            
            $CUR_FILE = "$CUR_DIR\\$_";
            
            # 将目录入查找栈
            if (-d $CUR_FILE)
            {
                push (@DIR_STACK, $CUR_FILE);
                next;
            }
            
            # 对文件进行处理
            if (m/\w+\.[cC]$/)
            {
                ${$SDK_SRC_LIST} .= "$CUR_FILE\n";
                $SRC_FLAG = 1;
                $num++;
                
                #print STDOUT "find $CUR_FILE ok!\n";
            }
            else
            {
                if (m/\w+\.[hH]$/ || m/\w+\.[iI][nN][cC]$/)
                {
                    $INC_FLAG = 1;
                    $num++;
                }
            }
        }
        
        ${$SDK_INC_PATH} .= "$CUR_DIR\n" if (1 == $INC_FLAG);
        ${$SDK_SRC_PATH} .= "$CUR_DIR\n" if (1 == $SRC_FLAG);
        
        closedir(SDK_DIR);
    }
    
    return $num;
}

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

sub compare_and_write_file_with_neq_result
{
    my ($src_data, $file_name) = @_;
    
    if ((!(defined $src_data)) || (!(defined $file_name)))
    {
        print 'not defined $src_data or $file_name.', " line ", __LINE__, ".\n";
        return 0;
    }
    
    my $wr_flag = 0;
    if (not -e $file_name)
    {
        $wr_flag = 1;
    }
    else
    {
        open FILE, "$file_name";
        my @data = <FILE>;
        close FILE;
        my @src_data = split /\n/, $src_data;
        my $rtn = compare_string_array(\@src_data, \@data);
        if ($rtn != 1)
        {
            $wr_flag = 1;
        }
    }
    
    if ($wr_flag == 1)
    {
        open (FILE, ">$file_name");
        print FILE $src_data;
        close (FILE);
    }
    
    return 1;
}

# 创建纯粹的路径
sub create_full_pure_path
{
	my ($file_full_pure_path) = @_;
	
	if (!defined($file_full_pure_path))
    {
    	print 'not defined $file_full_pure_path.', " line ", __LINE__, ".\n";
    	return 0;
    }
	
	my $rtn;
	my @file_path_last = split(/[\\\/]/, $file_full_pure_path);
 	my $file_full_path = shift @file_path_last;
	if (!(-d $file_full_path))
	{
		$rtn = mkdir($file_full_path, 0755);
		if (!$rtn)
		{
			print "create dir of $file_full_path failed.", " line ", __LINE__, ".\n";
			return 0;
		}
	}
 	
 	# 创建中间目录
 	foreach my $sub_path_str (@file_path_last)
 	{
 		$file_full_path = $file_full_path.'/'.$sub_path_str;
		if (!(-d $file_full_path))
		{
			#print "path $file_full_path not exists.\n";
		    $rtn = mkdir($file_full_path, 0755);
			if (!$rtn)
			{
				print "create dir of $file_full_path failed.", " line ", __LINE__, ".\n";
				return 0;
			}
		}
	}
	
	return 1;
}

# 生成gaf_res.h文件
sub create_res_head_file
{
    my ($file_name) = @_;
    
    if (!(defined $file_name))
    {
        print 'not defined $src_data or $file_name.', " line ", __LINE__, ".\n";
        return 0;
    }
    
    my $rtn;
	my $full_pure_path;
	if ($file_name =~ m/^(.*)[\\\/][^\\\/]+$/)
	{
		$full_pure_path = $1;
		$rtn = create_full_pure_path($full_pure_path);
		if (!$rtn)
		{
			return 0;
		}
	}
	else
	{
		print "the file path of $file_name is invalid!", " line ", __LINE__, ".\n";
		return 0;
	}
    
    my $file_data = <<"__RES_HEAD";

#ifndef _GAF_RES_H_
#define _GAF_RES_H_

typedef enum
{
  ID_STRING_START,
  ID_STRING_END,

  ID_IMAGE_START,
  ID_IMAGE_END,

  ID_COLOR_START,
  ID_COLOR_END,

  ID_RECT_START,
  ID_RECT_END,

  ID_VIDEO_START,
  ID_VIDEO_END,

  ID_AUDIO_START,
  ID_AUDIO_END,

}GAF_RES_ID;

#endif

__RES_HEAD

    open(FILE, ">$file_name") || die "$!";
    print FILE $file_data;
    close(FILE);
    
    return 1;
}

sub main
{
    if (!defined($APP_ROOT_NAME))
    {
        print STDOUT "please input the app name!!!\n";
        exit(0);
    }
    
    my $APP_PATH = "app\\$APP_ROOT_NAME";
    
    if (not -d $APP_PATH)
    {
        print STDOUT "not exist the directory of $APP_PATH.", " line ", __LINE__, ".\n";
        exit(0);
    }
    
    my $APP_INC_PATH = "";
    my $APP_SRC_PATH = "";
    my $APP_SRC_LIST = "";
    
    print STDOUT "update make file begin!\n";
    
    #print STDOUT "[SOURCE FILE]\n";
    
    my $rtn = 0;
    my $res_file = $APP_PATH."\\resource\\gaf_res.h";
    if (!(-e $res_file))
    {
        $rtn = create_res_head_file($res_file);
        if (!$rtn)
        {
            print STDOUT "create the file of $res_file failed!", " line ", __LINE__, ".\n";
            return 0;
        }
    }
    
    # 首先重新统计下加载器的代码
    if (0 == build_make_file (\$APP_INC_PATH, \$APP_SRC_PATH, \$APP_SRC_LIST, "sdk"))
    {
        print STDOUT "error sdk is empty!!\n";
        exit(0);
    }
    
    $APP_INC_PATH .= "\n";
    $APP_SRC_PATH .= "\n";
    $APP_SRC_LIST .= "\n";
    
    # 生成应用的文件路径
    if (0 == build_make_file(\$APP_INC_PATH, \$APP_SRC_PATH, \$APP_SRC_LIST, $APP_PATH))
    {
        print STDOUT "error app is empty!!\n";
        exit(0);
    }
    
    #print STDOUT "[SOURCE FILE]\n\n";
    
    if (not -e "make\\$APP_ROOT_NAME")
    {
        mkdir "make\\$APP_ROOT_NAME";
    }
    
    # 写入到make文件中去
    my $make_def_file = "make\\$APP_ROOT_NAME\\$APP_ROOT_NAME.def";
    my $make_inc_file = "make\\$APP_ROOT_NAME\\$APP_ROOT_NAME.inc";
    my $make_pth_file = "make\\$APP_ROOT_NAME\\$APP_ROOT_NAME.pth";
    my $make_lis_file = "make\\$APP_ROOT_NAME\\$APP_ROOT_NAME.lis";
    
    if (not -e $make_def_file)
    {
        open (FILE, ">$make_def_file");
        close (FILE);
    }
    
    # 更新包含头文件路径列表
    compare_and_write_file_with_neq_result($APP_INC_PATH, $make_inc_file);
    
    # 更新编译文件路径列表
    compare_and_write_file_with_neq_result($APP_SRC_PATH, $make_pth_file);
    
    if (not -e $make_lis_file)
    {
        if (open (FILE, ">$make_lis_file"))
        {
            print FILE $APP_SRC_LIST;
            close (FILE);
        }
    }
    
    print STDOUT "update make file ok!\n";
    
    return 1;
}

main();