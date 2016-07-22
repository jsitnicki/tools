#!/bin/bash
#
# Tests for setting L2 address using 'ip link'
#
# Assumes we are dealing with an Ethernet device.
#
# Author: Jakub Sitnicki <jkbs@redhat.com>
#

[[ $# -eq 1 ]] || {
	echo "Usage: $0 <dev>"
	exit 1
}

DEV=$1

#
# Filters for 'ip' output
#
filter_dev() {
	local dev=$1
	ip link show dev $dev
}

filter_lladdr() {
	perl -lane '/link\/ether ([a-f0-9]{2}(:[a-f0-9]{2}){5})/ and print $1;'
}

#
# Getters for device's L2 attributes
#
get_lladdr() {
	local dev=$1
	filter_dev $dev | filter_lladdr
}

#
# Tests
#
test_set_too_short_lladdr() {
	2>/dev/null ip link set dev $DEV addr aa
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV addr aa:bb
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV addr aa:bb:cc
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV addr aa:bb:cc
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV addr aa:bb:cc:dd
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV addr aa:bb:cc:dd:ee
	[[ $? -eq 1 ]] || exit 1
}

test_set_too_long_lladdr() {
	2>/dev/null ip link set dev $DEV addr aa:bb:cc:dd:ee:ff:11
	[[ $? -eq 1 ]] || exit 1

	2>/dev/null ip link set dev $DEV addr aa:bb:cc:dd:ee:ff:11:22
	[[ $? -eq 1 ]] || exit 1
}

test_set_correct_length_lladdr() {
	ip link set dev $DEV addr 32:26:87:18:04:bd
	[[ $? -eq 0 ]] || exit 1
	[[ "$(get_lladdr $DEV)" = "32:26:87:18:04:bd" ]] || exit 1

	ip link set dev $DEV addr 4a:0b:ed:4d:93:3f
	[[ $? -eq 0 ]] || exit 1
	[[ "$(get_lladdr $DEV)" = "4a:0b:ed:4d:93:3f" ]] || exit 1
}

#
# Test case
#
run_tests() {
	test_set_too_short_lladdr
	test_set_too_long_lladdr
	test_set_correct_length_lladdr
}

run_tests

