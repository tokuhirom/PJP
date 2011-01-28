use strict;
use warnings;
use utf8;

package PJP::M::Pod;
use Pod::Simple::XHTML;
use Log::Minimal;
use Text::Xslate::Util qw/mark_raw html_escape/;

sub pod2html {
	my ($class, $stuff) = @_;
	$stuff or die "missing mandatory argument: $stuff";

    no warnings 'redefine';
    local *Pod::Simple::XHTML::encode_entities = \&Text::Xslate::Util::html_escape;
    my $parser = PJP::Pod::Parser->new();
    $parser->html_header('');
    $parser->html_footer('');
    $parser->index(1); # display table of contents
	$parser->perldoc_url_prefix('/pod/');
    $parser->output_string(\my $out);
    $parser->html_h_level(3);
	if (ref $stuff eq 'SCALAR') {
		$parser->parse_string_document($$stuff);
	} else {
		$parser->parse_file($stuff);
	}
	return mark_raw($out);
}

sub get_file_list {
	my ($class, $name) = @_;

    my @path = reverse sort { eval { version->parse($a->[1]) } <=> eval { version->parse($b->[1]) } } map {
        +[ $_, map { local $_=$_; s!.*/perl/!!; s!/$name.pod!!; $_ } $_ ]
    } glob("assets/perldoc.jp/docs/perl/*/$name.pod");
	return @path;
}

sub get_latest_file_path {
	my ($class, $name) = @_;
	my ($latest) = $class->get_file_list($name);
	return $latest;
}

{
    package PJP::Pod::Parser;
    use parent qw/Pod::Simple::XHTML/;    # for google source code prettifier

    sub start_Verbatim {
        $_[0]{'scratch'} = '<pre class="prettyprint lang-perl"><code>';
    }
}

1;

