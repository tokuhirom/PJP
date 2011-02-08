#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use feature qw(say switch state);
use autodie;
use Text::Sass;
use IO::File;
use Filesys::Notify::Simple;
use IO::Socket::INET;

my $sass = Text::Sass->new();

my $sock = IO::Socket::INET->new(
    PeerHost => 'localhost',
    PeerPort => 4242,
) or die $!;
$sock->autoflush(1);

while (1) {
my $watcher = Filesys::Notify::Simple->new(['htdocs/static/css/']);
$watcher->wait(
    sub {
        # 見ているホスト名が localhost... ならリロード
        say "reloading";
        $sock->print("if (content.location.host.indexOf('localhost') == 0) content.location.reload(true)\n");
#       for my $event (@_) {
#           my $scss_path = $event->{path};
#           next unless $scss_path =~ /\.scss$/;
#           (my $css_path = $scss_path) =~ s/\.scss$/\.css/;
#           open my $fh, '<:utf8', $scss_path;
#           my $scss = do { local $/; <$fh> };
#           my $css = $converter->scss2css($scss);
#           my $ofh = IO::File->open($css_path, '<:utf8');
#           $ofh->print($css);
#           say "$scss_path => $css_path";
#       }
    }
);
}

