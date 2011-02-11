#!/bin/zsh
cd /usr/local/webapp/PJP/assets/perldoc.jp
cvs upd -dP

cd /usr/local/webapp/PJP/assets/module-pod-jp
git pull origin master

rm /usr/local/webapp/PJP/assets/index-module.pl

cd /usr/local/webapp/PJP
perl -Ilib -e 'use PJP::M::Index::Module; use PJP; my $c = PJP->bootstrap; PJP::M::Index::Module->generate_and_save($c)'

