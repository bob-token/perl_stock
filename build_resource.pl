#!/usr/bin/perl -w
# use strict;
use File::Path;


# ���ļ����������Զ�����������
my $TRUE = 1;
my $FALSE = 0;

my $app_name = $ARGV[0];
my $app_reso = $ARGV[1];

# ͼƬ����ӳ��
my %IMG_TYPE_MAP =
(
    'jpg' => 'GAF_IMG_TYPE_JPG',
    'jpeg' => 'GAF_IMG_TYPE_JPG',
    'gif' => 'GAF_IMG_TYPE_GIF',
    'bmp' => 'GAF_IMG_TYPE_BMP',
    'png' => 'GAF_IMG_TYPE_PNG',
);

# ��ý���ļ�����ӳ��
my %MEDIA_TYPE_MAP = 
(
    'mid' => 'GMDI_FORMAT_MIDI',
    '3gp' => 'GMDI_FORMAT_3GP',
);

# ��Դ���ļ�·��
my $RES_ROOT_PATH = "";
my $RES_LANUAGE_PATH = "";
my $RES_SKIN_PATH = "";
my $RES_DES_FILE_PATH = "";

if ((not defined $app_name) || (not defined $app_reso))
{
	print "useage: command app_name app_reso";
	exit;
}

my $src_dir = ".\\app\\".$app_name ."\\resource";
my $dst_dir = ".\\build\\release\\".$app_name.'\\'.$app_name."\\resource";
my $reso_dir = $src_dir.'\\'.$app_reso;
$reso_dir =~ s/\\/\\\\/g;
$reso_dir =~ s/\./\\\./g;

sub check_file_name
{
	my ($des_name) = @_;
	my $bfound = $FALSE;
	my @del_pre_list = ("string","rect","audio","color","image","video");
	my @del_last_list = (".xml",".xml.bak",".tmp",".tmp.bak");
	
	foreach my $next_name(@del_last_list)
	{
		foreach my $pre_name (@del_pre_list)
		{
			my $fullname =  $pre_name;
			$fullname .= $next_name;
			
			if($fullname eq $des_name)
			{
				$bfound = $TRUE;
				last;
			}
		}
	
		if($bfound == $TRUE)
		{
			last;
		}
	}
	

	if(($bfound == $FALSE ) && ($des_name eq "Thumbs.db"))
	{
		$bfound = $TRUE;
	}

	return $bfound;
}

# ��ȡĿ¼���������ݿ���
sub copy_dir_data 
{
    my ($src_sub_dir, $dst_sub_dir) = @_;
    opendir (DIR,"$src_sub_dir") or die "Can't open dir: $!";
    my @file = readdir(DIR);
    closedir(DIR);

    foreach (@file)
    {
        next if $_ eq '.' or $_ eq '..' or $_ eq '.svn';
	
        my $src_file = "$src_sub_dir\\$_";
        my $dst_file = "$dst_sub_dir\\$_";
        if (-d $src_file)
        {
	    if(not($src_file =~ m/$reso_dir/i))
	    {
		next;
	    }

	    
            ## !! recursive !!
            if (-e $src_file)
            {
            	# ���������Ŀ��Ŀ¼���򴴽�Ŀ��Ŀ¼
            	if (not -e $dst_file)
            	{
			last if (!mkdir($dst_file, 0755));
            	}
            
            	# ѭ����������
           	copy_dir_data($src_file, $dst_file);
            }
        } 
        else 
        {
		if(check_file_name($_) == $TRUE)
		{
			next;
		}

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

sub start_copy
{
	my ($src_dir, $dst_dir,$app_reso) = @_;
	
	if (not -e $src_dir)
	{
	    print "error: not exist $src_dir ! \n";
	    exit;
	}
	
	# ����Ŀ¼
	rmtree($dst_dir);
	mkpath($dst_dir); 
#	mkdir $dst_dir;
	if (not -e $dst_dir)
	{
		print "error: not exist $dst_dir!\n";
		exit;
	}
	
	# ɾ������Ҫ�������ļ�
	if (-e "$src_dir\\gaf_res.c")
	{
		unlink "$src_dir\\gaf_res.c";
	}
	
	# ����Ӧ���ļ���
	copy_dir_data($src_dir,$dst_dir);

    
	print "copy all data success!\n";
}

# ���ֽ�Ϊ��λ���ļ���ȡ��������
sub read_file_by_byte
{
    my ($data_file, $out_array_ref) = @_;
    my $i;
    my $buf;
    
    if ((!defined($data_file)) || (!defined($out_array_ref)))
    {
        return 0;
    }
    
    my $file_size = -s $data_file;
    
    if (open(DATAGET, $data_file))
    {
        
        binmode(DATAGET);
        for ($i = 0; $i < $file_size; $i++)
        {	
        read(DATAGET, $buf, 1);
        ${$out_array_ref}[$i] = hex(unpack("H2",$buf));
        }
        close(DATAGET);
        return 1;
    }
    else
    {
        return 0;
    }
}

# ���ֽ�����ת����c��ʽ�����飬�罫"ab",ת����"0x61, 0x62"
sub array_to_c_array_string
{
    my ($data_array_ref, $dst_val_ref) = @_;
    
    if ((!defined($data_array_ref)) || (!defined($dst_val_ref)))
    {
        return 0;
    }
    
    my $i = 0;
    my $length = @{$data_array_ref};
    if ($length == 0)
    {
        return 0;
    }
    
    for ($i = 0; $i < $length - 1; $i++)
    {
        ${$dst_val_ref} .= sprintf("0x%02x,", @{$data_array_ref}[$i]);
        if (15 == $i%16)
        {
            ${$dst_val_ref} .= "\n";
        }
        else
        {
            ${$dst_val_ref} .= " ";
        }
    }
    
    ${$dst_val_ref} .= sprintf("0x%02x\n", @{$data_array_ref}[$i]);
    
    return 1;
}

# ���ļ�ת����C��������
sub file_to_c_array_string
{
    my ($src_data_file, $array_type, $array_name, $dst_val_ref) = @_;
    
    if ((!defined($src_data_file)) || (!defined($array_type)) || (!defined($array_name)) || (!defined($dst_val_ref)))
    {
        return 0;
    }
    
    my $rtn = 0;
    my @rtn_data = ();
    $rtn = read_file_by_byte($src_data_file, \@rtn_data);
    if (0 == $rtn)
    {
        return 0;
    }
    
    my $c_array_str = "";
    $rtn = array_to_c_array_string(\@rtn_data, \$c_array_str);
    if (0 == $rtn)
    {
        return 0;
    }
    
    ${$dst_val_ref} = '';
    ${$dst_val_ref} .= $array_type.' '.$array_name."[] = {\n".$c_array_str."};";
    
    return 1;
}

# �����Դ����xml�ļ�������Ϣ
sub gaf_parser_res_xml_file
{
    my ($res_type, $res_path) = @_;
    
    if (!defined($res_path) && $res_path)
    {
        return;
    }
    
    my $res_name;
    my $res_value;
    my %RES_LIST_MAP;
    
    if (!open(XML_FILE, $res_path))
    {
        return;
    }
    
    while(defined($line_data = <XML_FILE>))
    {
        if ($line_data =~ /\s*<$res_type\s+/)
        {
            $_ = $line_data;
            
            # ��ö�Ӧ��IDֵ�������ֶ�
            if (/name="(\w+)"/)
            {
                $res_name = $1;
            }
            else
            {
                # ��������������ֶΣ�����������
            }
            
            # ��ö�Ӧ������ֵ
            if (/value="(.+)"/)
            {
                $res_value = $1;
            }
            else
            {
                # ��������������ֶΣ���鿴�Ƿ�����ڽڵ��С�
                if(/\s*<$res_type\s+.*>\s*(.+)\s*<\/$res_type>/)
                {
                    $res_value = $1;
                }
            }
            
            # ���뵽��ϣ��
            if ($res_name && $res_value)
            {
                $RES_LIST_MAP{$res_name} = $res_value;
            }
        }
    }
    
    close(XML_FILE);
    
    return %RES_LIST_MAP;
}

# ���xml��Ϣ
sub gaf_parser_config_xml_file
{
    my ($xml_start_node, $xml_file_path) = @_;
    
    if (!defined($xml_file_path))
    {
        return;
    }
    
    if (!open(XML_FILE, $xml_file_path))
    {
        return;
    }
    
    my $line_data = "";
    
    # �ҵ�<Config>�ڵ㣬����֮��ʼ��ȡ��Ϣ
    while (defined($line_data = <XML_FILE>))
    {
        last if ($line_data =~ /<$xml_start_node>/);
    }
    
    my %config_map;
    
    # ƥ��һ���ڵ�
    while(defined($line_data = <XML_FILE>) && !($line_data =~ /<\/$xml_start_node>/))
    {
        if ($line_data =~ /<(\w+)>\s*(.+)\s*<\/(\w+)>/)
        {
            $config_map{$1} = $2 if ($1 == $3);
        }
    }
        
    close(XML_FILE);
    
    return %config_map;
}

# ��Ƥ���ļ���������������ID��Ƥ������
sub gaf_search_skin
{
    my ($skin_id, $search_path) = @_;
    
    if (!defined($skin_id) && !defined($search_path))
    {
        return "";
    }
    
    if (!(-d $search_path))
    {
        return "";
    }

    $cur_path = "";
    
    # �򿪸�Ŀ¼
    if (!opendir(SEARCH_PATH, $search_path))
    {
        print "can't opendir $search_path";
        return "";
    }
    
    my %SKIN_INFO_MAP;
    
    # �����ļ�Ŀ¼�е��ļ�
    foreach (readdir(SEARCH_PATH))
    {
        $cur_path = "$search_path\\$_";
        
        if (-d $cur_path)
        {
            # ��û��Ƥ�������ļ���Ϣ
            %SKIN_INFO_MAP = gaf_parser_config_xml_file("skin", "$cur_path\\skin.xml");
            
            # �ɹ���ö�Ӧ��Ƥ���ļ�Ŀ¼
            last if (defined($SKIN_INFO_MAP{"id"}) && $skin_id == $SKIN_INFO_MAP{"id"});
        }
        
        # �ָ�Ϊ��
        $cur_path = "";
    }
    
    closedir(SRCPATH);

    return $cur_path;
}

# ���ָ��Ŀ¼�������ļ��б�
sub get_all_files
{
    my ($src_path, $path_list) = @_;
    
    $list_num = 0;
    
    if (-d $src_path)
    {
        $cur_path = "";
        
        # �򿪸�Ŀ¼
        if (!opendir(SRCPATH, $src_path))
        {
            print "Cannot opendir $src_path";
            return 0;
        }
        
        # �����ļ�Ŀ¼�е��ļ�
        foreach (readdir(SRCPATH))
        {
            $list_num++;
            $cur_path = $src_path."\\".$_;
            if (not -d $cur_path)
            {
                # ���һ���ļ���
                push(@{$path_list}, $cur_path);
            }
        }
        
        closedir(SRCPATH);
    }
    else
    {
        # ��ӵ�ǰ�ļ�
        push(@{$path_list}, $src_path);
    }
    
    return $list_num;
}

# ��ȫ·���ļ�������ȡ���ļ���������
sub split_file_name
{
    my ($src_file_name, $pure_file_name, $sprite) = @_;
    
    # ��ȫ·���ļ�����б�ֿܷ���������
    my @path_array = split /[\\\/]/, $src_file_name;
    my $file_name = @path_array[@path_array - 1];
    
    if ($file_name =~ m/^(.+)\.(\w+)$/s)
    {
        ${$pure_file_name} = $1;
        ${$sprite} = $2;
    }
    else
    {
        return 0;
    }
    
    return 1;
}

sub gaf_res_buid_header
{
    if (!open(FILE, ">$RES_DES_FILE_PATH"))
    {
        print STDOUT "cant't open the des file $RES_DES_FILE_PATH\n";
        return 0;
    }
    
    print FILE "\n\n#include \"gaf_data_type.h\"\n";
    print FILE "#include \"gaf_resource.h\"\n";
    print FILE "#include \"gaf_ico.h\"\n\n";
    
    close(FILE);
    
    return 1;
}

# ����ͼƬ��Դ�ṹ����
sub gaf_res_buid_img
{
    my ($IMG_ID_MAP, $img_root_path) = @_;
    
    my $rtn = 0;
    
    # ���ڱ����ͼƬ·���л�õ��ļ������ļ�����
    my $file_name = "";
    my $file_type = "";
    
    # ͼƬ��������ͷ
    my $array_type = 'static GU8';
    my $dst_data = '';
    my $img_path = "";
    
    # ��ϳ���ͼƬ��Ϣ�ṹ�б�
    my $info_list = "";
    my $code_list = "";
    my $num = 0;
    
    if (!open(FILE, ">>$RES_DES_FILE_PATH"))
    {
        print STDOUT "cant't open the des file $RES_DES_FILE_PATH\n";
        return 0;
    }
    
    foreach (keys %{$IMG_ID_MAP})
    {
        # �����ļ���������
        split_file_name(${$IMG_ID_MAP}{$_}, \$file_name, \$file_type);
        
        $file_name = "g_img_".$_;
        
        # �ж��ǲ���ָ��ͼƬ����
        if ($IMG_TYPE_MAP{$file_type})
        {
            $img_path = "$img_root_path\\${$IMG_ID_MAP}{$_}";
            $rtn = file_to_c_array_string($img_path, $array_type, $file_name, \$dst_data);
            
            if (1 == $rtn)
            {
                # ������д���ļ�
                print FILE $dst_data;
                print FILE "\n\n";
                print STDOUT "info: $_ bin_file_to_c_array success!!\n";
                
                # ��ϳ���Ӧ��ͼƬ�ṹ��
                $info_list .= "    {(GU8*)INTEGRATE_ARRAY($file_name), 0, 0, $_, $IMG_TYPE_MAP{$file_type}},\n";
                $code_list .= "    g_stImgResIco[$num].pData = $file_name;\n";
                $code_list .= "    g_stImgResIco[$num].Size = sizeof($file_name);\n";
                $num++;
            }
            else
            {
                print STDOUT "error: $_ bin_file_to_c_array error\n";
            }
        }
    }
    
        print FILE "GImgResSTSet g_stImgResSet = {0};\n\n";
	
	if ($num > 0)
	{
		print FILE "static GImgResST g_stImgResIco[] = {\n";
		print FILE $info_list;
		print FILE "};\n\n";
	}
    
	print FILE "GVOID gaf_img_res_init()\n";
	print FILE "{\n";
	
	if ($num > 0)
	{
		print FILE $code_list;
		print FILE "\n    g_stImgResSet.pData = g_stImgResIco;\n";
		print FILE "    g_stImgResSet.Size = sizeof(g_stImgResIco)/sizeof(g_stImgResIco[0]);";
	}
	print FILE "\n}\n\n";
	
	print STDOUT "build img complete!\n";
    
	close(FILE);
	
	return 1;
}

sub gaf_res_buid_aud
{
    my ($AUD_ID_MAP, $aud_root_path) = @_;
    
    my $rtn = 0;
    
    # ���ڱ����ͼƬ·���л�õ��ļ������ļ�����
    my $file_name = "";
    my $file_type = "";
    
    # ͼƬ��������ͷ
    my $array_type = 'static GU8';
    my $dst_data = '';
    my $img_path = "";
    
    # ��ϳ���ͼƬ��Ϣ�ṹ�б�
    my $info_list = "";
    my $code_list = "";
    my $num = 0;
    
    if (!open(FILE, ">>$RES_DES_FILE_PATH"))
    {
        print STDOUT "cant't open the des file $RES_DES_FILE_PATH\n";
        return 0;
    }
    
    foreach (keys %{$AUD_ID_MAP})
    {
        # �����ļ���������
        split_file_name(${$AUD_ID_MAP}{$_}, \$file_name, \$file_type);
        
        $file_name = "g_aud_".$_;
        
        # �ж��ǲ���ָ��ͼƬ����
        if ($MEDIA_TYPE_MAP{$file_type})
        {
            $img_path = "$aud_root_path\\${$AUD_ID_MAP}{$_}";
            $rtn = file_to_c_array_string($img_path, $array_type, $file_name, \$dst_data);
            
            if (1 == $rtn)
            {
                # ������д���ļ�
                print FILE $dst_data;
                print FILE "\n\n";
                print STDOUT "info: $_ bin_file_to_c_array success!!\n";
                
                # ��ϳ���Ӧ��ͼƬ�ṹ��
                $info_list .= "    {(GU8*)INTEGRATE_ARRAY($file_name), $_, $MEDIA_TYPE_MAP{$file_type}},\n";
                $code_list .= "    g_stAudRes[$num].pData = $file_name;\n";
                $code_list .= "    g_stAudRes[$num].Size = sizeof($file_name);\n";
                $num++;
            }
            else
            {
                print STDOUT "error: $_ bin_file_to_c_array error\n";
            }
        }
    }
    
        print FILE "GAudResStSet g_stAudResSet = {0};\n\n";
	
	if ($num > 0)
	{
		print FILE "static GAudResSt g_stAudRes[] = {\n";
		print FILE $info_list;
		print FILE "};\n\n";
	}
    
	print FILE "GVOID gaf_aud_res_init()\n";
	print FILE "{\n";
	if ($num > 0)
	{
		print FILE $code_list;
		print FILE "\n    g_stAudResSet.pData = g_stAudRes;\n";
		print FILE "    g_stAudResSet.Size = sizeof(g_stAudRes)/sizeof(g_stAudRes[0]);";
	}
	print FILE "\n}\n\n";
	
	print STDOUT "build img complete!\n";
	
	close(FILE);
	
	return 1;
}

# ������ɫ�ṹ����
sub gaf_res_buid_col
{
    my ($COL_ID_MAP) = @_;
    
    if (!open(FILE,">>$RES_DES_FILE_PATH"))
    {
        print STDOUT "cant't open the des file $RES_DES_FILE_PATH\n";
        return 0;
    }
    
    my $info_list = "";
    my $num = 0;
    
    foreach (keys %{$COL_ID_MAP})
    {
        $info_list .= "    {$_, ${$COL_ID_MAP}{$_}},\n";
        $num++;
    }
    
    if ($num > 0)
    {
        print FILE "GColorMap g_stColorMap = {\n";
        print FILE $info_list;
        print FILE "};\n\n";
        
        print STDOUT "build color complete!\n";
    }
    
    close(FILE);
    
    return 1;
}

# �����ַ����ṹ����
sub gaf_res_buid_lang
{
    my ($LANG_ID_MAP) = @_;
    
    if (!open(FILE,">>$RES_DES_FILE_PATH"))
    {
        print STDOUT "cant't open the des file $RES_DES_FILE_PATH\n";
        return 0;
    }
    
    my $info_list = "";
    my $code_list = "";
    my $num = 0;
    
    # �����ַ���ӳ�������
    foreach (keys %{$LANG_ID_MAP})
    {
        $info_list .= "    {$_, \"${$LANG_ID_MAP}{$_}\"},\n";
        $code_list .= "    g_stLangMap[$num].pData = \"${$LANG_ID_MAP}{$_}\";\n";
        $num++;
    }
    
    # �����ַ���ʼ������
    if ($num > 0)
    {
        print FILE "GLangMap g_stLangMap = {\n";
        print FILE $info_list;
        print FILE "};\n\n";
        
        print STDOUT "build string complete!\n";
    }
    
    print FILE "GVOID gaf_string_res_init()\n{\n";
    print FILE $code_list;
    print FILE "}\n\n";
    
    close(FILE);
    
    return 1;
}

sub start_rom_res
{
    my $APP_ROOT_PATH = $ARGV[0];
    my $SCREEN_SIZE = $ARGV[1];
    
    if (!defined($APP_ROOT_PATH))
    {
        return 0;
    }
    
    # ���û�ж���ͼƬ��Դ�ֱ��ʣ�ʹ��Ĭ�ϵķֱ���
    if (!defined($SCREEN_SIZE))
    {
        $SCREEN_SIZE = "240X320";
    }
    
    # ��ʼ����Դ·��
    $RES_ROOT_PATH    = "app\\".$APP_ROOT_PATH."\\resource";
    $RES_LANUAGE_PATH = "$RES_ROOT_PATH\\$SCREEN_SIZE\\language";
    $RES_SKIN_PATH    = "$RES_ROOT_PATH\\$SCREEN_SIZE\\skin";
    $RES_DES_FILE_PATH = "$RES_ROOT_PATH\\gaf_res.c";
    
    if (-d $RES_DES_FILE_PATH)
    {
        print STDOUT "the file $RES_DES_FILE_PATH is error!\n";
        exit(0);
    }
    
    my %LANGUAGE_ID_MAP;
    my %CONFIG_ID_MAP;
    my $skin_path = "";
    my $skin_img_path = "";
    my $skin_col_path = "";
    my $skin_aud_path = "";
    my $language_path = "";
    
    # ����������ļ���Ϣ
    %CONFIG_ID_MAP   = gaf_parser_config_xml_file("Config", "$RES_ROOT_PATH\\$SCREEN_SIZE\\config.xml");
    %LANGUAGE_ID_MAP = gaf_parser_config_xml_file("language", "$RES_ROOT_PATH\\language.xml");
    
    # ��þ�������԰�·��
    if ($CONFIG_ID_MAP{"LangId"} == $CONFIG_ID_MAP{"DefLang"})
    {
        # ʹ��Ĭ�����԰�
        $language_path = "$RES_LANUAGE_PATH\\default\\string.xml";
    }
    else
    {
        # ��������ӦID�����԰�
        foreach (keys %LANGUAGE_ID_MAP)
        {
            if ($LANGUAGE_ID_MAP{$_} == $CONFIG_ID_MAP{"LangId"})
            {
                $language_path = "$RES_LANUAGE_PATH\\$_\\string.xml";
            }
        }
    }
    
    # ��þ����ͼ����Դ·��
    if ($CONFIG_ID_MAP{"SkinId"} == $CONFIG_ID_MAP{"DefSkin"})
    {
        # ʹ��Ĭ�ϵ�Ƥ��
        $skin_path = "$RES_SKIN_PATH\\default";
    }
    else
    {
        # ����ָ����Ƥ��
        $skin_path = gaf_search_skin($CONFIG_ID_MAP{"SkinId"}, $RES_SKIN_PATH);
    }
    
    # ��װͼƬ����ɫ�����ļ�·��
    if ($skin_path)
    {
        $skin_img_path = "$skin_path\\image.xml";
        $skin_col_path = "$skin_path\\color.xml";
	$skin_aud_path = "$skin_path\\audio.xml";
    }
    
    my %IMG_ID_MAP;
    my %COL_ID_MAP;
    my %AUD_ID_MAP;
    my %LANG_ID_MAP;
    
    # �ֱ�����Դ��������Ϣ
    %IMG_ID_MAP = gaf_parser_res_xml_file("image", $skin_img_path);
    %COL_ID_MAP = gaf_parser_res_xml_file("color", $skin_col_path);
    %LANG_ID_MAP = gaf_parser_res_xml_file("string", $language_path);
    %AUD_ID_MAP = gaf_parser_res_xml_file("audio", $skin_aud_path);
    
    gaf_res_buid_header();
    gaf_res_buid_img(\%IMG_ID_MAP, $skin_path);
    gaf_res_buid_aud(\%AUD_ID_MAP, $skin_path);
    gaf_res_buid_col(\%COL_ID_MAP);
    gaf_res_buid_lang(\%LANG_ID_MAP);
    
    return 1;
}

# ��ʼ��������
start_copy($src_dir,$dst_dir,$app_reso);

# ��ʼ����Rom������Դ
start_rom_res();
