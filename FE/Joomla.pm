package FE::Joomla;
use strict;
use warnings;
use DBI;
use FE::Core;

our $db_info = {};

sub run_tests {
	FE::Core::info("Running Joomla Tests");
    get_db_data();
    if ( scalar(keys %{$db_info}) > 10 ) { 
        test_sql_connection();
    }
    print "\n";
}

sub get_db_data {
    if ( open my $fh, '<', 'configuration.php' ) {
        while ( my $line = <$fh> ) {
            if ( $line =~ /public\s\$(\S+)\s=\s'(\S+)';/ ) {
                $db_info->{$1} = $2;
            }
        }
        close $fh;
    } else {
        FE::Core::failed("Joomla configuration file is missing");
    }
}

sub test_sql_connection {
    my $db_not_connected = 0;
    my $dsn              = 'DBI:mysql:database=' . $db_info->{'db'} . ';host=' . $db_info->{'host'} . ';port=3306';
    my $dbh              = DBI->connect(
        $dsn,
        $db_info->{'user'},
        $db_info->{'password'},
        {  
            PrintError  => 0,
            HandleError => sub {
                $db_not_connected = 1;
                    }
        }
    );
    if ($db_not_connected) {
        FE::Core::failed('Unable to connect using DB credentials');
    }
    else {
        FE::Core::passed('MySQL connection successfully created with DB credentials');
    }

}

1;
