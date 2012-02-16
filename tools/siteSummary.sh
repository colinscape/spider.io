#!/bin/bash

# Output information in the form
#   <SITE>,<COUNT>

INFOS=`awk -F, '{arr[$1]+=1} END { for (i in arr) {print i","arr[i]} }' ./results/matches.index`
for INFO in $INFOS
do
	ID=`echo $INFO | cut -f1 -d,`
        COUNT=`echo $INFO | cut -f2 -d,`
	SITE=`grep -m1 "^$ID," ./data/top-1m.csv | cut -f2 -d,`
	echo "$SITE,$COUNT"
done
