#!/bin/bash
#
# Checks:
# - did HTTP GET succeed?
# - were there any misrouted PTBs?
#

set -o errexit

basedir=$(dirname "$0")

. $basedir/vars.sh
. $basedir/funcs.sh

nft_add_counters_v4()
{
	local netns=$1
	local frag_needed=4

	$netns nft add   table ip test_http_v4
	$netns nft add   chain ip test_http_v4 incoming { type filter hook input priority 0 \; }
	$netns nft flush chain ip test_http_v4 incoming # might have already existed...
	$netns nft add   rule  ip test_http_v4 incoming icmp type destination-unreachable icmp code $frag_needed counter
}

nft_del_counters_v4()
{
	local netns=$1

	$netns nft delete table ip test_http_v4
}

nft_get_icmp_pkt_count_v4()
{
	local netns=$1
	local frag_needed=4
	local rule_filter="icmp type destination-unreachable icmp code $frag_needed"

	$netns nft -nnn list chain ip test_http_v4 incoming | \
		sed -n "/$rule_filter/{s/.*counter packets \([0-9]\+\).*/\1/;p}"
}

test_http_v4()
{
	log "Testing HTTP over IPv4"

	nft_add_counters_v4 Fd
	nft_add_counters_v4 Fe

	Fd $basedir/toy-httpd.py -4 >/dev/null 2>&1 &
	Fe $basedir/toy-httpd.py -4 >/dev/null 2>&1 &
	sleep 1

	byte_count=$(A curl --max-time 1 --silent "http://$FF4:8080/?bytes=1400" | wc -c)
	[[ $byte_count == 1400 ]] || msg_err "Expected 1400 bytes, received $byte_count"

	ip netns pids Fd | xargs kill
	ip netns pids Fe | xargs kill

	icmp_count_Fd=$(nft_get_icmp_pkt_count_v4 Fd)
	icmp_count_Fe=$(nft_get_icmp_pkt_count_v4 Fe)
	icmp_total=$((icmp_count_Fd + icmp_count_Fe))
	[[ $icmp_total == 1 ]] || msg_err "Expected one ICMPv4 PTB, received $icmp_total"

	nft_del_counters_v4 Fd
	nft_del_counters_v4 Fe
}

nft_add_counters_v6()
{
	local netns=$1

	$netns nft add   table ip6 test_http_v6
	$netns nft add   chain ip6 test_http_v6 incoming { type filter hook input priority 0 \; }
	$netns nft flush chain ip6 test_http_v6 incoming
	$netns nft add   rule  ip6 test_http_v6 incoming icmpv6 type packet-too-big counter
}

nft_del_counters_v6()
{
	local netns=$1

	$netns nft delete table ip6 test_http_v6
}

nft_get_icmp_pkt_count_v6()
{
	local netns=$1
	local rule_filter="icmpv6 type packet-too-big"

	$netns nft -nnn list chain ip6 test_http_v6 incoming | \
		sed -n "/$rule_filter/{s/.*counter packets \([0-9]\+\).*/\1/;p}"
}

test_http_v6()
{
	log "Testing HTTP over IPv6"

	nft_add_counters_v6 Fd
	nft_add_counters_v6 Fe

	Fd $basedir/toy-httpd.py -6 >/dev/null 2>&1 &
	Fe $basedir/toy-httpd.py -6 >/dev/null 2>&1 &
	sleep 1

	byte_count=$(A curl --max-time 1 --silent "http://[$FF6]:8080/?bytes=1400" | wc -c)
	[[ $byte_count == 1400 ]] || msg_err "Expected 1400 bytes, received $byte_count"

	ip netns pids Fd | xargs kill
	ip netns pids Fe | xargs kill

	icmp_count_Fd=$(nft_get_icmp_pkt_count_v6 Fd)
	icmp_count_Fe=$(nft_get_icmp_pkt_count_v6 Fe)
	icmp_total=$((icmp_count_Fd + icmp_count_Fe))
	[[ $icmp_total == 1 ]] || msg_err "Expected one ICMPv6 PTB, received $icmp_total"

	nft_del_counters_v6 Fd
	nft_del_counters_v6 Fe
}

test_http()
{
	test_http_v4
	test_http_v6
}

test_http
