#!/bin/bash
#
# Tests for setting VF's max TX rate using 'ip link'
#
# Author: Jakub Sitnicki <jkbs@redhat.com>
#

[[ $# -eq 2 ]] || {
	echo "Usage: $0 <dev> <vf>"
	exit 1
}

DEV=$1
VF=$2

#
# Filters for 'ip' output
#
# Example input:
# 3: ens2f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT qlen 1000
#     link/ether 90:e2:ba:20:cb:d8 brd ff:ff:ff:ff:ff:ff
#     vf 0 MAC 46:26:70:2b:ff:b7, tx rate 500 (Mbps), max_tx_rate 500Mbps, spoof checking on, link-state auto, trust off
#     vf 1 MAC e2:62:d1:ea:12:28, spoof checking on, link-state auto, trust off
#
filter_dev() {
	local dev=$1
	ip link show dev $dev
}

filter_vf() {
	local vf=$1
	perl -slane '/^\s+vf $vf/ and print;' -- -vf=$vf
}

filter_vf_tx_rate() {
	perl -lane '/tx rate (\d+) \(Mbps\)/ and print $1;'
}

filter_vf_max_tx_rate() {
	perl -lane '/max_tx_rate (\d+)Mbps/ and print $1;'
}

#
# Getters for VF's attributes
#
get_tx_rate() {
	local dev=$1 vf=$2
	filter_dev $dev | filter_vf $vf | filter_vf_tx_rate
}

get_max_tx_rate() {
	local dev=$1 vf=$2
	filter_dev $dev | filter_vf $vf | filter_vf_max_tx_rate
}

#
# Asserts
#
assert_tx_rate_is_not_set() {
	local dev=$1 vf=$2
	[[ -z $(get_tx_rate $dev $vf) ]] || exit 1
}

assert_max_tx_rate_is_not_set() {
	local dev=$1 vf=$2
	[[ -z $(get_max_tx_rate $dev $vf) ]] || exit 1
}

#
# Common setup & teardown routines for tests
#
reset_tx_rate_limits() {
	local dev=$1 vf=$2

	ip link set dev $dev vf $vf rate 0
	ip link set dev $dev vf $vf max_tx_rate 0

	assert_tx_rate_is_not_set $dev $vf
	assert_max_tx_rate_is_not_set $dev $vf
}

setup() {
	reset_tx_rate_limits $DEV $VF
}

teardown() {
	reset_tx_rate_limits $DEV $VF
}

#
# Tests
#
test_init_max_tx_rate() {
	setup

	ip link set dev $DEV vf $VF max_tx_rate 700
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_max_tx_rate $DEV $VF) -eq 700 ]] || exit 1

	teardown
}

test_change_max_tx_rate() {
	setup

	ip link set dev $DEV vf $VF max_tx_rate 700
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_max_tx_rate $DEV $VF) -eq 700 ]] || exit 1

	ip link set dev $DEV vf $VF max_tx_rate 500
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_max_tx_rate $DEV $VF) -eq 500 ]] || exit 1

	teardown
}

test_init_tx_rate() {
	setup

	ip link set dev $DEV vf $VF rate 300
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_tx_rate $DEV $VF) -eq 300 ]] || exit 1

	teardown
}

test_change_tx_rate() {
	setup

	ip link set dev $DEV vf $VF rate 800
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_tx_rate $DEV $VF) -eq 800 ]] || exit 1

	ip link set dev $DEV vf $VF rate 400
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_tx_rate $DEV $VF) -eq 400 ]] || exit 1

	teardown
}

test_setting_tx_rate_sets_max_tx_rate() {
	setup

	ip link set dev $DEV vf $VF rate 300
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_tx_rate $DEV $VF) -eq 300 ]] || exit 1
	[[ $(get_max_tx_rate $DEV $VF) -eq 300 ]] || exit 1

	teardown
}

test_setting_max_tx_rate_sets_tx_rate() {
	setup

	ip link set dev $DEV vf $VF max_tx_rate 600
	[[ $? -eq 0 ]] || exit 1
	[[ $(get_tx_rate $DEV $VF) -eq 600 ]] || exit 1
	[[ $(get_max_tx_rate $DEV $VF) -eq 600 ]] || exit 1

	teardown
}

#
# Test case
#
run_tests() {
	test_init_max_tx_rate
	test_change_max_tx_rate
	test_init_tx_rate
	test_change_tx_rate
	test_setting_tx_rate_sets_max_tx_rate
	test_setting_max_tx_rate_sets_tx_rate
}

run_tests
