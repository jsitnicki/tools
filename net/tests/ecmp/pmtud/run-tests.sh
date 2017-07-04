#!/bin/bash

set -o errexit

basedir=$(dirname "$0")

. $basedir/funcs.sh

debug_maybe()
{
	local exit_status=$1

	if (( exit_status != 0 )); then
		msg_warn "Something failed. Going into debug shell..."
		PS1='DEBUG \$ ' bash
	fi
}

report_test_result()
{
	local exit_status=$1

	(( exit_status == 0 )) && msg_ok "SUCCESS" || msg_err "FAIL"
}

on_exit()
{
	debug_maybe "$@"
	$basedir/teardown.sh
	report_test_result "$@"
}

print_topology_1()
{
	log "Network topology #1"

	echo '
                                .- [L1] -- [S1]
                               /
   [C1] -- [F1] -- [F2] -- [R1] -- [L2] -- [S2]
                               \    ⋮       ⋮
                                `- [L9] -- [S9]
'
}

print_topology_2()
{
	log "Network topology #2"

	echo '
                                .- [L1] -- [S1]
                               /
   [C1] -- [F1] -- [F2] == [R1] -- [L2] -- [S2]
                               \    ⋮       ⋮
                                `- [L9] -- [S9]
'
}

print_topology_3()
{
	log "Network topology #3"

	echo '
                                .- [L1] -- [S1]
                               /
   [C1] -- [F1] == [F2] -- [R1] -- [L2] -- [S2]
                               \    ⋮       ⋮
                                `- [L9] -- [S9]
'
}

print_segments()
{
	log "L3 segments"

	echo '
   C1-F1  10.0.1./24, fd00:0:1::/64
   F1-F2  10.0.2./24, fd00:0:2::/64
   F2-R1  10.0.3./24, fd00:0:3::/64
   R1-Lx  10.1.x./24, fd00:1:x::/64
   Lx-Sx  10.2.0./24, fd00:2:0::/64
'
}

conf_link_mtu_1()
{
	: # Nothing to do
}

conf_link_mtu_2()
{
	log "Setting F2-R1 link MTU to 1400"

	F2 ip li set dev F2R1 mtu 1400
	R1 ip li set dev R1F2 mtu 1400
}

conf_link_mtu_3()
{
	log "Setting F1-F2 link MTU to 1400"

	F1 ip li set dev F1F2 mtu 1400
	F2 ip li set dev F2F1 mtu 1400
}

run_tests()
{
	trap "on_exit \$?" EXIT

	echo
	echo " *********************************"
	echo "  Run 1. MTU 1500 in all segments "
	echo "         (no PTB routing)         "
	echo " *********************************"
	echo

	print_topology_1
	print_segments

	$basedir/setup.sh
	conf_link_mtu_1
	$basedir/test-ping.sh
	$basedir/test-http.sh
	$basedir/teardown.sh

	echo
	echo "**********************************"
	echo " Run 2. MTU 1400 in F2-R1 segment "
	echo "        (PTB routing on OUTPUT)   "
	echo "**********************************"
	echo

	print_topology_2
	print_segments

	$basedir/setup.sh
	conf_link_mtu_2
	$basedir/test-ping.sh
	$basedir/test-http.sh
	$basedir/teardown.sh

	echo
	echo "**********************************"
	echo " Run 3. MTU 1400 in F1-F2 segment "
	echo "        (PTB routing on FORWARD)  "
	echo "**********************************"
	echo

	print_topology_3
	print_segments

	$basedir/setup.sh
	conf_link_mtu_3
	$basedir/test-ping.sh
	$basedir/test-http.sh
	# automatic teardown on EXIT
}

run_tests
