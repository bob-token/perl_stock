#!/usr/bin/perl -w
use utf8;
use strict;
use Cwd;
use File::Path;
use File::Compare;
use File::Copy;

require "./perl_script/dir_common_process.pl";
require "./perl_script/update_simulator_funcs.pl";

# ���� svn ����
# ��֮ǰ svn Ŀ¼�������Ա�
# ����svnĿ¼���˵�.svn�ļ�����hash�����ʽ����,����ϵ�Ŀ¼����hash�����Ҳ�����
# ��ֱ��ɾ������Ӧ�ļ���Ŀ¼��
# �����������ļ��ԱȺͿ����Ĳ�����ͬ�����֮�󣬸���֮ǰ�����svnĿ¼�ļ�Ϊ�����ļ����Ա����´αȶ�
# ���������м������˺�Ӧ�ö˵ı���

=cut

my $svn_path = 'F:\SandBox\LM\code\u+\117_52-11B-1132';
my $bak_path = 'E:\project\integration_backup\117_52-11B-1132';
my $dst_path = 'E:\project\117_H0004-C902-52-11b_i';
my $obj_relative_path = 'build\PUBLIC\gprs\MT6252o';
my $hw_and_sw_ver = '6252_11B';

=cut

my $svn_path = $ARGV[0];
my $bak_path = $ARGV[1];
my $dst_path = $ARGV[2];
my $obj_relative_path = $ARGV[3];
my $hw_and_sw_ver = $ARGV[4];



my %file_info_hash = ();
sub recoder_files_info
{
    my ($file_name) = @_;
    
    if (not defined $file_name)
    {
        print 'not defined $file_name!', " line ", __LINE__, ".\n";
        return 0;
    }
    
    my $inner_path = $svn_path;
    $inner_path =~ s/\\/\//g;
    adp_str_val_to_use_in_regex($inner_path, \$inner_path);
    $file_name =~ s/\\/\//g;
    if (not ($file_name =~ m/\.svn/i))
    {
        if ($file_name =~ m/^$inner_path\/(.*)$/i)
        {
            if (defined $1)
            {
                $file_info_hash{$1} = 1;
            }
        }
    }
    
    return 1;
}

# ɾ��Ŀ���ļ����Լ������ļ��������svn������ļ�
sub delete_redundant_files
{
    my ($file_name) = @_;
    
    if (not defined $file_name)
    {
        print 'not defined $file_name!', " line ", __LINE__, ".\n";
        return 0;
    }
    
    my $inner_path = $bak_path;
    $inner_path =~ s/\\/\//g;
    adp_str_val_to_use_in_regex($inner_path, \$inner_path);
    $file_name =~ s/\\/\//g;
    my $dst_file_path = $dst_path;
    $dst_file_path =~ s/\\/\//g;
    my @file_path;
    if (not ($file_name =~ m/\.svn/i))
    {
        if ($file_name =~ m/^$inner_path\/(.*)$/i)
        {
            if (defined $1)
            {
                $dst_file_path = $dst_file_path."/".$1;
                @file_path = ($file_name, $dst_file_path);
                foreach my $item (@file_path)
                {
                    if (not defined $file_info_hash{$1})
                    {
                        if (-e $item)
                        {
                            if (-d $item)
                            {
                                rmtree($item);
                            }
                            else
                            {
                                unlink $item;
                            }
                        }
                    } 
                }    
            }   
        }
    }
    
    return 1;
}

sub update_src_file
{
    my ($src_file, $dst_file) = @_;
	
	if ((!defined($src_file)) || (!defined($dst_file)))
    {
    	print 'not defined $src_file or $dst_file!'," line ", __LINE__, ".\n";
    	return 0;
    }
    
    if ($src_file =~ m/\.svn/i)
    {
        return 1;
    }
    
    if ((not -e $src_file) || (-d $src_file))
    {
        print "not exist $src_file or is a directory!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    if ((-e $dst_file) && (!(-d $dst_file)))
    {
        # �Ƚ��ļ���һ�£��򿽱�
        my $rtn = compare($src_file, $dst_file);
        if ($rtn == 1)
        {
            copy($src_file, $dst_file);
			print "copy $src_file to $dst_file.\n";
        }
    }
    else
    {
        copy_full_path_file($src_file, $dst_file);
    }
    
    return 1;
}

sub delete_obj_list
{
    my ($list_ref) = @_;
    
    if (not defined $list_ref)
    {
        print 'not defined $list_ref!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    foreach my $item (@{$list_ref})
    {
        if (-e $item)
        {
            unlink $item;
            print "delete $item.\n"
        }
    }
    
    return 1;
}

sub delete_ld_obj
{
    my ($src_dir) = @_;
    
    if (!defined($src_dir))
    {
    	print 'not defined $src_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    if (not -e $src_dir)
    {
        print 'not exist $src_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    my $ld_root_dir = $src_dir;
    my $ld_compile_model = "mmi_app";
    my $ld_model_make_dir = $ld_root_dir."\\make\\plutommi\\".$ld_compile_model;
    my $src_sub_dir = "plutommi\\mmi\\Extra\\";
    my $ld_src_file_dir;
    my @to_del_file_list = ();
    my @src_list_array = ();
    my @inc_list_array = ();
    my @hd_files_list_array = ();
    my @def_list_array = ();
    my @out_put_array = (\@src_list_array, \@inc_list_array, \@hd_files_list_array, \@def_list_array);
    my @to_del_model = ("GafLoader", "HomeApp", "MuseFeeNet");
    foreach my $item (@to_del_model)
    {
        @src_list_array = ();
        @inc_list_array = ();
        @hd_files_list_array = ();
        @def_list_array = ();
        @out_put_array = (\@src_list_array, \@inc_list_array, \@hd_files_list_array, \@def_list_array);
        $ld_src_file_dir = $src_sub_dir.$item;
        get_whole_src_mak_lists_from_single_makefile($ld_model_make_dir, $ld_compile_model, \@out_put_array, 0, \&filter_string_array_with_fixed_pre, $ld_src_file_dir);
        push @to_del_file_list, @src_list_array;
    }
    
    my @to_del_obj = ();
    my $obj_name;
    my $dst_name;
    my @item_array = ();
    foreach my $item (@to_del_file_list)
    {
        if ($item =~ m/\.c$/i)
        {
            @item_array = split /[\\\/]/, $item;
            $obj_name = $item_array[@item_array-1];
            $obj_name  =~ s/\.\w+$/\.obj/;
            push @to_del_obj, $obj_name;
        }
    }
    
    my $obj_path = $ld_root_dir."\\".$obj_relative_path."\\".$ld_compile_model;
    entry_special_dir_and_process($obj_path, \&delete_obj_list, \@to_del_obj);
    
    return 1;
}

sub update_muse_hw_sw_ver
{
    my ($file_data_ref, $file_flag_ref) = @_;
    
    if ((!(defined $file_data_ref)) || (!(defined $file_flag_ref)))
    {
    	print 'not defined $src_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    my $ver = $hw_and_sw_ver;
    
    # �ж��Ƿ����52_11B�궨�壬��������ڣ���ע�����к궨�壬���򿪸ú���
    if (!(${$file_data_ref} =~ m/^\s*\#define\s+MUSE_$hw_and_sw_ver/im))
    {
        # ��ע��ԭʼ�ĺ궨��
        if (${$file_data_ref} =~ s/^\s*\#define\s+MUSE_\d+[a-z]?_\d+[a-z]+/\/\/$&/im)
        {
            ${$file_flag_ref} = 1;
            print "close original macro define!\n";
        }
        
        # �ҵ�52_11B�궨�崦������ſ�
        if (${$file_data_ref} =~ s/^\/{2}\s*(#define\s+MUSE_$hw_and_sw_ver)/$1/im)
        {
            ${$file_flag_ref} = 1;
            print "open the new macro define!\n";
        }
    }
    
    # �ж��Ƿ����__MUSE_LOG_SWITCH_ON �궨�壬������ڣ���ע���궨��
    if (${$file_data_ref} =~ s/^\s*\#define\s+__MUSE_LOG_SWITCH_ON/\/\/$&/im)
    {
    		${$file_flag_ref} = 1;
        print "close the macro define of __MUSE_LOG_SWITCH_ON!\n";
    }
    
    # �ж��Ƿ����__MUSE_LOG_TO_FILE_ON �궨�壬������ڣ���ע���궨��
    if (${$file_data_ref} =~ s/^\s*\#define\s+__MUSE_LOG_TO_FILE_ON/\/\/$&/im)
    {
    		${$file_flag_ref} = 1;
        print "close the macro define of __MUSE_LOG_TO_FILE_ON!\n";
    }
    
    # �ж��Ƿ����__SOLAR_WAP_LOG_VERSION__ �궨�壬������ڣ���ע���궨��
    if (${$file_data_ref} =~ s/^\s*\#define\s+__SOLAR_WAP_LOG_VERSION__/\/\/$&/im)
    {
    		${$file_flag_ref} = 1;
        print "close the macro define of __SOLAR_WAP_LOG_VERSION__!\n";
    }   
    
    return 1;
}

sub check_and_update_special_files
{
    my ($src_dir) = @_;
    
    if (!defined($src_dir))
    {
    	print 'not defined $src_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    if (not -e $src_dir)
    {
        print 'not exist $src_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    my $muse_macro_file_relative_path = 'plutommi\mmi\Extra\MuseFeeNet\Common\inc\Muse_MacroDefs.h';
    my $full_name = $src_dir.'\\'.$muse_macro_file_relative_path;
    modify_file_data($full_name, 1, \&update_muse_hw_sw_ver);
    
    return 1;
}

sub build_project
{
    my ($src_dir) = @_;
    
    if (!(defined $src_dir))
    {
    	print 'not defined $src_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    if (not -e $src_dir)
    {
        print 'not exist $src_dir!', " line ", __LINE__, ".\n";
    	return 0;
    }
    
    # �����������
    # ɾ����ԭ�е�obj�ļ�
    my $ld_root_dir = $src_dir."\\ld_dvlp\\code";
    delete_ld_obj($ld_root_dir);
    
    # ���ͷ�ļ��������и���
    check_and_update_special_files($ld_root_dir);
    
    # ������������������
    my $ld_rtn_str = '';
    my $ld_build_line = "build.bat remake";
    
    entry_special_dir_and_run_commond($ld_root_dir, $ld_build_line, \$ld_rtn_str);
    print $ld_rtn_str;
    if (!($ld_rtn_str =~ m/Succeed\s+to\s+link/i))
    {
        return 0;
    }
    
    # ����Ӧ�ö�
    my $client_root_dir = $src_dir."\\app_dvlp";
    my @app_array = ("fee", "hm", "vm", "htm");
    my $build_file = "build.bat ";
    my $build_res_file = "build_res.bat ";
    my $client_build_line;
    my $client_build_res;
    my $app_obj_path;
    my $rtn_str = ();
    foreach my $item (@app_array)
    {
        # ɾ������obj�ļ�
        $app_obj_path = $client_root_dir."\\build\\obj\\".$item;
        rmtree($app_obj_path);
        
        $client_build_res = $build_res_file.$item." 240X320";
        entry_special_dir_and_run_commond($client_root_dir, $client_build_res, \$rtn_str);
        print $rtn_str;
        $client_build_line = $build_file.$item;
        entry_special_dir_and_run_commond($client_root_dir, $client_build_line, \$rtn_str);
        print $rtn_str;
        if (!($rtn_str =~ m/Link\s+Success/i))
        {
            return 0;
        }
    }
    
    return 1;
}

sub copy_non_svn_files
{
    my ($src_file, $dst_file) = @_;
    
    if ((not defined $src_file) || (not defined $dst_file))
	{
		print 'not defined $src_file or dst_file.', " line ", __LINE__, ".\n";
		return 0;
	}
	
	if (not -e $src_file)
	{
		print 'not exist $src_file.', " line ", __LINE__, ".\n";
		return 0;
	}
    
    if (not ($src_file =~ m/\.svn/i))
    {
        copy_full_path_file($src_file, $dst_file);
    }
    
    return 1;
}

sub update_and_build
{
    my $rtn = 0;

    # ���� svn ����
    my $svn_update = "TortoiseProc.exe /command:update /path:\"$svn_path\" /closeonend:1";
    system("$svn_update");

    # ����svn�ļ��У���¼�����ļ��б�
    $rtn = process_dir_data(\&recoder_files_info, $svn_path, 1);
    if ($rtn == 0)
    {
        print "recoder_files_info failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    
    # ����backup�ļ��У�ɾ��Ŀ���ļ��м������ļ����ж����ļ�
    print "delete redundant files begin.\n";
    $rtn = process_dir_data(\&delete_redundant_files, $bak_path, 1);
    if ($rtn == 0)
    {
        print "delete_redundant_files failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    print "delete redundant files end.\n";
   
    # ͬ�� svn ���ļ������빤��
    print "update files begin.\n";
    $rtn = process_dir_data_src_to_dst_not_with_mkdir(\&update_src_file, $svn_path, $dst_path);
    if ($rtn == 0)
    {
        print "update_src_file failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    print "update files end.\n";
     
    # ���±����ļ���
    print "update backup files begin.\n";
    $rtn = process_dir_data_src_to_dst_not_with_mkdir(\&update_src_file, $svn_path, $bak_path);
    if ($rtn == 0)
    {
        print "update backup files failed!", " line ", __LINE__, ".\n";
        return 0;
    }
    print "update backup files end.\n";
        
    # ���й��̱���
    return build_project($dst_path);
}

update_and_build;