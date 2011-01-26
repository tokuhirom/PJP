use strict;
use warnings;
use utf8;

package PJP::M::Pod;
use Pod::Simple::XHTML;
use Log::Minimal;
use Text::Xslate::Util qw/mark_raw/;

sub pod2html {
	my ($class, $path) = @_;
	$path or die "missing mandatory argument: $path";

    infof("parsing %s", $path);

    my $parser = PJP::Pod::Parser->new();
    $parser->html_header('');
    $parser->html_footer('');
    # $parser->index(1); # display table of contents
	$parser->perldoc_url_prefix('/pod/');
    $parser->output_string(\my $out);
    $parser->parse_file($path);
	return mark_raw($out);
}

{
    package PJP::Pod::Parser;
    use parent qw/Pod::Simple::XHTML/;    # for google source code prettifier

    sub start_Verbatim {
        $_[0]{'scratch'} = '<pre class="prettyprint lang-perl"><code>';
    }
}

1;

