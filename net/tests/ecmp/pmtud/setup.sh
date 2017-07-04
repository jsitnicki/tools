#!/bin/bash

set -e

basedir=$(dirname "$0")

. $basedir/funcs.sh

create_namespaces()
{
	log "Creating namespaces"

	for ns in C1 F1 F2 R1 {L,S}{1..9}; do
		ip netns add $ns
	done
}

link_namespaces()
{
	local i ns1 ns2

	log "Linking namespaces"

	ns1=C1
	for ns2 in F1 F2 R1; do
		ip li add $ns1$ns2 type veth peer name $ns2$ns1
		ip li set dev $ns1$ns2 netns $ns1
		ip li set dev $ns2$ns1 netns $ns2
		ns1=$ns2
	done

	ns1=R1
	for ns2 in L{1..9}; do
		ip li add $ns1$ns2 type veth peer name $ns2$ns1
		ip li set dev $ns1$ns2 netns $ns1
		ip li set dev $ns2$ns1 netns $ns2
	done

	for i in {1..9}; do
		ns1=L$i
		ns2=S$i

		ip li add $ns1$ns2 type veth peer name $ns2$ns1
		ip li set dev $ns1$ns2 netns $ns1
		ip li set dev $ns2$ns1 netns $ns2
	done
}

conf_tso_off()
{
	local i ns1 ns2

	log "Setting TSO off to make PMTUD work NS-NS"

	ns1=C1
	for ns2 in F1 F2 R1; do
		$ns1 ethtool -K $ns1$ns2 tso off
		$ns2 ethtool -K $ns2$ns1 tso off
		ns1=$ns2
	done

	ns1=R1
	for ns2 in L{1..9}; do
		$ns1 ethtool -K $ns1$ns2 tso off
		$ns2 ethtool -K $ns2$ns1 tso off
	done

	for i in {1..9}; do
		ns1=L$i
		ns2=S$i

		$ns1 ethtool -K $ns1$ns2 tso off
		$ns2 ethtool -K $ns2$ns1 tso off
	done
}

conf_forwarding_v4()
{
	local ns

	log "Configuring IPv4 forwarding"

	for ns in F1 F2 R1 L{1..9}; do
		$ns sysctl -q -w net.ipv4.conf.all.forwarding=1
	done
}

conf_forwarding_v6()
{
	local ns

	log "Configuring IPv6 forwarding"

	for ns in F1 F2 R1 L{1..9}; do
		$ns sysctl -q -w net.ipv6.conf.all.forwarding=1
	done
}

conf_reflection_v6()
{
	local ns

	log "Enabling Flow Label reflection on server namespaces (EXPERIMENTAL)"

	if [ -e /proc/sys/net/ipv6/flowlabel_reflect ]; then
		for ns in S{1..9}; do
			$ns sysctl -q -w net.ipv6.flowlabel_reflect=1
		done
	fi
}

conf_addrs_v4()
{
	local i ns1 ns2

	log "Configuring IPv4 addresses"

	# L3 segments:
	# 10.0.{1..3}./24
	# 10.1.{1..9}./24
	# 10.2.0./24 (anycast)

	i=1
	ns1=C1
	for ns2 in F1 F2 R1; do
		$ns1 ip ad add dev $ns1$ns2 10.0.$i.1/24
		$ns2 ip ad add dev $ns2$ns1 10.0.$i.2/24

		i=$((i+1))
		ns1=$ns2
	done

	i=1
	ns1=R1
	for ns2 in L{1..9}; do
		$ns1 ip ad add dev $ns1$ns2 10.1.$i.1/24
		$ns2 ip ad add dev $ns2$ns1 10.1.$i.2/24

		i=$((i+1))
	done

	for i in {1..9}; do
		ns1=L$i
		ns2=S$i

		$ns1 ip ad add dev $ns1$ns2 10.2.0.1/24
		$ns2 ip ad add dev $ns2$ns1 10.2.0.2/24
	done
}

conf_addrs_v6()
{
	log "Configuring IPv6 addresses"

	# L3 segments:
	# fd00:0:{1..3}::/64
	# fd00:1:{1..9}::/64
	# fd00:2:0::/64 (anycast)

	i=1
	ns1=C1
	for ns2 in F1 F2 R1; do
		$ns1 ip ad add dev $ns1$ns2 fd00:0:$i::1/64
		$ns2 ip ad add dev $ns2$ns1 fd00:0:$i::2/64

		i=$((i+1))
		ns1=$ns2
	done

	i=1
	ns1=R1
	for ns2 in L{1..9}; do
		$ns1 ip ad add dev $ns1$ns2 fd00:1:$i::1/64
		$ns2 ip ad add dev $ns2$ns1 fd00:1:$i::2/64

		i=$((i+1))
	done

	for i in {1..9}; do
		ns1=L$i
		ns2=S$i

		$ns1 ip ad add dev $ns1$ns2 fd00:2:0::1/64
		$ns2 ip ad add dev $ns2$ns1 fd00:2:0::2/64
	done
}

set_ifaces_up()
{
	log "Bringing interfaces up"

	for ns in C1 F1 F2 R1 {L,S}{1..9}; do
		$ns ip li set dev lo up
	done

	ns1=C1
	for ns2 in F1 F2 R1; do
		$ns1 ip li set dev $ns1$ns2 up
		$ns2 ip li set dev $ns2$ns1 up
		ns1=$ns2
	done

	ns1=R1
	for ns2 in L{1..9}; do
		$ns1 ip li set dev $ns1$ns2 up
		$ns2 ip li set dev $ns2$ns1 up
	done

	for i in {1..9}; do
		ns1=L$i
		ns2=S$i

		$ns1 ip li set dev $ns1$ns2 up
		$ns2 ip li set dev $ns2$ns1 up
	done
}

conf_routes_default_v4()
{
	local i ns nexthops

	log "Configuring default IPv4 routes"

	i=1
	for ns in C1 F1 F2; do
		$ns ip -4 ro add default via 10.0.$i.2
		i=$((i+1))
	done
	F2 ip -4 ro add 10.0.1.0/24 via 10.0.2.1

	nexthops=
	for i in {1..9}; do
		nexthops="$nexthops nexthop via 10.1.$i.2"
	done
	R1 ip -4 ro add default $nexthops
	R1 ip -4 ro add 10.0.1.0/24 via 10.0.3.1
	R1 ip -4 ro add 10.0.2.0/24 via 10.0.3.1

	for i in {1..9}; do
		L$i ip -4 ro add default via 10.1.$i.1
		S$i ip -4 ro add default via 10.2.0.1
	done
}

conf_routes_default_v6()
{
	local i ns nexthops

	log "Configuring default IPv6 routes"

	i=1
	for ns in C1 F1 F2; do
		$ns ip -6 ro add default via fd00:0:$i::2
		i=$((i+1))
	done
	F2 ip -6 ro add fd00:0:1::/64 via fd00:0:2::1

	nexthops=
	for i in {1..9}; do
		nexthops="$nexthops nexthop via fd00:1:$i::2"
	done
	R1 ip -6 ro add default $nexthops
	R1 ip -6 ro add fd00:0:1::/64 via fd00:0:3::1
	R1 ip -6 ro add fd00:0:2::/64 via fd00:0:3::1

	for i in {1..9}; do
		L$i ip -6 ro add default via fd00:1:$i::1
		S$i ip -6 ro add default via fd00:2:0::1
	done
}

setup()
{
	log "Starting setup"

	create_namespaces
	link_namespaces
	conf_tso_off
	conf_forwarding_v4
	conf_forwarding_v6
	conf_reflection_v6
	conf_addrs_v4
	conf_addrs_v6
	set_ifaces_up
	conf_routes_default_v4
	conf_routes_default_v6
}

setup
