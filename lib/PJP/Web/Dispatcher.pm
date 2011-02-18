package PJP::Web::Dispatcher;
use strict;
use warnings;
use utf8;

use Amon2::Web::Dispatcher::Lite;

use Log::Minimal;
use File::stat;
use Try::Tiny;
use Text::Xslate::Util qw/mark_raw/;

use PJP::M::TOC;
use PJP::M::Index::Module;
use PJP::M::Pod;
use PJP::M::PodFile;

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
    my ($package) = @{$p->{splat}};

    my $path = PJP::M::PodFile->get_latest(
        $package
    );
    return $c->res_404() unless $path;
    # my $is_old = $path !~ /delta/ && eval { version->parse($version) } < eval { version->parse("5.8.5") };

    return $c->redirect("/docs/$path");
};

use PJP::M::BuiltinFunction;
get '/func/*' => sub {
    my ($c, $p) = @_;
    my ($name) = @{$p->{splat}};

    my ($version, $html) = PJP::M::BuiltinFunction->retrieve($name);
    if ($version && $html) {
        return $c->render(
            'pod.tt' => {
                body         => mark_raw($html),
                title        => "$name 【perldoc.jp】",
                'PodVersion' => "perl-$version",
            },
        );
    } else {
        my $res = $c->show_error("'$name' は Perl の組み込み関数ではありません。");
        $res->code(404);
        return $res;
    }
};

get '/docs/modules/{distvname:[A-Za-z0-9._-]+}{trailingslash:/?}' => sub {
    my ($c, $p) = @_;
    my $distvname = $p->{distvname};

    my @rows = PJP::M::PodFile->search_by_distvname($distvname);
    return $c->res_404() unless @rows;

    return $c->render(
        'directory_index.tt' => {
            index     => \@rows,
            distvname => $distvname,
            'title'   => "$distvname 【perldoc.jp】",
        }
    );
};

# .pod.pod の場合は生のソースを表示する
get '/docs/{path:(modules|perl)/.+\.pod}.pod' => sub {
    my ($c, $p) = @_;

    my $content = PJP::M::PodFile->slurp($p->{path}) // return $c->res_404();

    my ($charset) = ($content =~ /=encoding\s+(euc-jp|utf-?8)/);
        $charset //= 'utf-8';

    $c->create_response(
        200,
        [
            'Content-Type'           => "text/plain; charset=$charset",
            'Content-Length'         => length($content),
        ],
        [$content]
    );
};

get '/docs/{path:(modules|perl)/.+\.pod}' => sub {
    my ($c, $p) = @_;

    my $pod = PJP::M::PodFile->retrieve($p->{path});
    if ($pod) {
        my @others = do {
            if ($pod->{package}) {
                grep { $_->{distvname} ne $pod->{distvname} }
                  PJP::M::PodFile->other_versions( $pod->{package} );
            } else {
                ();
            }
        };
        return $c->render(
            'pod.tt' => {
                body         => mark_raw( $pod->{html} ),
                others       => \@others,
                distvname    => $pod->{distvname},
                package      => $pod->{package},
                description  => $pod->{description},
                'PodVersion' => $pod->{distvname},
                'title' =>
                  "$pod->{package} - $pod->{description} 【perldoc.jp】",
                repository => $pod->{repository},
                path       => $pod->{path},
            }
        );
    } else {
        return $c->res_404();
    }
};

get '/perl*' => sub {
    my ($c, $p) = @_;
    my ($splat) = @{$p->{splat}};
    return $c->redirect("/pod/perl$splat");
};

my $re = join('|', qw(
  -r -w -x -o -R -W -X -O -e -z -s -f -d -l -p
  -S -b -c -t -u -g -k -T -B -M -A -C
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
