use strict;
use warnings;
use utf8;
use Test::More;
use PJP::M::Pod;
use utf8;

my $pod = <<'...';
foo
bar
__END__

=head1 NAME

B<OK> - あれです

=head1 SYNOPSIS

    This is a sample pod

=head1 注意

=head1 理解されるフォーマット

L<"SYNOPSIS">

L<"注意">

...
my $out = PJP::M::Pod->pod2package_name(\($pod));
is $out, "OK";

my $html = PJP::M::Pod->pod2html(\$pod);
like $html, qr{<h1 id="pod%E6%B3%A8%E6%84%8F">注意</h1>};
like $html, qr{<p><a href="#pod%E6%B3%A8%E6%84%8F">&quot;注意&quot;</a></p>};

subtest 'parse_name_section' => sub {
    my ($pkg, $desc) = PJP::M::Pod->parse_name_section(\$pod);
    is $pkg, 'OK';
    is $desc, 'あれです';
};

done_testing;

