#!C:/Perl64/bin/perl.exe

use strict;
use warnings;
use IO::Socket::INET;
use DBI;

my $cmd  = $ARGV[0];
my $prog = $ARGV[1];
my $table= $ARGV[2];
my $rowcache;
my $max_rows = 1;
my $job;

# auto-flush on socket
$| = 1;
 
# create a connecting socket
my $socket_send = new IO::Socket::INET (
    PeerHost => 'localhost',
    PeerPort => '5500',
    Proto => 'tcp'
);
die "Can't Connect to SAS Server $!\n" unless $socket_send;
#print "TCP Connection to SAS Established \n";
 
    $socket_send->autoflush(1);  # Send immediately
    
    # data to send to a server
    $socket_send->send("$cmd $prog $table\n");
     
    # Receive result from server
    #my $res = <$socket_send>;            
     
    # notify server that request has been sent
    shutdown($socket_send, 1);

$socket_send->close();

if ($cmd eq "RUN") {

    ########################################################################    
    #Connet to controller table
    ########################################################################
    my $db1 = DBI->connect('dbi:Pg:dbname=QTRACK;host=localhost',
                                'xxx',
                                'xxx',
                                {AutoCommit=>1,RaiseError=>1,PrintError=>0}
                                ) || die "Database connection not made: $DBI::errstr";

    ########################################################################
    #Update controller for status = running
    ########################################################################
    my $col = $db1->prepare("INSERT INTO controller (cmd,prog,tbl_name,status) VALUES('" . $cmd . "', '" . $prog . "', '" . $table . "', 0);")
	    or die (qq(Can't prepare COLUMN query for controller));
	    
       $col->execute()
	    or die qq(Can't execute COLUMN controller);
            
    ########################################################################
    #Start loop until status chages from 0 to 1
    ########################################################################
    
    my $stat = $db1->prepare("
                select status from controller
                where id = (select max(id) from controller where tbl_name = '" . $table . "');
                       ")
                or die (qq(Can't prepare COLUMN query for $table));
    
    my $a = 0;
    while ($a < 1) { 

        $stat->execute() or die qq(Can't execute COLUMN " . $table . ");

        #no warnings;
        while(my $row = shift(@$rowcache) || shift(@{$rowcache=$stat->fetchall_arrayref(undef, $max_rows)})) 
                                {
     
                    #my $e = new Emp (values @{$row});	
                    #push @{ $print_array }, join(" ", $JSON->encode($e), "\n");
                    
                    $a = @{$row}[0];
                    if ($a > 0) { $job = "complete"; };
                    #print @{$row}[0]."\n";
                                }		
        #use warnings;
    };
    ########################################################################
    #End loop when status = 1
    ########################################################################
 
    END {
       $db1->disconnect if defined($db1);
   };
 
}

print "status: $job \n";

