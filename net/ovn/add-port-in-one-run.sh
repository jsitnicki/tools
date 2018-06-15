#!/bin/bash
#
# Proof of concept for creating a port & ACLs in one invocation of ovn-nbctl.
# The motivation is to amortize the cost of fetching the NB DB contents when
# ovn-nbctl over several operations, thus reducing the total latency.
#

# Use GNU time, not Bash built-in
TIME=$(which time)

# Static addressing & address sets
# --------------------------------
#
# 1. Create two switches S1, S2.
# 2. Create an address set for a project A1.
# 3. Create port P1 on switch S1 that belongs to project A1.
# 4. Create port P2 on switch S2 that belongs to project A1.
#

ovn-nbctl \
  -- ls-add S1 \
  -- ls-add S2

# First port in project
$TIME -f "P1 %E" \
      ovn-nbctl \
      `# Create address set for the project (first Pod only)` \
      -- create Address_Set name=A1 \
      `# Create port` \
      -- lsp-add S1 P1 \
      -- lsp-set-addresses P1 "02:00:00:00:00:01 10.0.1.2" \
      -- add Address_Set A1 addresses "10.0.1.2" \
      -- acl-add S1 to-lport 1001 'outport == "P1" && ip4.src == $A1' 'allow' \
      -- acl-add S1 to-lport 1000 'outport == "P1"' 'drop'

# Subsequent ports
$TIME -f "P2 %E" \
      ovn-nbctl \
      `# Create port` \
      -- lsp-add S2 P2 \
      -- lsp-set-addresses P2 "02:00:00:00:00:02 10.0.2.2" \
      -- add Address_Set A1 addresses "10.0.2.2" \
      -- acl-add S2 to-lport 1001 'outport == "P2" && ip4.src == $A1' 'allow' \
      -- acl-add S2 to-lport 1000 'outport == "P2"' 'drop'


# Dynamic addressing & port groups (PoC)
# --------------------------------------
#
# 1. Create two switches S3, S4 and configure IPAM.
# 2. Create a port group for a project G1.
# 3. Create port P3 that belongs to project G1 on switch S3.
# 4. Create port P4 that belongs to project G1 on switch S4.
#
# Fixes needed:
# - Allow using Port Group name as its identifier for DB ops
# - Populate Port Group automatic Address Sets with addresses from IPAM
#

ovn-nbctl \
  -- ls-add S3 \
  -- add Logical_Switch S3 other_config subnet=10.0.3.0/24 \
  -- ls-add S4 \
  -- add Logical_Switch S4 other_config subnet=10.0.4.0/24

# First port in project
$TIME -f "P3 %E" \
      ovn-nbctl \
      `# Create port group and ACLs for the project (first Pod only)` \
      -- create Port_Group name=G1 \
      -- --type=port-group acl-add G1 to-lport 1001 'outport == @G1 && ip4.src == $G1_ip4' 'allow' \
      -- --type=port-group acl-add G1 to-lport 1000 'outport == @G1' 'drop' \
      `# Create port` \
      -- lsp-add S3 P3 \
      -- lsp-set-addresses P3 'dynamic' \
      -- --id=@p get Logical_Switch_Port P3 \
      -- add Port_Group G1 ports @p

# Subsequent ports
$TIME -f "P4 %E" \
      ovn-nbctl \
      `# Create port` \
      -- lsp-add S4 P4 \
      -- lsp-set-addresses P4 'dynamic' \
      -- --id=@p get Logical_Switch_Port P4 \
      -- add Port_Group G1 ports @p
