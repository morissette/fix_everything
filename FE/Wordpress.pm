package FE::Wordpress;
use strict;
use warnings;
use FE::Core;
use JSON;
use DBI;
use Cwd;
use File::Basename;

our $db_info     = {};
our $total_tests = 0;
our $conf        = undef; 
our $defs        = undef;

sub run_tests {
	FE::Core::info("Running Wordpress Tests");
	get_db_data();
	my $dbh = test_sql_connection();
    test_definitions($dbh);
    print "\n";
}

sub get_db_data {
	if ( open my $fh, '<', 'wp-config.php' ) {
    	while ( my $line = <$fh> ) {
	    	if ( $line =~ /(DB_\S+)',\s'(\S+)'\);/ ) {
		    	$db_info->{$1} = $2;
    		}
            if ( $line =~ /^\$(table_prefix)\s*=\s*'(\S+)';/ ) {
                $db_info->{$1} = $2;
            }
	    }
    	close $fh;
    } else {
        FE::Core::failed("Wordpress configuration file is missing");
    }
}

sub test_sql_connection {
    $total_tests++;
	my $db_not_connected = 0;
	my $dsn              = 'DBI:mysql:database=' . $db_info->{'DB_NAME'} . ';host=' . $db_info->{'DB_HOST'} . ';port=3306';
	my $dbh              = DBI->connect(
		$dsn,
		$db_info->{'DB_USER'},
		$db_info->{'DB_PASSWORD'},
		{
			PrintError  => 0,
			HandleError => sub {
				$db_not_connected = 1;
			}
		}
	);
	if ($db_not_connected) {
        if ( $total_tests > 1 ) {
            if ( $total_tests == 3 ) {
                FE::Core::sub_msg('Failed to update password successfully, falling back');
            } else {
                FE::Core::sub_msg('Still unable to connect, trying again');
                fix_db_creds();
            }
        } else {
    		FE::Core::failed('Unable to connect using DB credentials');
            fix_db_creds();
        }
	}
	else {
		FE::Core::passed('MySQL connection successfully created with DB credentials');
        return $dbh;
	}
}

sub fix_db_creds {
    my $dbh = FE::Mysql::connect_to_mysql_db();
    if ( $dbh ) {
        FE::Core::sub_msg('Attempting to update sql user to match password in config');
        my $rows = $dbh->do(
            'UPDATE user SET Password = PASSWORD(?) WHERE User = ?',
            undef,
            $db_info->{'DB_PASSWORD'},
            $db_info->{'DB_USER'},
        );
        $dbh->do('FLUSH PRIVILEGES');
        unless ( $total_tests == 3 ) {
            test_sql_connection();
        }    
    } else {
        FE::Core::sub_msg('Unable to connect to mysql database');
        FE::Core::sub_msg('No changes have been made');
    }
}

sub test_definitions {
    load_definitions();
    my $dbh = shift;
    foreach my $test ( keys %{$defs} ) {
        my $definition = $defs->{$test}->{'definition'};
        my $failed     = $defs->{$test}->{'failed'};
        my $success    = $defs->{$test}->{'success'};
        my $type       = $defs->{$test}->{'type'};
        if ( $type eq 'file' ) {
            if ( -f $definition ) {
                FE::Core::passed($success);
            } else {
                FE::Core::failed($failed);
            } 
        } elsif ( $type eq 'mysql' ) {
            my $table_prefix = $db_info->{'table_prefix'};
            $definition =~ s/table_placeholder/$table_prefix/;
            my $result = $dbh->selectrow_hashref($definition);
            $result = $result->{'option_value'};
            $failed =~ s/placeholder/$result/;
            if ( $result ) {
                FE::Core::passed($success);
            } else {
                FE::Core::failed($failed);
            }
        }
    }
}

sub load_definitions {
    my $config = '/root/bin/FE/Configs/wordpress.json';
    if ( -f $config ) {
        local $/;
        open my $fh, '<', $config or die $!;
        my $json_text = <$fh>;
        close $fh;
        $conf = decode_json($json_text);
        foreach my $test ( keys %{$conf} ) {
            #$defs->{$test};
            foreach my $data ( @{$conf->{$test}} ) {
                my($k, $v) = each %{$data};
                $defs->{$test}->{$k} = $v;
            }
        }
    }
    else {
        FE::Core::failed("Unable to find software configurations");
        return 0;
    }
}

1;
