#!/bin/bash -x
#
# IPsec tunnel between namespace A (10.0.0.1) and C (172.16.0.1)
# carrying overlay traffic 192.0.2.0/24.
#
# Equivalent of overlay-gre4.sh but using xfrm (ESP tunnel mode).
#

# B must forward ESP packets between A and C
ip netns exec B sysctl -qw net.ipv4.ip_forward=1

# Overlay addresses (on loopback, routed via xfrm policy)
ip -n A addr add 192.0.2.1/32 dev lo
ip -n C addr add 192.0.2.2/32 dev lo

# Routes to remote overlay — ensures correct src addr for xfrm policy match
ip -n A route add 192.0.2.2/32 via 10.0.0.2 src 192.0.2.1
ip -n C route add 192.0.2.1/32 via 172.16.0.2 src 192.0.2.2

# Keying material (demo only — static keys, AES-GCM-128)
KEY_A_C=0x$(printf '01%.0s' {1..20})  # 20 bytes = 16 key + 4 salt
KEY_C_A=0x$(printf '02%.0s' {1..20})
SPI_A_C=0x1000
SPI_C_A=0x2000

# --- xfrm state (SA) ---

# A → C
ip -n A xfrm state add \
   src 10.0.0.1 dst 172.16.0.1 \
   proto esp spi $SPI_A_C \
   mode tunnel \
   aead 'rfc4106(gcm(aes))' $KEY_A_C 128

ip -n C xfrm state add \
   src 10.0.0.1 dst 172.16.0.1 \
   proto esp spi $SPI_A_C \
   mode tunnel \
   aead 'rfc4106(gcm(aes))' $KEY_A_C 128

# C → A
ip -n C xfrm state add \
   src 172.16.0.1 dst 10.0.0.1 \
   proto esp spi $SPI_C_A \
   mode tunnel \
   aead 'rfc4106(gcm(aes))' $KEY_C_A 128

ip -n A xfrm state add \
   src 172.16.0.1 dst 10.0.0.1 \
   proto esp spi $SPI_C_A \
   mode tunnel \
   aead 'rfc4106(gcm(aes))' $KEY_C_A 128

# --- xfrm policy ---

# A: outbound overlay → tunnel
ip -n A xfrm policy add \
   dir out src 192.0.2.1/24 dst 192.0.2.2/24 \
   tmpl src 10.0.0.1 dst 172.16.0.1 \
         proto esp mode tunnel

# A: inbound tunnel → overlay
ip -n A xfrm policy add \
   dir in src 192.0.2.2/24 dst 192.0.2.1/24 \
   tmpl src 172.16.0.1 dst 10.0.0.1 \
         proto esp mode tunnel

# C: outbound overlay → tunnel
ip -n C xfrm policy add \
   dir out src 192.0.2.2/24 dst 192.0.2.1/24 \
   tmpl src 172.16.0.1 dst 10.0.0.1 \
         proto esp mode tunnel

# C: inbound tunnel → overlay
ip -n C xfrm policy add \
   dir in src 192.0.2.1/24 dst 192.0.2.2/24 \
   tmpl src 10.0.0.1 dst 172.16.0.1 \
         proto esp mode tunnel
