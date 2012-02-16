#!/bin/bash

# Output information in the form
#   <NAME> [<ID>],<COUNT>

INFOS=`cat ./data/bugs.json | sed -e's/.*\"name\":\"//g' | sed -e's/\",.*\"id\":\"/,/g' | sed -e's/\".*//g' | tr ' ' '_'`
echo $INFO
for INFO in $INFOS
do
	ID=`echo $INFO | cut -f2 -d,`
	NAME=`echo $INFO | cut -f1 -d, | tr '_' ' '`
	COUNT=`grep ",${ID}$" ./results/matches.index | wc -l`
	echo "${NAME} [$ID],$COUNT"
done
