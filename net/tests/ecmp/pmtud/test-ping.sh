#!/bin/bash

set -e

basedir=$(dirname "$0")

. $basedir/funcs.sh

test_ping_local_and_neighbours_v4()
{
	local i ns1 ns2

	log "Testing IPv4 ping to local address and to neighbours"

	i=1
	ns1=C1
	for ns2 in F1 F2 R1; do
		$ns1 ping -4 -c1 -w1 -n -q 10.0.$i.1 > /dev/null
		$ns1 ping -4 -c1 -w1 -n -q 10.0.$i.2 > /dev/null

		$ns2 ping -4 -c1 -w1 -n -q 10.0.$i.2 > /dev/null
		$ns2 ping -4 -c1 -w1 -n -q 10.0.$i.1 > /dev/null

		i=$((i+1))
		ns1=$ns2
	done

	i=1
	ns1=R1
	for ns2 in L{1..9}; do
		$ns1 ping -4 -c1 -w1 -n -q 10.1.$i.1 > /dev/null
		$ns1 ping -4 -c1 -w1 -n -q 10.1.$i.2 > /dev/null

		$ns2 ping -4 -c1 -w1 -n -q 10.1.$i.2 > /dev/null
		$ns2 ping -4 -c1 -w1 -n -q 10.1.$i.1 > /dev/null

		i=$((i+1))
	done

	for i in {1..9}; do
		ns1=L$i
		ns2=S$i

		$ns1 ping -4 -c1 -w1 -n -q 10.2.0.1 > /dev/null
		$ns1 ping -4 -c1 -w1 -n -q 10.2.0.2 > /dev/null

		$ns2 ping -4 -c1 -w1 -n -q 10.2.0.2 > /dev/null
		$ns2 ping -4 -c1 -w1 -n -q 10.2.0.1 > /dev/null
	done
}

test_ping_thru_multipath_router_v4()
{
	log "Testing IPv4 through ECMP router"

	R1 ping -4 -c1 -w1 -n -q 10.2.0.2 > /dev/null
	F2 ping -4 -c1 -w1 -n -q 10.2.0.2 > /dev/null
	F1 ping -4 -c1 -w1 -n -q 10.2.0.2 > /dev/null
	C1 ping -4 -c1 -w1 -n -q 10.2.0.2 > /dev/null
}

test_ping_local_and_neighbours_v6()
{
	local i ns1 ns2

	log "Testing IPv6 ping to local address and to neighbours"

	i=1
	ns1=C1
	for ns2 in F1 F2 R1; do
		$ns1 ping -6 -c1 -w1 -n -q fd00:0:$i::1 > /dev/null
		$ns1 ping -6 -c1 -w1 -n -q fd00:0:$i::2 > /dev/null

		$ns2 ping -6 -c1 -w1 -n -q fd00:0:$i::2 > /dev/null
		$ns2 ping -6 -c1 -w1 -n -q fd00:0:$i::1 > /dev/null

		i=$((i+1))
		ns1=$ns2
	done

	i=1
	ns1=R1
	for ns2 in L{1..9}; do
		$ns1 ping -6 -c1 -w1 -n -q fd00:1:$i::1 > /dev/null
		$ns1 ping -6 -c1 -w1 -n -q fd00:1:$i::2 > /dev/null

		$ns2 ping -6 -c1 -w1 -n -q fd00:1:$i::2 > /dev/null
		$ns2 ping -6 -c1 -w1 -n -q fd00:1:$i::1 > /dev/null

		i=$((i+1))
	done

	for i in {1..9}; do
		ns1=L$i
		ns2=S$i

		$ns1 ping -6 -c1 -w1 -n -q fd00:2:0::1 > /dev/null
		$ns1 ping -6 -c1 -w1 -n -q fd00:2:0::2 > /dev/null

		$ns2 ping -6 -c1 -w1 -n -q fd00:2:0::2 > /dev/null
		$ns2 ping -6 -c1 -w1 -n -q fd00:2:0::1 > /dev/null
	done
}

test_ping_thru_multipath_router_v6()
{
	log "Testing IPv6 through ECMP router"

	R1 ping -6 -c1 -w1 -n -q fd00:2:0::2 > /dev/null
	F2 ping -6 -c1 -w1 -n -q fd00:2:0::2 > /dev/null
	F1 ping -6 -c1 -w1 -n -q fd00:2:0::2 > /dev/null
	C1 ping -6 -c1 -w1 -n -q fd00:2:0::2 > /dev/null
}

test_ping()
{
	test_ping_local_and_neighbours_v4
	test_ping_thru_multipath_router_v4
	test_ping_local_and_neighbours_v6
	test_ping_thru_multipath_router_v6
}

test_ping
