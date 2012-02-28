use File::Path ;
use Cwd;

my $ROOT_DIR=$ARGV[0];
sub del_svn{
	$ROOT_DIR="@_";
	opendir(CUR_DIR,"$ROOT_DIR") or die "The dir $ROOT_DIR is not exist!" ;
	foreach(readdir(CUR_DIR)){
		next if(($_ eq ".") || ($_ eq ".."));
		$CUR_FILE="$ROOT_DIR\\$_";
		if(-d $CUR_FILE){
			if(/^.svn$/){
				print STDOUT "$CUR_FILE\n";
				rmtree($CUR_FILE);
			}else{
				del_svn($CUR_FILE);
			}
				
		}
	}
}
sub main{
	if(!defined($ROOT_DIR)){
		$ROOT_DIR = getcwd;
	}
	del_svn($ROOT_DIR);	
}
main;