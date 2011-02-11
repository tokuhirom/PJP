use strict;
use warnings;
use utf8;

package PJP::Cache;
use Cache::FileCache;
use File::stat;

sub new {
	my $class = shift;
	bless {
		cache => Cache::FileCache->new(),
	}, $class;
}

sub file_cache {
	my ($self, $prefix, $file, $cb) = @_;
	my $cache = $self->{cache};
	my $key = "2:${prefix}::${file}";
    $key .= rand() if $ENV{DEBUG};
	my $data = $cache->get($key);
	my $stat = stat($file) or die "Cannot stat $file: $!";
	if ($data && $data->[0] eq $stat->mtime) {
		return $data->[1];
	} else {
		my $out = $cb->();
		$cache->set($key => [$stat->mtime, $out]);
		return $out;
	}
}

sub get_or_set {
	my ($self, $key, $cb, $xt) = @_;

	my $val = $self->{cache}->get($key);
	return $val if defined $val;

	$val = $cb->();
	$self->{cache}->set($key, $val, $xt || '1 day');
}

1;

