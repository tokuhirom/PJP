package PJP::Web::Dispatcher;
use strict;
use warnings;

use Amon2::Web::Dispatcher::Lite;
use Pod::Simple::XHTML;
use Log::Minimal;
use PJP::M::TOC;
use PJP::M::Pod;
use File::stat;

get '/' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render($c);
    my $toc_func = PJP::M::TOC->render_function($c);
    $c->render('index.tt', {toc => $toc, toc_func => $toc_func});
};

get '/pod/*' => sub {
    my ($c, $p) = @_;
    my ($splat) = @{$p->{splat}};

    my $path_info = PJP::M::Pod->get_latest_file_path($splat);
    unless ($path_info) {
        warnf("missing %s, %s", $splat);
        return $c->render('please-translate.tt', {name => $splat});
    }

    my ($path, $version) = @$path_info;
    my $out = $c->cache->file_cache("pod:2", $path, sub {
        PJP::M::Pod->pod2html($path);
    });

    return $c->render('pod.tt', { body => $out, version => $version });
};

use Pod::Perldoc;
get '/func/*' => sub {
    my ($c, $p) = @_;
    my ($name) = @{$p->{splat}};

    my $path_info = PJP::M::Pod->get_latest_file_path('perlfunc');
    my ($path, $version) = @$path_info;

    my $out = $c->cache->file_cache("func:$name", $path, sub {
        infof("rendering %s from %s", $name, $path);
        my @dynamic_pod;
        my $perldoc = Pod::Perldoc->new(opt_f => $name);
        $perldoc->search_perlfunc([$path], \@dynamic_pod);
        PJP::M::Pod->pod2html(\(join("", "=encoding euc-jp\n\n=over 4\n\n", @dynamic_pod, "=back\n")));
    });

    return $c->render('pod.tt', { body => $out, version => $version });
};

1;
