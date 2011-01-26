use strict;
use warnings;
use utf8;
use Test::More;
use PJP::M::TOC;

my $out = PJP::M::TOC->render();
note $out;
ok $out;

done_testing;

