#!/bin/bash
BASE=$HOME/assets

. $HOME/.bashrc

cd $BASE/perldoc.jp

cvs upd -dP

if [ ! -d $HOME/assets/module-pod-jp/ ] ; then
    git clone git://github.com/perldoc-jp/module-pod-jp.git $HOME/assets/module-pod-jp/
fi
cd $HOME/assets/module-pod-jp
git pull origin master

rm $BASE/index-module.pl

cd $HOME/code/

perl -Ilib -e 'use PJP::M::Index::Module; use PJP; my $c = PJP->bootstrap; PJP::M::Index::Module->generate_and_save($c)'

# 組み込み関数
perl -Ilib -e 'use PJP; use PJP::M::BuiltinFunction; my $c = PJP->bootstrap; PJP::M::BuiltinFunction->generate($c)'

# pod
time perl -Ilib -e 'use PJP; use PJP::M::PodFile; my $c = PJP->bootstrap; PJP::M::PodFile->generate($c)'

echo $PLACK_MODE
