#!/bin/sh

for f in `find . -type f -name "*.pm"`
do perldoc -u $f > $f.pod
mv $f.pod ${f%.pm}.pod
rm $f
done
