#!/usr/bin/env python
"""
Send an IPv6/UDP ping (an empty UDP datagram) to port 0 (likely to be
closed) to a given address and with a given IPv6 flow label set.

This is for determining which path an IPv6/UDP flow will travel when
there are multiple routes to a host as when using ECMP routing.

Inspired by Jesper Brouer's scapy scripts:
  https://github.com/netoptimizer/network-testing/tree/master/scapy

Usage:
  udpv6_ping_with_label.py <flow label> <dst address>

Where:
  flow label   - IPv6 flow label (decimal number)
  dst address  - IPv6 address

"""

from __future__ import print_function
import sys

from scapy.all import *

def ipv6_udp_with_flow_label(flow_label, dst_addr):
    print("Sending empty IPv6/UDP packet with flow label %s to [%s]:0" % (flow_label, dst_addr))

    udp = UDP(dport=0)
    ipv6 = IPv6(dst=dst_addr, fl=int(flow_label))

    send(ipv6/udp)


if __name__ == "__main__":
    def usage():
        sys.stderr.write(__doc__)
        sys.exit(1)

    if len(sys.argv) != 3:
        usage()

    flow_label, dst_addr = sys.argv[1:]

    ipv6_udp_with_flow_label(flow_label, dst_addr)
