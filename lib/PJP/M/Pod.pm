use strict;
use warnings;
use utf8;

package PJP::M::Pod;
use Pod::Simple::XHTML;
use Log::Minimal;
use Text::Xslate::Util qw/mark_raw html_escape/;
use Encode ();
use HTML::Entities ();
use Amon2::Declare;

sub parse_name_section {
    my ($class, $stuff) = @_;
    my $src = do {
        if (ref $stuff) {
            $$stuff;
        } else {
            open my $fh, '<:raw', $stuff or die "Cannot open file $stuff: $!";
            my $src = do { local $/; <$fh> };
            if ($src =~ /^=encoding\s+(euc-jp|utf-?8)/sm) {
                $src = Encode::decode($1, $src);
            }
            $src;
        }
    };
    $src =~ s/=begin\s+original.+?=end\s+original\n//gsm;
    $src =~ s/X<[^>]+>//g;
    $src =~ s/=encoding\s+\S+\n//gsm;
    $src =~ s/\r\n/\n/g;

    my ($package, $description) = ($src =~ m/
        ^=head1\s+(?:NAME|名前|名前\ \(NAME\))[ \t]*\n(?:名前\n)?\s*\n+\s*
        \s*(\S+)(?:\s*-+\s*([^\n]+))?
    /msx);

    $package     =~ s/[A-Z]<(.+?)>/$1/g if $package;        # remove tags
    $description =~ s/[A-Z]<(.+?)>/$1/g if $description;    # remove tags
    return ($package, $description || '');
}

sub pod2html {
	my ($class, $stuff) = @_;
	$stuff or die "missing mandatory argument: $stuff";

    my $parser = PJP::Pod::Parser->new();
    $parser->html_encode_chars(q{&<>"'});
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
    } glob("@{[ c()->assets_dir() ]}/perldoc.jp/docs/perl/*/$name.pod");
	return @path;
}

sub get_latest_file_path {
	my ($class, $name) = @_;
	my ($latest) = $class->get_file_list($name);
	return $latest;
}

{
    package PJP::Pod::Parser;
    use Pod::Simple::XHTML;
    use parent qw/Pod::Simple::XHTML/;
    use URI::Escape qw/uri_escape_utf8/;

    sub new {
        my $self = shift->SUPER::new(@_);
        $self->{translated_toc} = +{
            NAME        => '名前',
            DESCRIPTION => '概要',
        };
        return $self;
    }

    # for google source code prettifier
    sub start_Verbatim {
        $_[0]{'scratch'} = '<pre class="prettyprint lang-perl"><code>';
    }
    sub end_Verbatim {
        $_[0]{'scratch'} .= '</code></pre>';
        $_[0]->emit;
    }

    sub _end_head {
        $_[0]->{last_head_body} = $_[0]->{scratch};
        $_[0]->{end_head}  = 1;

        my $h = delete $_[0]{in_head};

        my $add = $_[0]->html_h_level;
           $add = 1 unless defined $add;
        $h += $add - 1;

        my $id = $_[0]->idify($_[0]{scratch});
        my $text = $_[0]{scratch};
        # あとで翻訳したリソースと置換できるように、印をつけておく
        $_[0]{'scratch'} = sprintf(qq{<h$h id="$id">TRANHEADSTART%sTRANHEADEND<a href="#$id" class="toc_link">&#182;</a></h$h>}, $text);
        $_[0]->emit;
        push @{ $_[0]{'to_index'} }, [$h, $id, $text];
    }
    sub end_head1       { shift->_end_head(@_); }
    sub end_head2       { shift->_end_head(@_); }
    sub end_head3       { shift->_end_head(@_); }
    sub end_head4       { shift->_end_head(@_); }

    sub handle_text {
        my ($self, $text) = @_;
        if ($_[0]->{end_head}-- > 0 && $text =~ /^\((.+)\)$/) {
            # 最初の行の括弧でかこまれたものがあったら、それは翻訳された見出しとみなす
            # 仕様については Pod::L10N を見よ
            $_[0]->{translated_toc}->{$_[0]->{last_head_body}} = $1;
        } else {
            $self->SUPER::handle_text($text);
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
            s/([^-a-zA-Z0-9_:.]+)/unpack("U*", $1)/eg; # All other chars must be valid.
        }
        return $t if $not_unique;
        my $i = '';
        $i++ while $self->{ids}{"$t$i"}++;
        return "$t$i";
    }

    sub end_Document {
        my ($self) = @_;
        my $to_index = $self->{'to_index'};

        if ( $self->index && @{$to_index} ) {
            my @out;
            my $level  = 0;
            my $indent = -1;
            my $space  = '';
            my $id     = ' class="pod_toc"';

            for my $h ( @{$to_index}, [0] ) {
                my $target_level = $h->[0];

                # Get to target_level by opening or closing ULs
                if ( $level == $target_level ) {
                    $out[-1] .= '</li>';
                }
                elsif ( $level > $target_level ) {
                    $out[-1] .= '</li>' if $out[-1] =~ /^\s+<li>/;
                    while ( $level > $target_level ) {
                        --$level;
                        push @out, ( '  ' x --$indent ) . '</li>'
                          if @out && $out[-1] =~ m{^\s+<\/ul};
                        push @out, ( '  ' x --$indent ) . "</ul>";
                    }
                    push @out, ( '  ' x --$indent ) . '</li>' if $level;
                }
                else {
                    while ( $level < $target_level ) {
                        ++$level;
                        push @out, ( '  ' x ++$indent ) . '<li>'
                          if @out && $out[-1] =~ /^\s*<ul/;
                        push @out, ( '  ' x ++$indent ) . "<ul$id>";
                        $id = '';
                    }
                    ++$indent;
                }

                next unless $level;

                $space = '  ' x $indent;
                # 見出しが翻訳されていれば、翻訳されたものをつかう
                my $text = $h->[2];
                if ($self->{translated_toc}->{$text}) {
                    $text = $self->{translated_toc}->{$text};
                }
                push @out, sprintf '%s<li><a href="#%s">%s</a>',
                  $space, $h->[1], $text;
            }

            print { $self->{'output_fh'} } join "\n", @out;
        }

        my $output = join( "\n\n", @{ $self->{'output'} } );
        $output =~ s[TRANHEADSTART(.+?)TRANHEADEND][
            if (my $translated = $self->{translated_toc}->{$1}) {
                $translated;
            } else {
                $1;
            }
        ]ge;
        print { $self->{'output_fh'} }
            qq{\n\n<div class="pod_content_body">$output\n\n</div>};
        @{ $self->{'output'} } = ();
    }
}

1;

