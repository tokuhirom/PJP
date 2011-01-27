use inc::Module::Install;
all_from "lib/PJP.pm";

tests 't/*.t t/*/*.t t/*/*/*.t';
requires 'Amon2';
requires 'Text::Xslate';
requires 'Text::Xslate::Bridge::TT2Like';
requires 'Plack::Middleware::ReverseProxy';
requires 'Time::Piece';
requires 'Pod::Simple::XHTML';
requires 'Log::Minimal';
requires 'Cache::FileCache';

recursive_author_tests('xt');

WriteAll;
