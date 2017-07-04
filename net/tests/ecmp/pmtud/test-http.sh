#!/bin/bash
#
# Checks:
# - did HTTP GET succeed?
# - were there any misrouted PTBs?
#

set -o errexit

basedir=$(dirname "$0")

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

nft_get_icmp_ptb_count_v4()
{
	local netns=$1
	local frag_needed=4
	local rule_filter="icmp type destination-unreachable icmp code $frag_needed"

	$netns nft -nnn list chain ip test_http_v4 incoming | \
		sed -n "/$rule_filter/{s/.*counter packets \([0-9]\+\).*/\1/;p}"
}

test_http_v4()
{
	local ns ptb_count ptb_total

	log "Testing HTTP over IPv4"

	for ns in S{1..9}; do
		nft_add_counters_v4 $ns
		$ns $basedir/toy-httpd.py -4 >/dev/null 2>&1 &
	done
	sleep 1

	byte_count=$(C1 curl --max-time 1 --silent "http://10.2.0.2:8080/?bytes=1400" | wc -c)
	(( byte_count == 1400 )) || msg_err "Expected 1400 bytes, received $byte_count"

	ptb_total=0
	for ns in S{1..9}; do
		ip netns pids $ns | xargs kill
		ptb_count=$(nft_get_icmp_ptb_count_v4 $ns)
		ptb_total=$((ptb_total+ptb_count))
	done
	(( ptb_total <= 1 )) || msg_err "Expected at most one ICMPv4 PTB, received $ptb_total"

	for ns in S{1..9}; do
		nft_del_counters_v4 $ns
	done
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

nft_get_icmp_ptb_count_v6()
{
	local netns=$1
	local rule_filter="icmpv6 type packet-too-big"

	$netns nft -nnn list chain ip6 test_http_v6 incoming | \
		sed -n "/$rule_filter/{s/.*counter packets \([0-9]\+\).*/\1/;p}"
}

test_http_v6()
{
	local ns ptb_count ptb_total

	log "Testing HTTP over IPv6"

	for ns in S{1..9}; do
		nft_add_counters_v6 $ns
		$ns $basedir/toy-httpd.py -6 >/dev/null 2>&1 &
	done
	sleep 1

	byte_count=$(C1 curl --max-time 1 --silent "http://[fd00:2:0::2]:8080/?bytes=1400" | wc -c)
	(( byte_count == 1400 )) || msg_err "Expected 1400 bytes, received $byte_count"

	ptb_total=0
	for ns in S{1..9}; do
		ip netns pids $ns | xargs kill
		ptb_count=$(nft_get_icmp_ptb_count_v6 $ns)
		ptb_total=$((ptb_total+ptb_count))
	done
	(( ptb_total <= 1 )) || msg_err "Expected at most one ICMPv6 PTB, received $ptb_total"

	for ns in S{1..9}; do
		nft_del_counters_v6 $ns
	done
}

test_http()
{
	test_http_v4
	test_http_v6
}

test_http
