#!/bin/bash
#
# Tests if flows are well balanced by ECMP router
#
# 10 source addresses (IPv4, IPv6)
# 10 source ports (TCP, UDP)
# 10 destination addresses (IPv4, IPv6)
# 10 destination ports (TCP, UDP)
#
# Components:
# * Receiver
#   Takes address family and protocol as parameters.
#   Listens on 10 addresses and 10 ports.
#   Prints a count of received messages on each (address, port)
#
# Topology:
#
#  C0 [1000::100] --.   .-- S0 [2000::100..109]
#                    \ /
#  C1 [1001::101] --- R --- S1 [2000::100..109]
#  ⋮                 / \    ⋮
#  C9 [1009::109] --'   `-- S9 [2000::100..109]
#

set -o errexit
#set -o xtrace

create_namespaces()
{
	local i

	# client & server namespaces
	for i in {0..9}; do
		ip netns add C$i
		ip netns add S$i
	done
	# router namespaces
	ip netns add R
}

destroy_namespaces()
{
	local i

	# client & server namespaces
	for i in {0..9}; do
		ip netns del C$i || true
		ip netns del S$i || true
	done
	# router namespaces
	ip netns del R || true
}

link_namespaces()
{
	local i

	for i in {0..9}; do
		ip -netns R link add RC$i type veth peer name CR$i netns C$i
		ip -netns R link add RS$i type veth peer name SR$i netns S$i
	done
}

add_addreses()
{
	local i j

	for i in {0..9}; do
		ip -netns C$i addr add dev CR$i 100$i::10$i/64 nodad
		ip -netns R   addr add dev RC$i 100$i::1/64 nodad
	done

	for i in {0..9}; do
		for j in  {0..9}; do
			ip -netns S$i addr add dev SR$i 2000::10$j/64 nodad
		done
		ip -netns R addr add dev RS$i 2000::1/64 nodad
	done

}

bring_up_links()
{
	local i

	ip -netns R link set dev lo up

	for i in {0..9}; do
		ip -netns C$i link set dev lo up
		ip -netns S$i link set dev lo up

		ip -netns C$i link set dev CR$i up
		ip -netns S$i link set dev SR$i up

		ip -netns R link set dev RC$i up
		ip -netns R link set dev RS$i up
	done
}

conf_routing()
{
	local i nexthops

	ip netns exec R sysctl -q -w net.ipv6.conf.all.forwarding=1

	for i in {0..9}; do
		ip -netns C$i route add default via 100$i::1
		ip -netns S$i route add default via 2000::1

		ip -netns R route del 2000::/64 dev RS$i
		nexthops="$nexthops nexthop dev RS$i"
	done

	# shellcheck disable=SC2086
	ip -netns R route add 2000::/64 $nexthops
	# ip -netns R -6 route show
}

check_ping()
{
	local i

	for i in {0..9}; do
		ip netns exec S$i ping -6 -c1 -w1 -n -q 2000::1     > /dev/null
		ip netns exec C$i ping -6 -c1 -w1 -n -q 100$i::1    > /dev/null
		ip netns exec R   ping -6 -c1 -w1 -n -q 100$i::10$i > /dev/null
	done

	for i in {0..9}; do
		ip netns exec R   ping -6 -c1 -w1 -n -q 2000::10$i > /dev/null
		ip netns exec C$i ping -6 -c1 -w1 -n -q 2000::10$i > /dev/null
	done
}

main()
{
	# trap "destroy_namespaces" EXIT

	destroy_namespaces
	create_namespaces
	link_namespaces
	add_addreses
	bring_up_links
	conf_routing
	check_ping
	destroy_namespaces
}

main "$@"
