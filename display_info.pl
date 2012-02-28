#!/usr/bin/perl -w
use strict;
use utf8;

sub display_info
{
    my ($src_file_name, $print_size) = @_;
    
    if (not(defined $src_file_name))
    {
        print '$src_file_name not defined!'."\n";
        return 0;
    }
    
    if (not(defined $print_size))
    {
        $print_size = 40960;
    }
    
    if (not (-e $src_file_name))
    {
        print "not exist $src_file_name!\n";
        return 0;
    }
    
    my $data;
    open(SOURCE, "$src_file_name") || die "$!";
    my $file_size = -s $src_file_name;
    if ($file_size <= $print_size) 
    { 
        print <SOURCE>; 
    } 
    else 
    { 
        seek(SOURCE, -$print_size, 2);  	
        read(SOURCE,$data,$print_size);  	
        print $data;  
    } 
    
    close(SOURCE);
}

my $src_file = $ARGV[0];
my $dis_len = $ARGV[1];
if (not(defined $src_file))
{
    print '$src_file not defined!'."\n";
    return 0;
}

display_info($src_file, $dis_len);