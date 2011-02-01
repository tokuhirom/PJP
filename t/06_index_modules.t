use strict;
use warnings;
use utf8;
use Test::More;
use PJP::M::Index::Module;
use PJP;
use Log::Minimal;

my $c = PJP->bootstrap;
my @out = PJP::M::Index::Module->get($c);
note ddf(\@out);
ok scalar(@out);

done_testing;

