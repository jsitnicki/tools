#!/bin/bash
#
# Demonstration that vxlan devices can be bonded (because why not?).
# A PoC setup that uses net namespaces and veth pairs.
#

set -e
set -x

ip netns del ns0 || true
ip netns del ns1 || true

ip netns add ns0
ip netns add ns1

ip link add name p0 netns ns0 type veth \
       peer name p1 netns ns1
ip link add name p2 netns ns0 type veth \
       peer name p3 netns ns1

ip -n ns0 addr add dev p0 1.1.1.1/24
ip -n ns1 addr add dev p1 1.1.1.2/24

ip -n ns0 addr add dev p2 2.2.2.1/24
ip -n ns1 addr add dev p3 2.2.2.2/24

ip -n ns0 link set dev lo up
ip -n ns0 link set dev p0 up
ip -n ns0 link set dev p2 up

ip -n ns1 link set dev lo up
ip -n ns1 link set dev p1 up
ip -n ns1 link set dev p3 up

ip netns exec ns0 ping -c1 1.1.1.2
ip netns exec ns1 ping -c1 1.1.1.1
ip netns exec ns0 ping -c1 2.2.2.2
ip netns exec ns1 ping -c1 2.2.2.1

ip -n ns0 link add name vx0 type vxlan \
   id 1 dev p0 remote 1.1.1.2 dstport 4789
ip -n ns1 link add name vx1 type vxlan \
   id 1 dev p1 remote 1.1.1.1 dstport 4789

ip -n ns0 link add name vx2 type vxlan \
   id 2 dev p2 remote 2.2.2.2 dstport 4789
ip -n ns1 link add name vx3 type vxlan \
   id 2 dev p3 remote 2.2.2.1 dstport 4789

ip -n ns0 addr add dev vx0 10.10.10.1/24
ip -n ns1 addr add dev vx1 10.10.10.2/24

ip -n ns0 addr add dev vx2 20.20.20.1/24
ip -n ns1 addr add dev vx3 20.20.20.2/24

ip -n ns0 link set dev vx0 up
ip -n ns1 link set dev vx1 up

ip -n ns0 link set dev vx2 up
ip -n ns1 link set dev vx3 up

ip netns exec ns0 ping -c1 10.10.10.2
ip netns exec ns1 ping -c1 10.10.10.1

ip netns exec ns0 ping -c1 20.20.20.2
ip netns exec ns1 ping -c1 20.20.20.1

ip -n ns0 link set dev vx0 down
ip -n ns1 link set dev vx1 down
ip -n ns0 link set dev vx2 down
ip -n ns1 link set dev vx3 down

ip -n ns0 addr flush dev vx0 scope global
ip -n ns1 addr flush dev vx1 scope global
ip -n ns0 addr flush dev vx2 scope global
ip -n ns1 addr flush dev vx3 scope global

# WARNING: bond device cannot have higher mtu than vxlan (which
# reserves room for headers) or enslaving vxlans will fail with
# cryptic EINVAL.
ip -n ns0 link add name bo0 mtu 1450 type bond
ip -n ns0 link set dev vx0 master bo0
ip -n ns0 link set dev vx2 master bo0

ip -n ns1 link add name bo1 mtu 1450 type bond
ip -n ns1 link set dev vx1 master bo1
ip -n ns1 link set dev vx3 master bo1

ip -n ns0 addr add dev bo0 100.100.100.1/24
ip -n ns1 addr add dev bo1 100.100.100.2/24

ip -n ns0 link set dev bo0 up
ip -n ns1 link set dev bo1 up

ip netns exec ns0 ping -c1 100.100.100.2
ip netns exec ns1 ping -c1 100.100.100.1
