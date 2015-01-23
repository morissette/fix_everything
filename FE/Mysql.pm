package FE::Mysql;
use strict;
use warnings;
use Sys::Hostname;
use File::ReadBackwards;
use FE::Core;

our $line_limit = 25000;

sub run_tests {
	my $user = shift;
	FE::Core::info("Scanning mysql error log for user issues");
	check_mysql($user);
    print "\n";
}

sub check_mysql {
	my $user         = shift;
	my $hostname     = hostname;
	my $count        = 0;
	my $mysql_errors = {};
	my $log          = '/var/lib/mysql/' . $hostname . '.err';
	if ( -f $log ) {
		my $bw = File::ReadBackwards->new($log)
				or die "Unable to open MySQL log";
		while ( my $line = $bw->readline ) {
			last if ( $count >= $line_limit );
			if ( $line =~ /Table\s'\.\/($user\S+)\/\S+'\sis\smarked\sas\scrashed\sand\sshould\sbe\srepaired/xsm ) {
				$mysql_errors->{$1}++;
			}
			$count++;
		}
		my $num_err = keys %$mysql_errors;
		if ( $num_err > 0 ) {
			foreach my $k ( keys %$mysql_errors ) {
				FE::Core::failed("$k is marked as crashed and should be repaired\n");
			}
		}
		else {
			FE::Core::passed("No crashed tables found for '$user'");
		}
	}
	else {
		FE::Core::failed("Unable to find the MySQL error log");
	}
}

sub connect_to_mysql_db {
    my $db_pass = retreive_db_pass();
    if ( $db_pass ) {
        my $db_not_connected = 0;
        my $dsn              = 'DBI:mysql:database=mysql;host=localhost;port=3306';
        my $dbh              = DBI->connect(
            $dsn,
            'root',
            $db_pass,
            {  
                PrintError  => 0,
                HandleError => sub {
                    $db_not_connected = 1;
                }
            }
        );
        unless ( $db_not_connected ) {
            return $dbh;
        }
    } else {
        return 0;
    }
}

sub retreive_db_pass {
    if ( -f '/root/.my.cnf' ) {
        my $password;
        open my $fh, '<', '/root/.my.cnf';
        while ( my $line = <$fh> ) {
            if ( $line =~ /(?:pass|password)=(\S+)/ ) {
                $password = $1;
                last;
            }
        }
        close $fh;
        return $password;
    } else {
        FE::Core::failed("Unable to get mysql root password");
        return 0;
    }
}

1;
