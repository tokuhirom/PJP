use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use PJP::Web;
use Plack::Builder;

builder {
    if ($ENV{PLACK_MODE} ne 'production') {
        enable 'Plack::Middleware::Static',
            path => qr{^(/static/|favicon\.ico|robots\.txt)},
            root => './htdocs/';
    }
    enable 'Plack::Middleware::ReverseProxy';
    PJP::Web->to_app();
};
