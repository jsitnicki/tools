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

set -o errexit
#set -o xtrace

print_topo()
{
	echo >&2 "* Topology"
	cat >&2 <<-EOT

	C0 [1000::2] --.                                   .-- S0 [2000::2], [3000::100..109]
	                \                                 /
	C1 [1001::2] --- [1000..1009::1] R [2000..2009::1] --- S1 [2001::2], [3000::100..109]
	:               /                                 \    :
	C9 [1009::2] --'                                   '-- S9 [2009::2], [3000::100..109]

EOT
}

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
		ip -netns R   addr add dev RC$i 100$i::1/64 nodad
		ip -netns C$i addr add dev CR$i 100$i::2/64 nodad
	done

	for i in {0..9}; do
		ip -netns R   addr add dev RS$i 200$i::1/64 nodad
		ip -netns S$i addr add dev SR$i 200$i::2/64 nodad

		for j in  {0..9}; do
			ip -netns S$i addr add dev SR$i 3000::10$j/64 nodad
		done
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
		ip -netns C$i -6 route add default via 100$i::1
		ip -netns S$i -6 route add default via 200$i::1

		nexthops="$nexthops nexthop via 200$i::2"
		# XXX: Multiple interface routes don't get recognized as multipath for some reason...
		# nexthops="$nexthops nexthop dev RS$i"
	done

	# shellcheck disable=SC2086
	ip -netns R route add 3000::/64 $nexthops

	echo >&2 "* Multipath route"
	echo >&2
	ip -netns R -6 route show 3000::/64 >&2
	echo >&2
}

check_ping()
{
	local i

	for i in {0..9}; do
		ip netns exec C$i ping -6 -c1 -w1 -n -q 100$i::1 > /dev/null # Cx -> R
		ip netns exec R   ping -6 -c1 -w1 -n -q 100$i::2 > /dev/null # R  -> Cx

		ip netns exec S$i ping -6 -c1 -w1 -n -q 200$i::1 > /dev/null # Sx -> R
		ip netns exec R   ping -6 -c1 -w1 -n -q 200$i::2 > /dev/null # R  -> Sx

	done

	for i in {0..9}; do
		ip netns exec R   ping -6 -c1 -w1 -n -q 3000::10$i > /dev/null
		ip netns exec C$i ping -6 -c1 -w1 -n -q 3000::10$i > /dev/null
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
	print_topo
	conf_routing
	check_ping
	destroy_namespaces
}

main "$@"
