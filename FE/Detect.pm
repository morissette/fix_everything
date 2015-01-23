package FE::Detect;
use strict;
use warnings;
use FE::Cpanel;
use FE::Core;
use JSON;
use Cwd;

our $debug = 1;
our $conf  = undef;

sub find_software {
    my $user = shift;
	my $config = '/root/bin/FE/Configs/software.json';
	if ( -f $config ) {
		local $/;
		open my $fh, '<', $config or die $!;
		my $json_text = <$fh>;
		close $fh;
		$conf = decode_json($json_text);
		return detect_software($user);
	}
	else {
		FE::Core::failed("Unable to find software configurations");
		return 0;
	}
}

sub detect_software {
	my $user  = shift;
	my $count = 0;
	my $found = {};
	foreach my $software ( keys %{ $conf->{'software'} } ) {
		foreach my $file ( @{ $conf->{'software'}->{$software}->{'files'} } ) {
			if ( -f $file ) {
				$found->{$software}->{'found'}++;
				$count++;
			}
			$found->{$software}->{'total'}++;
		}
		foreach my $dir ( @{ $conf->{'software'}->{$software}->{'dirs'} } ) {
			if ( -d $dir ) {
				$found->{$software}->{'found'}++;
				$count++;
			}
			$found->{$software}->{'total'}++;
		}
	}

	if ($count) {
		foreach my $cms ( sort { $found->{$a}->{'found'} < $found->{$b}->{'found'} } keys %{$found} ) {

			# provide some leighway for custom mods
			my $limit = $found->{$cms}->{'total'} - 5;
			if ( $found->{$cms}->{'found'} > $limit ) {
				FE::Core::info("Detected " . ucfirst($cms));
				return $cms;
			}
			else {
				FE::Core::failed("Unable to detect software");
				return 0;
			}
		}
	}
}

1;
