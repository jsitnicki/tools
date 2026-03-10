#!/bin/bash
#
# Spawn a shell in dedicated mount + network + user + PID namespaces.
# Map current user to root inside the user namespace to gain CAP_NET_ADMIN.
# Kill all processes inside the PID namespace when the shell dies.
#
# Set up three network namespaces (A, B, C) chained with two veth pairs:
#
#   A ──(AB/BA)── B ──(BC/CB)── C
#
# Addressing:
#
#   A-B link: 10.0.0.0/24 (A=.1, B=.2) + fd00:a::/64 (A=::1, B=::2)
#   B-C link: 172.16.0.0/24 (C=.1, B=.2) + fd00:c::/64 (C=::1, B=::2)
#
# B has IPv4 and IPv6 forwarding enabled. Default routes on A and C point
# through B, so all three namespaces can reach each other.
#
# Shell helpers A, B, C are defined as wrappers around ip netns exec.
#
# To test connectivity:
#
#   sandbox $ A ping -c 1 10.0.0.2      # A -> B (IPv4)
#   sandbox $ A ping -c 1 fd00:a::2     # A -> B (IPv6)
#   sandbox $ A ping -c 1 172.16.0.1    # A -> C (IPv4, via B)
#   sandbox $ A ping -c 1 fd00:c::1     # A -> C (IPv6, via B)
#   sandbox $ C ping -c 1 fd00:a::1     # C -> A (IPv6, via B)
#

exec unshare \
     --mount \
     --net \
     --user --map-root-user \
     --pid --kill-child \
     -- \
     bash --init-file <(
        cat <<EOF
PS1='sandbox \\$ '

set -x

mount -t tmpfs tmpfs /var/run
mkdir /var/run/netns

ip netns add A
ip netns add B
ip netns add C

ip -n A link set dev lo up
ip -n B link set dev lo up
ip -n C link set dev lo up

ip -n A link add AB type veth peer BA netns B
ip -n B link add BC type veth peer CB netns C

ip -n A link set dev AB addr 02:00:00:00:00:ab
ip -n B link set dev BA addr 02:00:00:00:00:ba
ip -n B link set dev BC addr 02:00:00:00:00:bc
ip -n C link set dev CB addr 02:00:00:00:00:cb

ip -n A addr add dev AB 10.0.0.1/24
ip -n B addr add dev BA 10.0.0.2/24

ip -n B addr add dev BC 172.16.0.2/24
ip -n C addr add dev CB 172.16.0.1/24

ip -n A addr add dev AB fd00:a::1/64 nodad
ip -n B addr add dev BA fd00:a::2/64 nodad

ip -n B addr add dev BC fd00:c::2/64 nodad
ip -n C addr add dev CB fd00:c::1/64 nodad

ip -n A link set dev AB up
ip -n B link set dev BA up

ip -n B link set dev BC up
ip -n C link set dev CB up

# Routing

ip netns exec B sysctl -qw net.ipv4.ip_forward=1
ip netns exec B sysctl -qw net.ipv6.conf.all.forwarding=1

ip -n A route add default via 10.0.0.2
ip -n C route add default via 172.16.0.2

ip -n A -6 route add default via fd00:a::2
ip -n C -6 route add default via fd00:c::2

# ip netns exec Wrappers

A() { ip netns exec A "\$@"; }
B() { ip netns exec B "\$@"; }
C() { ip netns exec C "\$@"; }

set +x

EOF
)
