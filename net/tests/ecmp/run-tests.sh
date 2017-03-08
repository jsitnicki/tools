#!/bin/bash

set -e

run_tests()
{
	local basedir=$(dirname "$0")

	trap "$basedir/teardown.sh \$?" EXIT
	$basedir/setup.sh
	$basedir/test-ping.sh
	$basedir/test-http.sh
}

run_tests
