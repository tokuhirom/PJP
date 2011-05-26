use strict;
use warnings;
use utf8;
use 5.10.0;

package PJP::DBI;
use parent qw/DBI/;

sub connect {
	my ($self, $dsn, $user, $pass, $attr) = @_;
    $attr->{RaiseError}          //= 1;
    $attr->{AutoInactiveDestroy} //= 1;
	if ($dsn =~ /^dbi:SQLite:/) {
		$attr->{sqlite_unicode} //= 1;
	}
	return $self->SUPER::connect($dsn, $user, $pass, $attr);
}

package PJP::DBI::db;
use base qw/DBI::db/;
use SQL::Maker;
use DBIx::TransactionManager;
use SQL::Interp ();
use Try::Tiny;
use Data::Dumper ();

sub sql_maker { $_[0]->{private_sql_maker} // SQL::Maker->new(driver => $_[0]->{Driver}->{Name}, new_line => q{ }) }

sub _txn_manager {
    my $self = shift;
    $self->{private_txn_manager} //= DBIx::TransactionManager->new($self);
}

sub txn_scope { $_[0]->_txn_manager->txn_scope(caller => [caller(0)]) }

sub do_i {
    my $self = shift;
    my ($sql, @bind) = SQL::Interp::sql_interp(@_);
    $self->do($sql, {}, @bind);
}

sub insert {
    my ($self, @args) = @_;
    my ($sql, @bind) = $self->sql_maker->insert(@args);
    $self->do($sql, {}, @bind);
}

sub replace {
    my ($self, $table, $vars, $attr) = @_;
	$attr //= {};
	$attr->{prefix} = 'REPLACE INTO ';
    my ($sql, @bind) = $self->sql_maker->insert($table, $vars, $attr);
    $self->do($sql, {}, @bind);
}

sub single {
    my ($self, $table, $where, $opt) = @_;
    my $sth = $self->search($table, $where, $opt);
    return $sth->fetchrow_hashref();
}

sub search {
    my ($self, $table, $where, $opt) = @_;
    my ($sql, @bind) = $self->sql_maker->select($table, ['*'], $where, $opt);

    # inject file/line to help tuning
    my ($package, $file, $line);
    my $i = 0;
    while (($package, $file, $line) = caller($i++)) {
        unless ($package eq __PACKAGE__) {
            last;
        }
    }
    $sql =~ s! !/* at $file line $line */ !;

    my $sth = $self->prepare($sql);
    $sth->execute(@bind);
    return $sth;
}

sub prepare {
    my ($self, @args) = @_;
    my $sth = $self->SUPER::prepare(@args) or do {
        PJP::DBI::Util::handle_error($_[1], [], $self->errstr);
    };
    $sth->{private_sql} = $_[1];
    return $sth;
}

package PJP::DBI::dr;
use base qw/DBI::dr/;

package PJP::DBI::st;
use base qw/DBI::st/;


sub execute {
    my ($self, @args) = @_;
    $self->SUPER::execute(@args) or do {
        PJP::DBI::Util::handle_error($self->{private_sql}, \@args, $self->errstr);
    };
}

sub sql { $_[0]->{private_sql} }

package PJP::DBI::Util;
use Carp::Clan qw{^(DBI::|PJP::DBI::|DBD::)};
use Data::Dumper ();

sub handle_error {
    my ( $stmt, $bind, $reason ) = @_;

    $stmt =~ s/\n/\n          /gm;
    my $err = sprintf <<"TRACE", $reason, $stmt, Data::Dumper::Dumper($bind);

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@ FrePAN::DBI 's Exception @@@@@
Reason  : %s
SQL     : %s
BIND    : %s
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
TRACE
    $err =~ s/\n\Z//;
    croak $err;
}

1;

