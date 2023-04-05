#!/bin/bash
#
# Usage:
#
#   vm.sh <script opts> -- <virtme opts>
#
# Script ops:
#
#  -c #   Number of vCPUs
# 


prog=$(basename $0)
base_dir=$(dirname $(realpath $0))

kern_dir=$PWD

opt_ncpu=4
opt_net=0

while getopts c:n opt
do
        case $opt in
        c) opt_ncpu=$OPTARG ;;
	n) opt_net=1 ;;
        esac
done
shift $(( OPTIND - 1 ))

echo 2>&1 "${prog}: Booting kernel from ${kern_dir}..."

args_net=
if (( opt_net )); then
	args_net="-netdev type=tap,id=guest0,ifname=tap0,script=no,downscript=no,vhost=on -device virtio-net-pci,netdev=guest0"
fi

# To enable gdb stub:
# -gdb tcp:127.0.0.1:1234

exec virtme-run \
     --show-command \
     --show-boot-console \
     --kdir ${kern_dir} \
     $(: --rwdir ${base_dir}/guest) \
     $(: --rwdir ${base_dir}/tests) \
     --pwd \
     --mods=use \
     "$@" \
     --kopt 'panic=-1'            `# reboot after panic` \
     --qemu-opts                  `# QEMU options follow` \
     -m 4G \
     -smp ${opt_ncpu} \
     -no-reboot                   `# exit on guest reboot` \
     -gdb tcp::1234 \
     ${args_net}

