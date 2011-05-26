package PJP;
use strict;
use warnings;
use parent qw/Amon2/;
our $VERSION='0.01';
use 5.01000;

use Amon2::Config::Simple;
sub load_config { Amon2::Config::Simple->load(shift) }

use PJP::Cache;
my $cache = PJP::Cache->new();
sub cache { $cache }

use PJP::DBI;
sub dbh {
	my $c = shift;
	my $conf = $c->config->{DB} // die "Missing mandatory configuraion parameter: DB";
	return $c->{db} //= PJP::DBI->connect(@$conf);
}

sub assets_dir {
    my $c = shift;
    $c->config->{assets_dir} // die "Missing configuration for assets dir";
}

1;
