use strict;
use warnings;
use utf8;

package PJP::M::BuiltinFunction;
use PJP::M::Pod;
use Pod::Perldoc;
use Amon2::Declare;

# 5.12.3 時点でのもの
our @FUNCTIONS = qw(
  -r -w -x -o -R -W -X -O -e -z -s -f -d -l -p
  -S -b -c -t -u -g -k -T -B -M -A -C
  abs accept alarm atan2 bind binmode bless break caller chdir chmod chomp chop chown chr chroot close closedir connect
  continue cos crypt dbmclose dbmopen defined delete die do dump each endgrent endhostent endnetent endprotoent endpwent
  endservent eof eval getprotoent getpwent getpwnam getpwuid getservbyname getservbyport getservent
  getsockname getsockopt glob gmtime goto grep hex import index int ioctl join keys kill last lc lcfirst length link
  listen local localtime lock log lstat m map mkdir msgctl msgget msgrcv msgsnd my next no oct open opendir ord order
  our pack package pipe pop pos precision print printf prototype push q qq qr quotemeta qw qx rand read readdir readline
  readlink readpipe recv redo ref rename require reset return reverse rewinddir rindex rmdir s say scalar seek seekdir select
  semctl semget semop send setgrent sethostent setnetent setpgrp setpriority setprotoent setpwent setservent setsockopt shift
  shmctl shmget shmread shmwrite shutdown sin size sleep socket socketpair sort splice split sprintf sqrt srand stat state
  study sub substr symlink syscall sysopen sysread sysseek system syswrite tell telldir tie tied time times tr truncate uc
  ucfirst umask undef unlink unpack unshift untie use utime values vec vector wait waitpid wantarray warn write y
);

sub retrieve {
	my ($class, $name) = @_;
	return c->dbh->selectrow_array(q{SELECT version, html FROM func WHERE name=?}, {}, $name);
}

sub generate {
	my ($class, $c) = @_;

    my $path_info = PJP::M::Pod->get_latest_file_path('perlfunc');
    my ($path, $version) = @$path_info;

	my $txn = $c->dbh->txn_scope();
	$c->dbh->do(q{DELETE FROM func});
	for my $name (@FUNCTIONS) {
		my @dynamic_pod;
		my $perldoc = Pod::Perldoc->new(opt_f => $name);
		$perldoc->search_perlfunc([$path], \@dynamic_pod);
		my $pod = join("", "=encoding euc-jp\n\n=over 4\n\n", @dynamic_pod, "=back\n");
		$pod =~ s!L</([a-z]+)>!L<$1|http://perldoc.jp/func/$1>!g;
		my $html = PJP::M::Pod->pod2html(\$pod);
		$c->dbh->insert(
			func => {
				name => $name,
				version => $version,
				html => $html,
			},
		);
	}
	$txn->commit();
}

1;

