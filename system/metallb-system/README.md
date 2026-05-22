# MetalLB hybrid migration notes

This component is the foundation for moving dedicated service VIPs away from
`CiliumL2AnnouncementPolicy` while keeping Cilium responsible for Gateway API
 and general cluster networking.

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

have proven unstable with Cilium L2 when `externalTrafficPolicy=Local`, because
the L2 speaker can be elected on a node that does not host a local backend pod.

## Current safe state

- Cilium continues to own:
  - `10.137.0.226` (`public-gateway` + `gitea-ssh-lb` shared VIP)
- Direct dedicated-IP services remain on Cilium for now, but with
  `externalTrafficPolicy=Cluster` where needed to maintain reachability.
- MetalLB is introduced with a dedicated `loadBalancerClass` (`metallb`) so it
  can coexist safely with Cilium.

The legacy shared `cilium-ingress` service on `10.137.0.224` is no longer
needed once all HTTP exposure is handled by Gateway API and there are no live
`Ingress` resources.

## Prerequisite before cutting services over to MetalLB BGP

To preserve *real* client IPs with `externalTrafficPolicy=Local`, the upstream
router must peer with every node that may advertise a service VIP.

Today the UDM Pro only peers with the control-plane nodes:

- `10.137.0.10`
- `10.137.0.11`
- `10.137.0.12`

That is not sufficient for services that can run on other nodes (for example
`clusterplex-pms` currently runs on `virtual0` / `virtual1`).

### Target router peer set for a no-pinning design

- `10.137.0.10`
- `10.137.0.11`
- `10.137.0.12`
- `10.137.0.13`
- `10.137.0.14`
- `10.137.0.15`
- `10.137.0.16`
- `10.137.0.17`

## Planned first-wave service migration after router prerequisite is met

Services to move to `spec.loadBalancerClass: metallb` first:

- `apps/pihole` DNS VIP `10.137.0.253`
- `apps/clusterplex` PMS VIP `10.137.0.228`
- `apps/homebridge` webhook VIP `10.137.0.227`
- `apps/lancache` VIP `10.137.0.229`
- `apps/lancache-dns-forwarder` VIP `10.137.0.230`
- `apps/neko` VIP `10.137.0.231`
- `apps/minecraft` VIP `10.137.0.248`
- `apps/hermitcraft` shared VIP `10.137.0.249`
- `apps/hytale` VIP `10.137.0.250`

`gitea-ssh-lb` should remain on the Cilium gateway shared VIP (`10.137.0.226`).

## Follow-up implementation items

1. Add MetalLB BGP CRs (`BGPPeer`, `IPAddressPool`, `BGPAdvertisement`) once the
   router peers are expanded.
2. Migrate the first-wave direct VIP services to `loadBalancerClass: metallb`.
3. Remove Cilium-specific LB IPAM annotations from migrated services.
4. Narrow the Cilium LB IPAM pool to the remaining Cilium-owned VIPs if desired.
