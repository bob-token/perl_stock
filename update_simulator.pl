#!/usr/bin/perl -w
use utf8;
use strict;
use Encode;

require("./perl_script/update_simulator_funcs.pl");

my $src_dir = $ARGV[0];
my $src_prj_name = $ARGV[1];
my $dst_dir = $ARGV[2];
my $dst_prj_name = $ARGV[3];
my $relative_path = $ARGV[4];
my $add_head_file_flag = $ARGV[5];
my $build_str = $ARGV[6];

if ((!defined($src_dir)) || (!defined($src_prj_name)) || (!defined($dst_dir)) || (!defined($dst_prj_name)) || (!defined($relative_path)))
{
	print 'not define $src_file_dir, $src_name, $dst_file_dir or $dst_name.'."\n";
}

$src_dir .= "\\$src_prj_name";
$dst_dir .= "\\$dst_prj_name";

my $build_flag = 1;
if (defined($build_str))
{
    if ($build_str =~ m/^no\s*build$/i)
    {
        $build_flag = 0;
    }
}

# 更新工程配置文件
my $rtn = 0;

#---------------------------------------应用开发端使用这段代码-------------------------------------
my $sub_rtn = 0;
$rtn = update_pure_simulator_project($src_dir, $src_prj_name, $dst_dir, $dst_prj_name, $relative_path, $add_head_file_flag);
if ($rtn != 0)
{
    # 标识需要编译才进行编译
    if ($build_flag == 1)
    {
        # 调用VC命令进行编译
        $sub_rtn = devenv_build($dst_dir, $dst_prj_name);
        if ($rtn != 0)
        {
            #print "build project success!\n";
        }
    }
}
else
{
    print "update project files failed!", " line ", __LINE__, ".\n";
}
#--------------------------------------------------------------------------------------------------
