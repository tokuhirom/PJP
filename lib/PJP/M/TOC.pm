use strict;
use warnings;
use utf8;

package PJP::M::TOC;
use Text::Xslate::Util qw/html_escape mark_raw/;
use File::stat;
use Log::Minimal;

sub render {
	my ($class, $c) = @_;
    $c // die;

	return mark_raw($c->cache->file_cache(
		"toc:4", 'toc.txt', sub {
			infof("regen toc");
			my $ret = $class->_render();
            warn $ret;
            return $ret;
		}
	));
}

sub _render {
	my ($class) = @_;

	open my $fh, '<:utf8', 'toc.txt' or die "Cannot open toc.txt: $!";
	my $out;
    my $started = 0;
	while (<$fh>) {
		chomp;
		if (!/\S/) {
			next;
		} elsif (/^\s*\#/) {
			next; # comment line
		} elsif (/^\S/) { # header line
            $out .= "</ul>" if $started++;
			$out .= sprintf("<h3>%s</h3><ul>\n", html_escape($_));
		} else { # main line
			s/^\s+//;
			my ($pkg, $desc) = split /\s*-\s*/, $_;
			$out .= sprintf('<li><a href="/pod/%s">%s</a>', (html_escape($pkg))x2);
			if ($desc) {
				$out .= sprintf(' - %s', html_escape($desc));
			}
			$out .= "</li>\n";
		}
	}
    $out .= "</ul>" if $started;
	$out;
}

# XXX 直接 perlfunc.pod からよみこむようにした方がベターではある。
sub render_function {
	my ($class, $c) = @_;
	return $class->_render_function();
}

sub _render_function {
	my ($class) = @_;

	open my $fh, '<:utf8', 'toc-func.txt' or die "Cannot open toc-func.txt: $!";
	my $out;
	while (<$fh>) {
		chomp;
		if (!/\S/) {
			next;
		} elsif (/^\s*\#/) {
			next; # comment line
		} elsif (/^\((.+)\)/) { # name
			$out .= sprintf("<h2>%s</h2>\n", html_escape($1));
		} elsif (/^C</) { # link
			my @outs;
			my $line = $_;
			while ($line =~ s/C<([^>]+)>//) {
				push @outs, sprintf('<a href="/func/%s">%s</a>', (html_escape($1))x2);
			}
			$out .= join(", ", @outs) . "<br />\n";
		}
	}
	mark_raw($out);
}

1;

