use strict;
use warnings;
use utf8;
use Test::More;
use PJP::M::Pod;

my $out = PJP::M::Pod->pod2package_name(\(<<'...'));
foo
bar
__END__

=head1 NAME

B<OK> - foobar

=head1 SYNOPSIS

    This is a sample pod

...
is $out, "OK";

is(PJP::M::Pod->pod2package_name('assets/perldoc.jp/docs/modules/Acme-Bleach-1.12/Bleach.pod'), "Acme::Bleach");

done_testing;

