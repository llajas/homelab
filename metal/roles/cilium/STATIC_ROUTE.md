# Cilium Migration - Static Route Configuration

## UDM-Pro Static Route Requirement

**CRITICAL**: Before deploying Cilium with the temporary LB pool, configure this static route on the UDM-Pro:

```
Destination Network: 10.137.1.0/28
Next Hop: 10.137.0.10 (metal0 - primary cluster node)
Interface: Node VLAN / Cluster VLAN
```

### Configuration Steps (UDM-Pro UI):
1. Navigate to: Settings → Routing & Firewall → Static Routes
2. Add new static route:
   - **Name**: Cilium Temporary Pool
   - **Destination**: 10.137.1.0/28
   - **Next Hop**: 10.137.0.10
   - **Interface**: (Select the VLAN where cluster nodes reside)
3. Save and apply

### Verification:
```bash
# From any node on the network, test reachability to the temporary pool
ping 10.137.1.1

# Check routing table on UDM-Pro (if SSH access available)
ip route show | grep 10.137.1.0
```

### Post-Cutover Cleanup:
This static route will be **removed** after Task 7 completes (when Cilium BGP takes over the final pool 10.137.0.224/27).

## Temporary Pool Details:
- **CIDR**: 10.137.1.0/28
- **Usable IPs**: 10.137.1.1 - 10.137.1.14 (14 addresses)
- **Purpose**: Testing Cilium LB functionality before final MetalLB handoff
- **Duration**: Wave 1-3 (until final BGP cutover in Wave 4)
