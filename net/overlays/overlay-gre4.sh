#!/bin/bash -x
#
# GRE tunnel between namespace A (10.0.0.1) and C (172.16.0.1)
# carrying overlay traffic 192.0.2.0/24.
#

ip -n A tunnel add greA mode gre local 10.0.0.1 remote 172.16.0.1
ip -n C tunnel add greC mode gre local 172.16.0.1 remote 10.0.0.1

ip -n A addr add 192.0.2.1/24 dev greA
ip -n C addr add 192.0.2.2/24 dev greC

ip -n A link set dev greA up
ip -n C link set dev greC up
