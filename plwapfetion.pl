#!/usr/bin/perl -w
use strict;
use warnings;
use LWP 5.64;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Encode;
use HTTP::Cookies;
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
		print "Require fail:$fun_url","Reason:",$respone->status_line,"\r\n";
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
	my $ret = &_open('im/login/inputpasssubmit1.action',['m' => $mobile,'pass' => $password, 'loginstatus' => $loginstatus]);
	return _string_in("登录",$ret);
}
sub send2self {
	my ($message,$time)=@_;
	if ($time){
		return _string_in('成功', _open('im/user/sendTimingMsgToMyselfs.action',['msg' => $message,'timing' => $time]));
	}else{
		return _string_in('成功', _open('im/user/sendMsgToMyselfs.action',['msg' => $message])) ;

	}
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
 
sub findid{
	my ($mobile) = @_;
	my $id=_get_id_from_cache($mobile);
	if (not $id){
		$id=_get_id_from_serv($mobile);
	}
    return $id; 
}
sub sendBYid{
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
sub send2friend{
	my ($mobile,$message,$sm)=@_;
	if ($mobile == $self->{mobile}){
		return send2self($message);
	}
	return sendBYid(findid($mobile),$message,$sm);
}
sub main{
	_login('13590216192','15989589076xhb','4');
	&send2self('你上飞信了没？');
	#&send2friend(15989589076,'你上飞信了没？');
}
&main;
