package FE::Core;
use strict;
use warnings;
use Term::ANSIColor;
use Cwd;

sub failed {
	my $msg = shift;
	print color 'red';
	print '[!!] ';
	print color 'reset';
	print $msg . "\n";
}

sub passed {
	my $msg = shift;
	print color 'green';
	print '[ok] ';
	print color 'reset';
	print $msg . "\n";
}

sub debug {
	my $msg = shift;
	print color 'yellow';
	print '[%%] ';
	print color 'reset';
	print $msg . "\n";
}

sub info {
	my $msg = shift;
	print color 'blue';
	print '[**] ';
	print color 'reset';
	print $msg . "\n";
}

sub sub_msg {
    my $msg = shift;
    print "     -> $msg\n";
}

sub get_user {
	my $pwd         = getcwd;
	my @structure   = split( '/', $pwd );
	my $user        = $structure[2];
	my $user_exists = FE::Cpanel::check_user_exists($user);
	if ($user_exists) {
		return $user;
	} elsif ( ! $user ) {
        failed("Unable to detect user from path");
        return 0;
	} else {
		failed("User '$user' does not exist");
		return 0;
	}
}

sub test_environment {
    my @cpanel_dirs = qw|
        /var/cpanel
        /usr/local/cpanel
        /home/virtfs
    |;
    my $found_dirs = 0;
    foreach my $dir ( @cpanel_dirs ) {
        if ( -d $dir ) {
            $found_dirs++;
        }
    }
    if ( $found_dirs != scalar(@cpanel_dirs) ) {
        failed('Fix Everything is built for cPanel servers only');
        exit;
    }
}

1;
