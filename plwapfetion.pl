#!/usr/bin/perl -w
use strict;
use warnings;
require "perl_common.pl";
use LWP 5.64;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Encode;
use HTTP::Cookies;
use MIME::Base64;
my $self;
sub _init{
        #登录状态：
        #在线：1；隐身：4；忙碌：2；离开：3
	my ($mobile,$password,$loginstatus,$keepalive) = @_;
	$self->{mobile}		= $mobile;
	$self->{password} 	= $password;
	$self->{loginstatus}  = $loginstatus;
	$self->{keepalive}	= $keepalive;
	$self->{browser}	= LWP::UserAgent->new;
	$self->{browser}->cookie_jar(HTTP::Cookies->new(
		'file' => 'perlcookies.lwp',
		#where to read/write cookies
		'autosave' => 1,
		#save it to disk when done
		));
	return 1;
}
sub _open{
	my ($fun_url,$ref_data)=@_;
	my $url = sprintf('http://f.10086.cn/%s',$fun_url);
	my $respone;
	if($ref_data){
			$respone = $self->{browser}->post($url,
			$ref_data,
			'Accept-encoding' => 'gzip');
	}else{
			$respone = $self->{browser}->post($url,
			'Accept-encoding' => 'gzip');
	}
	if($respone->is_success){
		my $out;
		my $status = gunzip \$respone->content => \$out;
		return $out;
	}else{
		print "Require fail:$fun_url"," Reason:",$respone->status_line,"\r\n";
	}
	return undef;
}
sub _string_in{
	my ($str,$content)=@_;
	if( $content && $str ){
		my $re =qr/$str/; 
		if ($content =~ $re){
			return 1;
		}
	}
	return 0;
}
sub _login{
	my ($mobile,$password,$loginstatus) = @_;
	_init($mobile,$password,$loginstatus,0);
	my $page = &_open('/im5/login/loginHtml5.action');
	my $codekey_re = qr(name="codekey" value="(.*?)">);
	my @chkcodes = _find_all(\$page,$codekey_re);
	my $chkcode = $chkcodes[0];
	my $decode = decode_base64($chkcode);
	#my $ret = &_open('im/login/inputpasssubmit1.action',['m' => $mobile,'pass' => $password, 'checkCode' => $decode,'codekey' => $chkcode]);
	my $ret = &_open('/im5/login/loginHtml5.action',['m' => $mobile,'pass' => $password, 'checkCode' => $decode,'codekey' => $chkcode]);
	if(_string_in("验证码错误!",$ret)){
		print "验证码错误"."\n";
		return 0;
	}
	$ret = &_open('/im/login/cklogin.action');
	return _string_in("登录",$ret);
}
sub _get_id_from_cache{
	return undef;	
} 
sub _get_id_from_serv{
	my ($mobile) = @_;
    my $htm = _open('im/index/searchOtherInfoList.action',['searchText' => $mobile]);
	if ($htm and $htm =~ m/touserid=(\d*)/){
		return $1;
	}
	return undef;
}
sub _find_all{
	my ($ref_content,$re) = @_;
	my @val=($$ref_content=~ m/$re/g );	
	return @val;
}
sub _find_id{
	my ($mobile) = @_;
	my $id=_get_id_from_cache($mobile);
	if (not $id){
		$id=_get_id_from_serv($mobile);
	}
    return $id; 
}
sub _mark_read {
    my ($id)=@_;
	_open('im/box/deleteMessages.action',['fromIdUser' => $id]);
}
sub _get_message{
	my $web      = _open('im/box/alllist.action');
	my $id_re 		 = qr(<a href="/im/chat/toinputMsg.action\?touserid=(\d*)&amp;);
	my $name_re 	 = qr(<a href="/im/chat/toinputMsg.action\?touserid=[^"]*">([^/]*)</a>:);
	my $content_re  = qr(<a href="/im/chat/toinputMsg.action\?touserid=[^"]*">[^/]*</a>:(.*?)<br/>);
	my @ids=($web =~ m/$id_re/g );	
	my @names=($web =~ m/$name_re/g );	
	my @contents=($web =~ m/$content_re/g );	
	my $msg;
	my $i=0;
	for($i=0;$i < @ids;$i++){
		$msg->{$ids[$i]}->{name}=$names[$i];
		$msg->{$ids[$i]}->{content}=$contents[$i];
	}
	return $msg;
}
sub PWF_Send2Self {
	my ($message,$time)=@_;
	if ($time){
		return _string_in('成功', _open('im/user/sendTimingMsgToMyselfs.action',['msg' => $message,'timing' => $time]));
	}else{
		return _string_in('成功', _open('im/user/sendMsgToMyselfs.action',['msg' => $message])) ;

	}
}
sub PWF_SendById{
	my ($id,$message,$sm) = @_;
	my $url;
	if ($sm){
		$url = sprintf('im/chat/sendMsg.action?touserid=%s',$id); 
	}else{
		$url = sprintf('im/chat/sendShortMsg.action?touserid=%s',$id);
	}
	my $htm = _open($url,['msg' => $message]);
	return _string_in( '成功',$htm);
}
sub PWF_Send2Friend{
	my ($mobile,$message,$sm)=@_;
	if ($mobile == $self->{mobile}){
		return PWF_Send2Self($message);
	}
	return PWF_SendById(_find_id($mobile),$message,$sm);
}
sub _add_stock{
	my ($code)=@_;
	print "add sotck:$code","\r\n";
}
sub _delete_stock{
	my ($code)=@_;
	print "delete sotck:$code","\r\n";
}
sub _process_message{
	my ($msg)=@_;
	print "$msg->{name}:$msg->{content}","\r\n";
	if($msg->{content} =~ m/添加股票(s[hz]\d{6})\b/){
		_add_stock($1);
	}elsif($msg->{content} =~ m/删除股票(s[hz]\d{6})\b/){
		_delete_stock($1);
	}
	#&PWF_Send2Friend(15989589076,'你上飞信了没？');
}
sub main{
	my $flag0=COM_get_flag(0,"flag");
	my $flag1=COM_get_flag(1,"flag");
	_login($flag0,$flag1,'4');
	&PWF_Send2Self('你上飞信了没？');
	#&PWF_Send2Friend(15989589076,'你上飞信了没？');
	while(1){
		if (my $msgs=_get_message()){
			foreach my $id ( keys %$msgs ){
				_process_message($msgs->{$id});
				_mark_read($id);
			}
			sleep 1;
		}
	}
}
&main;
