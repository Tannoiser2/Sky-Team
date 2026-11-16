#!/bin/bash
# controlla che tutti gli script compilino
for f in scripts/*.gd; do godot --headless --path . --check-only -s $f 2>&1 | grep -E "SCRIPT ERROR|Parse Error" -A1 | grep -v "^--" ; done
exit 0
