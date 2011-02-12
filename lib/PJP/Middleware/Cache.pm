use strict;
use warnings;
use utf8;

# コンテンツキャッシュ

package PJP::Middleware::Cache;
use parent qw(Plack::Middleware);
our $VERSION = '1';
use Plack::Util::Accessor qw/
    cache
/;

sub call {
    my ($self, $env) = @_;

    my $meth = $env->{REQUEST_METHOD};
    my $use_cache = do {
        if ($meth ne 'GET' && $meth ne 'HEAD') {
            0;
        }
        if ($env->{HTTP_AUTHORIZATION} || $env->{HTTP_COOKIE}) {
            0;
        }
        1;
    };
    if ($use_cache) {
        my $key = "$env->{HTTP_HOST}:$env->{PATH_INFO}:$env->{QUERY_STRING}";
        if (my $data = $self->cache->get($key)) {
            return $data;
        } else {
            my $res = $self->app->($env);
            unless ($res->[0] eq 200 || $res->[0] eq 301) {
                return $res;
            }
            if (Plack::Util::header_exists($res->[1], 'Set-Cookie')) {
                return $res;
            }
            $self->cache->set($key => $res, '3 days');
            return $res;
        }
    } else {
        return $self->app->($env);
    }
}

1;
