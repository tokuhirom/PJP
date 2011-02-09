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
use Try::Tiny;

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

    my $index = PJP::M::Index::Module->get($c);
    $c->render('index/module.tt', {index => $index});
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
    my $out = $c->cache->file_cache("pod:6", $path, sub {
        PJP::M::Pod->pod2html($path);
    });
    my $is_old = $path !~ /delta/ && eval { version->parse($version) } < eval { version->parse("5.8.5") };

    return $c->render('pod.tt', { body => $out, distvname => "perl-$version", subtitle => $splat, is_old => $is_old, version => $version });
};

use Pod::Perldoc;
get '/func/*' => sub {
    my ($c, $p) = @_;
    my ($name) = @{$p->{splat}};

    my $path_info = PJP::M::Pod->get_latest_file_path('perlfunc');
    my ($path, $version) = @$path_info;

    try {
        my $out = $c->cache->file_cache("func:$name:1", $path, sub {
            infof("rendering %s from %s", $name, $path);
            my @dynamic_pod;
            my $perldoc = Pod::Perldoc->new(opt_f => $name);
            $perldoc->search_perlfunc([$path], \@dynamic_pod);
            PJP::M::Pod->pod2html(\(join("", "=encoding euc-jp\n\n=over 4\n\n", @dynamic_pod, "=back\n")));
        });

        return $c->render('pod.tt', { body => $out, version => $version });
    } catch {
        if (/No documentation for perl function/) {
            my $res = $c->show_error("'$name' は Perl の組み込み関数ではありません。");
            $res->code(404);
            return $res;
        } else {
            die $_;
        }
    };
};

use File::Spec::Functions qw/catfile abs2rel/;
use Cwd ();
use File::Find qw/finddepth/;
get '/docs{path:/|/.+}' => sub {
    my ($c, $p) = @_;
    my $path = $p->{path};
    $path = Cwd::realpath(catfile("./assets/perldoc.jp/docs/$path")) or do {
        warnf("path '%s' is missing", $p->{path});
        return $c->res_404();
    };
    my $container = Cwd::realpath(catfile("./assets/perldoc.jp/docs/"));

    if ($path =~ m{/CVS(/|$)} || $path !~ m{^\Q$container} || $p->{path} =~ /\.\./) {
        return $c->create_response(403, ['Content-Type' => 'text/html; charset=utf-8'], ['forbidden']);
    }

    if ($path =~ m{/([^/]+)/[^/]+\.pod$}) {
        my $distvname = $1;
        my ($html, $package, $description) = @{$c->cache->file_cache("path:17", $path, sub {
            infof("rendering %s", $path);
            [PJP::M::Pod->pod2html($path), PJP::M::Pod->parse_name_section($path)];
        })};
        return $c->render(
            'pod.tt' => {
                body      => $html,
                distvname => $distvname,
                subtitle  => do { ( my $subtitle = $path ) =~ s!/modules/!!; $subtitle },
                package   => $package,
                description => $description,
            }
        );
    } elsif (-f $path) {
        return $c->show_error("未知のファイル形式です: $p->{path}");
    } else {
        my @index;
        finddepth(sub {
            unless (/^\./ || /^CVS$/ || $File::Find::name =~ m{/CVS/} || -d $_) {
                push @index, abs2rel($File::Find::name, $path);
            }
            return 1; # need true value
        }, $path);
        return $c->render('directory_index.tt', {index => [sort @index], path => $c->req->path_info});
    }
};

get '/perl*' => sub {
    my ($c, $p) = @_;
    my ($splat) = @{$p->{splat}};
    return $c->redirect("/pod/perl$splat");
};

my $re = join('|', qw(
  abs accept alarm atan bind binmode bless break caller chdir chmod chomp chop chown chr chroot close closedir connect
  continue cos crypt dbmclose dbmopen defined delete die do dump each endgrent endhostent endnetent endprotoent endpwent
  endservent eof eval bynumber getprotoent getpwent getpwnam getpwuid getservbyname getservbyport getservent
  getsockname getsockopt glob gmtime goto grep hex import index int ioctl join keys kill last lc lcfirst length link
  listen local localtime lock log lstat m map mkdir msgctl msgget msgrcv msgsnd my next no oct open opendir ord order
  our pack package pipe pop pos precision print printf prototype push q qq qr quotemeta qw qx rand read readdir readline
  readlink readpipe recv redo ref rename require reset return reverse rewinddir rindex rmdir s say scalar seek seekdir select
  semctl semget semop send setgrent sethostent setnetent setpgrp setpriority setprotoent setpwent setservent setsockopt shift
  shmctl shmget shmread shmwrite shutdown sin size sleep socket socketpair sort splice split sprintf sqrt srand stat state
  study sub substr symlink syscall sysopen sysread sysseek system syswrite tell telldir tie tied time times tr truncate uc
  ucfirst umask undef unlink unpack unshift untie use utime values vec vector wait waitpid wantarray warn write y
));
get "/{name:$re}" => sub {
    my ($c, $p) = @_;

    return $c->redirect("/func/$p->{name}");
};

1;
