use inc::Module::Install;
all_from "lib/PJP.pm";
license 'perl';

tests 't/*.t t/*/*.t t/*/*/*.t';
requires 'Amon2';
requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';
requires 'Plack::Middleware::ReverseProxy';
requires 'Time::Piece';
requires 'Pod::Simple::XHTML';
requires 'Log::Minimal';
requires 'Cache::FileCache';
requires 'CPAN::DistnameInfo';
requires 'LWP::UserAgent';
requires 'URI::Escape';
requires 'Try::Tiny';
requires 'DBD::SQLite';
requires 'SQL::Maker';
requires 'DBIx::TransactionManager';
requires(
	'SQL::Interp' => 0,
	'Carp::Clan' => 0,
	'JSON' => 0,
	'File::Find::Rule' => 0,
);

can_run('cronlog') or do {
	use File::Temp;
	my $tmp = File::Temp->new(UNLINK => 1);
	system "curl -L --output $tmp http://github.com/kazuho/kaztools/tarball/master";
	system "cpanm -nv $tmp";
};

test_requires 'Test::Requires';

recursive_author_tests('xt');

WriteAll;
