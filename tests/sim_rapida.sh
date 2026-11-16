#!/bin/bash
# prove veloci su un gruppo di scenari: tests/sim_rapida.sh N scen1 scen2 ...
N=$1; shift
for sc in "$@"; do godot --headless --path . -s tests/sim.gd -- $N $sc 2>&1 | grep -E "^[a-z]" ; done
