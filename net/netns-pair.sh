#!/bin/bash
#
# Spawn a shell in a dedicated mount + network + user + PID namespaces.
# Then set up two network namespaces linked with a veth pair.
#
# Map current user to root inside the user namespace to gain CAP_NET_ADMIN.
# And kill all processes inside the PID namespace when shell dies.
#
# To test networking:
#
#   sandbox # ip netns exec A ping -c 1 10.0.0.2
#   sandbox # ip netns exec A ping -c 1 fd00::2
#   sandbox # ip netns exec B ping -c 1 10.0.0.2
#   sandbox # ip netns exec B ping -c 1 fd00::1
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

mount -t tmpfs tmpfs /var/run/netns

ip netns add A
ip netns add B

ip -n A link set dev lo up
ip -n B link set dev lo up

ip -n A link add AB type veth peer BA netns B

ip -n A addr add dev AB 10.0.0.1/24
ip -n B addr add dev BA 10.0.0.2/24

ip -n A addr add dev AB fd00::1/64 nodad
ip -n B addr add dev BA fd00::2/64 nodad

ip -n A link set dev AB up
ip -n B link set dev BA up

set +x

EOF
)
