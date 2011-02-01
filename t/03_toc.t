use strict;
use warnings;
use utf8;
use Test::More;
use PJP::M::TOC;
use PJP;

my $c = PJP->bootstrap;
my $out = PJP::M::TOC->render($c);
note $out;
ok $out;

done_testing;

