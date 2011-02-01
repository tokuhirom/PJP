use strict;
use warnings;
use utf8;

package PJP::M::Index::Module;

sub get {
    my ($class, $c) = @_;

    my @mods;
    opendir my $dh, 'assets/perldoc.jp/docs/modules/';
    while (defined(my $e = readdir $dh)) {
        next if $e =~ /^\./;
        next if $e =~ /^CVS$/;
        push @mods, $e;
    }
    @mods = sort @mods;
    return @mods;
}

1;

