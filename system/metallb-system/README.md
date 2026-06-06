# Dedicated VIP migration notes

These notes track the current direction for dedicated LAN VIPs after testing
both Cilium L2 and MetalLB-assisted approaches.

## Why this exists

Dedicated service VIPs such as:

- `10.137.0.227` Homebridge webhook
- `10.137.0.228` ClusterPlex PMS
- `10.137.0.229` LanCache
- `10.137.0.230` LanCache DNS forwarder
- `10.137.0.231` Neko WebRTC
- `10.137.0.248` Minecraft
- `10.137.0.249` Hermitcraft
- `10.137.0.250` Hytale
- `10.137.0.253` Pi-hole DNS

proved unstable with Cilium L2 when `externalTrafficPolicy=Local`, because the
L2 speaker can be elected on a node that does not host a local backend pod.

## Current tested state

- Cilium continues to own:
  - `10.137.0.226` (`public-gateway` + `gitea-ssh-lb` shared VIP)
- Cilium BGP is peered to all routable nodes:
  - `10.137.0.10` through `10.137.0.17`
- Cilium service VIP advertisements are selected by the Service label:
  - `io.cilium/bgp-announce: "true"`
- Cilium LB IPAM assigns direct VIPs using:
  - `lbipam.cilium.io/ips: <vip>`
- The cluster-wide `CiliumL2AnnouncementPolicy` has been removed for live
  BGP-only testing.

The legacy shared `cilium-ingress` service on `10.137.0.224` is no longer
needed once all HTTP exposure is handled by Gateway API and there are no live
`Ingress` resources.

## Current direct VIP status

- Converted to the Cilium BGP-only direct VIP pattern:
  - `10.137.0.227` Homebridge webhook
  - `10.137.0.228` ClusterPlex PMS
  - `10.137.0.231` Neko WebRTC
- Still pending migration away from MetalLB-backed direct VIP exposure:
  - `10.137.0.229` LanCache
  - `10.137.0.230` LanCache DNS forwarder
  - `10.137.0.248` Minecraft
  - `10.137.0.249` Hermitcraft
  - `10.137.0.250` Hytale
  - `10.137.0.253` Pi-hole DNS

## BGP-only tradeoffs observed so far

- The UDM Pro continues to learn `/32` VIP routes over BGP.
- Real client IP preservation works for tested workloads such as Neko and Plex
  when traffic reaches the correct backend node.
- Same-subnet clients may fail direct VIP access after L2 removal because they
  try to ARP for the VIP locally, while BGP only influences routed traffic.
- This means BGP-only behavior should be validated from routed clients and not
  judged solely by same-VLAN raw `curl` tests.

## Why MetalLB is still present

MetalLB still backs the remaining direct VIP services that have not yet been
migrated to the Cilium BGP-only pattern. It is no longer the preferred target
state for new direct VIP migrations unless a specific workload proves that
BGP-only Cilium is insufficient.

`gitea-ssh-lb` should remain on the Cilium gateway shared VIP (`10.137.0.226`).

## Follow-up implementation items

1. Decide whether the BGP-only tradeoff for same-subnet clients is acceptable,
   or whether a narrower L2 policy is still needed for specific VIPs.
2. Continue migrating remaining direct VIP services to the Cilium BGP-only
   pattern one service at a time.
3. Remove stale MetalLB-specific configuration from workloads that have already
   been migrated.
4. Keep Git/Argo/Ansible as the source of truth for any live networking state.
