sub MSH_DropDB{
	my $dbh=shift;
	my $db_name=shift;
	#create db
	my $sql=sprintf("DROP DATABASE  %s ;",$db_name);
	$dbh->do($sql);
}
sub MSH_CreateDB{
	my $dbh=shift;
	my $db_name=shift;
	#create db
	my $sql=sprintf("CREATE DATABASE  %s ;",$db_name);
	$dbh->do($sql);
}
sub MSH_OpenDB{
	my $dbname=shift;
	return DBI->connect("DBI:mysql:database=$dbname;host=localhost", "root", "1983410", {'RaiseError' => 1});
}
sub MSH_GetValue{
	my $dbh=shift;
	my $table=shift;
	my $column=shift;
	my $condition=shift;
	#show tables
	if(defined $condition){
		$sql=sprintf("select %s from %s where %s",$column,$table,$condition);		
	}else{
		$sql=sprintf("select %s from %s",$column,$table);		
	}
	my $sth =$dbh->prepare($sql);
	$sth->execute();
	my @value=();
	while(my $code=$sth->fetchrow_array){
		push @value,$code;
	}
	return @value;
}
sub MSH_GetValueFirst{
	my $dhe=shift;
	my $table=shift;
	my $column=shift;
	my $condition=shift;
	
	my @result=MSH_GetValue($dbh,$table,$column,$condition);
	if(defined @result){
		return @result[0];
	}
	return undef;
}
sub MSH_GetAllTablesName1{
	my $dbh=shift;
	#show tables
	$sql=("SHOW TABLES;");
	my $sth =$dbh->prepare($sql);
	$sth->execute();
	my @names=();
	while(my $code=$sth->fetchrow_array){
		push @names,$code;
	}
	return @names;
}
sub MSH_GetAllTablesName{
	my $dbh=shift;
	my $db_name=shift;
	#use database;
	my $sql=sprintf("USE %s ;",$db_name);
	$dbh->do($sql);
	#show tables
	$sql=("SHOW TABLES;");
	my $sth =$dbh->prepare($sql);
	$sth->execute();
	my @names=();
	while(my $code=$sth->fetchrow_array){
		push @names,$code;
	}
	return join('',@names,'');
}
sub MSH_CreateTable{
	my $dbh=shift;
	my $TableName=shift;
	my $CreateDefinition=shift;
	my $sql=sprintf("CREATE TABLE %s (%s);",$TableName,$CreateDefinition);
	return $dbh->do($sql);
}
sub MSH_CreateTableIfNotExist{
	my $dbh=shift;
	my $TableName=shift;
	my $CreateDefinition=shift;
	my $sql=sprintf("CREATE TABLE IF NOT EXISTS %s (%s);",$TableName,$CreateDefinition);
	return $dbh->do($sql);
}
sub MSH_SetUniqueKey{
	my $dbh=shift;
	my $TableName=shift;
	my $Key=shift;
	my $sql=sprintf("ALTER TABLE  %s ADD UNIQUE (%s);",$TableName,$Key);
	$dbh->do($sql);
}
1;
