#!/usr/bin/perl -w
use strict;

# 该文件可以批量自动化拷贝数据
my $GTRUE = 1;
my $GFALSE = 0;
my $total = 0;

my $src_dir      = $ARGV[0];
my $dst_dir      = $ARGV[1];
my $file_name    = $ARGV[2];
my $file_postfix = '.ipk';

if ((not defined $src_dir) || (not defined $dst_dir) || (not defined $file_name))
{
	print "useage: command src_dir dst_dir project_name";
	exit;
}

sub print_array
{
	foreach my $member (@_)
	{
		print $member, " ";
	}
	print "\n";
}

# 获取目录并进行数据处理
sub process_dir_data
{
    my ($file_func, $src_sub_dir) = @_;
    
    if ((!defined($file_func)) || (!defined($src_sub_dir)))
    {
    	print 'not exist $file_func or $dst_sub_dir';
    	return;
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
           	process_dir_data($file_func, $src_file);
        } 
        else 
        {
            &{$file_func}($src_file) if -e $src_file;
        }
    }
}

sub delete_file
{
	my ($src_full_file_name) = @_;
	if (-e $src_full_file_name)
    {
    	unlink $src_full_file_name;
    }
}

# 获取目录并进行数据拷贝
sub copy_dir_data 
{
    my ($src_sub_dir, $dst_sub_dir) = @_;
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
            	# 如果不存在目的目录，则创建目的目录
            	if (not -e $dst_file)
            	{
            		last if (!mkdir($dst_file, 0755));
            	}
            
            	# 循环拷贝数据
           		copy_dir_data($src_file, $dst_file);
        	}
        } 
        else 
        {
        	if (not -e $dst_file)
			{
				copy_file_data($src_file, $dst_file) if -e $src_file;
			}
        }
    }
}

sub copy_file_data 
{
    my ($src_file, $dst_file) = @_;
	
    open(SOURCE, "$src_file") || die "$!";
    binmode(SOURCE);
	open(DEST, ">$dst_file") || die "$!";
	binmode(DEST);
	print DEST <SOURCE>;
	close(DEST);
	close(SOURCE);
	
	print "copy $src_file to $dst_file.\n";
}

# 创建目录拷贝文件
sub copy_full_path_file
{
	my ($src_full_file_name, $dst_full_file_name) = @_;
	
	if ((!defined($src_full_file_name)) || (!defined($dst_full_file_name)))
    {
    	print 'not exist $src_full_file_name or $dst_full_file_name',"\n";
    	return $GFALSE;
    }
	
	if ((not -e $src_full_file_name) || (-d $src_full_file_name))
	{
		print "$src_full_file_name not exist or is dir.\n";
		return $GFALSE;
	}
	
	my @file_path_first = split(/\//, $dst_full_file_name);
	my @file_path_last = ();
	
	foreach my $temp_str (@file_path_first)
	{
		my @temp_str = split(/\\/, $temp_str);
		push(@file_path_last, @temp_str);
	}
 
 	my $file_full_path = shift @file_path_last;
 	my $pure_file_name = pop @file_path_last;
 	
 	# 创建中间目录
 	foreach my $sub_path_str (@file_path_last)
 	{
 		$file_full_path = $file_full_path.'/'.$sub_path_str;
		if (-e $file_full_path)
		{  
		    #print "path $file_full_path exists.\n"
		} 
		else 
		{
			#print "path $file_full_path not exists.\n";
		    mkdir ($file_full_path);
		}
	}
	
	copy_file_data($src_full_file_name, $dst_full_file_name);
	
	return $GTRUE;
}

sub main 
{
    my $dst_app_root = $dst_dir."/APPBOX";
	my $dst_app_path  = $dst_app_root."/".$file_name;
	my $dst_pack_path = $dst_dir."/".$file_name.$file_postfix;
	my $src_app_path  = $src_dir."/build/release/".$file_name."/".$file_name;
	my $src_pack_path = $src_dir."/build/release/".$file_name."/".$file_name.$file_postfix;
	
	if (not -e $src_app_path)
	{
	    print "error: not exist $src_app_path ! \n";
	    exit;
	}
	
	if (not -e $dst_dir)
	{
	    print "error: not exist $dst_dir ! \n";
	    exit;
	}
	
	if (not -e $dst_app_root)
	{
		mkdir $dst_app_root;
		if (not -e $dst_app_root)
		{
			print "error: not exist $dst_app_root!\n";
			exit;
		}
	}
	
	if (not -e $dst_app_path)
	{
		mkdir $dst_app_path;
		if (not -e $dst_app_path)
		{
			print "error: not exist $dst_app_path!\n";
			exit;
		}
	}
	
	# 删除原有的文件
	process_dir_data(\&delete_file, $dst_app_path);
	
	# 拷贝应用文件夹
	copy_dir_data($src_app_path, $dst_app_path);
	
	# 首先删除T卡中已存在的包
	if (-e $dst_pack_path)
    {
    	unlink $dst_pack_path;
    }
    
    # 拷贝打包文件
    copy_full_path_file($src_pack_path, $dst_pack_path);
    
    print "copy all data success!\n";
}

main;
