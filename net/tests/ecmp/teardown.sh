#!/bin/bash

# set -x

basedir=$(dirname "$0")

. $basedir/vars.sh
. $basedir/funcs.sh

kill_processes()
{
	for ns in A B C D E Fd Fe; do
		ip netns pids $ns | xargs kill 2>/dev/null
	done
}

destroy_namespaces()
{
	log "Destroying namespaces"

	ip netns del A
	ip netns del B
	ip netns del C
	ip netns del D
	ip netns del E
	ip netns del Fd
	ip netns del Fe
}

debug_maybe()
{
	log "Going into debug shell"

	PS1='DEBUG \$ ' bash
}

report_test_result()
{
	local exit_status=$1

	[[ $exit_status == 0 ]] && msg_ok "SUCCESS" || msg_err "FAIL"
}

teardown()
{
	log "Starting teardown"
	# debug_maybe
	kill_processes
	destroy_namespaces
	report_test_result "$@"
}

teardown "$@"
