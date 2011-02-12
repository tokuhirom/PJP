package PJP::Web;
use strict;
use warnings;
use parent qw/PJP Amon2::Web/;

# load all controller classes
use Module::Find ();
Module::Find::useall("PJP::Web::C");

# custom classes
use PJP::Web::Request;
use PJP::Web::Response;
sub create_request  { PJP::Web::Request->new($_[1]) }
sub create_response { shift; PJP::Web::Response->new(@_) }

# dispatcher
use PJP::Web::Dispatcher;
sub dispatch {
    return PJP::Web::Dispatcher->dispatch($_[0]) or die "response is not generated";
}

# setup view class
use Tiffany::Text::Xslate;
{
    my $view_conf = __PACKAGE__->config->{'Text::Xslate'} || die "missing configuration for Text::Xslate";
    my $view = Tiffany::Text::Xslate->new(+{
        'syntax'   => 'TTerse',
        'module'   => [ 'Text::Xslate::Bridge::TT2Like' ],
        'function' => {
            c => sub { Amon2->context() },
            uri_with => sub { Amon2->context()->req->uri_with(@_) },
            uri_for  => sub { Amon2->context()->uri_for(@_) },
        },
        %$view_conf
    });
    sub create_view { $view }
}

sub show_error {
    my ($c, $msg) = @_;
    $c->render('error.tt', {message => $msg});
}

1;
