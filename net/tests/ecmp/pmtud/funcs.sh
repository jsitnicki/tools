#!/bin/bash

for ns in C1 F1 F2 R1 {L,S}{1..9}; do
	eval $ns '() { ip netns exec ${FUNCNAME[0]} "$@"; }'
done

color_red()    { echo -en '\033[1;31m'; }
color_green()  { echo -en '\033[1;32m'; }
color_yellow() { echo -en '\033[1;33m'; }
color_off()    { echo -en '\033[0m'; }

msg_err()  { color_red;    echo "$@"; color_off; return 1; }
msg_warn() { color_yellow; echo "$@"; color_off; return 0; }
msg_ok()   { color_green;  echo "$@"; color_off; return 0; }

log() { echo " * $@"; }
