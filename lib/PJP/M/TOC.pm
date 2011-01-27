use strict;
use warnings;
use utf8;

package PJP::M::TOC;
use Text::Xslate::Util qw/html_escape mark_raw/;
use File::stat;
use Log::Minimal;

sub render {
	my ($class, $c) = @_;

	return mark_raw($c->cache->file_cache(
		"toc", 'toc.txt', sub {
			infof("regen toc");
			$class->_render();
		}
	));
}

sub _render {
	my ($class) = @_;

	open my $fh, '<:utf8', 'toc.txt' or die "Cannot open toc.txt: $!";
	my $out;
	while (<$fh>) {
		chomp;
		if (!/\S/) {
			next;
		} elsif (/^\s*\#/) {
			next; # comment line
		} elsif (/^\S/) { # header line
			$out .= sprintf("<h2>%s</h2>\n", html_escape($_));
		} else { # main line
			s/^\s+//;
			my ($pkg, $desc) = split /\s*-\s*/, $_;
			$out .= sprintf('<a href="/pod/%s">%s</a>', (html_escape($pkg))x2);
			if ($desc) {
				$out .= sprintf(' - %s', html_escape($desc));
			}
			$out .= "<br />\n";
		}
	}
	$out;
}

1;

