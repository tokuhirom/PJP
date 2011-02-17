use strict;
use warnings;
use utf8;
use 5.10.0;

# perl -Ilib -e 'use PJP::M::Index::Module; use PJP; my $c = PJP->bootstrap; PJP::M::Index::Module->generate_and_save($c)'

package PJP::M::Index::Module;
use LWP::UserAgent;
use CPAN::DistnameInfo;
use Log::Minimal;
use URI::Escape qw/uri_escape/;
use JSON;
use File::Spec::Functions qw/catfile/;
use File::Find::Rule;
use version;
use autodie;
use PJP::M::Pod;
use Data::Dumper;

sub slurp {
    if (@_==1) {
        my ($stuff) = @_;
        open my $fh, '<', $stuff or die "Cannot open file: $stuff";
        do { local $/; <$fh> };
    } else {
        die "not implemented yet.";
    }
}

sub get {
    my ($class, $c) = @_;

    my $fname = $class->cache_path($c);
    unless (-f $fname) {
        die "Missing '$fname'";
    }

    return do $fname;
}

sub cache_path {
    my ($class, $c) = @_;
    return catfile($c->base_dir(), 'assets', 'index-module.pl');
}

sub generate_and_save {
    my ($class, $c) = @_;

    my $fname = $class->cache_path($c);

    my @data = $class->generate($c);
    local $Data::Dumper::Terse  = 1;
    local $Data::Dumper::Indent = 1;
    local $Data::Dumper::Purity = 1;

    open my $fh, '>', $fname;
    print $fh Dumper(\@data);
    close $fh;

    return;
}

sub generate {
    my ($class, $c) = @_;

    # 情報をかきあつめる
    my @mods;
    for my $base (qw(
        assets/perldoc.jp/docs/modules/
        assets/module-pod-jp/docs/modules/
    )) {
        push @mods, $class->_generate($c, $base);
    }

    # モジュールを中心に GROUP 化する
    my %module2versions;
    for (@mods) {
        push @{$module2versions{$_->{name}}}, $_;
    }
    for my $module ( keys %module2versions ) {
        $module2versions{$module} = [
            map            { $_->[0] }
              reverse sort { $a->[1] <=> $b->[1] }
              map {
                [ $_, eval { version->new( $_->{version} ) } || 0 ]
              } @{ $module2versions{$module} }
        ];
    }

    my @sorted = (
        map {
            +{
                name     => $_,
                abstract => $module2versions{$_}->[0]->{abstract},
                repository => $module2versions{$_}->[0]->{repository},
                latest_version => $module2versions{$_}->[0]->{latest_version},
                versions => $module2versions{$_}
              }
          }
          sort { $a cmp $b } keys %module2versions
    );
    return @sorted;
}

sub _generate {
    my ($class, $c, $base) = @_;
    state $ua = LWP::UserAgent->new(agent => 'PJP', timeout => 1);

    my $repository = do {
        local $_ = $base;
        s!assets/!!;
        s!/.+!!;
        $_;
    };

    my @mods;
    opendir(my $dh, $base);
    while (defined(my $e = readdir $dh)) {
        next if $e =~ /^\./;
        next if $e =~ /^CVS$/;
        my ($dist, $version) = CPAN::DistnameInfo::distname_info($e);
        my $row = {distvname => $e, name => $dist, version => $version};

        # get information from FrePAN
        my $data = $c->cache->get_or_set("frepanapi:1:$e", sub {
            my $res = $ua->get('http://frepan.org/api/v1/dist/show.json?dist_name=' . uri_escape($dist));
            if ($res->is_success) {
                my $data = JSON::decode_json($res->content);
                infof("api response: %s", ddf($data));
                $data;
            } else {
                warnf("Cannot get latest version info from frepan API: %s, %s", $res->status_line, $res->content);
                undef;
            }
        });
        if ($data) {
            $row->{latest_version} = $data->{version};
            $row->{abstract}       = $data->{abstract};
        }

        # ファイル名のいちばん短い pod ファイルが代表格といえる
        my ($pod_file) = sort { length($a) <=> length($b) }
            File::Find::Rule->file()
                            ->name('*.pod')
                            ->in("$base/$e");

        # pod file が一個もないものは表示しない(具体的には CPANPLUS)
        next unless $pod_file;

        infof("parsing %s", $pod_file);
        my ($name, $desc) = PJP::M::Pod->parse_name_section($pod_file);
        if ($desc) {
            infof("Japanese Description: %s, %s", $name, $desc);
            $row->{abstract} = $desc;
        }

        $row->{repository} = $repository;

        push @mods, $row;
    }
    return @mods;
}

1;

