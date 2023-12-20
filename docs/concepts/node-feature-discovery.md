# Node Feature Discovery

## Labeling Nodes

[Node Feature Discovery (NFD)](https://github.com/kubernetes-sigs/node-feature-discovery) is an application that automatically detects hardware features and system configuration of a node in a Kubernetes cluster. It is leveraged in this project to detect nodes that have Bluetooth hardware and apply labels accordingly which can be used by apps that require specific hardware for their deployments.

!!! tip
    Using tools like `lsusb` and `lspci` can help reveal the hardware/vendor ID's needed for creating a custom rule. Note that these tools are not installed on the nodes as part of this build.

### lsusb

- Install - `sudo dnf install usbutils -y`
- Removal - `sudo dnf remove usbutils -y; sudo dnf autoremove`


### lspci

- Install - `sudo dnf install pciutils -y`
- Removal - `sudo dnf remove pciutils -y; sudo dnf autoremove`

### Default Labels

NFD comes with [built-in labels](https://kubernetes-sigs.github.io/node-feature-discovery/v0.14/usage/features.html#built-in-labels) that surround the various aspects of the hardware, namely CPU featuresets.

## Reference

[Dynamic Node Labeling via Node Feature Discovery on Kubernetes](https://medium.com/@reefland/dynamic-kubernetes-node-labeling-via-node-feature-discovery-2c3e9c1879d1)
