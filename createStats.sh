#!/bin/bash

# Create .stats files which are ranked lists of bugs and stats
# according to which occur the most and have most bugs respectively.

./tools/bugSummary.sh | sort -t, -k2 -n -r > ./results/bug.stats
./tools/siteSummary.sh | sort -t, -k2 -n -r > ./results/site.stats
