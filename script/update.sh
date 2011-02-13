#!/bin/zsh
cd /usr/local/webapp/PJP/assets/perldoc.jp
cvs upd -dP

cd /usr/local/webapp/PJP/assets/module-pod-jp
git pull origin master

rm /usr/local/webapp/PJP/assets/index-module.pl

cd /usr/local/webapp/PJP
perl -Ilib -e 'use PJP::M::Index::Module; use PJP; my $c = PJP->bootstrap; PJP::M::Index::Module->generate_and_save($c)'

# 組み込み関数
perl -Ilib -e 'use PJP; use PJP::M::BuiltinFunction; my $c = PJP->bootstrap; PJP::M::BuiltinFunction->generate($c)'

# pod
time perl -Ilib -e 'use PJP; use PJP::M::PodFile; my $c = PJP->bootstrap; PJP::M::PodFile->generate($c)'

