##!/bin/bash
#
# Tests for setting VF's MAC address using 'ip link'
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
filter_dev() {
	local dev=$1
	ip link show dev $dev
}

filter_vf() {
	local vf=$1
	perl -slane '/^\s+vf $vf/ and print;' -- -vf=$vf
}

filter_vf_mac() {
	perl -lane '/MAC ([a-f0-9]{2}(:[a-f0-9]{2}){5})/ and print $1;'
}

#
# Getters for VF's attributes
#
get_vf_mac() {
	local dev=$1 vf=$2
	filter_dev $dev | filter_vf $vf | filter_vf_mac
}

#
# Tests
#
test_set_too_short_mac() {
	2>/dev/null ip link set dev $DEV vf $VF mac aa
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV vf $VF mac aa:bb
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV vf $VF mac aa:bb:cc
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV vf $VF mac aa:bb:cc
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV vf $VF mac aa:bb:cc:dd
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV vf $VF mac aa:bb:cc:dd:ee
	[[ $? -eq 1 ]] || exit 1
}

test_set_too_long_mac() {
	2>/dev/null ip link set dev $DEV vf $VF mac aa:bb:cc:dd:ee:ff:11
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV vf $VF mac aa:bb:cc:dd:ee:ff:11:22
	[[ $? -eq 1 ]] || exit 1
}

test_set_correct_length_mac() {
	ip link set dev $DEV vf $VF mac 32:26:87:18:04:bd
	[[ $? -eq 0 ]] || exit 1
	[[ "$(get_vf_mac $DEV $VF)" = "32:26:87:18:04:bd" ]] || exit 1

	ip link set dev $DEV vf $VF mac 4a:0b:ed:4d:93:3f
	[[ $? -eq 0 ]] || exit 1
	[[ "$(get_vf_mac $DEV $VF)" = "4a:0b:ed:4d:93:3f" ]] || exit 1
}

#
# Test case
#
run_tests() {
	test_set_too_short_mac
	test_set_too_long_mac
	test_set_correct_length_mac
}

run_tests
