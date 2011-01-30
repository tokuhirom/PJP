#!/usr/bin/perl

use strict;
use Time::Piece;
use HTML::Template;
use List::MoreUtils qw/uniq/;

use constant HTDOCS_DIR => '/home/ktat/cvs/perldocjp/web/htdocs/';
use constant CPAN_HOME  => '/home/ktat/.cpan/';

main();

sub main{
  # my $check = new Perldocjp ('/home/ktat/cvs/perldocjp');
  my $check = Perldocjp->new;
  $check->cpan_home(CPAN_HOME);
#  $check->cpan_reload;
  $check->check();
  create_file($check);
}

sub create_file {
  my $check = shift;
  my $update = $check->all_module;

  my $menu = [ map{ { alpha => lc $_, alpha_uc => uc $_ } } sort {$a cmp $b} uniq map { lc substr $_, 0, 1 } keys %$update ];
  my (%module_per_initial, %tmp);
  foreach my $module (sort {($tmp{$a} ||= lc $a) cmp ($tmp{$b} ||= lc $b)} keys %$update) {
    my $initial = lc substr $module, 0, 1;
    my $module_name_cpan = $module;
    $module_name_cpan =~ s{::}{-}g;
    $module_per_initial{$initial} ||= [];
    push @{$module_per_initial{$initial}},
      {
       module         => $module,
       color          => (@{$module_per_initial{$initial}} % 2 ? '' : 'bgcolor="#eeeeee"'),
       cpan_link      => 'http://search.cpan.org/dist/' . $module_name_cpan,
       module2        => $update->{$module}->[0],
       status         => $update->{$module}->[1],
       perldocjp_link => 'http://perldoc.jp/docs/modules/' . $module_name_cpan . '-' . $update->{$module}->[0] . '/',
      };
  }

  my $text = template();
  my $rh = { alpha_menu  => $menu, update_time => Time::Piece->new->strftime("%Y/%m/%d %H:%M:%S") };
  foreach my $initial (keys %module_per_initial) {
    $rh->{module_list} = $module_per_initial{$initial};
    my $tmpl = HTML::Template->new(scalarref => \$text);
    $tmpl->param($rh);
    open my $fh,">", HTDOCS_DIR . 'module_list_' . $initial . '.htm' or die $!;
    print $fh $tmpl->output;
    close $fh;
  }
}

sub template {
  return <<'_TEMPLATE_';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<HTML>
<HEAD>
<link rel="stylesheet" href="style.css">
<TITLE>最新のバージョンとの対応 - Japanaized Perl Resources Project</TITLE>
</HEAD>
<BODY>
<div class="menu">
<ul>
<li><a href="/">Home</a></li>
<li><a HREF="joinus">参加するには?</a>(<a HREF="joinus#ml">メーリングリスト</a>)</li>

<li><a HREF="translation">翻訳の入手</a></li>
<li><a HREF="event">イベント</a></li>
<li><a HREF="perldocjp-faq">FAQ</a></li>
<li><a HREF="link">リンク</a></li>
<li class="sourceforge"><a HREF="http://sourceforge.jp/projects/perldocjp/">sourceforge site</a></li>
</ul>
</div>
<H1>最新のバージョンとの対応</H1>
<div><TMPL_VAR UPDATE_TIME>更新</div>
<p>
下記の内容は正確でない可能性があります。また、Perlのコアドキュメントとして登録されているモジュールは、チェックしていません。<br>
翻訳バージョンのリンクは、perldoc.jp のドキュメントへのリンクです。<br>
最新バージョンのリンクは、cpan.org のドキュメントへのリンクです。<br>
</p>
<DL><DT>
<TMPL_LOOP NAME="alpha_menu">
<A HREF="module_list_<TMPL_VAR ALPHA>"><TMPL_VAR ALPHA_UC></A>
</TMPL_LOOP>
</DT>
<DD><P>
<TABLE border=1 cellspacing=0>
<TR><TH>モジュール名</TH><TH>翻訳バージョン</TH><TH>最新バージョン</TH><TR>
<TMPL_LOOP name="module_list">
<TR>
<TD <TMPL_VAR color>><tmpl_var module></TD>
<TD <tmpl_var color> align=right><a href="<TMPL_VAR perldocjp_link>"><tmpl_var module2></a></TD>
<TD <tmpl_var color> align=right><a href="<TMPL_VAR cpan_link>"><tmpl_var status></a></TD><TR>
</TMPL_LOOP>
</TABLE>
</P>
</DD>
</DL>

<div class="footer">
<address>
<a href="http://sourceforge.jp/projects/perldocjp/">Japanize Perl Resources Project</a></address>

</div>
</BODY>
<HTML>
_TEMPLATE_
}

BEGIN {
package Perldocjp;

use strict;
use Carp;
use version;
use CPAN;
use CPAN::Config;
use Storable;
use LWP::Simple ();

$Perldocjp::VERSION = '0.6';

my $Cpan = new CPAN;

=pod

=head1 Name

 Perldocjp

=head1 Description

翻訳されたドキュメントが最新かどうかチェックするもの
違う名前のがよさそう。

=head1 Requirement

 version
 CPAN
 LWP::Simple

=head1 Example

 #!/usr/binn/perl -w

 use strict;
 use Perldocjp;

 # ディレクトリを指定しなければ、http://perldoc.jp/docs/modules をパースします。
 my $check = new Perldocjp ('/home/ktat/cvs/perldocjp');

 # .cpan が、/root 下にあって、読めない場合
 $check->cpan_home($ENV{HOME}.'my_cpan_dir');

 # Metadata を最新にしたければ
 $check->cpan_reload;

 # チェックするものをしぼる場合
 $check->check_list('Date::Simple','Data::FormValidator','Test::Simple','Audio::Beep','VCS::Lite');

 $update = $check->updated_module;

 foreach my $module(sort {$a cmp $b} keys %$update){
   printf "%-25s %10s   ->%10s\n", $module,@{$update->{$module}};
 }

=head1 Constructor

=over 4

=item new

 my $obj = new Perldocjp($perldocjp_dir);

$perldoc_dir は、perldocjp の cvs のディレクトリ。
たとえば、"/home/hoo/cvs/perldocjp" みたいな。

ディレクトリを指定しない場合、
http://perldoc.jp/docs/modules/ を解析します。

=back

=cut

sub new{
  my $class = shift;
  my $cvs_dir = shift;
  my $cvs_module_dir = $cvs_dir ? $cvs_dir . "/docs/modules" : undef;
  my $self =
    {
     cvs_dir => $cvs_dir,
     cvs_module_dir => $cvs_module_dir,
     cvs_module => ($cvs_module_dir ? _read_cvs_dir($cvs_module_dir) : _read_perldocjp()),
     cpan_module => $Cpan,
     check_list => {},
     update => {},
    };
  bless $self => $class;
}

=pod

=head1 Methods

=over 4

=item cvs_dir

 $dir = $obj->cvs_dir;

perldocjp の cvs のディレクトリを返します。

=cut

sub cvs_dir{
  return $_[0]->{cvs_dir};
}

sub _cpan_metadata{
  return retrieve($CPAN::Config->{cpan_home} . '/Metadata');
}

=pod

=item check_list

 $obj->check_list('Date::Simple','Audio::Beep');
 @list = $obj->check_list;

チェックするモジュールを配列で渡します。
返り値は、渡されたモジュールの名前。
なお、'-' が、名前に含まれる場合は、'::' に変換されます。

指定しない場合は、cvs にある全てのモジュールについて、チェックします。

=cut

sub check_list{
  my $self = shift;
  my @list = @_;
  foreach (@list){
    s/-/::/g;
  }
  @{$self->{check_list}}{@list} = ();
  return keys %{$self->{check_list}};
}

=pod

=item remove_check_list

 $obj->remove_check_list('Date::Simple','Audio::Beep');

check_list で指定したものを削除します。

=cut

sub remove_check_list{
  my $self = shift;
  delete @{$self->{check_list}}{@_};
  return keys %{$self->{check_list}};
}

=pod

=item cpan_reload

 CPAN モジュールが使っている Metadata を最新版にします。

=cut

sub cpan_reload{
  my $self = shift;
  CPAN::Index->reload;
  $self->cpan_module(_cpan_metadata());
}

sub _read_cvs_dir{
  my $self = shift if ref $_[0];
  my $dir = shift;
  opendir(IN,$dir) or die("Can't read $dir");
  my @modules = grep !/^\.\.?$/,readdir(IN);
  closedir IN;
  my $mod = {};
  foreach my $dir (@modules){
    my $regex = __parse_regex();
    if(my($module, $version) = ($dir =~/^$regex$/)){
      $module =~s/-/::/g;
      unless($mod->{$module}){
        $mod->{$module} = $version;
      }elsif(new version ($mod->{$module}) lt new version ($version)){
        $mod->{$module} = $version;
      }
    }
  }
  return $mod;
}

sub _read_perldocjp{
  my $urls = perldocjp_url();
  my %module;
  foreach my $url (ref $urls ? @{$urls} : $urls){
    my $contents = LWP::Simple::get($url);
    $contents =~s/^.*Parent Directory//s;
    $contents =~s/^<\/A>.*$//m;
    $contents =~s|</PRE>.*$||is;
    my $regex = __parse_regex();
    my %mod = ($contents =~m|/">$regex/</A>|img);
    @module{keys %mod} = @mod{keys %mod};
  }
  return {map { my $key = $_; s/-/::/g;
                my $module_name = $_;
                ($_ => $module{$key});
              } keys %module};
}

sub __parse_regex{
  return '([\w-]+)-(\d[\d.]+)';
}

=pod

=item perldocjp_url

 $obj->perldocjp_url

perldoc.jp の モジュール置いてるとこのURLを返す。

http://perldoc.jp/docs/modules/

=cut

sub perldocjp_url{
  return 'http://perldoc.jp/docs/modules/';
}

=pod

=item check

 $obj->check;

 チェックします。

=cut

sub check{
  my $self = shift;
  my $opt  = shift || '';
  my $cvs_module = $self->cvs_module;
  $self->cpan_module(_cpan_metadata()) unless %{$self->{cpan_module}};
  if($self->check_list){
    %$cvs_module = map{$_ => $self->cvs_version($_) }$self->check_list;
  }
  if($opt eq 'all'){
    %$cvs_module = map{$_ => $self->cvs_version($_) || 'unknown' } keys %{$self->cpan_module};
  }
  while(my($module, $cvs_version) = (each %$cvs_module)){
    my $cpan_version = $self->cpan_version($module);
    unless($cvs_version){
      $self->{update}->{$module} = ["none" => $cpan_version];
      $self->{all}->{$module} = ["none" => $cpan_version];
    }else{
      if(new version ($cvs_version) lt new version ($cpan_version)){
        $self->{update}->{$module} = [$cvs_version => $cpan_version];
        $self->{all}->{$module} = [$cvs_version => $cpan_version];
      }elsif(new version ($cvs_version) gt new version ($cpan_version)){
        $self->{all}->{$module} = [$cvs_version => $cpan_version];
      }else{
        $self->{all}->{$module} = [$cvs_version => 'latest'];
      }
    }
  }
  return $self->{update};
}

=pod

=item updated_module

 $hash_ref = $obj->updated_module;

ハッシュリファレンスを返します。
キーはモジュール名で、値は配列リファレンスです。
配列リファレンスの、最初の要素は翻訳されたモジュールのバージョンで、
2番目の要素は、Metadata の中のバージョンです。

check を行っていない場合、自動的に check が呼ばれます。

=cut

sub updated_module{
  my $self = shift;
  return $self->check unless %{$self->{update}};
  return $self->{update};
}

=pod

=item all_module

ハッシュリファレンスを返します。
update_module と大体同じですが、更新されていないものも返します。

check を行っていない場合、自動的に check が呼ばれます。

=cut

sub all_module{
  my $self = shift;
  return $self->check unless %{$self->{update}};
  return $self->{all};
}

sub cvs_module{
  my $self = shift;
  $self->{cvs_module} = shift  if @_;
  return $self->{cvs_module};
}

sub cvs_version{
  my $self = shift;
  my $module = shift or Carp::croak("module name is needed.");
  return $self->cvs_module->{$module};
}

sub cpan_module{
  my $self = shift;
  $self->{cpan_module} = shift  if @_;
  return $self->{cpan_module}->{'CPAN::Module'};
}

sub cpan_bundle{
  my $self = shift;
  return $self->{cpan_module}->{'CPAN::Bundle'};
}

sub list_cpan_module{
  my $self = shift;
  $self->capn_module(_cpan_metadata()) unless %{$self->cpan_module};
  return keys %{$self->{cpan_module}->{'CPAN::Module'}};
}


my %FIX_MAP = (
               'libapreq'        => 'Apache::libapreq',
               # 'Text::CVS_XS'    => 'Text::CSV_XS',
               'libwww::perl'    => 'LWP',
               'Net::TrackBack'  => 'Net::Trackback::Client',
               'MIDI::Perl'      => 'MIDI',
               'HTTPD::WatchLog' => undef,
              );

sub cpan_version{
  my $self = shift;
  my $module = shift or Carp::croak("module name is needed.");
  $module = $FIX_MAP{$module} if $FIX_MAP{$module};
  unless ($self->cpan_module->{$module}) {
    # maybe Bundle;
    my $bundle = $self->cpan_bundle;
    unless($bundle->{"Bundle::$module"}){
      warn("I don't know about $module");
    }else{
      return __retrieve_version($bundle->{"Bundle::$module"})
    }
  }else{
    return __retrieve_version($self->cpan_module->{$module})
  }
  return '';
}

sub __retrieve_version {
  my $mod_data = shift;
  if ($mod_data->{CPAN_VERSION}) {
    return $mod_data->{CPAN_VERSION};
  } else {
    if ($mod_data->{CPAN_FILE} =~ m{-([\d\.]+)\.tar\.(gz|bz2)}) {
      return $1;
    }
  }
}

=pod

=item $obj->cpan_dir($dir);

$CPAN::Config->{cpan_home}の値を変更します。
第一引数は、ディレクトリ。省略すると、$ENV{HOME}.'/.cpan' になる。
明示的に呼ばなければ、$CPAN::Config->{cpan_home}は、変更されません。

$CPAN::Config->{cpan_home}が、root のホームディレクトリだと
一般ユーザが使えないので、自分用のディレクトリを指定するためにあります。

=cut

sub cpan_home{
  my $self = shift;
  my $cpan_dir = shift || $ENV{HOME}.'/.cpan';
  $CPAN::Config->{cpan_home} = $cpan_dir;
  $CPAN::Config->{build_dir} = $cpan_dir.'/build';
  $CPAN::Config->{keep_source_where} = $cpan_dir.'/source';
}

=pod

=back

=head1 Author

 Kato Atushi <atusi@pure.ne.jp>.

=head1 Copyright

 Copyright 2003 by Kato Atushi <atusi@pure.ne.jp>.
 This program is free software; you can redistribute it
 and/or modify it under the same terms as Perl itself.

 See http://www.perl.com/perl/misc/Artistic.html

=cut

}
