#!/bin/bash
#
# Demonstrate when full logical flow processing is taking place. This can be
# used to check if incremental flow processing is working as expected.
#
# The script counts calls to lflow_run() on each hypervisor (chassis) for
# typical operations (e.g. create switch, create port, create addres set, etc.).
#

set -e

header() {
	printf "Counting calls to lflow_run() for each operation...\n"
	printf "\n"
	printf "%3s  %3s  %s\n" "HV1" "HV2" "COMMAND"
	printf "%3s  %3s  %s\n" "---" "---" "-------"
}

group() {
	printf "\n"
	printf "%3s  %3s  %s\n" "" "" "# $*"
}

C() {
	local a1= a2= b1= b2= c1= c2=

	b1=$(as hv1 ovs-appctl -t ovn-controller coverage/read-count lflow_run)
	b2=$(as hv2 ovs-appctl -t ovn-controller coverage/read-count lflow_run)

	"$@" > /dev/null

	a1=$(as hv1 ovs-appctl -t ovn-controller coverage/read-count lflow_run)
	a2=$(as hv2 ovs-appctl -t ovn-controller coverage/read-count lflow_run)
	c1=$((a1-b1))
	c2=$((a2-b2))

	if [[ $c1 > 0 || $c2 > 0 ]]; then
		printf "%3d  %3d  %s\n" $c1 $c2 "$*"
	else
		printf "%3s  %3s  %s\n" " " " " "$*"
	fi
}

ovn_start
net_add n1
for i in 1 2; do
	hv=hv$i

	sim_add $hv
	as $hv

	ovs-vsctl add-br br-phys
	ovn_attach n1 br-phys 192.168.0.$i
	ovs-appctl -t ovn-controller vlog/set dbg
done
as main

header
group Add router lr1
C ovn-nbctl lr-add lr1

for i in 1 2; do
	ls=ls$i
	lsp=$ls-lr1

	group Add switch $ls
	C ovn-nbctl --wait=hv ls-add $ls
	C ovn-nbctl --wait=hv add Logical_Switch $ls other_config subnet="10.0.$i.0/24"

	group Add router port to $ls
	C ovn-nbctl --wait=hv lrp-add lr1 lr1-$ls 02:00:00:00:0$i:01 10.0.$i.1/24
	C ovn-nbctl --wait=hv lsp-add $ls $lsp
	C ovn-nbctl --wait=hv lsp-set-type $lsp router
	C ovn-nbctl --wait=hv lsp-set-addresses $lsp router
done

for i in 1 2; do
	as=as$i
	ls=ls$i
	lp=lp$i
	vif=vif$i
	hv=hv$i

	group Add port $lp
	C ovn-nbctl --wait=hv lsp-add $ls $lp
	# C ovn-nbctl --wait=hv lsp-set-port-security lp1 "02:00:00:00:00:01 10.0.0.1"
	C ovn-nbctl --wait=hv lsp-set-addresses $lp "dynamic"
	C ovn-nbctl --wait=hv wait-until Logical_Switch_Port $lp 'dynamic_addresses!=[]'
	C ovn-nbctl --wait=hv get Logical_Switch_Port $lp dynamic_addresses

	group Add address set $as
	C ovn-nbctl --wait=hv create Address_Set name="$as"
	C ovn-nbctl --wait=hv add Address_Set "$as" addresses "10.0.$i.10"

	group Add ACLs for port $lp
	C ovn-nbctl --wait=hv acl-add $ls to-lport 1001 "outport == \"$lp\" && ip4.src == \$$as" allow
	C ovn-nbctl --wait=hv acl-add $ls to-lport 1000 "outport == \"$lp\"" drop

	group Bind port $lp
	C as $hv ovs-vsctl add-port br-int $vif -- set Interface $vif external-ids:iface-id=$lp

	group Wait for port $lp
	C ovn-nbctl --wait=hv wait-until Logical_Switch_Port $lp 'up=true'
done

# (TODO) 5. Trigger packet in

# Check state after setup
# echo "*** AFTER SETUP ***"
# ovn-nbctl show
# ovn-sbctl show

for i in 1 2; do
	as=as$i
	ls=ls$i
	lp=lp$i

	group Delete port $lp
	C ovn-nbctl --wait=hv lsp-del $lp

	group Delete ACLs for port $lp
	C ovn-nbctl --wait=hv acl-del $ls to-lport 1001 "outport == \"$lp\" && ip4.src == \$$as"
	C ovn-nbctl --wait=hv acl-del $ls to-lport 1000 "outport == \"$lp\""

	group Delete address set $as
	C ovn-nbctl --wait=hv remove Address_Set "$as" addresses "10.0.$i.10"
	C ovn-nbctl --wait=hv destroy Address_Set "$as"
done

for i in 1 2; do
	ls=ls$i

	group Delete switch $ls
	C ovn-nbctl ls-del $ls
done

group Delete router lr1
C ovn-nbctl lr-del lr1

# Check state after teardown
# echo "*** AFTER SETUP ***"
# ovn-nbctl show
# ovn-sbctl show

set +e
