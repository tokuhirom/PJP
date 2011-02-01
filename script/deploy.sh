#!/bin/zsh
git push origin master
ssh 64p.org -p 2222 "cd /usr/local/webapp/PJP/; git pull origin master; sudo /usr/local/webapp/PJP/script/restart.sh"
