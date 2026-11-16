#!/bin/bash
# prove in parallelo: tests/par.sh N scenari...
N=$1; shift
for sc in "$@"; do timeout 600 godot --headless --path . -s tests/motivi.gd -- $N $sc 2>&1 | grep -v Godot > /tmp/par_$sc.txt & done; wait
cat $(for sc in "$@"; do echo /tmp/par_$sc.txt; done) | awk '{w[$1]+=($5=="vinto");n[$1]++} END{for(k in n){print k, w[k]"/"n[k]; W+=w[k];N+=n[k]} print "TOT",W"/"N}'
cat $(for sc in "$@"; do echo /tmp/par_$sc.txt; done) | grep perso | cut -d" " -f6- | cut -c1-60 | sort | uniq -c | sort -rn | head -12
