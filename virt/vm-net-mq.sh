#!/bin/sh
#
# Multiqueue is not documented in qemu man page. See instead:
# https://fedoraproject.org/wiki/Features/MQ_virtio_net
#
# Using tap devices requires root priviledges.
#

VIRTME_DEFAULT_OPTS="--installed-kernel --pwd"

if [[ $# == 0 ]]; then
  set -- $VIRTME_DEFAULT_OPTS
fi

exec virtme-run "$@" \
     --qemu-opts \
     -m 4G -smp 4 \
     -netdev tap,id=nic0,script=no,downscript=no,queues=4 \
     -device virtio-net-pci,netdev=nic0,mq=on
