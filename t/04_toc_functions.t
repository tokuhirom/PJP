use strict;
use warnings;
use utf8;
use t::Util;
use Test::More;
use PJP::M::TOC;
use PJP;

my $c = PJP->bootstrap;
my $out = PJP::M::TOC->render_function($c);
note $out;
ok $out;

done_testing;

