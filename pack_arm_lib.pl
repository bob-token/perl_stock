#!/usr/bin/perl -w
use strict;
use Cwd;

# 将armar 统计OBJ 各段大小的输出文件格式化

sub print_array
{
	foreach my $member (@_)
	{
		print $member, " ";
	}
	print "\n";
}

sub space_to_table 
{
    my $file = shift;
    my $write_flat = 1;
    open (SH,"$file") or die "Can't open the file:$!\n";
    my @file_string=<SH>;
    close(SH); 
    
    # 消除空行
    foreach (@file_string)
    {
    	s/^\s*$//;
    }
   
    # 格式化表头
    grep {if (/^\s*Code\s+RO Data\s+RW Data\s+ZI Data\s+Debug\s+Object Name.*$/) 
    		{
    			#print;
    			chomp;
    			$_ = "Code\tRO Data\tRW Data\tZI Data\tDebug\tObject Name\n";
    		}
    		} @file_string;
    
    # 格式化统计数据
    grep {if (/^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([^\s]+).*$/) 
    		{
    			#print;
    			chomp;
    			$_ = $1."\t".$2."\t".$3."\t".$4."\t".$5."\t".$6."\n";
    		}
    		} @file_string;
	
    if ($write_flat == 1)
    {
    	open (DH,">$file") or die "Can't open the file:$!\n";
    	print DH @file_string;
    	close(DH);
	}
    print "replaced spaces with tables in the file of $file.\n";
}

sub pack_lib_and_stat 
{
    my ($src_list_full_path, $src_obj_path, $dst_lib_full_path, $dst_stat_full_path) = @_;

    if ((!defined($src_list_full_path)) || (!defined($src_obj_path)) || (!defined($dst_lib_full_path)))
    {
    	print 'not define $src_list_full_path, $src_obj_path or $dst_lib_full_path.'."\n";
    	return 0;
    }

    # 如果存在统计文件名，则进行统计
    my $stat_flag = 0;
    if (defined($dst_stat_full_path))
    {
        $stat_flag = 1;
    }

    # 从文件中获取列表
    # 从源文件中读取键值对，并保存在hash表中
    if (not (-e $src_list_full_path))
    {
        print "not exist $src_list_full_path!\n";
        return 0;
    }
    
    open (FH,"$src_list_full_path") or die "Can't open the file of $src_list_full_path:$!\n";
    my @file_data=<FH>;
    close FH;
    
    my @sub_data;
    my $sub_data;
    my $sub_data_cnt;
    my $input_list = '';
    foreach my $data (@file_data) 
    {
        if (!($data =~ m/^\s*$/s))
        {
            @sub_data = split(/[\\\/]/, $data);
            $sub_data_cnt = @sub_data;
            $sub_data = $sub_data[$sub_data_cnt-1];
            $sub_data =~ s/\s//g;
            $sub_data =~ s/(\.)(\w+)($)/$1obj$3/;
            $input_list .= " $sub_data";
        }
    }
    
    my $cur_dir = getcwd;
    
    # 进指定目录
    if (not (chdir $src_obj_path))
    {
        print "enter the directory of  $src_obj_path failed!\n";
        return 0;
    }
    
    # 先删除原来的库
    if (-e $dst_lib_full_path)
    {
        unlink $dst_lib_full_path;
    }
    
    # 打库
    system("armar --create $dst_lib_full_path $input_list");
    if (not (-e $dst_lib_full_path))
    {
        print "pack the library of $dst_lib_full_path failed!\n";
        return 0;
    }
    
    print "pack the library of $dst_lib_full_path success!\n"; 
    
    # 恢复成原始路径
    if (not (chdir $cur_dir))
    {
        print "recover to the directory of $cur_dir failed!\n";
        return 0;
    }
       
    # 统计并处理成excel能处理的格式
    if ($stat_flag != 0)
    {
        system("armar --sizes $dst_lib_full_path > $dst_stat_full_path");
        if (-e $dst_stat_full_path)
        {
            space_to_table($dst_stat_full_path);
        }
    }
    
    return 1;
}

 
my $src_list_file = $ARGV[0];
my $src_obj_path = $ARGV[1];
my $dst_lib_path = $ARGV[2];
my $dst_stat_path = $ARGV[3];

=cut
my $src_list_file = "E:\\project\\111_6253_10A_1032_4\\app_dvlp\\make\\lib\\lib.lis";
my $src_obj_path = "E:\\project\\111_6253_10A_1032_4\\app_dvlp\\build\\obj\\lib";
my $dst_lib_path = "E:\\project\\111_6253_10A_1032_4\\app_dvlp\\sdk\\lib\\app_dvlp.o";
my $dst_stat_path = "E:\\project\\111_6253_10A_1032_4\\app_dvlp\\sdk\\lib\\app_dvlp_stat.txt";
=cut

if ((!defined($src_list_file)) || (!defined($src_obj_path)) || (!defined($dst_lib_path)))
{
	print 'not define $src_list_file, $src_obj_path or $dst_lib_path.'."\n";
	print "please check and do again!\n";
	exit(0);
}

pack_lib_and_stat($src_list_file, $src_obj_path, $dst_lib_path, $dst_stat_path);
