#!/bin/bash
#
# Set up routing so that packets go through veth pair
#

set -o xtrace
set -o errexit

ip link add veth0 type veth peer name veth1

ip link set dev veth0 addr 02:00:00:00:00:01
ip link set dev veth1 addr 02:00:00:00:00:02

ip addr add 10.0.0.1/24 dev veth0
ip addr add 10.0.0.2/24 dev veth1

# OPTIONAL
# ip neigh add 10.0.0.1 lladdr 02:00:00:00:00:01 nud permanent dev veth1
# ip neigh add 10.0.0.2 lladdr 02:00:00:00:00:02 nud permanent dev veth0

ip link set dev veth0 up
ip link set dev veth1 up

ip route add 10.0.0.1/32 table 42 dev veth1 src 10.0.0.2
ip route add 10.0.0.2/32 table 42 dev veth0 src 10.0.0.1

ip rule del prio 0 table local
ip rule add prio 100 table local

ip rule add prio 0 iif veth0 table local
ip rule add prio 1 iif veth1 table local
ip rule add prio 3 table 42
