#!/usr/bin/awk -f
#
# Prints a histogram for the distribution of port bindings among chassis.
# Expects output of 'ovn-sbctl show' as input.
#
# Usage:
#   port-binding-hist.awk [FILE]
#     or
#   awk [-o bs=M] [-o bw=N] -f port-binding-hist.awk [FILE]
#
# Options:
#   bs=M  - Set histogram bucket size to M (integer, default 5)
#   bw=N  - Set maxium bar width to N characters (default 72)
#

function print_bar(lower, upper, value, max_value, max_width,
		   line, bar_width, i)
{
    line = sprintf("[%3d,%3d] |", lower, upper)
    bar_width = int(max_width * value / max_value)
    for (i = 0; i < bar_width; i++)
	line = line "="
    for (i = 0; i < max_width - bar_width; i++)
	line = line " "
    line = line "| " int(value)
    print line
}

function end_of_chassis(i)
{
    i = int(port_count / bucket_size)
    hist[i]++
    if (i > max_bucket)
	max_bucket = i
}

BEGIN {
    max_bucket = 0
    bucket_size = bs ? bs : 5;
    hist_width = bw ? bw : 72;
}

NR > 1 && $1 == "Chassis" {
	end_of_chassis()
}

END {
	end_of_chassis()
}

$1 == "Chassis" {
    port_count = 0
}

$1 == "Port_Binding" {
    port_count++
}

END {
    # Find histograms maximum
    max_value = 0
    for (i = 0; i <= max_bucket; i++) {
	if (max_value < hist[i])
	    max_value = hist[i]
    }

    for (i = 0; i <= max_bucket; i++) {
	lower = i * bucket_size
	upper = lower + bucket_size - 1
	print_bar(lower, upper, hist[i], max_value, hist_width)
    }
}
