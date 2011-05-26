#!/bin/bash
BASE=$HOME/code

. $HOME/.bashrc

cd $BASE/assets/perldoc.jp

cvs upd -dP

cd $BASE/PJP/assets/module-pod-jp
git pull origin master

rm $BASE/assets/index-module.pl

cd $BASE
which perl

perl -Ilib -e 'use PJP::M::Index::Module; use PJP; my $c = PJP->bootstrap; PJP::M::Index::Module->generate_and_save($c)'

# 組み込み関数
perl -Ilib -e 'use PJP; use PJP::M::BuiltinFunction; my $c = PJP->bootstrap; PJP::M::BuiltinFunction->generate($c)'

# pod
time perl -Ilib -e 'use PJP; use PJP::M::PodFile; my $c = PJP->bootstrap; PJP::M::PodFile->generate($c)'

echo $PLACK_MODE
