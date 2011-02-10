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

{
    package PJP::Template;
    use parent qw/Exporter/;
    use HTML::Zoom;
    use File::Spec;
    use File::Spec::Functions qw/catfile catdir/;
    use Amon2::Declare;
    use Encode qw/encode_utf8/;

    our @EXPORT = qw/h/;

    sub h { HTML::Zoom->from_html($_[0]) }

    sub new {
        my $class = shift;
        my %args = @_==1 ? %{$_[0]} : @_;
        return bless {%args}, $class;
    }

    sub load_file {
        my ($self, $fname) = @_;

        $fname = File::Spec->catfile(c()->base_dir(), "tmpl/$fname") unless -f $fname;

        open my $fh, '<:utf8', $fname or die "Cannot open file '$fname': $!";
        my $content = do { local $/; <$fh> };
        $self->{content} = HTML::Zoom->from_html($content);
        return $self;
    }

    # ->replace($selector, [$tmpl, \%vars]);
    # ->replace($selector, $string);
    sub replace {
        my ($self, $selector) = (shift, shift);
        if (ref $_[0] eq 'ARRAY') {
            my ($tmpl, $vars) = @{ $_[0] };
            my $html = c()->create_view->render($tmpl, $vars || +{});
            $self->{content} = $self->{content}->select($selector)->replace_content(HTML::Zoom->from_html($html));
        } else {
            my $string = $_[0];
            $self->{content} = $self->{content}->select($selector)->replace_content($string);
        }
        return $self;
    }

    sub to_html {
        $_[0]->{content}->to_html();
    }

    sub as_response {
        my $self = shift;
        my $html = encode_utf8($self->to_html());
        PJP::Web->create_response(
            200,
            [
                'Content-Type'  => 'text/html; charset=utf-8',
                'Conten-Length' => length($html),
            ],
            [$html]
        );
    }
}

PJP::Template->import();

get '/' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render($c);
    my $toc_func = PJP::M::TOC->render_function($c);
    PJP::Template->new()
                 ->load_file('layout.html')
                 ->replace('#content' => [
                    'index.tt'
                 ])
                 ->as_response();
};

get '/index/core' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render($c);
    PJP::Template->new()
                 ->load_file('layout.html')
                 ->replace(title => 'コアドキュメント - perldoc.jp')
                 ->replace('#content' => h($toc))
                 ->as_response();
};

get '/index/function' => sub {
    my $c = shift;

    my $toc = PJP::M::TOC->render_function($c);
    PJP::Template->new()
                 ->load_file('layout.html')
                 ->replace(title => '組み込み関数 - perldoc.jp')
                 ->replace('#content' => h($toc))
                 ->as_response();
};

# モジュールの目次
get '/index/module' => sub {
    my $c = shift;

    my $index = PJP::M::Index::Module->get($c);

    my $toc = PJP::M::TOC->render_function($c);
    PJP::Template->new()
                 ->load_file('layout.html')
                 ->replace(title => '翻訳済モジュール - perldoc.jp')
                 ->replace('#content' => h(
                    $c->create_view->render('index/module.tt', {
                        index => $index,
                    })
                 ))
                 ->as_response();
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
    my ($html, $package, $description) = @{$c->cache->file_cache("pod:8", $path, sub {
        [PJP::M::Pod->pod2html($path), PJP::M::Pod->parse_name_section($path)];
    })};
    my $is_old = $path !~ /delta/ && eval { version->parse($version) } < eval { version->parse("5.8.5") };

    PJP::Template->new()
                 ->load_file('layout.html')
                 ->replace('#content' => [
                    'pod.tt', {
                        is_old    => $is_old,
                        version   => $version
                    }
                 ])
                 ->replace('title' => "$package - $description 【perldoc.jp】")
                 ->replace('.PodVersion' => "perl-$version")
                 ->replace('.PodBody' => h($html))
                 ->as_response();
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

        PJP::Template->new()
                     ->load_file('layout.html')
                     ->replace('#content' => [
                         'pod.tt', {
                             body => $out,
                             version => $version,
                         }
                     ])
                     ->replace('.PodVersion' => "perl-$version")
                     ->replace('title' => "$name 【perldoc.jp】")
                     ->as_response();
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
        PJP::Template->new()
                     ->load_file('layout.html')
                     ->replace('#content' => [
                         'pod.tt', {
                            body      => $html,
                            distvname => $distvname,
                            subtitle  => do { ( my $subtitle = $path ) =~ s!/modules/!!; $subtitle },
                            package   => $package,
                            description => $description,
                         }
                     ])
                     ->replace('.PodVersion' => $distvname)
                     ->replace('title' => "$package - $description 【perldoc.jp】")
                     ->as_response();
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

        PJP::Template->new()
                     ->load_file('layout.html')
                     ->replace('#content' => [
                         'directory_index.tt', {
                            index => [sort @index],
                            path => $c->req->path_info,
                         }
                     ])
                     ->replace('title' => "@{[ $c->req->path_info ]} 【perldoc.jp】")
                     ->as_response();
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
