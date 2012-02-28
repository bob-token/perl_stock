#!/usr/bin/perl -w
# use strict;
use File::Path;


# 该文件可以批量自动化拷贝数据
my $TRUE = 1;
my $FALSE = 0;

my $app_name = $ARGV[0];
my $app_reso = $ARGV[1];

# 图片类型映射
my %IMG_TYPE_MAP =
(
    'jpg' => 'GAF_IMG_TYPE_JPG',
    'jpeg' => 'GAF_IMG_TYPE_JPG',
    'gif' => 'GAF_IMG_TYPE_GIF',
    'bmp' => 'GAF_IMG_TYPE_BMP',
    'png' => 'GAF_IMG_TYPE_PNG',
);

# 多媒体文件类型映射
my %MEDIA_TYPE_MAP = 
(
    'mid' => 'GMDI_FORMAT_MIDI',
    '3gp' => 'GMDI_FORMAT_3GP',
);

# 资源的文件路径
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

# 获取目录并进行数据拷贝
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
	
	# 创建目录
	rmtree($dst_dir);
	mkpath($dst_dir); 
#	mkdir $dst_dir;
	if (not -e $dst_dir)
	{
		print "error: not exist $dst_dir!\n";
		exit;
	}
	
	# 删除不需要拷贝的文件
	if (-e "$src_dir\\gaf_res.c")
	{
		unlink "$src_dir\\gaf_res.c";
	}
	
	# 拷贝应用文件夹
	copy_dir_data($src_dir,$dst_dir);

    
	print "copy all data success!\n";
}

# 以字节为单位将文件读取到数组中
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

# 将字节数组转换成c形式的数组，如将"ab",转换成"0x61, 0x62"
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

# 将文件转化成C语言数组
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

# 获得资源类型xml文件配置信息
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
            
            # 获得对应的ID值，名字字段
            if (/name="(\w+)"/)
            {
                $res_name = $1;
            }
            else
            {
                # 如果不存在名字字段，这里做处理
            }
            
            # 获得对应的属性值
            if (/value="(.+)"/)
            {
                $res_value = $1;
            }
            else
            {
                # 如果不存在属性字段，则查看是否存在于节点中。
                if(/\s*<$res_type\s+.*>\s*(.+)\s*<\/$res_type>/)
                {
                    $res_value = $1;
                }
            }
            
            # 键入到哈希表
            if ($res_name && $res_value)
            {
                $RES_LIST_MAP{$res_name} = $res_value;
            }
        }
    }
    
    close(XML_FILE);
    
    return %RES_LIST_MAP;
}

# 获得xml信息
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
    
    # 找到<Config>节点，从这之后开始读取信息
    while (defined($line_data = <XML_FILE>))
    {
        last if ($line_data =~ /<$xml_start_node>/);
    }
    
    my %config_map;
    
    # 匹配一个节点
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

# 在皮肤文件夹中搜索出给定ID的皮肤数据
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
    
    # 打开该目录
    if (!opendir(SEARCH_PATH, $search_path))
    {
        print "can't opendir $search_path";
        return "";
    }
    
    my %SKIN_INFO_MAP;
    
    # 遍历文件目录中的文件
    foreach (readdir(SEARCH_PATH))
    {
        $cur_path = "$search_path\\$_";
        
        if (-d $cur_path)
        {
            # 获得获得皮肤配置文件信息
            %SKIN_INFO_MAP = gaf_parser_config_xml_file("skin", "$cur_path\\skin.xml");
            
            # 成功获得对应的皮肤文件目录
            last if (defined($SKIN_INFO_MAP{"id"}) && $skin_id == $SKIN_INFO_MAP{"id"});
        }
        
        # 恢复为空
        $cur_path = "";
    }
    
    closedir(SRCPATH);

    return $cur_path;
}

# 获得指定目录中所有文件列表
sub get_all_files
{
    my ($src_path, $path_list) = @_;
    
    $list_num = 0;
    
    if (-d $src_path)
    {
        $cur_path = "";
        
        # 打开该目录
        if (!opendir(SRCPATH, $src_path))
        {
            print "Cannot opendir $src_path";
            return 0;
        }
        
        # 遍历文件目录中的文件
        foreach (readdir(SRCPATH))
        {
            $list_num++;
            $cur_path = $src_path."\\".$_;
            if (not -d $cur_path)
            {
                # 获得一个文件名
                push(@{$path_list}, $cur_path);
            }
        }
        
        closedir(SRCPATH);
    }
    else
    {
        # 添加当前文件
        push(@{$path_list}, $src_path);
    }
    
    return $list_num;
}

# 从全路径文件名中提取出文件名和类型
sub split_file_name
{
    my ($src_file_name, $pure_file_name, $sprite) = @_;
    
    # 将全路径文件名按斜杠分开到数组中
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

# 构造图片资源结构数组
sub gaf_res_buid_img
{
    my ($IMG_ID_MAP, $img_root_path) = @_;
    
    my $rtn = 0;
    
    # 用于保存从图片路径中获得的文件名和文件类型
    my $file_name = "";
    my $file_type = "";
    
    # 图片数组类型头
    my $array_type = 'static GU8';
    my $dst_data = '';
    my $img_path = "";
    
    # 组合出得图片信息结构列表
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
        # 分离文件名和类型
        split_file_name(${$IMG_ID_MAP}{$_}, \$file_name, \$file_type);
        
        $file_name = "g_img_".$_;
        
        # 判断是不是指定图片类型
        if ($IMG_TYPE_MAP{$file_type})
        {
            $img_path = "$img_root_path\\${$IMG_ID_MAP}{$_}";
            $rtn = file_to_c_array_string($img_path, $array_type, $file_name, \$dst_data);
            
            if (1 == $rtn)
            {
                # 将数组写入文件
                print FILE $dst_data;
                print FILE "\n\n";
                print STDOUT "info: $_ bin_file_to_c_array success!!\n";
                
                # 组合出对应的图片结构体
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
    
    # 用于保存从图片路径中获得的文件名和文件类型
    my $file_name = "";
    my $file_type = "";
    
    # 图片数组类型头
    my $array_type = 'static GU8';
    my $dst_data = '';
    my $img_path = "";
    
    # 组合出得图片信息结构列表
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
        # 分离文件名和类型
        split_file_name(${$AUD_ID_MAP}{$_}, \$file_name, \$file_type);
        
        $file_name = "g_aud_".$_;
        
        # 判断是不是指定图片类型
        if ($MEDIA_TYPE_MAP{$file_type})
        {
            $img_path = "$aud_root_path\\${$AUD_ID_MAP}{$_}";
            $rtn = file_to_c_array_string($img_path, $array_type, $file_name, \$dst_data);
            
            if (1 == $rtn)
            {
                # 将数组写入文件
                print FILE $dst_data;
                print FILE "\n\n";
                print STDOUT "info: $_ bin_file_to_c_array success!!\n";
                
                # 组合出对应的图片结构体
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

# 构造颜色结构数组
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

# 构造字符串结构数组
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
    
    # 构造字符串映射对数组
    foreach (keys %{$LANG_ID_MAP})
    {
        $info_list .= "    {$_, \"${$LANG_ID_MAP}{$_}\"},\n";
        $code_list .= "    g_stLangMap[$num].pData = \"${$LANG_ID_MAP}{$_}\";\n";
        $num++;
    }
    
    # 构造字符初始化函数
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
    
    # 如果没有定义图片资源分辨率，使用默认的分辨率
    if (!defined($SCREEN_SIZE))
    {
        $SCREEN_SIZE = "240X320";
    }
    
    # 初始化资源路径
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
    
    # 获得主配置文件信息
    %CONFIG_ID_MAP   = gaf_parser_config_xml_file("Config", "$RES_ROOT_PATH\\$SCREEN_SIZE\\config.xml");
    %LANGUAGE_ID_MAP = gaf_parser_config_xml_file("language", "$RES_ROOT_PATH\\language.xml");
    
    # 获得具体的语言包路径
    if ($CONFIG_ID_MAP{"LangId"} == $CONFIG_ID_MAP{"DefLang"})
    {
        # 使用默认语言包
        $language_path = "$RES_LANUAGE_PATH\\default\\string.xml";
    }
    else
    {
        # 搜索到对应ID的语言包
        foreach (keys %LANGUAGE_ID_MAP)
        {
            if ($LANGUAGE_ID_MAP{$_} == $CONFIG_ID_MAP{"LangId"})
            {
                $language_path = "$RES_LANUAGE_PATH\\$_\\string.xml";
            }
        }
    }
    
    # 获得具体的图标资源路径
    if ($CONFIG_ID_MAP{"SkinId"} == $CONFIG_ID_MAP{"DefSkin"})
    {
        # 使用默认的皮肤
        $skin_path = "$RES_SKIN_PATH\\default";
    }
    else
    {
        # 查找指定的皮肤
        $skin_path = gaf_search_skin($CONFIG_ID_MAP{"SkinId"}, $RES_SKIN_PATH);
    }
    
    # 组装图片和颜色配置文件路径
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
    
    # 分别获得资源的配置信息
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

# 开始拷贝数据
start_copy($src_dir,$dst_dir,$app_reso);

# 开始生成Rom化的资源
start_rom_res();
