# Cilium off-link LoadBalancer VIPs

Use this runbook to validate a Cilium-managed LoadBalancer VIP that lives outside the node VLAN. This is useful when Kubernetes nodes live on a broad LAN prefix, such as `10.137.0.0/16`, and Service VIPs in that same prefix are treated by the node kernel as directly connected/on-link addresses instead of routed BGP destinations.

The intended design is:

- node LAN: `10.137.0.0/16`
- routed Service VIP range: `10.138.0.0/24`
- Cilium LB IPAM allocates Service VIPs from the routed range
- Cilium BGP advertises selected LoadBalancer Services to the router
- Services that need client IP preservation use `externalTrafficPolicy: Local`

With this split, nodes route traffic for `10.138.0.0/24` toward the router instead of treating the VIP as local Ethernet. The router can then choose one of the Cilium BGP next hops that is actually advertising the VIP.

## Temporary end-to-end test workload

Apply this manifest to create an isolated test namespace, a one-IP Cilium pool, and a small HTTP echo Service at `10.138.0.253`.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cilium-vip-test
---
apiVersion: cilium.io/v2
kind: CiliumLoadBalancerIPPool
metadata:
  name: test-offlink-pool
spec:
  blocks:
    - cidr: 10.138.0.253/32
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vip-echo
  namespace: cilium-vip-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vip-echo
  template:
    metadata:
      labels:
        app: vip-echo
    spec:
      containers:
        - name: agnhost
          image: registry.k8s.io/e2e-test-images/agnhost:2.45
          args:
            - netexec
            - --http-port=8080
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: vip-echo
  namespace: cilium-vip-test
  labels:
    io.cilium/bgp-announce: "true"
  annotations:
    lbipam.cilium.io/ips: 10.138.0.253
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  loadBalancerIP: 10.138.0.253
  selector:
    app: vip-echo
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
```

Apply it with:

```bash
kubectl apply -f cilium-off-link-vip-test.yaml
```

## Validate allocation and endpoints

Confirm the Service received the requested VIP:

```bash
kubectl get svc -n cilium-vip-test vip-echo -o wide
```

Expected result:

```text
EXTERNAL-IP    PORT(S)
10.138.0.253   80:.../TCP
```

Confirm the backends and the nodes hosting them:

```bash
kubectl get endpointslice \
  -n cilium-vip-test \
  -l kubernetes.io/service-name=vip-echo \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]}{" node="}{.nodeName}{" ready="}{.conditions.ready}{"\n"}{end}'
```

## Validate router BGP state

On the router, the VIP should appear as a `/32` learned from Cilium BGP. When the echo Deployment has two replicas on two nodes, the router should show ECMP next hops for the nodes that have local endpoints.

Example expected router view:

```text
10.138.0.253/32
  ECMP
  BGP
  Next Hop 1: 10.137.0.12
  Next Hop 2: 10.137.0.16
```

The exact next hops depend on where Kubernetes scheduled the `vip-echo` pods. They should match the endpoint nodes from the previous step.

You can also inspect Cilium's advertised routes from a Cilium pod running on an endpoint node:

```bash
kubectl exec -n kube-system <cilium-pod> -- \
  cilium-dbg bgp routes advertised ipv4 unicast
```

Look for `10.138.0.253/32` with the node's `10.137.0.x` address as the next hop.

## Validate node route selection

The key difference between on-link and off-link VIPs is visible from the host-network routing table.

From a Cilium pod, compare route lookup for an old on-link VIP and the test off-link VIP:

```bash
kubectl exec -n kube-system <cilium-pod> -- ip route get 10.137.0.253
kubectl exec -n kube-system <cilium-pod> -- ip route get 10.138.0.253
```

Expected result for the on-link VIP:

```text
10.137.0.253 dev eno1 src 10.137.0.x
```

Expected result for the off-link VIP:

```text
10.138.0.253 via 10.137.0.1 dev eno1 src 10.137.0.x
```

This proves the node is routing `10.138.0.253` toward the router instead of treating it as directly connected Ethernet.

## Validate pod connectivity

From inside the cluster, run a temporary client pod:

```bash
kubectl run vip-test-client \
  --rm -i \
  --restart=Never \
  --image=curlimages/curl:8.8.0 \
  -- sh -lc 'ip route get 10.138.0.253; curl -fsS --connect-timeout 5 http://10.138.0.253/hostname; echo'
```

The `curl` response should be the name of one of the `vip-echo` pods.

To force the client onto a specific node, add a node selector override:

```bash
kubectl run vip-test-client-metal0 \
  --rm -i \
  --restart=Never \
  --image=curlimages/curl:8.8.0 \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"metal0"},"tolerations":[{"operator":"Exists"}]}}' \
  -- sh -lc 'ip route get 10.138.0.253; curl -fsS --connect-timeout 5 http://10.138.0.253/hostname; echo'
```

This verifies that pods on non-endpoint nodes can still reach the off-link VIP through the routed/BGP path.

## Validate client IP preservation

The test Service uses `externalTrafficPolicy: Local`, so the backend should see the real client IP.

From a LAN or remote client, open:

```text
http://10.138.0.253/clientip
```

The response should contain the client's real IP and source port:

```text
10.137.0.151:39169
```

A preserved source IP is a client address. A failed preservation check usually shows a node IP, router IP, or pod overlay IP instead.

For example, a successful LAN-host test from `10.137.0.151` returned:

```text
10.137.0.151:39169
```

That confirms the backend pod saw the original client address through the off-link Cilium BGP VIP.

## Cleanup

Remove the temporary workload and pool when testing is complete:

```bash
kubectl delete namespace cilium-vip-test
kubectl delete ciliumloadbalancerippool test-offlink-pool
```

## Migration note

If this test passes, move production Service VIPs from the node VLAN range to the routed range one service at a time. Keep kube-vip responsible for the Kubernetes API bootstrap VIP, and keep Cilium responsible for Service VIP allocation and BGP advertisement.

Start with a low-risk Service before moving critical DNS, cache, gateway, or game-server VIPs. Update firewall rules, DNS records, and application-level NAT or advertised-host settings alongside each Service IP change.
