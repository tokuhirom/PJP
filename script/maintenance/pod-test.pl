#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use feature qw(say switch state);
use Test::More;
use Test::Pod 1.00;

my @poddirs = qw( assets/perldoc.jp/docs/ );
all_pod_files_ok( all_pod_files( @poddirs ) );
