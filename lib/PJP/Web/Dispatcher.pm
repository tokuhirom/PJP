package PJP::Web::Dispatcher;
use strict;
use warnings;

use Amon2::Web::Dispatcher::Lite;
use Pod::Simple::XHTML;
use Log::Minimal;
use PJP::M::TOC;
use PJP::M::Pod;

get '/' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render();
    $c->render('index.tt', {toc => $toc});
};

get '/pod/*' => sub {
    my ($c, $p) = @_;
    my ($splat) = @{$p->{splat}};

    my @path = map { $_->[0] } reverse sort { eval { version->parse($a->[1]) } <=> eval { version->parse($b->[1]) } } map {
        +[ $_, map { local $_=$_; s!.*/perl/!!; s!/$splat.pod!!; $_ } $_ ]
    } glob("assets/perldoc.jp/docs/perl/*/$splat.pod");
    my ($latest) = @path;
    my $path = $latest;

    unless ($path) {
        warnf("missing %s, %s", ddf($splat), ddf(\@path));
        return $c->render('please-translate.tt', {name => $splat});
    }

    my ($version) = ($path =~ m{([^/]+)\/\Q$splat.pod\E\Z});

    my $out = PJP::M::Pod->pod2html($path);
    return $c->render('pod.tt', { body => $out, version => $version });
};

1;
