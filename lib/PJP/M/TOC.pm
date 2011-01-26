use strict;
use warnings;
use utf8;

package PJP::M::TOC;
use Text::Xslate::Util qw/html_escape mark_raw/;

sub render {
	my $class = shift;
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
	return mark_raw($out);
}

1;

