use warnings;
use strict;
require File::Spec;

sub _get_dir_modified_time{
	my $path=shift;
	return 10000000000000 unless -d $path;
	my $lasttime=1000000000000;
	opendir(DIR,$path) or die $!;
	while(my $file = readdir(DIR)){
		next if $file eq '.' or $file eq '..';
		if(-f $file){
			my $tmp=join('',$path,'\\',$file);
			if(-M $tmp < $lasttime){
				$lasttime = -M $file;
			}
		}else{
			my $dirlasttime=_get_dir_modified_time($file);
			if( $dirlasttime < $lasttime){
				$lasttime=$dirlasttime;
			}
		}
	}
	close(DIR);
	return $lasttime;
}

sub _get_file_modified_time{
	my $path=shift;
	return 0 unless -f $path;
	return -M $path;
}
sub _new_than{
	my $dest=shift;
	my $src=shift;
	my $true=1;
	my $false=0;
	return $false unless -e $src;
	return $true unless -e $dest;
	my $last=-M $dest;
	if(-d $src){
		return $last > _get_dir_modified_time($src);
	}else{
		return $last > _get_file_modified_time($src);
	}
}
sub backup{
	my $path=shift;
	my $dest=shift;
	my $myzip="\"C:\\Program Files\\7-Zip\\Uedit32.exe\"";
	if(-e $path){
		my @arg;
		print "compress directory:$path\n";
		if (-d $path){
			@arg=($myzip,'a',$dest,join('',$path,'\\*'));
		}elsif(-f $path){
			@arg=($myzip,'a',$dest,$path);
		}
		if(_new_than($dest,$path)){
			system(@arg);	
		}
	}
}
sub main{
	if(@ARGV==0){
		open(CON,"<","backuplist.txt");
		while(<CON> =~ m/(?<=\[SRC\]=)(.*)(;\[DEST\]=)(.*)(?=;)/ ){
			backup($1,$3);
		}
		close CON;
		return 1;
	}
	my $src;
	my $dest;
	my $flag_dd=0;
	my $flag_remember=0;
	
	while(my $opt=shift @ARGV){
		if ($opt =~ /-h/){			 
		print <<"HELP";
		-s: source path
		[-d]: destination path
HELP
		}elsif($opt =~ /-s\b/){
			$src=shift @ARGV;
		}elsif($opt =~ /-d\b/){
			$dest=shift @ARGV;
		}elsif($opt =~ /-dd\b/){
			$dest=shift @ARGV;
			$flag_dd=1;
		}elsif($opt =~ /-r\b/){
			$flag_remember=1;
		}
	}

	die "souce path  not defined!" unless defined $src  ;
	die "$src  not defined!" unless -e $src  ;
	if($flag_dd){
		my $volume;
		my $directories;
		my $file;
		($volume,$directories,$file) = File::Spec->splitpath($src);
		$dest=join('',$dest,'\\',$file,'.7z');
	}
	if(!defined $dest){
		$dest=join('',$src,'.7z');
	}
	if($flag_remember){
		open(CON,"+>>","backuplist.txt");
		my $add=1;
		seek(CON,0,0);
		while(my $line=<CON>){
			if(index($line,'[SRC]='.$src.';'.'[DEST]='.$dest.';')>=0){
				$add=0;
			}
		}
		if($add){
			seek(CON,0,2);
			syswrite(CON,'[SRC]='.$src.';'.'[DEST]='.$dest.';'."\n");			
		}
		close CON;
	}
	backup($src,$dest);
	print "\nbye bye!";
}

main;