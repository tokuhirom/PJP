package PJP::Web::Dispatcher;
use strict;
use warnings;
use utf8;

use Amon2::Web::Dispatcher::Lite;
use Pod::Simple::XHTML;
use Log::Minimal;
use PJP::M::TOC;
use PJP::M::Index::Module;
use PJP::M::Pod;
use File::stat;
use Try::Tiny;
use Text::Xslate::Util qw/mark_raw/;

get '/' => sub {
    my $c = shift;

    return $c->render('index.tt');
};

get '/index/core' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render($c);
    return $c->render('index/core.tt', {
        title => 'コアドキュメント - perldoc.jp',
        toc   => $toc,
    });
};

get '/index/function' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render_function($c);
    return $c->render('index/function.tt' => {
        title => '組み込み関数 - perldoc.jp',
        toc   => $toc,
    });
};

# モジュールの目次
get '/index/module' => sub {
    my $c = shift;

    my $content = $c->cache->file_cache("index/module", PJP::M::Index::Module->cache_path($c), sub {
        my $index = PJP::M::Index::Module->get($c);
        $c->create_view->render(
            'index/module.tt' => {
                index => $index,
            }
        );
    });

    $c->render(
        'layout.html' => {
            title => '翻訳済モジュール - perldoc.jp',
            content => mark_raw($content),
        }
    );
};

# 添付 pod の表示
get '/pod/*' => sub {
    my ($c, $p) = @_;
    my ($splat) = @{$p->{splat}};

    my $path_info = PJP::M::Pod->get_latest_file_path($splat);
    unless ($path_info) {
        warnf("missing %s, %s", $splat);
        return $c->render(
            'please-translate.tt' => {
                name => $splat
            },
        );
    }

    my ($path, $version) = @$path_info;
    my ($html, $package, $description) = @{$c->cache->file_cache("pod:17", $path, sub {
        [PJP::M::Pod->pod2html($path), PJP::M::Pod->parse_name_section($path)];
    })};
    my $is_old = $path !~ /delta/ && eval { version->parse($version) } < eval { version->parse("5.8.5") };

    return $c->render('pod.tt' => {
        is_old    => $is_old,
        version   => $version,
        'title' => "$package - $description 【perldoc.jp】",
        'PodVersion' => "perl-$version",
        'body' => $html,
    });
};

use Pod::Perldoc;
get '/func/*' => sub {
    my ($c, $p) = @_;
    my ($name) = @{$p->{splat}};

    my $path_info = PJP::M::Pod->get_latest_file_path('perlfunc');
    my ($path, $version) = @$path_info;

    try {
        my $out = $c->cache->file_cache("func:$name:5", $path, sub {
            infof("rendering %s from %s", $name, $path);
            my @dynamic_pod;
            my $perldoc = Pod::Perldoc->new(opt_f => $name);
            $perldoc->search_perlfunc([$path], \@dynamic_pod);
            my $pod = join("", "=encoding euc-jp\n\n=over 4\n\n", @dynamic_pod, "=back\n");
            $pod =~ s!L</([a-z]+)>!L<$1|http://perldoc.jp/func/$1>!g;
            PJP::M::Pod->pod2html(\$pod);
        });

        return $c->render(
            'pod.tt' => {
                body => $out,
                version => $version,
                title => "$name 【perldoc.jp】",
                'PodVersion' => "perl-$version",
            },
        );
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

use File::Spec::Functions qw/catfile abs2rel catdir/;
use Cwd ();
use File::Find qw/finddepth/;
get '/docs/modules/{dist:[A-Za-z0-9._-]+}{trailingslash:/?}' => sub {
    my ($c, $p) = @_;
    my ($path, ) = glob(catdir($c->base_dir(), 'assets', '*', 'docs', 'modules', $p->{dist}));
    unless (-d $path) {
        warnf("path '%s' is missing", $p->{path});
        return $c->res_404();
    }

    # directory index
    my @index;
    finddepth(sub {
        unless (/^\./ || /^CVS$/ || $File::Find::name =~ m{/CVS/} || -d $_) {
            if (/\.pod$/) {
                my ($package, $desc) = PJP::M::Pod->parse_name_section($File::Find::name);
                push @index,
                    [
                    abs2rel( $File::Find::name, $path ),
                    $package || abs2rel($File::Find::name, $path),
                    $desc
                    ];
            }
        }
        return 1; # need true value
    }, $path);

    my $distvname = $c->req->path_info;
    $distvname =~ s!\/$!!;
    $distvname =~ s!.+\/!!;
    return $c->render(
        'directory_index.tt' => {
            index     => [ sort { $a->[0] cmp $b->[0] } @index ],
            distvname => $distvname,
            'title' => "$distvname 【perldoc.jp】",
        }
    );
};

get '/docs/modules/{path:.+\.pod}' => sub {
    my ($c, $p) = @_;

    my ($path, ) = map { Cwd::realpath($_) } glob(catdir($c->base_dir(), 'assets', '*', 'docs', 'modules', $p->{path}));
    unless (-f $path) {
        warnf("path '%s' is missing", $p->{path});
        return $c->res_404();
    }

    return $c->show_403() if $path      =~ m{/CVS(/|$)};
    return $c->show_403() if $p->{path} =~ m{\.\.};
    my $base = Cwd::realpath(catdir($c->base_dir(), 'assets'));
    return $c->show_403() unless $path =~ qr{^\Q$base\E/[a-zA-Z0-9._-]+/docs/modules/([^/]+)/};
    my $distvname = $1;

    my ($html, $package, $description) = @{$c->cache->file_cache("path:19", $path, sub {
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
            'PodVersion' => $distvname,
            'title' => "$package - $description 【perldoc.jp】",
        }
    );
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
