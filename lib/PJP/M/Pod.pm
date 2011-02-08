use strict;
use warnings;
use utf8;

package PJP::M::Pod;
use Pod::Simple::XHTML;
use Log::Minimal;
use Text::Xslate::Util qw/mark_raw html_escape/;
use Encode ();

sub parse_name_section {
    my ($class, $stuff) = @_;
    my $src = do {
        if (ref $stuff) {
            $$stuff;
        } else {
            open my $fh, '<', $stuff or die "Cannot open file $stuff: $!";
            my $src = do { local $/; <$fh> };
            if ($src =~ /^=encoding\s+(euc-jp|utf-?8)/sm) {
                $src = Encode::decode($1, $src);
            }
            $src;
        }
    };
    my ($package, $description) = ($src =~ m/
        ^=head1\s+(?:NAME|名前)\s*\n+
        \s*(\S+)(?:\s*-\s*([^\n]+))?
    /msx);
    $package =~ s/[A-Z]<(.+)>/$1/; # remove tags
    $description =~ s/[A-Z]<(.+)>/$1/; # remove tags
    return ($package, $description || '');
}

sub pod2html {
	my ($class, $stuff) = @_;
	$stuff or die "missing mandatory argument: $stuff";

    no warnings 'redefine';
    local *Pod::Simple::XHTML::encode_entities = \&Text::Xslate::Util::html_escape;
    my $parser = PJP::Pod::Parser->new();
    $parser->accept_targets_as_text('original');
    $parser->html_header('');
    $parser->html_footer('');
    $parser->index(1); # display table of contents
	$parser->perldoc_url_prefix('/pod/');
    $parser->output_string(\my $out);
    # $parser->html_h_level(3);
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
    use URI::Escape qw/uri_escape_utf8/;

    sub start_Verbatim {
        $_[0]{'scratch'} = '<pre class="prettyprint lang-perl"><code>';
    }

    sub start_for {
       my ($self, $flgs, @rest) = @_;
       if ($flgs->{'target'} eq 'original') {
           $self->{in_original} = 1;
       } else {
         $self->SUPER::start_for($flgs, @rest);
       }
    }

    sub end_for {
       my $self = shift;
       if ($self->{in_original}) {
           $self->{in_original} = 0;
       }
       $self->SUPER::end_for(@_);
    }

    sub handle_text {
        my ($self, $text) = @_;
        if (exists $self->{'in_original'} and $self->{'in_original'} == 1) {
            $self->{'scratch'} .= q{<div class="original">} . $text;
            $self->{'in_original'} = 2;
        } else {
            $self->{'scratch'} .= $text;
        }
    }

    # idify がマルチバイトクリーンじゃないから適当に対応してある。
    sub idify {
        my ($self, $t, $not_unique) = @_;
        for ($t) {
            s/<[^>]+>//g;            # Strip HTML.
            s/&[^;]+;//g;            # Strip entities.
            s/^\s+//; s/\s+$//;      # Strip white space.
            s/^([^a-zA-Z]+)$/pod$1/; # Prepend "pod" if no valid chars.
#           s/^[^a-zA-Z]+//;         # First char must be a letter.
            s/([^-a-zA-Z0-9_:.]+)/uri_escape_utf8($1)/eg; # All other chars must be valid.
        }
        return $t if $not_unique;
        my $i = '';
        $i++ while $self->{ids}{"$t$i"}++;
        return "$t$i";
    }
}

1;

