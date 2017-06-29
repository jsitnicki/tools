#!/bin/bash

A () { ip netns exec ${FUNCNAME[0]} "$@"; }
B () { ip netns exec ${FUNCNAME[0]} "$@"; }
C () { ip netns exec ${FUNCNAME[0]} "$@"; }
D () { ip netns exec ${FUNCNAME[0]} "$@"; }
E () { ip netns exec ${FUNCNAME[0]} "$@"; }
Fd() { ip netns exec ${FUNCNAME[0]} "$@"; }
Fe() { ip netns exec ${FUNCNAME[0]} "$@"; }

color_red()   { echo -en '\033[1;31m'; }
color_green() { echo -en '\033[1;32m'; }
color_off()   { echo -en '\033[0m'; }

log() { echo " * $@"; }
msg_err() { color_red; echo "$@"; color_off; return 1;}
msg_ok()  { color_green; echo "$@"; color_off; return 0; }
