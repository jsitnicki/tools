#!/usr/bin/env python
"""
Sniff-and-reply script to mimic the behavior of a quirky Cisco UCS
switch firmware which tags forwarded frames with VLAN id 0.

Reply only to ARP requests and ICMP Echo requests. Everything else
is ignored. This is enough to test with ping from the host.

An alternative would be to use Scapy's Automaton class.

Usage:
  arp_and_icmp_reply_with_vlan0.py <iface to sniff on>
"""

import sys
from scapy.all import *

IFACE=""                    # iface to sniff on, set from the command line
SRC_MAC="0a:e0:c5:28:0c:a7" # random local unicast MAC address

def packet_callback(pkt):
    resp=None

    if ARP in pkt and pkt[ARP].op == 1: # who-has
        l2_src=SRC_MAC
        l2_dst=pkt[Ether].src
        l3_src=pkt[ARP].pdst
        l3_dst=pkt[ARP].psrc

        resp=Ether(src=l2_src,
                   dst=l2_dst)/Dot1Q(vlan=0)/ARP(op="is-at",
                                                 hwsrc=l2_src,
                                                 psrc=l3_src,
                                                 hwdst=l2_dst,
                                                 pdst=l3_dst)

    if ICMP in pkt and pkt[ICMP].type == 8: # echo request
        l2_src=pkt[Ether].dst
        l2_dst=pkt[Ether].src
        l3_src=pkt[IP].dst
        l3_dst=pkt[IP].src
        echo_id=pkt[ICMP].id
        echo_seq=pkt[ICMP].seq
        # RFC 1122: 3.2.2.6 Data received in the ICMP_ECHO request
        #           MUST be included in the reply.
        echo_data=pkt[Raw]

        resp=Ether(src=l2_src,
                   dst=l2_dst)/Dot1Q(vlan=0)/IP(src=l3_src,
                                                dst=l3_dst)/ICMP(type="echo-reply",
                                                                 code=0,
                                                                 id=echo_id,
                                                                 seq=echo_seq)/echo_data

    # If we've prepared a response, send it out
    if resp:
        sendp(resp, iface=IFACE);

    return pkt.summary()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write(__doc__)
        sys.exit(1)

    IFACE=sys.argv[1]

    sniff(iface=IFACE, prn=packet_callback, filter="arp or icmp", store=0)
