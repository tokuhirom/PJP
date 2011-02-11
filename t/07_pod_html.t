use strict;
use warnings;
use utf8;
use Test::More;
use PJP::M::Pod;

my $html = PJP::M::Pod->pod2html('assets/perldoc.jp/docs/perl/5.12.1/perl.pod');
ok $html;

# HTML をチェックする
my $testee = $html;
for my $tag (qw/div pre p h1 h2 code b a ul li nobr i/) {
    my ($open, $close) = (0, 0);
    $testee =~ s/<$tag[^>]*>/$open++/gei;
    $testee =~ s!</$tag[^>]*>!$close++!gei;
    cmp_ok $open, '>', 0, $tag;
    cmp_ok $open, '=', $close;
}

done_testing;

