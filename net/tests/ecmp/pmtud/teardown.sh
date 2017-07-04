#!/bin/bash

set -o errexit

basedir=$(dirname "$0")

. $basedir/funcs.sh

kill_processes()
{
	log "Kill all processes in namespaces"

	for ns in C1 F1 F2 R1 {L,S}{1..9}; do
		ip netns pids $ns | xargs kill 2>/dev/null || true
	done
}

destroy_namespaces()
{
	log "Destroy namespaces"

	for ns in C1 F1 F2 R1 {L,S}{1..9};  do
		ip netns del $ns
	done
}

cleanup()
{
	kill_processes
	destroy_namespaces
}

teardown()
{
	log "Starting teardown"

	kill_processes
	destroy_namespaces
}

teardown
