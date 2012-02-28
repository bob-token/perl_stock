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
my $file_item_pre = $ARGV[5];

if ((!defined($src_dir)) || (!defined($src_prj_name)) || (!defined($dst_dir)) || (!defined($dst_prj_name)) || (!defined($relative_path)))
{
	print 'not define $src_file_dir, $src_name, $dst_file_dir or $dst_name.'."\n";
}

$src_dir .= "\\$src_prj_name";
$dst_dir .= "\\$dst_prj_name";

#-----------------------------------------加载器端使用这段代码--------------------------------------
update_loader_simulator_project($src_dir, $src_prj_name, $dst_dir, $dst_prj_name, $relative_path, $file_item_pre, \&get_whole_src_mak_lists_from_single_makefile);
#--------------------------------------------------------------------------------------------------
