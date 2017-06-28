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

	for ns in A B C D E Fd Fe;  do
		ip netns del $ns
	done
}

debug_maybe()
{
	local exit_status=$1

	if (( $exit_status != 0 )); then
		log "Going into debug shell"
		PS1='DEBUG \$ ' bash
	fi
}

report_test_result()
{
	local exit_status=$1

	[[ $exit_status == 0 ]] && msg_ok "SUCCESS" || msg_err "FAIL"
}

teardown()
{
	log "Starting teardown"
	debug_maybe "$@"
	kill_processes
	destroy_namespaces
	report_test_result "$@"
}

teardown "$@"
