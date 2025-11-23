# Unifi CloudKey Gen2+

## Overview

The Unifi CloudKey Gen2+ has been repurposed from its original role as a Unifi network controller to serve as a dedicated bastion host for the homelab cluster. This device was selected for its low power consumption and PoE (Power over Ethernet) capability, making it an ideal always-on entry point for automation and management tasks.

## Hardware Preparation

To ensure the device functions reliably as a standard Linux server, specific hardware and firmware modifications were required to overcome the limitations of the stock firmware, specifically regarding `fstab` persistence.

### J22 Header Access
Access to the device's internal J22 header was necessary to interface with the hardware directly. This process involved opening the device casing as detailed in the [Unifi Cloud Key Rescue](https://colincogle.name/blog/unifi-cloud-key-rescue/) guide.

### Firmware Modification
The stock firmware resets `fstab` on every reboot, which interferes with persistent storage configuration. To resolve this, a custom image was flashed to the eMMC storage. This modification sources the filesystem overlay configuration from a persistent location, effectively solving the reset issue.

Detailed steps for this procedure can be found in this [XDA Forums post](https://xdaforums.com/t/unifi-cloud-key-gen-2-plus.4664639/#post-89438067).

## Software Setup

Once the hardware was prepared and the base OS issues were resolved, the software environment was standardized using Infrastructure as Code principles.

### Operating System Upgrade
The device ships with an older version of Debian. An Ansible role was developed to automate the upgrade process to a modern Debian release:
[System Upgrade Role](https://github.com/llajas/new-system-upgrade-role)

### Environment Configuration
The local development environment, including tools and configurations, is managed via `chezmoi`. This ensures the bastion host maintains a consistent state with other development environments:
[Dotfiles](https://github.com/llajas/dotfiles)

## Specifications

| Component | Details |
| :--- | :--- |
| **CPU** | Octa-core Arm® Cortex®-A53 @ 2.2GHz |
| **RAM** | 3GB LPDDR3 |
| **Storage** | 512GB SSD<br>32GB eMMC<br>64GB microSD |
