#!/bin/bash

set -e

basedir=$(dirname "$0")

. $basedir/vars.sh
. $basedir/funcs.sh

test_ping_local_and_neighbours_v4()
{
	log "Testing IPv4 ping to local address and to neighbours"

	A ping -c1 -w1 -n -q $AB4 > /dev/null
	A ping -c1 -w1 -n -q $BA4 > /dev/null

	B ping -c1 -w1 -n -q $BA4 > /dev/null
	B ping -c1 -w1 -n -q $AB4 > /dev/null

	B ping -c1 -w1 -n -q $BC4 > /dev/null
	B ping -c1 -w1 -n -q $CB4 > /dev/null

	C ping -c1 -w1 -n -q $CB4 > /dev/null
	C ping -c1 -w1 -n -q $BC4 > /dev/null

	C ping -c1 -w1 -n -q $CD4 > /dev/null
	C ping -c1 -w1 -n -q $DC4 > /dev/null

	C ping -c1 -w1 -n -q $CE4 > /dev/null
	C ping -c1 -w1 -n -q $EC4 > /dev/null

	D ping -c1 -w1 -n -q $DC4 > /dev/null
	D ping -c1 -w1 -n -q $CD4 > /dev/null

	D ping -c1 -w1 -n -q $DF4 > /dev/null
	D ping -c1 -w1 -n -q $FD4 > /dev/null

	E ping -c1 -w1 -n -q $EC4 > /dev/null
	E ping -c1 -w1 -n -q $CE4 > /dev/null

	E ping -c1 -w1 -n -q $EF4 > /dev/null
	E ping -c1 -w1 -n -q $FE4 > /dev/null

	Fd ping -c1 -w1 -n -q $FD4 > /dev/null
	Fd ping -c1 -w1 -n -q $DF4 > /dev/null

	Fe ping -c1 -w1 -n -q $FE4 > /dev/null
	Fe ping -c1 -w1 -n -q $EF4 > /dev/null
}

test_ping_thru_multipath_router_v4()
{
	log "Testing IPv4 through ECMP router"

	C ping -c1 -w1 -n -q $FF4 > /dev/null
	B ping -c1 -w1 -n -q $FF4 > /dev/null
	A ping -c1 -w1 -n -q $FF4 > /dev/null
}

test_ping_local_and_neighbours_v6()
{
	log "Testing IPv6 ping to local address and to neighbours"

	A ping -c1 -w1 -n -q $AB6 > /dev/null
	A ping -c1 -w1 -n -q $BA6 > /dev/null

	B ping -c1 -w1 -n -q $BA6 > /dev/null
	B ping -c1 -w1 -n -q $AB6 > /dev/null

	B ping -c1 -w1 -n -q $BC6 > /dev/null
	B ping -c1 -w1 -n -q $CB6 > /dev/null

	C ping -c1 -w1 -n -q $CB6 > /dev/null
	C ping -c1 -w1 -n -q $BC6 > /dev/null

	C ping -c1 -w1 -n -q $CD6 > /dev/null
	C ping -c1 -w1 -n -q $DC6 > /dev/null

	C ping -c1 -w1 -n -q $CE6 > /dev/null
	C ping -c1 -w1 -n -q $EC6 > /dev/null

	D ping -c1 -w1 -n -q $DC6 > /dev/null
	D ping -c1 -w1 -n -q $CD6 > /dev/null

	D ping -c1 -w1 -n -q $DF6 > /dev/null
	D ping -c1 -w1 -n -q $FD6 > /dev/null

	E ping -c1 -w1 -n -q $EC6 > /dev/null
	E ping -c1 -w1 -n -q $CE6 > /dev/null

	E ping -c1 -w1 -n -q $EF6 > /dev/null
	E ping -c1 -w1 -n -q $FE6 > /dev/null

	Fd ping -c1 -w1 -n -q $FD6 > /dev/null
	Fd ping -c1 -w1 -n -q $DF6 > /dev/null

	Fe ping -c1 -w1 -n -q $FE6 > /dev/null
	Fe ping -c1 -w1 -n -q $EF6 > /dev/null
}

test_ping_thru_multipath_router_v6()
{
	log "Testing IPv6 through ECMP router"

	C ping -c1 -w1 -n -q $FF6 > /dev/null
	B ping -c1 -w1 -n -q $FF6 > /dev/null
	A ping -c1 -w1 -n -q $FF6 > /dev/null
}

test_ping()
{
	test_ping_local_and_neighbours_v4
	test_ping_thru_multipath_router_v4
	test_ping_local_and_neighbours_v6
	test_ping_thru_multipath_router_v6
}

test_ping
