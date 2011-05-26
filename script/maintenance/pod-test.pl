#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use feature qw(say switch state);
use Test::More;
use Test::Pod 1.00;
use PJP;

my $c = PJP->bootstrap;
my @poddirs = File::Spec->catfile($c->assets_dir(), qw( perldoc.jp/docs/ ));
all_pod_files_ok( all_pod_files( @poddirs ) );
