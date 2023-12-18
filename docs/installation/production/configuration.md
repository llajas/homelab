# Configuration

Open the [tools container](../../concepts/tools-container.md), which includes all the tools needed:

=== "Docker"

    ```sh
    make tools
    ```

=== "Nix"

    ```sh
    nix-develop
    ```

!!! note

     It will take a while to build the tools container on the first time

Run the following script to configure the homelab:

```sh
make configure
```

!!! example

    <!-- TODO update example input -->

    ```
    Text editor (nvim):
    Enter seed repo (github.com/llajas/homelab): github.com/example/homelab
    Enter your domain (lajas.tech): example.com
    ```

It will prompt you to edit the inventory:

- IP address: the desired one, not the current one, since your servers have no operating system installed yet
- Disk: based on `/dev/$DISK`, in my case it's `sda`, but yours can be `sdb`, `nvme0n1`...
- Network interface: usually it's `eth0`, mine are `eno1` and `enp0s31f6`. Note that this is not arbitrary and must match what the host sets during setup. You can either search for the chipset behind the ethernet adapter or do a test run while attached to a screen to see what the value eventually turns into. See the following StackExchange/ServerFault links for more clarity:
    - [Why is my ethernet interface called enp0s10 instead of eth0?](https://unix.stackexchange.com/questions/134483/why-is-my-ethernet-interface-called-enp0s10-instead-of-eth0)
    - [disabling predictable network interface names in xubuntu 15.10](https://serverfault.com/questions/741210/disabling-predictable-network-interface-names-in-xubuntu-15-10%5D)
- Ensuring that the adapter is set properly will allow the host to take on the proper IP address defint in the inventory, else a DHCP address will be taken and cause issues with cluster connectivity unless set with a reserved address on the DHCP Server.
- MAC address: the **lowercase, colon separated** MAC address of the above network interface

!!! example

    ```yaml title="metal/inventories/prod.yml"
    --8<--
    metal/inventories/prod.yml
    --8<--
    ```

At the end it will show what has changed. After examining the diff, commit and push the changes.
