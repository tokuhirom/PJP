package PJP::Web::Dispatcher;
use strict;
use warnings;

use Amon2::Web::Dispatcher::Lite;
use Pod::Simple::XHTML;
use Log::Minimal;
use PJP::M::TOC;
use PJP::M::Index::Module;
use PJP::M::Pod;
use File::stat;

get '/' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render($c);
    my $toc_func = PJP::M::TOC->render_function($c);
    $c->render('index.tt', {toc => $toc, toc_func => $toc_func});
};

get '/index/core' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render($c);
    $c->render('index/core.tt', {toc => $toc});
};

get '/index/function' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render_function($c);
    $c->render('index/function.tt', {toc => $toc});
};

# モジュールの目次
get '/index/module' => sub {
    my $c = shift;

    my @index = PJP::M::Index::Module->get($c);
    $c->render('index/module.tt', {index => \@index});
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
    my $out = $c->cache->file_cache("pod:4", $path, sub {
        PJP::M::Pod->pod2html($path);
    });

    return $c->render('pod.tt', { body => $out, version => $version, subtitle => $splat });
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

# TODO: Plack::App::Directory つかうのやめたい
use Plack::App::Directory;
use File::Spec::Functions qw/catfile/;
use Cwd ();
my $dirapp = Plack::App::Directory->new({root => "./assets/perldoc.jp/"});
get '/docs{path:/|/.+}' => sub {
    my ($c, $p) = @_;
    my $path = $p->{path};
    $path = Cwd::realpath(catfile("./assets/perldoc.jp/docs/$path"));
    my $container = Cwd::realpath(catfile("./assets/perldoc.jp/docs/"));

    if ($path =~ m{/CVS(/|$)} || $path !~ m{^\Q$container} || $p->{path} =~ /\.\./) {
        return $c->create_response(403, ['Content-Type' => 'text/html; charset=utf-8'], ['forbidden']);
    }

    if ($path =~ m{/([^/]+)/[^/]+\.pod$}) {
        my $distvname = $1;
        my $out = $c->cache->file_cache("path:3", $path, sub {
            PJP::M::Pod->pod2html($path);
        });
        return $c->render(
            'pod.tt',
            {
                body    => $out,
                version => $distvname,
                subtitle =>
                  do { ( my $subtitle = $path ) =~ s!/modules/!!; $subtitle }
            }
        );
    } elsif (-f $path) {
        return $c->show_error("未知のファイル形式です: $p->{path}");
    } else {
        my @index;
        opendir my $dh, $path or die "Cannot open directory: $path";
        while (defined(my $e = readdir($dh))) {
            next if $e =~ /^\./;
            next if $e =~ /^CVS$/;
            push @index, $e;
        }
        return $c->render('directory_index.tt', {index => \@index, path => $c->req->path_info});
    }
};

1;
