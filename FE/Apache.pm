package FE::Apache;
use strict;
use warnings;
use File::ReadBackwards;
use FE::Cpanel;
use FE::Core;

our $line_limit = 25000;

sub run_tests {
	my $user = shift;
	FE::Core::info("Scanning user apache error logs for errors");
	check_apache($user);
    print "\n";
}

sub check_apache {
	my $user          = shift;
	my $log           = '/usr/local/apache/logs/error_log';
	my $count         = 0;
	my $apache_errors = {};
	if ($user) {
		my @domains = FE::Cpanel::get_domains_from_user($user);
		if ( -f $log ) {
			my $bw = File::ReadBackwards->new($log)
					or die "Cannot read 'log' $!";
			while ( my $line = $bw->readline ) {
				last if ( $count >= $line_limit );
				foreach my $domain (@domains) {
					if (
						$line =~ /\[\S+\s\S+\s\d+\s\d+:\d+:\d+\s\d+\] # Match Date
                                        \s\[(?:crit|error|alert)\]\s\S+\s\S+\s([^:]+ # Match and capture errors only
                                        .*($user|$domain).*)\n # Match everything else and check for user or domain in question
                        /xsm
							)
					{
						$apache_errors->{$1}++;
					}
				}
				$count++;
			}
			my $errs    = parse_apache_errors($apache_errors);
			my $num_err = @$errs;
			if ( $num_err > 0 ) {
				fix_apache_errors( $errs, $user, $num_err );
			}
			else {
				FE::Core::passed("Apache log yields no errors");
			}
		}
		else {
			FE::Core::failed("No Apache Log Found: $!");
		}
	}
}

sub parse_apache_errors {
	my $errors = shift;
	my @keys   = keys %$errors;
	my @errs;
	my $mod_sec_count = 0;
	foreach my $k (@keys) {
		next if $k =~ /File\sdoes\snot\sexist/xsm;
		next if $k =~ /403.shtml/xsm;
		next if $k =~ /favicon/xsm;
		if ( $k =~ /ModSecurity:/xsm ) {
			$mod_sec_count++;
			next;
		}
		push @errs, $k;
	}
	if ($mod_sec_count) {
		FE::Core::info("Found $mod_sec_count mod security hits");
	}
	return \@errs;
}

sub fix_apache_errors {
	my ( $errs, $user, $num_err ) = @_;
	my @manual;
	my @limits;
	FE::Core::info("Found $num_err errors");
	my $found_count = 1;
	foreach my $err (@$errs) {

		# HG Limiting
		if ( $err =~ /SystemException\sin\sAPI_Linux.cpp:\d+\sexecve\(\)\sfor\sprogram\s"\/usr\/bin\/php"/xsm ) {
			push @limits, "Process Limit Warning";
		}

		# Old htaccess rule sets
		if (
			$err =~ /(\S+):\sInvalid\scommand\s'php_flag',\sperhaps\smisspelled\sor\sdefined
                              \sby\sa\smodule\snot\sincluded\sin\sthe\sserver\sconfiguration/xsm
				)
		{
			push @manual, "php_flag or php_value error on $1";
		}
		else {
			push @manual, $err;
		}
	}
	my $limit_count = @limits;
	if ( $limit_count >= 1 ) {
		print "\n\t...account limits...\n";
		foreach my $limit (@limits) {
			FE::Core::failed($limit);
		}
	}
	my $man_count = @manual;
	if ( $man_count >= 1 ) {
		print "\n\t...Errors...\n";
		foreach my $man (@manual) {
			FE::Core::failed($man);
		}
	}
	print "\n\n";
}

1;
