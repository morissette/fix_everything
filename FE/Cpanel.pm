package FE::Cpanel;
use strict;
use warnings;
use FE::Core;

our $debug = 1;

sub check_user_exists {
	my $user = shift;
	if ($user) {
		if ( -f "/var/cpanel/users/$user" ) {
			return 1;
		}
	}
	else {
		return 0;
	}
}

sub get_domains_from_user {
	my $user = shift;
	my $file = "/var/cpanel/userdata/$user/main";
	my (@domains);
	open my $fh, '<', $file or FE::Core::failed("Userdata file for $user is missing");
	while (<$fh>) {

		# pull addon domains
		if ( $_ =~ /(\S+):\s/xsm && $_ !~ /_/xsm ) {
			push @domains, $1;
		}

		# pull main domain
		if ( $_ =~ /main_domain:\s(\S+)/xsm ) {
			push @domains, $1;
		}

		# pull parked domains
		if ( $_ =~ /-\s(\S+)/xsm ) {
			push @domains, $1;
		}
		if ( $_ =~ /sub_domains:/xsm ) {
			last;
		}
	}
	close $fh;
	return @domains;
}

1;
