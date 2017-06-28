#!/bin/bash

set -e

basedir=$(dirname "$0")

. $basedir/vars.sh
. $basedir/funcs.sh


create_namespaces()
{
	log "Creating namespaces"

	ip netns add A
	ip netns add B
	ip netns add C
	ip netns add D
	ip netns add E
	ip netns add Fd
	ip netns add Fe
}

link_namespaces()
{
	log "Linking namespaces"

	ip li add AB type veth peer name BA
	ip li set dev AB netns A
	ip li set dev BA netns B

	ip li add BC type veth peer name CB
	ip li set dev BC netns B
	ip li set dev CB netns C

	ip li add CD type veth peer name DC
	ip li set dev CD netns C
	ip li set dev DC netns D

	ip li add CE type veth peer name EC
	ip li set dev CE netns C
	ip li set dev EC netns E

	ip li add DF type veth peer name FD
	ip li set dev DF netns D
	ip li set dev FD netns Fd

	ip li add EF type veth peer name FE
	ip li set dev EF netns E
	ip li set dev FE netns Fe
}

print_topology()
{
	log "Network topology"

	cat <<_EOF_

                     [D] -- [Fd]
                    /
   [A] -- [B] == [C]
                    \\
                     [E] -- [Fe]

_EOF_
}

conf_tso_off()
{
	log "Setting TSO off to make PMTUD work NS-NS"

	A ethtool -K AB tso off
	B ethtool -K BA tso off
	B ethtool -K BC tso off
	C ethtool -K CB tso off
	C ethtool -K CD tso off
	C ethtool -K CE tso off
	D ethtool -K DC tso off
	D ethtool -K DF tso off
	E ethtool -K EC tso off
	E ethtool -K EF tso off
	Fd ethtool -K FD tso off
	Fe ethtool -K FE tso off
}

conf_link_mtu()
{
	log "Configuring link MTU from B to C"

	B ip li set dev BC mtu 1400
	C ip li set dev CB mtu 1400
}

conf_forwarding_v4()
{
	log "Configuring IPv4 forwarding"

	B sysctl -q -w net.ipv4.conf.all.forwarding=1
	C sysctl -q -w net.ipv4.conf.all.forwarding=1
	D sysctl -q -w net.ipv4.conf.all.forwarding=1
	E sysctl -q -w net.ipv4.conf.all.forwarding=1
}

conf_forwarding_v6()
{
	log "Configuring IPv6 forwarding"

	B sysctl -q -w net.ipv6.conf.all.forwarding=1
	C sysctl -q -w net.ipv6.conf.all.forwarding=1
	D sysctl -q -w net.ipv6.conf.all.forwarding=1
	E sysctl -q -w net.ipv6.conf.all.forwarding=1
}

conf_reflection_v6()
{
	log "Enabling Flow Label reflection on server namespaces (EXPERIMENTAL)"

	if [ -e /proc/sys/net/ipv6/flowlabel_reflect ]; then
		Fd sysctl -q -w net.ipv6.flowlabel_reflect=1
		Fe sysctl -q -w net.ipv6.flowlabel_reflect=1
	fi
}

conf_addrs_v4()
{
	log "Configuring IPv4 addresses"

	A ip ad add dev AB $AB4/$PREFIX4
	B ip ad add dev BA $BA4/$PREFIX4

	B ip ad add dev BC $BC4/$PREFIX4
	C ip ad add dev CB $CB4/$PREFIX4

	C ip ad add dev CD $CD4/$PREFIX4
	D ip ad add dev DC $DC4/$PREFIX4

	C ip ad add dev CE $CE4/$PREFIX4
	E ip ad add dev EC $EC4/$PREFIX4

	D  ip ad add dev DF $DF4/$PREFIX4
	Fd ip ad add dev FD $FD4/$PREFIX4

	E  ip ad add dev EF $EF4/$PREFIX4
	Fe ip ad add dev FE $FE4/$PREFIX4
}

conf_addrs_v6()
{
	log "Configuring IPv6 addresses"

	A ip ad add dev AB $AB6/$PREFIX6 nodad
	B ip ad add dev BA $BA6/$PREFIX6 nodad

	B ip ad add dev BC $BC6/$PREFIX6 nodad
	C ip ad add dev CB $CB6/$PREFIX6 nodad

	C ip ad add dev CD $CD6/$PREFIX6 nodad
	D ip ad add dev DC $DC6/$PREFIX6 nodad

	C ip ad add dev CE $CE6/$PREFIX6 nodad
	E ip ad add dev EC $EC6/$PREFIX6 nodad

	D  ip ad add dev DF $DF6/$PREFIX6 nodad
	Fd ip ad add dev FD $FD6/$PREFIX6 nodad

	E  ip ad add dev EF $EF6/$PREFIX6 nodad
	Fe ip ad add dev FE $FE6/$PREFIX6 nodad
}

set_ifaces_up()
{
	log "Bringing interfaces up"

	A  ip li set dev lo up
	B  ip li set dev lo up
	C  ip li set dev lo up
	D  ip li set dev lo up
	E  ip li set dev lo up
	Fd ip li set dev lo up
	Fe ip li set dev lo up

	A ip li set dev AB up
	B ip li set dev BA up

	B ip li set dev BC up
	C ip li set dev CB up

	C ip li set dev CD up
	D ip li set dev DC up

	C ip li set dev CE up
	E ip li set dev EC up

	D  ip li set dev DF up
	Fd ip li set dev FD up

	E  ip li set dev EF up
	Fe ip li set dev FE up
}

conf_routes_default_v4()
{
	log "Configuring default IPv4 routes"

	A  ip ro add default via $BA4
	B  ip ro add default via $CB4
	C  ip ro add default via $BC4
	D  ip ro add default via $CD4
	E  ip ro add default via $CE4
	Fd ip ro add default via $DF4
	Fe ip ro add default via $EF4
}

conf_routes_default_v6()
{
	log "Configuring default IPv6 routes"

	A  ip ro add default via $BA6
	B  ip ro add default via $CB6
	C  ip ro add default via $BC6
	D  ip ro add default via $CD6
	E  ip ro add default via $CE6
	Fd ip ro add default via $DF6
	Fe ip ro add default via $EF6
}

conf_routes_multipath_v4()
{
	log "Configuring multipath IPv4 routes"

	C ip ro add $FF4/32 \
	  nexthop via $DC4 \
	  nexthop via $EC4
}

conf_routes_multipath_v6()
{
	log "Configuring multipath IPv6 routes"

	C ip ro add $FF6/128 \
	  nexthop via $DC6 \
	  nexthop via $EC6
}

run_tcpdump()
{
	A  tcpdump -U -s0 -n -nn -w  A.cap -i any &
	Fd tcpdump -U -s0 -n -nn -w Fd.cap -i any &
	Fe tcpdump -U -s0 -n -nn -w Fe.cap -i any &
	sleep 0.1
}

setup()
{
	log "Starting setup"

	create_namespaces
	link_namespaces
	print_topology
	conf_tso_off
	conf_link_mtu
	conf_forwarding_v4
	conf_forwarding_v6
	conf_reflection_v6
	conf_addrs_v4
	conf_addrs_v6
	set_ifaces_up
	conf_routes_default_v4
	conf_routes_default_v6
	conf_routes_multipath_v4
	conf_routes_multipath_v6
	# run_tcpdump
}

setup
