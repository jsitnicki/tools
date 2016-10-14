#!/bin/bash
#
# test-ecmp-icmpv6-error-routing.sh
# Test for ICMPv6 error routing  when ECMP routing is used.
#
# Topology:
#                  (D)     (Fd)
#                  Re1 --- Hs1
#                 /
# Hc --- Ri --- Rc (C)
# (A)    (B)      \
#                  Re1 --- Hs2
#                  (E)     (Fe)
#
# Hc  - client host
# HsX - server host
# Rc  - core router
# ReX - edge router
# Ri  - intermediate router
#
# Pass condition: ICMPv6 error messages, generated in response to a
# packet send from a server host to the client host, travel down the
# same path as would the packets beloging to same flow as the packet
# that triggered the error but when going in the opposite direction
# (i.e. source and destination addess are swapped, but flow label is
# the same).
#
# Author: Jakub Sitnicki <jkbs@redhat.com>
#

NAMESPACES="A B C D E Fd Fe"

# Create a function for easy execution of commands in each namespace
for ns in $NAMESPACES; do
	eval "$ns () { ip netns exec $ns \$*; }"
done

# Addresses

AB=fd00:ab::a
BA=fd00:ab::b

BC=fd00:bc::b
CB=fd00:bc::c

CD=fd00:cd::c
DC=fd00:cd::d

CE=fd00:ce::c
EC=fd00:ce::e

FF=fd00:ff::f

DF=fd00:ff::d
FD=$FF

EF=fd00:ff::e
FE=$FF

# Fail fast
set -e
# Uncomment for debugging
#set -x

test_setup_namespaces() {
	for ns in $NAMESPACES; do
		# Create namespace
		ip netns add $ns
		# Make ping to local interface work
		$ns ip li set dev lo up
	done
}

test_setup_links() {
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

test_setup_addresses() {
	A ip ad add dev AB $AB/64 nodad
	B ip ad add dev BA $BA/64 nodad

	B ip ad add dev BC $BC/64 nodad
	C ip ad add dev CB $CB/64 nodad

	C ip ad add dev CD $CD/64 nodad
	D ip ad add dev DC $DC/64 nodad

	C ip ad add dev CE $CE/64 nodad
	E ip ad add dev EC $EC/64 nodad

	D  ip ad add dev DF $DF/64 nodad
	Fd ip ad add dev FD $FD/64 nodad

	E  ip ad add dev EF $EF/64 nodad
	Fe ip ad add dev FE $FE/64 nodad
}

test_setup_forwarding() {
	B sysctl -q -w net.ipv6.conf.all.forwarding=1
	C sysctl -q -w net.ipv6.conf.all.forwarding=1
	D sysctl -q -w net.ipv6.conf.all.forwarding=1
	E sysctl -q -w net.ipv6.conf.all.forwarding=1
}

test_setup_routing() {
	A ip ro add default via $BA
	B ip ro add default via $CB
	C ip ro add default via $BC
	D ip ro add default via $CD
	E ip ro add default via $CE
	Fd ip ro add default via $DF
	Fe ip ro add default via $EF

	# Multipath routing (ECMP)
	C ip ro add $FF/64 \
	   nexthop via $DC \
	   nexthop via $EC
}

test_setup_links_up() {
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

test_check_connectivity() {
	A ping -c1 -w1 -n -q $AB > /dev/null
	A ping -c1 -w1 -n -q $BA > /dev/null

	B ping -c1 -w1 -n -q $BA > /dev/null
	B ping -c1 -w1 -n -q $AB > /dev/null

	B ping -c1 -w1 -n -q $BC > /dev/null
	B ping -c1 -w1 -n -q $CB > /dev/null

	C ping -c1 -w1 -n -q $CB > /dev/null
	C ping -c1 -w1 -n -q $BC > /dev/null

	C ping -c1 -w1 -n -q $CD > /dev/null
	C ping -c1 -w1 -n -q $DC > /dev/null

	C ping -c1 -w1 -n -q $CE > /dev/null
	C ping -c1 -w1 -n -q $EC > /dev/null

	D ping -c1 -w1 -n -q $DC > /dev/null
	D ping -c1 -w1 -n -q $CD > /dev/null

	D ping -c1 -w1 -n -q $DF > /dev/null
	D ping -c1 -w1 -n -q $FD > /dev/null

	E ping -c1 -w1 -n -q $EC > /dev/null
	E ping -c1 -w1 -n -q $CE > /dev/null

	E ping -c1 -w1 -n -q $EF > /dev/null
	E ping -c1 -w1 -n -q $FE > /dev/null

	Fd ping -c1 -w1 -n -q $FD > /dev/null
	Fd ping -c1 -w1 -n -q $DF > /dev/null

	Fe ping -c1 -w1 -n -q $FE > /dev/null
	Fe ping -c1 -w1 -n -q $EF > /dev/null

	# ECMP routing works forward?
	C ping -c1 -w1 -n -q $FF > /dev/null
	B ping -c1 -w1 -n -q $FF > /dev/null
	A ping -c1 -w1 -n -q $FF > /dev/null
}

# This is the main test. We use traceroute in UDP mode and expect the
# ICMP errors (Time Exceeded or Destination Unreachable) to travel
# back to the source host.
#
# When flow label is set (i.e. doesn't change for each UDP probe),
# traceroute to the client namespace will work, that is it won't
# report any missing replies ('*', asterisks), from one of the server
# namespaces.
#
# We cannot predict which server the replies will hit but that doesn't
# matter. Test from either and one of them should be succeed.
#
test_check_traceroute() {
	flow_label=$RANDOM
	Fd_trace=/tmp/traceroute-Fd.$$.out
	Fe_trace=/tmp/traceroute-Fe.$$.out

	Fd traceroute -n -U -l $flow_label -w 0.1 -m 4 $AB > $Fd_trace

	echo
	echo "Traceroute from Fd to A"
	cat $Fd_trace
	echo

	Fe traceroute -n -U -l $flow_label -w 0.1 -m 4 $AB > $Fe_trace

	echo
	echo "Traceroute from Fe to A"
	cat $Fe_trace
	echo

	# Check for no missing replices from hops in one of outputs
	grep -q '*' $Fd_trace
	Fd_no_response=$?

	grep -q '*' $Fe_trace
	Fe_no_response=$?

	test ! $Fd_no_response -o ! $Fe_no_response
}

test_teardown() {
	test_result=$?

	# Plow through teardown steps even if they fail
	set +e

	# Destroy namespaces, veth pairs go with them
	for ns in $NAMESPACES; do
		ip netns del $ns
	done

	if [[ $test_result -eq 0 ]]; then
		echo SUCCESS
	else
		echo FAILURE
	fi
}

trap 'test_teardown' EXIT

test_setup_namespaces
test_setup_links
test_setup_addresses
test_setup_forwarding
test_setup_routing
test_setup_links_up

# Uncomment for debugging
#PS1="$0 \$ " bash

test_check_connectivity
test_check_traceroute
