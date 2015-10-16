#!C:/Perl64/bin/perl.exe

use strict;
use warnings;
use DBI;
use Cwd;
use CGI qw(:standard);
use Data::Dumper;
use DateTime;

my $query = new CGI;

#declare variables:
#pick local directory
#my $sql_location = cwd();

my $sql_location = 'C:\Bitnami\wampstack-5.4.37-0\apache2\htdocs\hydra\sas\output';

my $sql_query = lc $ARGV[0];
my $tbl_target = lc $ARGV[1];

#my $sql_query  = lc 'CI_SASNumericAnalysis_sch';
#my $tbl_target = lc 'CI_SASNumericAnalysis';
    
    #declare sub-elements		
    #my $row;
    my $rowcache;
    my $max_rows = 1;
    my $array_load;
    my $array_qmark;
    #my $datestring = localtime();
    
    my $dt = DateTime->now( time_zone => 'America/New_York' ); 
    #print "$dt \n";
            
    my $ymd = $dt->ymd('/');
    my $hms = $dt->hms;    
		
    my $sqlFile = ${sql_location}."/".${sql_query};
    
	#load sql file
	open (SQL, "$sqlFile");
	    #or die (Can't open file "$sqlFile" for reading);
	
	my $array_ref;
	while (my $sqlStatement = <SQL>) {
	    
	    #remove lines that start with "--"
	    if ($sqlStatement =~ /^\s*\--/ ) {
		next;
	    }
	    
	    #replace variable if found
	    #$sqlStatement =~ s/&FIC_MIS_DATE/$fic_mis_date/g;
	    
	    #push into array
	    push @{ $array_ref }, $sqlStatement;
	
	}
	
	my $tbl_file = ${sql_location}."/".${tbl_target};	

    #Connect to SQL SERVER for insert
#    my $db2 = DBI->connect('dbi:Pg:dbname=QTRACK;host=98.218.185.87',
#			    'shsethi',
#			    'root123',
#			    {AutoCommit=>1,RaiseError=>1,PrintError=>0}
#			    ) || die "Database connection not made: $DBI::errstr";
    
    my $db2 = DBI->connect('dbi:Pg:dbname=QTRACK;host=localhost',
			    'postgres',
			    'root123',
			    {AutoCommit=>1,RaiseError=>1,PrintError=>0}
			    ) || die "Database connection not made: $DBI::errstr";    
    
    ########################################################################    
    #Drop existing table in SQL
    ########################################################################
    my $del = $db2->prepare("DROP TABLE IF EXISTS "  . $tbl_target)
    	    or die (qq(Can't prepare DELETE query for $tbl_target));
           $del->execute()
    	    or die qq(Can't execute DELETE $tbl_target);
	    
    ########################################################################
    #Create new table via schema;
    ########################################################################
	my $sth_create = $db2->prepare("@{ $array_ref }")
	      or die (qq(Can't prepare "@{ $array_ref }"));
	      
	$sth_create->execute()
	    or die qq(Can't execute "@{ $array_ref }");
    ########################################################################
    
    ########################################################################
    #Get column names from table
    ########################################################################
    my $col = $db2->prepare("SELECT COLUMN_NAME FROM information_schema.columns WHERE table_schema = 'public' and table_name = '" .$tbl_target. "'")
	    or die (qq(Can't prepare COLUMN query for $tbl_target));
	    
       $col->execute()
	    or die qq(Can't execute COLUMN $tbl_target);
    ########################################################################	
        
    ########################################################################
    #Push column names into array and count # of question marks would go into insert query (also push into array)
    ########################################################################    
	no warnings;
        while(my $row = shift(@$rowcache) || shift(@{$rowcache=$col->fetchall_arrayref(undef, $max_rows)})) 
				{
		#print join(", ", values @{$row}), "\n";
		push @ { $array_load }, values @ { $row } ;
		push @ { $array_qmark }, '?' ;
				}		
	use warnings;
    ########################################################################
    
    ########################################################################
    #Prepare insert query into database from file
    ########################################################################    
    open(my $fh, '<', $tbl_file) || die "can't open folks: $!";
    my @data;

    my $ins = $db2->prepare("INSERT INTO $tbl_target (" . join(", ", values @ { $array_load }) . ") VALUES(" . join(", ", values @ { $array_qmark }) . ")");
    
    	no warnings;
	
	while (my $line = <$fh>) {
	    
	    chomp $line;
	    my @fields = split(/\|/, $line);
	    push @data, \@fields;
	    
	    my @tuple_status;
	    $ins->execute_for_fetch( sub { shift @data }, \@tuple_status);	    
	}
	
	use warnings;	
    
    ########################################################################
    #Update controller for status = finished
    ########################################################################    
    
    my $update = $db2->prepare("UPDATE controller SET status = 1 WHERE id = (select max(id) from controller);")
	    or die (qq(Can't prepare COLUMN query for controller));
	    
       $update->execute()
	    or die qq(Can't execute COLUMN controller);
    
	END {
	}