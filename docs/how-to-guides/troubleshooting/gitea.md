# Gitea

## Changing the `gitea_admin` password

!!! tip
    Spawn a shell into the Gitea pod, on the `gitea` container specifically such as thus:
    ```sh
    ❯ kc -n gitea exec -it gitea-7ccf4c587f-72tr2 -- /bin/sh
    Defaulted container "gitea" out of: gitea, init-directories (init), init-app-ini (init), configure-gitea (init)
    /var/lib/gitea $ gitea admin user change-password -u gitea_admin -p 'yourNewPassword'
    /var/lib/gitea $
    ```

## Gitea Doctor (Redis DB)

!!! tip
    As before, spawn a shell into the Gitea pod.
    ```sh
    ❯ kc -n gitea exec -it gitea-7ccf4c587f-72tr2 -- /bin/sh
    Defaulted container "gitea" out of: gitea, init-directories (init), init-app-ini (init), configure-gitea (init)
    /var/lib/gitea $ gitea doctor check

    [1] Check paths and basic configuration
     - [I] Configuration File Path:    "/data/gitea/conf/app.ini"
     - [I] Repository Root Path:       "/data/git/gitea-repositories"
     - [I] Data Root Path:             "/data"
     - [I] Custom File Root Path:      "/data/gitea"
     - [I] Work directory:             "/data"
     - [I] Log Root Path:              "/data/log"
    OK

    [2] Check Database Version
     - [I] Expected database version: 280
    OK

    [3] Check if user with wrong type exist
    OK

    [4] Check if OpenSSH authorized_keys file is up-to-date
    OK

    [5] Synchronize repo HEADs
     - [I] All 1 repos have their HEADs in the correct state
    OK

    All done.
    /var/lib/gitea $
    ```

## Valkey cluster outage caused by stale node addresses

### Symptoms and impact

Gitea authentication can fail when the Valkey cluster used for session storage is
down. The Gitea logs may contain:

```text
SignIn: CLUSTERDOWN The cluster is down
session(release): CLUSTERDOWN The cluster is down
```

OAuth login through Dex and other operations that require Gitea's session backend
will fail. Gitea may panic while releasing or accessing the session:

```text
PANIC: session(release): CLUSTERDOWN The cluster is down
```

Git HTTP traffic may remain partially available. For example, an unauthenticated
repository discovery request may still succeed:

```text
GET /ops/homelab/info/refs?service=git-upload-pack
200 OK
```

This combination indicates a session-store failure rather than complete Gitea
application unavailability.

### Valkey topology

The Gitea Valkey deployment has six cluster members:

```text
gitea-valkey-cluster-0
gitea-valkey-cluster-1
gitea-valkey-cluster-2
gitea-valkey-cluster-3
gitea-valkey-cluster-4
gitea-valkey-cluster-5
```

All six nodes are masters and the cluster is configured without replicas:

```text
VALKEY_CLUSTER_REPLICAS="0"
```

The 16,384 hash slots are distributed across the masters:

```text
Node 0:     0-2730
Node 1:  2731-5460
Node 2:  5461-8191
Node 3:  8192-10922
Node 4: 10923-13652
Node 5: 13653-16383
```

This topology does not provide six-way redundancy. Each master exclusively owns
part of the hash space, so the loss or isolation of one master makes its slots
unavailable and can put the entire cluster into `cluster_state:fail`.

### Diagnosis

#### 1. Check Kubernetes status

```bash
kubectl -n gitea get pods -o wide
```

Several Valkey pods may appear as `0/1 Running`. This does not necessarily mean
that several Valkey processes have failed. The readiness probe runs:

```text
/scripts/ping_readiness_local.sh 1
```

Because this probe evaluates global cluster health, one unavailable master can
cause otherwise functional members to fail readiness with:

```text
Readiness probe failed: cluster_state:fail
```

#### 2. Inspect cluster health

```bash
kubectl -n gitea exec gitea-valkey-cluster-0 -- \
  valkey-cli CLUSTER INFO
```

During the incident, the cluster reported:

```text
cluster_state:fail
cluster_slots_assigned:16384
cluster_slots_ok:13653
cluster_slots_pfail:0
cluster_slots_fail:2731
cluster_known_nodes:6
cluster_size:6
```

Exactly 2,731 slots were unavailable, which corresponds to one master's slot
range.

#### 3. Identify the unavailable member

```bash
kubectl -n gitea exec gitea-valkey-cluster-0 -- \
  valkey-cli CLUSTER NODES
```

The healthy side of the cluster identified the failed member and retained its
slot ownership:

```text
93281dc6638d8c3c2aa8621f6c81e484008107e6 10.42.7.151:6379@16379 master,fail 13653-16383
```

The unavailable range `13653-16383` contains 2,731 slots, identifying
`gitea-valkey-cluster-5` as the isolated master.

#### 4. Compare membership views

Inspect the suspected member directly:

```bash
kubectl -n gitea exec gitea-valkey-cluster-5 -- \
  valkey-cli CLUSTER NODES
```

After pod rescheduling, `cluster-5` retained its original Valkey node ID and slot
ownership but knew its new pod IP:

```text
93281dc... 10.42.5.82:6379@16379 myself,master
```

It recorded all five peers at stale pod IP addresses and marked them `fail?`.
Its cluster status reflected the split view:

```text
cluster_slots_ok:2731
cluster_slots_pfail:13653
cluster_stats_messages_sent:0
cluster_stats_messages_received:0
```

The other five masters communicated with each other but still associated
`cluster-5`'s stable node ID with an old pod IP and marked it `master,fail`.
This inverse view indicates divergent address information rather than lost node
identity or slot metadata.

#### 5. Confirm startup and persistent data are healthy

Review the isolated pod's logs. In this incident, the Bitnami startup script
detected its changed pod IP:

```text
Changing old IP 10.42.7.105 by the new one 10.42.5.82
```

Valkey then loaded the original node identity and persisted data successfully:

```text
Node configuration loaded, I'm 93281dc6638d8c3c2aa8621f6c81e484008107e6
DB loaded from append only file
Ready to accept connections tcp
```

These messages rule out an application startup failure or obvious persistent
volume corruption.

#### 6. Verify network connectivity

Test the client port from the isolated member to every peer:

```bash
for i in 0 1 2 3 4; do
  kubectl -n gitea exec gitea-valkey-cluster-5 -- \
    valkey-cli \
      -h gitea-valkey-cluster-$i.gitea-valkey-cluster-headless \
      -p 6379 PING
done
```

Each healthy target should return `PONG`.

Test the cluster bus as well:

```bash
for i in 0 1 2 3 4; do
  kubectl -n gitea exec gitea-valkey-cluster-5 -- \
    timeout 2 bash -c \
    "echo >/dev/tcp/gitea-valkey-cluster-$i.gitea-valkey-cluster-headless/16379"
done
```

Successful connections on both `6379/tcp` and `16379/tcp` rule out basic pod
networking, Cilium routing, NetworkPolicy, and firewall failures. If either port
is unreachable, fix that network problem before changing Valkey membership.

### Root cause

Valkey persisted stable node IDs, slot ownership, cluster topology, and peer IP
addresses. Kubernetes StatefulSets preserve pod names and storage identities,
but not pod IP addresses. After pods were recreated or rescheduled, their IPs
changed.

The Bitnami startup logic updated the restarting node's own address, but cluster
gossip did not fully reconcile the peer addresses. The resulting split membership
view was:

```text
cluster-5
    |
    | knows its new IP
    | retains stale IPs for nodes 0-4
    |
    X
    |
nodes 0-4
    |
    | know each other's current IPs
    | retain a stale IP for node 5
```

Because all members were masters and there were no replicas, isolation of one
master made its 2,731 slots unavailable. Valkey changed the entire cluster to
`cluster_state:fail`, and Gitea session operations began returning `CLUSTERDOWN`.

### Recovery

!!! warning
    Use `CLUSTER MEET` only after confirming that the isolated process is the
    existing cluster member with the expected node ID, persistent data, and slot
    ownership. Also confirm connectivity on ports `6379` and `16379`. Do not use
    this procedure to add a replacement or newly initialized node.

When identity, data, slots, and connectivity are intact, reintroduce the isolated
member to one healthy member using that healthy member's **current pod IP**:

```bash
kubectl -n gitea exec gitea-valkey-cluster-5 -- \
  valkey-cli CLUSTER MEET <healthy-node-ip> 6379 16379
```

For the incident described here, the recovery command was:

```bash
kubectl -n gitea exec gitea-valkey-cluster-5 -- \
  valkey-cli CLUSTER MEET 10.42.0.237 6379 16379
```

The command returned `OK`. This re-established the cluster relationship and
allowed gossip to propagate current member addresses.

### Verify recovery

Check cluster health from both sides until their views agree:

```bash
kubectl -n gitea exec gitea-valkey-cluster-0 -- \
  valkey-cli CLUSTER INFO

kubectl -n gitea exec gitea-valkey-cluster-5 -- \
  valkey-cli CLUSTER INFO

kubectl -n gitea exec gitea-valkey-cluster-0 -- \
  valkey-cli CLUSTER NODES

kubectl -n gitea exec gitea-valkey-cluster-5 -- \
  valkey-cli CLUSTER NODES
```

Confirm all of the following:

- `cluster_state:ok`
- `cluster_slots_ok:16384`
- `cluster_slots_fail:0`
- Both membership views show the current pod addresses.
- All Valkey pods return to `1/1 Running`.
- Gitea OAuth login succeeds without `CLUSTERDOWN` errors.

### Destructive actions to avoid

Do not immediately use any of the following operations for an address-convergence
failure:

```text
CLUSTER FORGET
CLUSTER RESET
manual slot reassignment
PVC deletion
cluster recreation
```

They are unnecessary when the original node IDs, data, and slot ownership remain
intact. Using them prematurely can turn an address-convergence problem into a
data-loss or slot-ownership recovery problem.

### Follow-up actions

- Review the Valkey Helm configuration. Six masters with zero replicas means any
  isolated master can make the cluster unavailable.
- Determine whether replicated masters or a simpler highly available Valkey
  topology better fits Gitea's session and cache workload.
- Investigate why cluster gossip did not reconcile pod IP changes automatically.
- Review the deployed chart and Valkey versions for Kubernetes-aware address
  discovery or announcement settings.

### Incident summary

| Field | Details |
| --- | --- |
| Service | Gitea |
| Dependency | Valkey Cluster |
| Symptom | OAuth login failed with `CLUSTERDOWN The cluster is down` |
| Impact | Session-backed Gitea functionality failed; Git HTTP operations remained partially functional |
| Cause | Valkey members retained stale pod IPs after rescheduling, partitioning membership information |
| Amplifying factor | Six masters and zero replicas; loss of one master made 2,731 hash slots unavailable |
| Network | Pod connectivity on TCP ports 6379 and 16379 remained healthy |
| Data | Persistent data, node IDs, and slot ownership remained intact |
| Resolution | `CLUSTER MEET` re-established gossip between the isolated member and a healthy member |
| Data loss | None observed |
