use inc::Module::Install;
all_from "lib/PJP.pm";
license 'perl';

tests 't/*.t t/*/*.t t/*/*/*.t';
requires 'Amon2';
requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';
requires 'Plack::Middleware::ReverseProxy';
requires 'Time::Piece';
requires 'Pod::Simple' => 3.16;
requires 'Pod::Simple::XHTML';
requires 'Log::Minimal';
requires 'Cache::FileCache';
requires 'CPAN::DistnameInfo';
requires 'LWP::UserAgent';
requires 'URI::Escape';
requires 'Try::Tiny';
requires 'DBD::SQLite';
requires 'SQL::Maker' => 0.14;
requires 'DBIx::TransactionManager';
requires 'SQL::Interp';
requires 'Carp::Clan';
requires 'File::Find::Rule';
requires 'Tiffany';

test_requires 'Test::Requires';

# recursive_author_tests('xt');

WriteAll;
