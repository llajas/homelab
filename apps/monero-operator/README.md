# Monero Operator Helm Chart

A Helm chart for deploying Monero-related Kubernetes resources, including nodes, networks, and miners.

## Features

- **MoneroNodeSet:** Deploy and manage Monero nodes.
- **MoneroMiningNodeSet:** Deploy and manage Monero miners.
- **MoneroNetwork:** Create and manage private Monero networks.

## Installation

```bash
helm install monero-release ./monero-chart --namespace monero-system --create-namespace
