#!/bin/bash
#
# Test weighted multipath (ECMP) routing over IPv6.
#
# Issue requests to HTTP servers behind an ECMP router and count how many
# requests have reached each server.
#
# With default settings server1 should receive roughly two times less requests
# than server2.
#
# Author: Jakub Sitnicki <jkbs@redhat.com>
#

NUM_REQUESTS=${1:-100}
SERVER1_WEIGHT=1
SERVER2_WEIGHT=2

set -o errexit
# Uncommend for debugging
# set -o xtrace

veth_link() {
	local ns1=$1
	local ns2=$2
	local dev1=${ns1}-${ns2}
	local dev2=${ns2}-${ns1}

	ip netns exec "${ns1}" ip link add name "${dev1}" type veth peer name "${dev2}" netns "${ns2}"
	ip netns exec "${ns1}" ip link set "${dev1}" up
	ip netns exec "${ns2}" ip link set "${dev2}" up
}

teardown() {
	echo "* Killing HTTP servers"
	ip netns pids server2 | xargs kill
	ip netns pids server1 | xargs kill

	echo "* Destroying namespaces"
	ip netns del server2
	ip netns del server1
	ip netns del router
	ip netns del client
}

trap teardown EXIT

echo "* Creating namespaces"
ip netns add client
ip netns add router
ip netns add server1
ip netns add server2

echo "* Linking namespaces"
veth_link router client
veth_link router server1
veth_link router server2

echo "* Assigning addresses"
ip netns exec router ip addr add dev router-client fd00::1/64 nodad
ip netns exec client ip addr add dev client-router fd00::2/64 nodad

ip netns exec router ip addr add dev router-server1 fd01::1/64 nodad
ip netns exec router ip addr add dev router-server2 fd02::1/64 nodad

ip netns exec server1 ip addr add dev server1-router fd01::2/64 nodad
ip netns exec server2 ip addr add dev server2-router fd02::2/64 nodad

# Specify zero preferred lifetime (deprecated) so that the address becomes secondary
ip netns exec server1 ip addr add dev server1-router fc00::1/64 nodad preferred_lft 0
ip netns exec server2 ip addr add dev server2-router fc00::1/64 nodad preferred_lft 0

echo "* Configuring routes"
ip netns exec client ip -6 route add default via fd00::1
ip netns exec server1 ip -6 route add default via fd01::1
ip netns exec server2 ip -6 route add default via fd02::1

ip netns exec router sysctl -q -w net.ipv6.conf.all.forwarding=1

ip netns exec router ip -6 route add fc00::1/128 \
   nexthop via fd01::2 dev router-server1 weight $SERVER1_WEIGHT \
   nexthop via fd02::2 dev router-server2 weight $SERVER2_WEIGHT

echo "* Bringing up HTTP servers"
ip netns exec server1 socat -6 TCP-LISTEN:80,crlf,reuseaddr,fork SYSTEM:"echo server1" &
while ! ip netns exec client curl -s -o /dev/null 'http://[fd01::2]'; do
	sleep 0.1
done

ip netns exec server2 socat -6 TCP-LISTEN:80,crlf,reuseaddr,fork SYSTEM:"echo server2" &
while ! ip netns exec client curl -s -o /dev/null 'http://[fd02::2]'; do
	sleep 0.1
done

echo "* Testing request load balancing"
for ((i = 0; i < NUM_REQUESTS; i++)); do
	ip netns exec client curl -s 'http://[fc00::1]'
done | sort | uniq -c
