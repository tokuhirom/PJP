use strict;
use warnings;
use utf8;
use 5.10.0;

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
    if (-f $fname) {
        my $json = slurp $fname;
        return JSON::decode_json($json);
    } else {
        return $class->generate_and_save($c);
    }
}

sub cache_path {
    my ($class, $c) = @_;
    return catfile($c->base_dir(), 'assets', 'index-module.pl');
}

sub generate_and_save {
    my ($class, $c) = @_;

    my $fname = $class->cache_path($c);
    my @data = $class->generate($c);
    open my $fh, '>', $fname;
    print $fh JSON->new->pretty->canonical->utf8->encode(\@data);
    close $fh;

    return \@data;
}

sub generate {
    my ($class, $c) = @_;

    my @mods;
    for my $base (qw(
        assets/perldoc.jp/docs/modules/
        assets/module-pod-jp/docs/modules/
    )) {
        push @mods, $class->_generate($c, $base);
    }
    my %sort_tmp;
    @mods = sort { $a->{name} cmp $b->{name} or
                   ($sort_tmp{$b} ||= version->new($b->{version})) <=> ($sort_tmp{$a} ||= version->new($a->{version}))
                 }  @mods;
    infof("data: %s", ddf(\@mods));
    return @mods;
}

sub _generate {
    my ($class, $c, $base) = @_;
    state $ua = LWP::UserAgent->new(agent => 'PJP', timeout => 1);

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
                warnf("Cannot get latest version info from frepan API: %s", $res->status_line);
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
        if ($pod_file) {
            infof("parsing %s", $pod_file);
            my ($name, $desc) = PJP::M::Pod->parse_name_section($pod_file);
            if ($desc) {
                infof("Japanese Description: %s, %s", $name, $desc);
                $row->{abstract} = $desc;
            }
        }

        push @mods, $row;
    }
    return @mods;
}

1;

