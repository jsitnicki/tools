#!/usr/bin/env python
#
# https://stackoverflow.com/a/49592515
#
"""
Usage: decode-bitflags.py <NUMBER>

Print indices of set bit flags.
"""

import sys

if len(sys.argv) != 2:
    print(__doc__)
    sys.exit(1)

flags = sys.argv[1]
flags = int(flags, base=0)
flags = bin(flags)[2:]

print(flags, end="\n\n")

list(
    map(
        lambda p: print(p[0]),
        filter(lambda p: bool(int(p[1])), enumerate(reversed(flags))),
    )
)
