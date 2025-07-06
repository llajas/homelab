# Virtualization Ansible Role

## ⚠️ Disclaimer: For Advanced Users Only

This role is a highly customized and opinionated solution for managing the lifecycle of virtualized Kubernetes nodes within a specific homelab environment. It is **not** a general-purpose tool and is not intended for the faint of heart. The setup requires specific hardware, a QEMU/KVM-ready hypervisor, and familiarity with Ansible, Terraform, and virtualization concepts like GPU passthrough.

Proceed with caution. This is tailored to a unique infrastructure, and adapting it will require a deep understanding of its inner workings.

## Overview

This Ansible role automates the provisioning and configuration of KVM/QEMU virtual machines intended to serve as nodes in a Kubernetes cluster. It handles the entire lifecycle, from creating the virtual machine and its disks to installing necessary packages and drivers post-boot.

The role is designed to be idempotent and is split into two distinct stages to match the provisioning workflow of this homelab:

1.  **Boot Stage (`tasks/boot.yml`):** Handles the initial creation of infrastructure. This includes initializing the hypervisor, creating the VMs via Terraform, setting up GPU passthrough, and configuring Wake-on-LAN.
2.  **Cluster Stage (`tasks/cluster.yml`):** Handles the configuration of the guest OS after it has been provisioned via PXE boot. This includes installing specific OS packages and GPU drivers.

## Use Case & Environment

The primary use case is the automated creation of virtual Kubernetes nodes on an UNRAID server.

### UNRAID Hypervisor

This role is explicitly designed to work with an **UNRAID** host. UNRAID provides the underlying QEMU/KVM hypervisor and a robust community-driven ecosystem.

### Virtual Machine Wake-on-LAN

A critical and highly specific dependency is the use of the **"Wake on LAN"** plugin from the UNRAID Community Apps store. The `update_vm_wol` task constructs a JSON payload and uses a `curl` command to interact with this plugin's web UI to enable the Wake-on-LAN feature for newly created virtual machines.

This is a crucial step in the automation chain, allowing the `wake` role to power on virtual machines alongside bare-metal machines.

## Requirements

-   **Hypervisor:** A QEMU/KVM-ready host. Designed for and tested on UNRAID 6.12+.
-   **Ansible:** Ansible 2.14+ - This must be installed on the Ansible control node and on the target QEMU host.
-   **Terraform:** Terraform must be installed on the Ansible control node.
-   **UNRAID Plugin:** The "Wake on LAN" Community App must be installed and running on the UNRAID host, otherwise you'll need to start the VM's manually.
-   **Hardware:** Hardware that supports IOMMU for GPU passthrough if you intend to use that feature. Configuring the hypervisor for GPU passthrough is outside the scope of this role, this role assumes that the hypervisor is already configured to support GPU passthrough and that the GPU is ready for consumption by the VMs.

## Adaptation

While heavily customized, the role can be adapted for other environments with some effort:

-   **Wake-on-LAN:** The `update_vm_wol.yml` task is the most UNRAID-specific part. To adapt this role for a different hypervisor (like a standard CentOS/Debian server with QEMU/KVM), you would need to replace the logic in this file with a method appropriate for your environment to enable WoL for VMs.
-   **Terraform:** The VM creation is handled by Terraform. The underlying provider can be modified to work with other libvirt-based systems.
-   **Configuration:** All configuration is driven by Ansible inventory variables. Review the files in `defaults/main.yml` and `vars/main.yml` to understand the required variables.
